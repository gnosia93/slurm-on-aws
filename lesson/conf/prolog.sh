#============================================================
# prolog.sh — 잡 시작 전 실행 (GPU 헬스체크)
#============================================================
#!/bin/bash

LOG="/var/log/slurm/prolog.log"
echo "$(date) [Job $SLURM_JOB_ID] Prolog start on $(hostname)" >> $LOG

# 1. GPU 존재 확인
GPU_COUNT=$(nvidia-smi -L | wc -l)
if [ "$GPU_COUNT" -lt 8 ]; then
    echo "$(date) [Job $SLURM_JOB_ID] GPU count mismatch: $GPU_COUNT/8" >> $LOG
    exit 1    # exit 1 → 잡 실패, 노드 drain
fi

# 2. ECC 에러 체크 (Uncorrectable)
for i in $(seq 0 7); do
    UE=$(nvidia-smi -i $i --query-gpu=ecc.errors.uncorrected.volatile.total --format=csv,noheader,nounits)
    if [ "$UE" -gt 0 ]; then
        echo "$(date) [Job $SLURM_JOB_ID] GPU $i UE ECC error: $UE" >> $LOG
        exit 1
    fi
done


# nvidia-smi -q | grep -A 5 "Temperature"
# GPU Shutdown Temp          : 95 C
# GPU Slowdown Temp          : 92 C    ← 스로틀링 시작
# GPU Max Operating Temp     : 89 C
# Memory Current Temp        : 45 C
# 3. GPU 온도 체크
for i in $(seq 0 7); do
    TEMP=$(nvidia-smi -i $i --query-gpu=temperature.gpu --format=csv,noheader,nounits)
    if [ "$TEMP" -gt 85 ]; then
        echo "$(date) [Job $SLURM_JOB_ID] GPU $i temp too high: ${TEMP}C" >> $LOG
        exit 1
    fi
done

# 4. NVLink 상태 체크
NVLINK_ERR=$(nvidia-smi nvlink -s | grep -c "inactive")
if [ "$NVLINK_ERR" -gt 0 ]; then
    echo "$(date) [Job $SLURM_JOB_ID] NVLink inactive detected" >> $LOG
    exit 1
fi

echo "$(date) [Job $SLURM_JOB_ID] Prolog passed" >> $LOG
exit 0
