
## [pcluster 설치하기](https://pypi.org/project/aws-parallelcluster/) ## 
```
sudo dnf install python3-pip -y

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
[INFO] SECURITY_GROUP = sg-094ac36f5e082cf86
```


```bash
export CLUSTER_NAME="slurm-on-aws"
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
export PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SOA-pub-subnet-1" \
  --query "Subnets[0].SubnetId" --output text)
export PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SOA-priv-subnet-1" \
  --query "Subnets[0].SubnetId" --output text)
export SECURITY_GROUP=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ec2-host-sg" \
  --query "SecurityGroups[0].GroupId" --output text)

export CPU_INSTANCE_TYPE="m7i.8xlarge"
export GPU_INSTACNE_TYPE="g6e.8xlarge"

echo ${CLUSTER_NAME}
echo ${AWS_REGION}
echo ${AWS_ACCOUNT_ID}
echo ${VPC_ID}
echo ${PUBLIC_SUBNET_ID}
echo ${PRIVATE_SUBNET_ID}
echo ${SECURITY_GROUP}
```

```
aws ec2 describe-instance-types \
    --instance-types ${GPU_INSTACNE_TYPE} \
    --query "InstanceTypes[*].{InstanceType:InstanceType, \
        EfaSupported:NetworkInfo.EfaSupported, \
        MaxNetworkInterfaces:NetworkInfo.MaximumNetworkInterfaces, \
        MaxEfaInterfaces:NetworkInfo.EfaInfo.MaximumEfaInterfaces, \
        NetworkPerformance:NetworkInfo.NetworkPerformance}" --output table
```

```
source env_vars
cat > config.yaml << EOF
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


## 레퍼런스 ##

* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US
