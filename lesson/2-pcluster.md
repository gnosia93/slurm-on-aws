
## [pcluster 설치하기](https://pypi.org/project/aws-parallelcluster/) ## 
pip, nodejs 및 aws-parallelcluster 클러스터를 설치한다.
```
sudo dnf install python3-pip -y
sudo dnf install nodejs -y

pip install aws-parallelcluster
pcluster version
```
[결과]
```
{
  "version": "3.14.2"
}
```

## 클러스터 생성하기 ##

```
[INFO] FSX_ID = fs-0cfc8084593407ace
[INFO] FSX_MOUNTNAME = obmixbev
[INFO] FSXO_ID = fsvol-0be57cf3806xxxxx
```

클러스터 생성에 필요한 환경변수 값을 설정한다. AZ 의 경우 1번을 사용하도록 한다. 
```bash
export CLUSTER_NAME="slurm-on-aws"
export CPU_INSTANCE_TYPE="m7i.8xlarge"
export GPU_INSTACNE_TYPE="g7e.8xlarge"
export AZ="1"

export AWS_DEFAULT_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
export PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SOA-pub-subnet-${AZ}" \
  --query "Subnets[0].SubnetId" --output text)
export PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SOA-priv-subnet-${AZ}" \
  --query "Subnets[0].SubnetId" --output text)
export SECURITY_GROUP=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ec2-host-sg" \
  --query "SecurityGroups[0].GroupId" --output text)

echo ${CLUSTER_NAME}
echo ${AWS_DEFAULT_REGION}
echo ${AWS_ACCOUNT_ID}
echo ${VPC_ID}
echo ${PUBLIC_SUBNET_ID}
echo ${PRIVATE_SUBNET_ID}
echo ${SECURITY_GROUP}
```

GPU_INSTACNE_TYPE 인스턴스의 efa 정보를 조회한다. 
```
aws ec2 describe-instance-types \
    --instance-types ${GPU_INSTACNE_TYPE} \
    --query "InstanceTypes[*].{InstanceType:InstanceType, \
        EfaSupported:NetworkInfo.EfaSupported, \
        MaxNetworkInterfaces:NetworkInfo.MaximumNetworkInterfaces, \
        MaxEfaInterfaces:NetworkInfo.EfaInfo.MaximumEfaInterfaces, \
        NetworkPerformance:NetworkInfo.NetworkPerformance}" --output table
```
[결과]
```
----------------------------------------------------------------------------------------------------
|                                       DescribeInstanceTypes                                      |
+--------------+---------------+-------------------+------------------------+----------------------+
| EfaSupported | InstanceType  | MaxEfaInterfaces  | MaxNetworkInterfaces   | NetworkPerformance   |
+--------------+---------------+-------------------+------------------------+----------------------+
|  True        |  g7e.8xlarge  |  1                |  8                     |  100 Gigabit         |
+--------------+---------------+-------------------+------------------------+----------------------+
```

### 키페어 생성 ###
```
aws ec2 create-key-pair --key-name slurm-key --region ${AWS_DEFAULT_REGION} --key-type ed25519 \
  --query 'KeyMaterial' --output text > slurm-key.pem

chmod 400 slurm-key.pem
```



