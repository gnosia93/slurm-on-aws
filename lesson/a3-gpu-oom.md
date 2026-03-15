## GPU OOM ##

###  1. GPU 메모리를 뭐가 차지하는가 ###
```
GPU 메모리 (예: H100 80GB)
├── 모델 파라미터          (수 GB ~ 수십 GB)
├── Optimizer 상태         (파라미터의 2~3배, Adam 기준)
├── Gradient              (파라미터와 동일 크기)
├── Activation            (배치 크기에 비례, 가장 가변적)
├── NCCL 통신 버퍼         (수백 MB ~ 수 GB)
├── CUDA 컨텍스트          (~1 GB, 고정)
└── 임시 버퍼/fragmentation (예측 어려움)

예시 (7B 모델, FP16):

파라미터:     7B × 2 bytes = 14 GB
Optimizer:   7B × 8 bytes = 56 GB (Adam: fp32 파라미터 + momentum + variance)
Gradient:    7B × 2 bytes = 14 GB
Activation:  배치/시퀀스 길이에 따라 가변
─────────────────────────────────
합계:        84 GB + Activation → 단일 GPU로 불가능
```

### 2. 방지 방법 ###

#### 1. Mixed Precision Training (가장 기본) ####
```
from torch.cuda.amp import autocast, GradScaler

scaler = GradScaler()

for batch in dataloader:
    optimizer.zero_grad()
    
    with autocast(dtype=torch.bfloat16):  # FP16/BF16으로 연산
        loss = model(batch)
    
    scaler.scale(loss).backward()
    scaler.step(optimizer)
    scaler.update()
```
* FP32 학습:  파라미터 14GB + Activation 40GB = 54GB
* BF16 학습:  파라미터  7GB + Activation 20GB = 27GB  (약 50% 절감)

#### 2. Gradient Accumulation (배치 크기 유지하면서 메모리 절감) ####
```
accumulation_steps = 4
effective_batch_size = batch_size * accumulation_steps  # 실제 배치 크기

for i, batch in enumerate(dataloader):
    with autocast(dtype=torch.bfloat16):
        loss = model(batch) / accumulation_steps  # loss 스케일링
    
    loss.backward()
    
    if (i + 1) % accumulation_steps == 0:
        optimizer.step()
        optimizer.zero_grad()
```
* 배치 크기 32 한번에:     Activation 40GB  ← OOM
* 배치 크기 8 × 4 누적:    Activation 10GB  ← OK, 결과는 동일

#### 3. Activation Checkpointing (= Gradient Checkpointing) ###
순전파 중간 결과를 저장하지 않고, 역전파 시 다시 계산:
```
from torch.utils.checkpoint import checkpoint

class MyModel(nn.Module):
    def forward(self, x):
        # 일반: 모든 레이어의 activation 저장 → 메모리 많이 씀
        # Checkpointing: 일부만 저장, 나머지는 역전파 시 재계산
        x = checkpoint(self.layer1, x, use_reentrant=False)
        x = checkpoint(self.layer2, x, use_reentrant=False)
        x = checkpoint(self.layer3, x, use_reentrant=False)
        return x
일반:          메모리 ████████████████  (모든 activation 저장)
               연산   ████████

Checkpointing: 메모리 ██████            (60~70% 절감)
               연산   ████████████      (30~40% 재계산 오버헤드)
```
메모리 ↓ 대신 연산 시간 ↑ 트레이드오프.

#### 4. ZeRO (Zero Redundancy Optimizer) ####
DeepSpeed의 핵심 기능. Optimizer 상태, Gradient, 파라미터를 GPU들에 분산:

```
ZeRO Stage 1: Optimizer 상태 분산
  GPU 0: Adam state (1/8)  +  전체 파라미터 + 전체 gradient
  GPU 1: Adam state (2/8)  +  전체 파라미터 + 전체 gradient
  ...
  메모리 절감: Optimizer 부분만 (약 4배)

ZeRO Stage 2: + Gradient도 분산
  GPU 0: Adam state (1/8)  +  전체 파라미터 + gradient (1/8)
  메모리 절감: 약 8배

ZeRO Stage 3: + 파라미터도 분산
  GPU 0: Adam state (1/8)  +  파라미터 (1/8) + gradient (1/8)
  메모리 절감: 약 N배 (GPU 수에 비례)
  단점: 통신량 증가
```

### 5. CPU/NVMe Offloading ###
```
# DeepSpeed ZeRO-Offload
{
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {
            "device": "cpu",          # Optimizer 상태를 CPU RAM으로
            "pin_memory": true
        },
        "offload_param": {
            "device": "cpu",          # 파라미터도 CPU로
            "pin_memory": true
        }
    }
}

# NVMe Offload (CPU RAM도 부족할 때)
{
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {
            "device": "nvme",
            "nvme_path": "/local/nvme/offload"
        }
    }
}
속도:  GPU 메모리 >> CPU RAM >> NVMe
용량:  GPU 80GB  << CPU 2TB << NVMe 수 TB
```



실전 조합 (권장)
```
7B 모델, 8x H100:
  → BF16 + ZeRO Stage 2 + Gradient Accumulation

70B 모델, 8x H100:
  → BF16 + ZeRO Stage 3 + Activation Checkpointing

70B 모델, 64x H100:
  → BF16 + Tensor Parallel (8) + Data Parallel (8) + Activation Checkpointing

405B 모델:
  → BF16 + TP(8) + PP(8) + DP(N) + Activation Checkpointing + ZeRO-1
```

#### GPU OOM이 발생하면 어떻게 대응하나요? ####

* 먼저 torch.cuda.max_memory_allocated()로 피크 메모리 확인
* 배치 크기 줄이기 + Gradient Accumulation으로 effective batch size 유지
* Activation Checkpointing 적용
* Deep Zero 적용
