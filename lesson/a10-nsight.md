Nsight Systems는 NVIDIA의 시스템 레벨 프로파일러로 GPU 학습에서 "어디서 시간을 쓰고 있는지"를 타임라인을 보여준다.

![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/nsight.png)

### 설치 ###
```
# 이미 CUDA Toolkit에 포함되어 있음
which nsys
# /usr/local/cuda/bin/nsys

# 없으면
apt install nsight-systems
```

### 기본 사용법 ###
```
# 1. 프로파일링 실행
nsys profile -o my_profile python train.py

# 2. 결과 파일 생성
# my_profile.nsys-rep (GUI용)
# my_profile.sqlite (분석용)
```

### 주요 옵션 ###
```
nsys profile \
  -o output_name \                    # 출력 파일명
  --trace=cuda,nvtx,nccl,osrt \      # 추적 대상
  --sample=none \                     # CPU 샘플링 끔 (오버헤드 줄임)
  --capture-range=cudaProfilerApi \   # 특정 구간만 캡처
  python train.py


추적 대상 (--trace):
  cuda  → GPU 커널 실행, 메모리 복사 (cudaMemcpy)
  nvtx  → 코드에 삽입한 마커 (Forward, Backward 등)
  nccl  → All-Reduce, All-to-All 등 집합 통신
  osrt  → OS 런타임 (pthread, sleep, I/O)
  cublas → 행렬 연산 (GEMM)
```

### 결과 분석 ###
```
# 통계 요약
nsys stats my_profile.nsys-rep

# CUDA 커널 Top 10
nsys stats --report cuda_gpu_kern_sum my_profile.nsys-rep

# NCCL 통신 요약
nsys stats --report nccl my_profile.nsys-rep

# 전체 리포트 CSV로 추출
nsys stats --report cuda_gpu_kern_sum --format csv my_profile.nsys-rep > kernels.csv

# 결과 분석: GUI #
nsys-ui my_profile.nsys-rep
```

### 병목 진단 패턴 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/nsight-2.png)

### NVTX 마커 (코드에 삽입) ###
```
import torch

# 수동 마커
torch.cuda.nvtx.range_push("Forward")
output = model(input)
torch.cuda.nvtx.range_pop()

torch.cuda.nvtx.range_push("Backward")
loss.backward()
torch.cuda.nvtx.range_pop()
```
Megatron-LM은 이미 NVTX 마커가 내장되어 있어서 별도 삽입 없이 Forward/Backward/Optimizer 구간이 보인다.

### 핵심 메트릭 ###
```
GPU Utilization:     GPU 커널이 실행 중인 시간 비율
                     70% 이하면 병목 있음

SM Occupancy:        SM에 할당된 warp 비율
                     낮으면 커널 최적화 필요

Memory Throughput:   HBM 대역폭 사용률
                     높으면 memory-bound 커널

NCCL Time:           전체 대비 통신 시간 비율
                     30% 이상이면 통신 병목
```

### Megatron-LM 프로파일링 ###
```
#!/bin/bash
#SBATCH --job-name=nsys-profile
#SBATCH --nodes=4
#SBATCH --gpus-per-node=8
#SBATCH --exclusive

srun torchrun --nproc_per_node=8 \
  --nnodes=$SLURM_NNODES \
  --rdzv_backend=c10d \
  --rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT \
  bash -c '
    nsys profile \
      -o /fsx/nsys/rank_${SLURM_PROCID} \
      --trace=cuda,nvtx,nccl,osrt \
      --sample=none \
      python pretrain_gpt.py \
        --tensor-model-parallel-size 4 \
        --pipeline-model-parallel-size 4 \
        --train-iters 10 \
        --mock-data \
        ...
  '
```

```
/fsx/nsys/rank_0.nsys-rep   ← GPU 0 (PP Stage 0)
/fsx/nsys/rank_1.nsys-rep   ← GPU 1
...
/fsx/nsys/rank_31.nsys-rep  ← GPU 31 (PP Stage 3)
32개 파일 다 볼 필요는 없고, 보통 이렇게 골라서 봅니다:


rank_0:  PP 첫 스테이지 (Forward 시작점)
rank_7:  같은 노드 마지막 GPU (TP 통신 패턴)
rank_24: PP 마지막 스테이지 (loss 계산, Backward 시작점)
```
                     