pcluster 용 cluster.yaml 파일을 생성한다. ParallelCluster가 자동으로 보안 그룹을 생성하고 헤드노드-컴퓨트노드 간 통신, SLURM 포트, NFS/EFS 포트 등이 자동으로 설정한다.   
AdditionalSecurityGroups은 다음과 같은 경우 설정한다.
* 외부에서 헤드노드에 SSH 접속하려면 22번 포트 인바운드를 열어야 한다.
* 기존 VPC의 보안 그룹을 사용하고 싶다면 yaml에 지정 가능하다
```
cat > cluster.yaml << EOF
Imds:
  ImdsSupport: v1.0
Image:
  Os: ubuntu2204
HeadNode:
  InstanceType: ${CPU_INSTANCE_TYPE}
  Ssh:
    KeyName: slurm-key          # 여기 추가
  Networking:
    SubnetId: ${PUBLIC_SUBNET_ID}
    AdditionalSecurityGroups:
      - ${SECURITY_GROUP}
  LocalStorage:
    RootVolume:
      Size: 500
      DeleteOnTermination: true                 # that's your root and /home volume for users
  Iam:
    AdditionalIamPolicies: # grant ECR, SSM and S3 read access
      - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      - Policy: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
      - Policy: arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
      - Policy: arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess
#  CustomActions:
#    OnNodeConfigured:
#      Sequence:
#        - Script: 'https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/docker/postinstall.sh'
#        - Script: 'https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/nccl/postinstall.sh'
#          Args:
#            - v2.23.4-1 # NCCL version
#            - v1.11.0-aws # AWS OFI NCCL version
  Imds:
    Secured: false
Scheduling:
  Scheduler: slurm
  SlurmSettings:
    ScaledownIdletime: 60
    QueueUpdateStrategy: DRAIN
    CustomSlurmSettings:
      # Simple accounting to text file /home/slurm/slurm-job-completions.txt.
      - JobCompType: jobcomp/filetxt
      - JobCompLoc: /home/slurm/slurm-job-completions.txt
      - JobAcctGatherType: jobacct_gather/linux
  SlurmQueues:
    - Name: gpu
      CapacityType: ONDEMAND
      Networking:
        SubnetIds:
          - ${PRIVATE_SUBNET_ID}
        PlacementGroup:
          Enabled: true                  # set this to false if using a targeted ODCR
        AdditionalSecurityGroups:
          - ${SECURITY_GROUP}
      ComputeSettings:
        LocalStorage:
          EphemeralVolume:
            MountDir: /scratch           # each instance has a local scratch on NVMe
          RootVolume:
            Size: 200
      JobExclusiveAllocation: true       # GenAI training likes to gobble all GPUs in an instance
      ComputeResources:
        - Name: ml
          InstanceType: ${GPU_INSTACNE_TYPE}
          MinCount: 2                    # if min = max then capacity is maintained and will
          MaxCount: 2                    # not scale down
          Efa:
            Enabled: true
#      CustomActions:
#        OnNodeConfigured:
#          Sequence:
#            - Script: 'https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/docker/postinstall.sh'
#            - Script: 'https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/nccl/postinstall.sh'
#              Args:
#                - v2.23.4-1             # NCCL version
#                - v1.11.0-aws           # AWS OFI NCCL version
#SharedStorage:
#  - Name: HomeDirs
#    MountDir: /home
#    StorageType: FsxOpenZfs
#    FsxOpenZfsSettings:
#      VolumeId: ${FSXO_ID}
#  - MountDir: /fsx
#    Name: fsx
#    StorageType: FsxLustre
#    FsxLustreSettings:
#      FileSystemId: ${FSX_ID}
Monitoring:
  DetailedMonitoring: true
  Logs:
    CloudWatch:
      Enabled: true # good for debug
  Dashboards:
    CloudWatch:
      Enabled: true # provide basic dashboards
Tags:
  - Key: 'Grafana'
    Value: 'true'
EOF
```
클러스터를 생성한다. 
```
pcluster create-cluster -n ${CLUSTER_NAME} -c cluster.yaml --rollback-on-failure false
```
[결과]
```
{
  "cluster": {
    "clusterName": "slurm-on-aws",
    "cloudformationStackStatus": "CREATE_IN_PROGRESS",
    "cloudformationStackArn": "arn:aws:cloudformation:ap-northeast-2:499514681453:stack/slurm-on-aws/2bed8870-1c98-11f1-b93a-0617e7ce90ef",
    "region": "ap-northeast-2",
    "version": "3.14.2",
    "clusterStatus": "CREATE_IN_PROGRESS",
    "scheduler": {
      "type": "slurm"
    }
  },
  "validationMessages": [
    {
      "level": "WARNING",
      "type": "DetailedMonitoringValidator",
      "message": "Detailed Monitoring is enabled for EC2 instances in your compute fleet. The Amazon EC2 console will display monitoring graphs with a 1-minute period for these instances. Note that this will increase the cost. If you want to avoid this and use basic monitoring instead, please set `Monitoring / DetailedMonitoring` to false."
    },
    {
      "level": "WARNING",
      "type": "KeyPairValidator",
      "message": "If you do not specify a key pair, you can't connect to the instance unless you choose an AMI that is configured to allow users another way to log in"
    }
  ]
}
```

생성된 클러스터를 조회한다. 
```
pcluster list-clusters
```
[결과]
```
{
  "clusters": [
    {
      "clusterName": "slurm-on-aws",
      "cloudformationStackStatus": "CREATE_COMPLETE",
      "cloudformationStackArn": "arn:aws:cloudformation:ap-northeast-2:499514681453:stack/slurm-on-aws/c71a5560-1d35-11f1-ba26-0abf24fe3867",
      "region": "ap-northeast-2",
      "version": "3.14.2",
      "clusterStatus": "CREATE_COMPLETE",
      "scheduler": {
        "type": "slurm"
      }
    }
  ]
}
```
AWS 콘솔에서 생성된 리소스를 확인한다.  
[cloudformation]
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/cf-slurm.png)

[ec2]
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/cf-slurm-2.png)

