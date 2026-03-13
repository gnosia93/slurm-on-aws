
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
### 환경변수 설정 ###

클러스터 생성에 필요한 환경변수 값을 설정한다. AZ 의 경우 1번을 사용하도록 한다. 
```bash
export CLUSTER_NAME="slurm-on-aws"
export CPU_INSTANCE_TYPE="m6i.4xlarge"
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


### slurm 클러스터 생성 ###
pcluster 용 cluster.yaml 파일을 생성한다. ParallelCluster가 자동으로 보안 그룹을 생성하고 헤드노드-컴퓨트노드 간 통신, SLURM 포트, NFS/EFS 포트 등이 자동으로 설정한다.   
AdditionalSecurityGroups은 다음과 같은 경우 설정한다.
* 외부에서 헤드노드에 SSH 접속하려면 22번 포트 인바운드를 열어야 한다.
* 기존 VPC의 보안 그룹을 사용하고 싶다면 yaml에 지정 가능하다
```
export GPU_MIN=2
export GPU_MAX=2

cat > cluster.yaml << EOF
Imds:
  ImdsSupport: v1.0
Image:
  Os: ubuntu2204
HeadNode:
  InstanceType: ${CPU_INSTANCE_TYPE}
  Ssh:
    KeyName: slurm-key
  Networking:
    SubnetId: ${PUBLIC_SUBNET_ID}
    AdditionalSecurityGroups:
      - ${SECURITY_GROUP}
  LocalStorage:
    RootVolume:
      Size: 500
      DeleteOnTermination: true                 # that's your root and /home volume for users
  Iam:
    AdditionalIamPolicies:
      - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      - Policy: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
      - Policy: arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
      - Policy: arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess
  CustomActions:
    OnNodeConfigured:
      Sequence:
#        - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/stop-ssm.sh'
        - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/docker.sh'
          Args:
            - 1.18.2-1                         # NVIDIA_CONTAINER_TOOLKIT_VERSION version
        - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/slurm-exporter.sh'
  Imds:
    Secured: false
Scheduling:
  Scheduler: slurm
  SlurmSettings:
    ScaledownIdletime: 300               # Idle 상태의 노드의 경우 5분후 삭제
    QueueUpdateStrategy: DRAIN           # 클러스터 업데이트시 DRAIN은 실행 중인 작업이 끝날 때까지 대기후 업데이트, TERMINATE은 실행 중인 작업을 즉시 종료하고 바로 업데이트
    CustomSlurmSettings:
      #- SlurmdTimeout: 1800              # slurmctld가 slurmd의 응답 최대 대기 시간(초), 이 시간 내에 slurmd가 응답하지 않으면, 해당 노드를 DOWN 상태로 전환, 기본값 3분(180)
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
          MinCount: ${GPU_MIN}
          MaxCount: ${GPU_MAX}
          Efa:
            Enabled: true
      CustomActions:
        OnNodeConfigured:
          Sequence:
#            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/stop-ssm.sh'
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/docker.sh'
              Args:
                - 1.18.2-1              # NVIDIA_CONTAINER_TOOLKIT_VERSION version
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/nccl.sh'
              Args:
                - v2.29.2-1             # NCCL version
                - v1.18.0               # AWS OFI NCCL version
#            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/enroot.sh'
#            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/dcgm.sh'
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
  DetailedMonitoring: false
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
    "cloudformationStackArn": "arn:aws:cloudformation:ap-northeast-2:499514681453:stack/slurm-on-aws/45cd1ba0-1ec0-11f1-ae57-0aa0bd5694a3",
    "region": "ap-northeast-2",
    "version": "3.14.2",
    "clusterStatus": "CREATE_IN_PROGRESS",
    "scheduler": {
      "type": "slurm"
    }
  }
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


### AWS 콘솔에서 확인 ###
AWS 콘솔에서 생성된 리소스를 확인한다.  
[cloudformation]
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/cf-slurm.png)

[ec2]
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/cf-slurm-2.png)


### 클러스터 상세 정보 조회 ###

헤드 노드로 로그인해서 클러스터 노드 정보를 조회한다. 
```
pcluster ssh -n ${CLUSTER_NAME} -i ~/slurm-key.pem

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
slurm 설정 조회하기 
```
scontrol show config 
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

### 클러스터 생성 로그 조회 ###
클러스터 생성 완료 후, 헤드 노드에서 아래의 명령어를 이용하여 클러스터 프러비저닝시 생성된 로그 파일을 조회할 수 있다. 
```
# CloudFormation 초기화 로그 (클러스터 생성 과정)
sudo cat /var/log/cfn-init.log

# cloud-init 로그
sudo cat /var/log/cloud-init-output.log

# ParallelCluster 설치 로그
sudo cat /var/log/parallelcluster/slurm_resume
```


