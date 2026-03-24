#!/bin/bash

LOG="/var/log/slurm/epilog.log"
echo "$(date) [Job $SLURM_JOB_ID] Epilog start on $(hostname)" >> $LOG


# GPU 클러스터에서 좀비 프로세스가 남는 주요 원인:
#
# 1. 멀티노드 학습 비정상 종료
# 노드 0에서 에러 → 노드 0 프로세스는 죽음
# 노드 1~3은 NCCL 통신 대기 상태로 hang
# slurm이 scancel로 잡 취소해도 NCCL 대기 중인 프로세스가 안 죽는 경우 있음
# 2. OOM kill
# 메인 프로세스는 OOM으로 죽었는데 DataLoader 워커 프로세스가 살아남음
# num_workers=8 같은 서브프로세스들이 부모 없이 남는 것
# 3. scancel 시그널 무시
# scancel → SIGTERM 전송 → 프로세스가 SIGTERM 핸들러에서 체크포인트 저장 중 hang
# 타임아웃 후 SIGKILL 보내지만, GPU 커널 실행 중이면 즉시 안 죽을 수 있음
# 4. CUDA 컨텍스트 잔류
# 프로세스는 죽었는데 GPU 메모리에 CUDA 컨텍스트가 남아있는 경우
# nvidia-smi에 프로세스가 보이는데 ps로는 안 보이는 상태

# 1. 좀비 프로세스 정리 (먼저!)
GPU_PIDS=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null)
for PID in $GPU_PIDS; do
    echo "$(date) [Job $SLURM_JOB_ID] Killing leftover GPU process: $PID" >> $LOG
    kill -9 $PID 2>/dev/null
done

# 2. GPU 리셋 (프로세스 없어야 동작)
for i in $(seq 0 7); do
    nvidia-smi -i $i -r >> $LOG 2>&1
done

# 3. GPU 컴퓨트 모드 복원
nvidia-smi -c DEFAULT >> $LOG 2>&1

# 4. /tmp 정리
rm -rf /tmp/slurm_job_${SLURM_JOB_ID}_* 2>/dev/null

# 5. 공유 메모리 정리
rm -rf /dev/shm/nccl-* 2>/dev/null
rm -rf /dev/shm/torch_* 2>/dev/null

echo "$(date) [Job $SLURM_JOB_ID] Epilog done" >> $LOG
exit 0
