
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

클러스터 생성에 필요한 환경변수 값을 설정한다. 서브넷의 경우 2번을 사용하도록 한다. 
```bash
export CLUSTER_NAME="slurm-on-aws"

export AWS_DEFAULT_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
export PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SOA-pub-subnet-2" \
  --query "Subnets[0].SubnetId" --output text)
export PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SOA-priv-subnet-2" \
  --query "Subnets[0].SubnetId" --output text)
export SECURITY_GROUP=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ec2-host-sg" \
  --query "SecurityGroups[0].GroupId" --output text)

export CPU_INSTANCE_TYPE="m7i.8xlarge"
export GPU_INSTACNE_TYPE="g6e.12xlarge"

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
|  True        |  g6e.12xlarge |  1                |  10                    |  100 Gigabit         |
+--------------+---------------+-------------------+------------------------+----------------------+
```

pcluster 용 cluster.yaml 파일을 생성한다. 
```
cat > cluster.yaml << EOF
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

Imds:
  ImdsSupport: v1.0
Image:
  Os: ubuntu2204
HeadNode:
  InstanceType: ${CPU_INSTANCE_TYPE}
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
  CustomActions:
    OnNodeConfigured:
      Sequence:
        - Script: 'https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/docker/postinstall.sh'
        - Script: 'https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/nccl/postinstall.sh'
          Args:
            - v2.23.4-1 # NCCL version
            - v1.11.0-aws # AWS OFI NCCL version
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
    - Name: compute-gpu
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
        - Name: dist-ml
          InstanceType: ${GPU_INSTACNE_TYPE}
          MinCount: 4                    # if min = max then capacity is maintained and will
          MaxCount: 4                    # not scale down
          Efa:
            Enabled: true
      CustomActions:
        OnNodeConfigured:
          Sequence:
            - Script: 'https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/docker/postinstall.sh'
            - Script: 'https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/nccl/postinstall.sh'
              Args:
                - v2.23.4-1             # NCCL version
                - v1.11.0-aws           # AWS OFI NCCL version
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
pcluster create-cluster -n ${CLUSTER_NAME} -c cluster.yaml
```


## 레퍼런스 ##

* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US
