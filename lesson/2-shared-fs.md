## FSX for Lustre 파일 시스템 생성 ##

### 1. 스토리지 구성 레이아웃 ###
```
/home (ZFS - Zetta):
  - 소스 코드, 설정 파일, 스크립트
  - 용량 작고, I/O 적음
  - 스냅샷으로 실수 복구 가능
  - 사용자별 환경 관리

/scratch (local NVME)

/fsx (Lustre):
  - 학습 데이터셋 (수 TB)
  - 체크포인트 (수십~수백 GB)
  - 수백 GPU가 동시에 읽기/쓰기
  - 초고속 I/O 필요
```

### 2. Lustre 파일시스템 생성 ###
lustre 는 성능을 위해 하나의 AZ 에만 생성된다.
PerUnitStorageThroughput 옵션은 PERSISTENT_2 의 경우 125, 250, 500, 1000 까지 지원하며, AI 클러스터의 경우 500 이상을 설정하는 것이 좋다. (필요 IO Throughput 계산 결과에 따라 설정).
아래 예시에서는 125 값을 설정하는데 1 TiB 당 125 MB/s 의 처리량(Troughput) 을 제공한다는 의미이다.

```
export CLUSTER_NAME="slurm-on-aws"
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
export VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids ${VPC_ID} --query "Vpcs[0].CidrBlock" --output text)

echo "cluster name: $CLUSTER_NAME"
echo "aws regin: $AWS_REGION"
echo "account id: $AWS_ACCOUNT_ID"
echo "vpc id: $VPC_ID"
echo "vpc cidr: $VPC_CIDR"

export SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=SOA-priv-subnet-1" "Name=vpc-id,Values=${VPC_ID}" \
    --query "Subnets[*].{ID:SubnetId}" --output text)
echo $SUBNET_IDS
```
LUSTRE 용 시큐리티 그룹을 생성한다.
```
LUSTRE_SG_ID=$(aws ec2 create-security-group --group-name fsx-lustre-sg \
  --description "FSx Lustre Access" \
  --vpc-id ${VPC_ID} --query "GroupId" --output text)
echo "LUSTRE_SG_ID: ${LUSTRE_SG_ID}"

aws ec2 authorize-security-group-ingress \
  --group-id ${LUSTRE_SG_ID} --protocol tcp --port 988 --cidr ${VPC_CIDR}
```

Lustre 파일 시스템을 생성한다.
```
LUSTRE_ID=$(aws fsx create-file-system --file-system-type LUSTRE \
  --storage-capacity 1200 \
  --subnet-ids ${SUBNET_ID} \
  --security-group-ids ${LUSTRE_SG_ID} \
  --lustre-configuration DeploymentType=PERSISTENT_2,PerUnitStorageThroughput=125,DataCompressionType=LZ4 \
  --tags Key=Name,Value=${CLUSTER_NAME} \
  --query "FileSystem.FileSystemId" \
  --output text)
#    ImportPath=s3://my-bucket/data,\
#    ExportPath=s3://my-bucket/output \

echo ${LUSTRE_ID}
```
생성된 파일시스템을 조회한다. 
```
aws fsx describe-file-systems --file-system-ids ${LUSTRE_ID}
```

> [!NOTE]
> 파일 시스템 삭제:
>  
> aws fsx delete-file-system --file-system-id ${LUSTRE_ID}


### 3. OpenZFS 생성하기 ###
NFS 용 시큐리티 그룹을 생성한다. 
```
SG_ID=$(aws ec2 create-security-group --group-name fsx-openzfs-sg \
  --description "FSx OpenZFS NFS access" \
  --vpc-id ${VPC_ID} --query "GroupId" --output text)
echo "sg-id: ${SG_ID}"

aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} --protocol tcp --port 111 --cidr ${VPC_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} --protocol tcp --port 2049 --cidr ${VPC_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} --protocol tcp --port 20001-20003 --cidr ${VPC_CIDR}

aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} --protocol udp --port 111 --cidr ${VPC_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} --protocol udp --port 2049 --cidr ${VPC_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} --protocol udp --port 20001-20003 --cidr ${VPC_CIDR}
```
OpenZFS 파일 시스템을 생성한다. 
```
ZFS_ID=$(aws fsx create-file-system --file-system-type OPENZFS \
  --storage-capacity 64 --storage-type SSD \
  --subnet-ids ${SUBNET_ID} \
  --security-group-ids ${SG_ID} \
  --open-zfs-configuration '{
    "DeploymentType": "SINGLE_AZ_1",
    "ThroughputCapacity": 64,
    "RootVolumeConfiguration": {
      "NfsExports": [{
        "ClientConfigurations": [{
          "Clients": "'"${VPC_CIDR}"'",
          "Options": ["rw","crossmnt","no_root_squash"]
        }]
      }]
    }
  }' \
  --query "FileSystem.FileSystemId" \
  --output text)

echo  ${ZFS_ID}
```

> [!NOTE]
> 시큐리티 그룹 삭제:
>  
> aws ec2 delete-security-group --group-id ${SG_ID}

## Additional Explanation ##

### 네트워크 아키텍처 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/network-1.png)

### ZFS 마운트 ###
```
# DNS 이름 확인 후
sudo mkdir -p /home
sudo mount -t nfs -o nfsvers=4.1 fs-xxxx.fsx.ap-northeast-2.amazonaws.com:/fsx /home

# 영구 마운트 (/etc/fstab)
echo "fs-xxxx.fsx.ap-northeast-2.amazonaws.com:/fsx /home nfs4 nfsvers=4.1,defaults 0 0" | sudo tee -a /etc/fstab
```

