## 좀비 프로세스 ##
분산 학습이 비정상 종료되면 일부 프로세스가 GPU를 잡고 안 놓는 경우가 생기게 된다. 이로인해서 다음 학습을 시작을 방해하게 되는데, "CUDA out of memory"가 뜨거나, GPU utilization이 0%인 상태로 남아 있게 된다.
```
정상 종료:
  학습 완료 → 모든 rank 프로세스 종료 → GPU 메모리 해제 ✅

비정상 종료:
  Node 3에서 OOM 크래시
  → Node 3의 프로세스 죽음
  → Node 0,1,2의 프로세스는 NCCL AllReduce에서 대기 중 (hang)
  → 타임아웃 후에도 GPU 메모리 안 놓음
  → 좀비 상태 
```
### 존비 감지 ###
### 1. GPU 좀비 감지 ###
```
# GPU를 점유하고 있는 프로세스 확인
nvidia-smi

# 출력 예시:
+-------+-----+------+-----+-----+---------+
| GPU   | PID | Type | SM% | Mem | Process |
+-------+-----+------+-----+-----+---------+
|   0   | 1234| C    |  0% | 40G | python  |  ← SM 0%인데 메모리 40G 점유 = 좀비
|   1   |  -  |  -   |  -  |  -  |    -    |
+-------+-----+------+-----+-----+---------+
```
#### 자동 감지 스크립트 ####
```
#!/bin/bash
# gpu_zombie_detector.sh

while true; do
    # GPU 사용 중인 프로세스 목록
    nvidia-smi --query-compute-apps=pid,gpu_uuid,used_memory,gpu_utilization \
               --format=csv,noheader,nounits | while IFS=, read -r pid gpu mem util; do
        
        # SM utilization이 0%인데 메모리를 1GB 이상 점유
        if [ "$util" -eq 0 ] && [ "$mem" -gt 1024 ]; then
            # 프로세스가 실제로 살아있는지 확인
            if ! kill -0 "$pid" 2>/dev/null; then
                echo "ZOMBIE: PID $pid is dead but holding ${mem}MB on $gpu"
            else
                # 살아있지만 10분 이상 GPU 0% → hang 상태
                age=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
                if [ -n "$age" ] && [ "$age" -gt 600 ]; then
                    echo "HANG: PID $pid, GPU 0% for ${age}s, holding ${mem}MB"
                fi
            fi
        fi
    done
    sleep 30
done
```

### 2. NCCL Hang 감지 ###
NCCL Hang은 통신에서 상대 노드를 무한 대기하는 상태이다.
```
# NCCL hang 상태 확인 - 프로세스 스택 트레이스
py-spy dump --pid <PID>

# 출력에서 이런 게 보이면 NCCL hang:
# Thread 1234:
#   ncclAllReduce (nccl/src/collectives.cc:123)
#   c10d::ProcessGroupNCCL::allreduce (...)
#   ← 여기서 멈춰있음
```

### 3. Slurm Job 기반 감지 ###
```
# Slurm job이 끝났는데 프로세스가 남아있는 경우
#!/bin/bash
# orphan_detector.sh

# 현재 노드에서 실행 중인 Slurm job 목록
active_jobs=$(squeue -h -w $(hostname) -o "%A" | sort)

# GPU를 쓰고 있는 프로세스의 Slurm job ID 확인
nvidia-smi --query-compute-apps=pid --format=csv,noheader | while read pid; do
    # 프로세스의 cgroup에서 Slurm job ID 추출
    job_id=$(cat /proc/$pid/cgroup 2>/dev/null | grep slurm | grep -oP 'job_\K\d+')
    
    if [ -n "$job_id" ]; then
        if ! echo "$active_jobs" | grep -q "$job_id"; then
            echo "ORPHAN: PID $pid belongs to finished job $job_id"
        fi
    fi
done
```

