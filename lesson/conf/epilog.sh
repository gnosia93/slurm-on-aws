#!/bin/bash

LOG="/var/log/slurm/epilog.log"
echo "$(date) [Job $SLURM_JOB_ID] Epilog start on $(hostname)" >> $LOG

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