### 컴퓨트 노드 확인 ###
ssh 를 이용하여 컴퓨트 노드로 접속한다. 
```
ssh gpu-st-ml-1
```

#### 1. nvidia device driver 확인 ####
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

#### 2. Docker 및 NVIDIA Container Toolkit 확인 ####
```
docker -v
nvidia-ctk --version

docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi
```
[결과]
```
Unable to find image 'nvidia/cuda:12.8.0-base-ubuntu22.04' locally
12.8.0-base-ubuntu22.04: Pulling from nvidia/cuda
4b650590013c: Pull complete 
7d21de8cade1: Pull complete 
ad69d3880477: Pull complete 
2d01ee89ef0b: Pull complete 
Digest: sha256:12242992c121f6cab0ca11bccbaaf757db893b3065d7db74b933e59f321b2cf4
Status: Downloaded newer image for nvidia/cuda:12.8.0-base-ubuntu22.04
Thu Mar 12 12:27:38 2026       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 570.172.08             Driver Version: 570.172.08     CUDA Version: 12.8     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA RTX PRO 6000 Blac...    On  |   00000000:30:00.0 Off |                    0 |
| N/A   27C    P8             30W /  600W |       0MiB /  97887MiB |      0%      Default |
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

#### 3. CUDA Toolkit 확인 ####

nvcc 는 NVIDIA CUDA Compiler 로 .cu 파일(CUDA C/C++ 코드)을 GPU에서 실행 가능한 바이너리로 컴파일하는 컴파일러이다.
gcc가 C 컴파일러인 것처럼, nvcc는 CUDA 컴파일러이다. CUDA Toolkit에 포함되어 있어서 CUDA Toolkit 설치 확인용으로 많이 쓰인다.
```
# CUDA 버전 확인
nvcc --version

# CUDA 설치 경로 확인
ls -la /usr/local/cuda

# CUDA 라이브러리 확인
ls /usr/local/cuda/lib64/
```

#### 4. MPI 확인 ####
Message Passing Interface 는 분산 컴퓨팅에서 노드 간 메시지를 주고받기 위한 표준 규격이고, 구현체로는 OpenMPI, Intel MPI, MPICH 등이 있다.
GPU 1개짜리 작업이면 MPI 필요 없지만, 여러 노드에 걸쳐 분산 학습을 하려면 노드 간 통신이 필요하고, 그 통신 레이어가 MPI 이다. 즉 MPI는 GPU 자체를 위한 게 아니라, 여러 노드의 GPU를 묶어서 쓰기 위한 프로세스 관리/통신 프레임워크로, mpirun -np 4 --hostfile hosts python train.py 이런 식으로 4개 노드에 학습 프로세스를 동시에 띄우는 역할을 한다.
전통적인 HPC 환경에서는 MPI 를 이용해서 통신을 조율하고 pytorch 의 경우 torchrun 기반으로 프로세스간의 통신을 조율한다 (MPI 없이도 동작)
* NCCL: GPU ↔ GPU 간 데이터 전송 (gradient 교환 등)
* MPI: 프로세스 런칭 및 조율 (mpirun으로 여러 노드에 프로세스 띄우기)
* EFA: 네트워크 하드웨어 (RDMA로 저지연 통신)
```
ls -l /opt/amazon/openmpi  # 경로가 존재하는지 확인
mpirun --version           # MPI 실행 도구가 잡히는지 확인
```

#### 5. efa / aws-ofi-nccl 확인 ####
aws-ofi-nccl은 NCCL이 EFA(Elastic Fabric Adapter)를 통해 통신할 수 있게 해주는 플러그인으로, EFA를 쓰는 멀티노드 GPU 학습에 필수이다.
```
fi_info -p efa
lsmod | grep efa

ls /opt/aws-ofi-nccl/
```
* aws-ofi-nccl 버전을 출력하는 방법을 확인해야 한다. 


#### 6. nccl 버전 확인 ####
```
cat /opt/nccl/makefiles/version.mk 2>/dev/null
```
[결과]
```
##### version
NCCL_MAJOR   := 2
NCCL_MINOR   := 29
NCCL_PATCH   := 2
NCCL_SUFFIX  :=
PKG_REVISION := 1
```

#### 7. fabric manager 확인 ####
nvlink 또는 nvswitch 로 연결된 서버에서 활성화 되어 있어야 한다.
```
sudo systemctl status nvidia-fabricmanager
```

## 레퍼런스 ##

* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US
* https://aws.amazon.com/ko/blogs/korea/announcing-amazon-ec2-g7e-instances-accelerated-by-nvidia-rtx-pro-6000-blackwell-server-edition-gpus/
* https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
