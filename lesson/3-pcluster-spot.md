## Spot 큐 사용하기 ##

CapacityType은 큐 레벨 설정이고 한 큐에 하나만 지정할 수 있다. Spot과 OnDemand를 둘 다 쓰려면 큐를 나눠야 한다.

```
Scheduling:
  Scheduler: slurm
  SlurmSettings:
    ScaledownIdletime: 300               # Idle 상태의 노드는 5분 후 삭제
    QueueUpdateStrategy: DRAIN           # 업데이트 시 실행 중인 작업이 끝날 때까지 대기 후 업데이트
    CustomSlurmSettings:
      - JobCompType: jobcomp/filetxt
      - JobCompLoc: /home/slurm/slurm-job-completions.txt
      - JobAcctGatherType: jobacct_gather/linux

  SlurmQueues:
    # ============================================================
    # 1) SPOT 큐 - 우선적으로 사용 (비용 절감)
    # ============================================================
    - Name: gpu-spot
      CapacityType: SPOT
      AllocationStrategy: capacity-optimized   # 중단 확률이 낮은 풀을 우선 선택
      Networking:
        SubnetIds:
          - ${PRIVATE_SUBNET_ID}
        PlacementGroup:
          Enabled: true                  # targeted ODCR 사용 시 false로 변경
        AdditionalSecurityGroups:
          - ${SECURITY_GROUP}
      ComputeSettings:
        LocalStorage:
          EphemeralVolume:
            MountDir: /scratch           # 인스턴스 로컬 NVMe scratch
          RootVolume:
            Size: 200
      JobExclusiveAllocation: true       # GenAI 훈련은 인스턴스의 모든 GPU를 점유
      ComputeResources:
        - Name: ml
          InstanceType: ${GPU_NODE_TYPE}
          MinCount: 0                    # static 노드 0개 → 완전 dynamic
          MaxCount: ${GPU_MAX}           # 필요 시 최대 GPU_MAX 대까지 자동 기동
          Efa:
            Enabled: true
      CustomActions:
        OnNodeConfigured:
          Sequence:
#            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/stop-ssm.sh'
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/docker.sh'
              Args:
                - 1.18.2-1              # NVIDIA_CONTAINER_TOOLKIT_VERSION
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/nccl.sh'
              Args:
                - v2.29.2-1             # NCCL version
                - v1.18.0               # AWS OFI NCCL version
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/enroot.sh'
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/dcgm.sh'
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/alloy.sh'
              Args:
                - ${LOKI_URL}

    # ============================================================
    # 2) ONDEMAND 큐 - Spot 용량 확보 실패 시 fallback
    # ============================================================
    - Name: gpu-ondemand
      CapacityType: ONDEMAND
      Networking:
        SubnetIds:
          - ${PRIVATE_SUBNET_ID}
        PlacementGroup:
          Enabled: true                  # targeted ODCR 사용 시 false로 변경
        AdditionalSecurityGroups:
          - ${SECURITY_GROUP}
      ComputeSettings:
        LocalStorage:
          EphemeralVolume:
            MountDir: /scratch           # 인스턴스 로컬 NVMe scratch
          RootVolume:
            Size: 200
      JobExclusiveAllocation: true       # GenAI 훈련은 인스턴스의 모든 GPU를 점유
      ComputeResources:
        - Name: ml
          InstanceType: ${GPU_NODE_TYPE}
          MinCount: 0                    # static 노드 0개 → 완전 dynamic
          MaxCount: ${GPU_MAX}           # 필요 시 최대 GPU_MAX 대까지 자동 기동
          Efa:
            Enabled: true
      CustomActions:
        OnNodeConfigured:
          Sequence:
#            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/stop-ssm.sh'
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/docker.sh'
              Args:
                - 1.18.2-1              # NVIDIA_CONTAINER_TOOLKIT_VERSION
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/nccl.sh'
              Args:
                - v2.29.2-1             # NCCL version
                - v1.18.0               # AWS OFI NCCL version
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/enroot.sh'
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/dcgm.sh'
            - Script: 'https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/setup/script/alloy.sh'
              Args:
                - ${LOKI_URL}
```

단, "무조건 별도 큐가 필요"한 건 Spot과 OnDemand를 동시에 쓰고 싶을 때이다. 만약 "그냥 Spot만 쓰겠다"면 기존 gpu 큐의 CapacityType을 SPOT으로 바꾸기만 하면 된다.

* Spot만 → 큐 1개, CapacityType: SPOT
* OnDemand만 → 큐 1개, CapacityType: ONDEMAND
* 둘 다 (fallback) → 큐 2개

실행시 partition 파라미터에 sport 을 먼저 지정한다. 
```
sbatch --partition=gpu-spot,gpu-ondemand train.sh
```
Slurm은 나열된 순서대로 파티션을 시도하므로, 앞에 있는 gpu-spot을 먼저 잡으려 하고 안 되면 gpu-ondemand로 넘어간다.
하지만 Spot으로 이미 시작한 뒤 중간에 Spot이 회수되면 그 작업은 그냥 실패 상태가 된다. 자동으로 OnDemand로 옮겨가지 않는다.

#### Spot 중단 시 작업을 자동으로 다시 큐에 넣으려면 ###

```bash
#!/bin/bash
#SBATCH --job-name=train
#SBATCH --partition=gpu-spot,gpu-ondemand    # Spot 우선, 실패 시 OnDemand
#SBATCH --nodes=2
#SBATCH --exclusive
#SBATCH --requeue                            # Spot 중단 시 자동 재큐

srun python train.py --checkpoint-dir /fsx/checkpoints
```

## 소프트웨어 버전 확인 ##

* 헤드노드 진입 (아래 둘중 하나의 명령어로 진입) 
```
pcluster ssh --cluster-name <클러스터이름> -i ~/.ssh/${KEY_NAME}.pem

aws ssm start-session --target <헤드노드-instance-id>
```

* 인터랙티브 세션으로 노드 띄우고 바로 들어가기
```
# 헤드노드에서 실행. GPU 노드 1대를 잡아서 셸을 띄움
srun --partition=gpu-spot --nodes=1 --exclusive --pty bash

# 이제 GPU 노드 안이므로 아래 명령들이 동작함
fi_info -p efa
find / -name "libnccl.so*" 2>/dev/null
ls /opt/aws-ofi-nccl/
nvidia-smi
```