헤드 노드로 로그인해서 클러스터 노드 정보를 조회한다. 
```
pcluster ssh -n slurm-on-aws -i ~/slurm-key.pem

sinfo -N
```
[결과]
```
NODELIST                  NODES    PARTITION STATE 
gpu-st-ml-1      1 compute-gpu* idle  
gpu-st-ml-2      1 compute-gpu* idle
```
컴퓨트 노드 상세 정보를 조회한다. 
```
scontrol show node gpu-st-ml-1
```
[결과]
```
NodeName=gpu-st-ml-1 Arch=x86_64 CoresPerSocket=1 
   CPUAlloc=0 CPUEfctv=32 CPUTot=32 CPULoad=1.23
   AvailableFeatures=static,g7e.8xlarge,dist-ml,efa,gpu
   ActiveFeatures=static,g7e.8xlarge,dist-ml,efa,gpu
   Gres=gpu:rtxproserver6000:1
   NodeAddr=10.0.10.160 NodeHostName=gpu-st-ml-1 Version=24.11.7
   OS=Linux 6.8.0-1045-aws #47~22.04.1-Ubuntu SMP Thu Jan 29 21:28:23 UTC 2026 
   RealMemory=249036 AllocMem=0 FreeMem=239612 Sockets=32 Boards=1
   State=IDLE+CLOUD ThreadsPerCore=1 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=compute-gpu 
   BootTime=2026-03-11T11:04:15 SlurmdStartTime=2026-03-11T11:05:49
   LastBusyTime=2026-03-11T11:05:51 ResumeAfterTime=None
   CfgTRES=cpu=32,mem=249036M,billing=32
   AllocTRES=
   CurrentWatts=0 AveWatts=0
   
   Reason=Node start up [root@2026-03-11T11:05:51]
   InstanceId=i-0cba89ff05359cd2f InstanceType=g7e.8xlarge
```

```
sudo vi /opt/slurm/etc/slurm.conf
# CLUSTER SETTINGS
ResumeTimeout=3600     <--- 추가 

sudo /opt/slurm/bin/scontrol reconfigure
scontrol show config | grep -i ResumeTimeout
```
[결과]
```
Configuration data as of 2026-03-11T11:45:41
AccountingStorageBackupHost = (null)
AccountingStorageEnforce = none
AccountingStorageHost   = localhost
AccountingStorageExternalHost = (null)
AccountingStorageParameters = (null)
AccountingStoragePort   = 0
AccountingStorageTRES   = cpu,mem,energy,node,billing,fs/disk,vmem,pages
AccountingStorageType   = (null)
...
```



ssh 를 이용하여 컴퓨트 노드로 접속한다. 
```
ssh gpu-st-ml-1
```

### nvidia device driver 확인 ###
```
nvidia-smi
```
[결과]
```
Wed Mar 11 11:30:59 2026       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 570.172.08             Driver Version: 570.172.08     CUDA Version: 12.8     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA RTX PRO 6000 Blac...    On  |   00000000:30:00.0 Off |                    0 |
| N/A   27C    P8             28W /  600W |       0MiB /  97887MiB |      0%      Default |
|                                         |                        |             Disabled |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

### ###



## trouble shooting ##
#### compute 노드가 10분 단위로 termination 됨 ####
1. 컴퓨트 노드에서 SSM Agent 자체를 끄기 (부팅 때마다 해야 함)
```
sudo systemctl stop snap.amazon-ssm-agent.amazon-ssm-agent.service
sudo systemctl disable snap.amazon-ssm-agent.amazon-ssm-agent.service
```

2. cluster.yaml에서 PostInstall 스크립트로 영구 적용:
```
CustomActions:
  OnNodeConfigured:
    Script: s3://your-bucket/disable-ssm.sh

disable-ssm.sh 내용:

#!/bin/bash
systemctl stop snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl disable snap.amazon-ssm-agent.amazon-ssm-agent.service
```
하지만 SSM 전체를 끄면 SSM Session Manager 접속도 안 됩니다. 더 나은 방법은 Patch Manager association만 제거하는 것입니다:

# 패치 association 찾기
aws ssm list-associations --region ap-northeast-2 --query "Associations[*].[AssociationId,Name,Targets]" --output table
이걸로 AWS-RunPatchBaseline 관련 association을 찾아서 삭제하면 SSM은 살리면서 자동 패치만 막을 수 있어요


## 클러스터 삭제하기 ##
```
pcluster delete-cluster -n ${CLUSTER_NAME} 
```

## 레퍼런스 ##

* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US
* https://aws.amazon.com/ko/blogs/korea/announcing-amazon-ec2-g7e-instances-accelerated-by-nvidia-rtx-pro-6000-blackwell-server-edition-gpus/