#### 4. DataLoader 워커 좀비 ####
```
# 부모 프로세스가 죽은 DataLoader 워커 찾기
ps aux | grep "dataloader" | grep -v grep

# 또는 PPID가 1(init)인 python 프로세스 = 고아 프로세스
ps -eo pid,ppid,cmd | grep python | awk '$2 == 1 {print "ORPHAN:", $0}'
```

### 방지 방법 ###
### 1. Slurm Epilog 스크립트 (가장 효과적) ###
Job이 끝나면 자동으로 정리:
```
# /etc/slurm/epilog.sh
#!/bin/bash
# Slurm이 job 종료 시 자동 실행

# 해당 job의 모든 프로세스 강제 종료
scontrol listpids ${SLURM_JOB_ID} | tail -n+2 | awk '{print $1}' | xargs -r kill -9

# GPU 프로세스 정리
nvidia-smi --query-compute-apps=pid --format=csv,noheader | while read pid; do
    # 이 프로세스가 현재 활성 job에 속하는지 확인
    job_id=$(cat /proc/$pid/cgroup 2>/dev/null | grep slurm | grep -oP 'job_\K\d+')
    if [ -z "$job_id" ] || ! squeue -j "$job_id" &>/dev/null; then
        echo "Killing orphan GPU process: $pid"
        kill -9 "$pid" 2>/dev/null
    fi
done

# GPU 상태 리셋 (MIG 모드가 아닌 경우)
nvidia-smi --gpu-reset 2>/dev/null || true

echo "Epilog cleanup completed for job ${SLURM_JOB_ID}"
```
```
# slurm.conf에 등록
Epilog=/etc/slurm/epilog.sh
EpilogSlurmctld=/etc/slurm/epilog.sh
# Job이 실패하든 성공하든 항상 실행됨
```

### 2. 학습 스크립트 내 방어 코드 ###
```
import signal
import sys
import torch
import torch.distributed as dist

def cleanup_handler(signum, frame):
    """시그널 받으면 깨끗하게 종료"""
    print(f"Rank {dist.get_rank()}: Received signal {signum}, cleaning up...")
    
    # NCCL 통신 그룹 정리
    if dist.is_initialized():
        dist.destroy_process_group()
    
    # GPU 메모리 해제
    torch.cuda.empty_cache()
    
    sys.exit(1)

# SIGTERM, SIGINT 핸들러 등록
signal.signal(signal.SIGTERM, cleanup_handler)
signal.signal(signal.SIGINT, cleanup_handler)

# 학습 코드를 try-finally로 감싸기
try:
    dist.init_process_group(backend='nccl', timeout=timedelta(minutes=5))
    train()
finally:
    if dist.is_initialized():
        dist.destroy_process_group()
    torch.cuda.empty_cache()
```

### 3. NCCL Watchdog 설정 ###
```
# 환경변수로 NCCL hang 방지
export TORCH_NCCL_HEARTBEAT_TIMEOUT_SEC=300    # 5분 후 자동 abort
export NCCL_TIMEOUT=300
export TORCH_NCCL_ENABLE_MONITORING=1          # 모니터링 활성화
export TORCH_NCCL_DUMP_ON_TIMEOUT=1            # 타임아웃 시 디버그 덤프
```

### 4. Slurm cgroup 설정 (근본적 방지) ###
```
# /etc/slurm/cgroup.conf
CgroupPlugin=cgroup/v2
ConstrainCores=yes
ConstrainDevices=yes         # GPU 디바이스 격리
ConstrainRAMSpace=yes
ConstrainSwapSpace=yes
SignalChildrenProcesses=yes  # Job 종료 시 모든 자식 프로세스에 시그널

# slurm.conf
TaskPlugin=task/cgroup,task/affinity
PrologFlags=Alloc            # 할당 시 prolog 실행
KillOnBadExit=1              # 한 태스크 실패 시 전체 job 종료
```
KillOnBadExit=1 의 경우 한 노드가 크래시하면 나머지 노드의 프로세스도 즉시 종료시켜서 NCCL hang을 방지한다.

