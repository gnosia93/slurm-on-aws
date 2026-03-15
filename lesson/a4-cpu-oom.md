## CPU OOM ##

AI 학습에서 GPU OOM만 신경 쓰다가 CPU 쪽에서 터지는 경우도 종종 있다.

### 1. CPU 메모리를 뭐가 차지하는가 ###
```
시스템 메모리 (예: p5.48xlarge 2TB RAM)
├── DataLoader 워커 프로세스     (워커 수 × 데이터 복사본)
├── 데이터 전처리 버퍼           (이미지 디코딩, 토크나이징 등)
├── Pin Memory 버퍼             (GPU 전송용 고정 메모리)
├── CUDA 컨텍스트               (GPU당 ~1GB)
├── ZeRO Offload 데이터         (CPU offload 사용 시)
├── 모델 로딩 시 임시 복사본     (체크포인트 로드 시)
├── OS + 시스템 데몬             (수 GB)
└── 파일시스템 캐시 (Lustre)     (가변)
```

### 2. 주요 원인과 해결 ###

#### 1. DataLoader 워커 메모리 폭발 (가장 흔함) ###
```
# 문제: 워커마다 데이터셋 객체를 복사
DataLoader(dataset, num_workers=16, ...)
# 16개 워커 × 데이터셋 크기 = 메모리 폭발

원인: Python fork로 워커를 생성하면 부모 프로세스의 메모리를 Copy-on-Write로 공유하지만, 데이터를 수정하면 실제 복사가 발생:
부모 프로세스: dataset (10GB)
fork 후:
  Worker 0: dataset 복사 (10GB)  ← CoW 트리거
  Worker 1: dataset 복사 (10GB)
  ...
  Worker 15: dataset 복사 (10GB)
  합계: 160GB


해결:
# 방법 1: num_workers 줄이기
DataLoader(dataset, num_workers=4, ...)  # 16 → 4

# 방법 2: 데이터셋을 numpy memmap으로 (메모리 매핑)
import numpy as np

class MemmapDataset(Dataset):
    def __init__(self, path):
        # 파일을 메모리에 올리지 않고 매핑만
        self.data = np.memmap(path, dtype='float32', mode='r', shape=(1000000, 768))
    
    def __getitem__(self, idx):
        return torch.from_numpy(self.data[idx].copy())

# 방법 3: WebDataset / LMDB 등 I/O 기반 데이터셋
import webdataset as wds

dataset = wds.WebDataset("/shared/dataset/shard-{0000..0063}.tar")
    .decode("pil")
    .to_tuple("input.pth", "target.pth")

# 방법 4: 공유 메모리 사용
# Python list 대신 numpy array나 torch.Tensor로 데이터 저장
# → fork 시 CoW가 트리거되지 않음
```

#### 2. Pin Memory ####
```
DataLoader(dataset, pin_memory=True, ...)

# CPU → GPU 전송 속도를 높이기 위해 페이지 고정
# 하지만 고정된 메모리는 OS가 swap 못 함
pin_memory=True:
  배치 크기 32, 이미지 224×224×3, float32
  = 32 × 224 × 224 × 3 × 4 = ~19MB per batch
  × prefetch_factor(2) × num_workers(16)
  = ~608MB 고정 메모리

  큰 배치 + 많은 워커 → 수 GB 고정


해결:

# 메모리 부족하면 끄기 (GPU 전송 약간 느려짐)
DataLoader(dataset, pin_memory=False, ...)

# 또는 prefetch 줄이기
DataLoader(dataset, pin_memory=True, prefetch_factor=1, ...)
```

#### 3. 모델 체크포인트 로딩 ####
```
# 문제: 체크포인트 로드 시 CPU 메모리에 전체 모델 임시 복사
checkpoint = torch.load("model_70b.pt")   # CPU에 70B 모델 로드 (~140GB)
model.load_state_dict(checkpoint)         # GPU로 복사

# 이 시점에 CPU에 140GB + GPU에 140GB 동시 존재
del checkpoint  # 여기서야 CPU 메모리 해제

해결:

# 방법 1: mmap으로 로드 (PyTorch 2.1+)
checkpoint = torch.load("model.pt", mmap=True)
# 파일을 메모리 매핑, 실제 메모리 사용 최소화

# 방법 2: device_map으로 직접 GPU에 로드
from accelerate import load_checkpoint_and_dispatch

model = load_checkpoint_and_dispatch(
    model, "model.pt",
    device_map="auto"  # 바로 GPU에 올림, CPU 임시 복사 최소화
)

# 방법 3: safetensors 포맷 사용
from safetensors.torch import load_file
state_dict = load_file("model.safetensors")  # mmap 기본 지원
```

#### 4. ZeRO CPU Offload ####
```
# DeepSpeed ZeRO-Offload 사용 시 CPU 메모리를 대량 사용
{
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {"device": "cpu"},
        "offload_param": {"device": "cpu"}
    }
}
70B 모델 ZeRO-3 CPU Offload:
  Optimizer 상태 (CPU): ~560GB (Adam, FP32)
  파라미터 (CPU):       ~140GB
  합계:                 ~700GB CPU 메모리 필요

해결:

# CPU 메모리 부족하면 NVMe offload로 전환
{
    "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {
            "device": "nvme",
            "nvme_path": "/local/nvme/offload"
        },
        "offload_param": {
            "device": "nvme",
            "nvme_path": "/local/nvme/offload"
        }
    }
}
```

#### 5. 데이터 전처리 메모리 누수 ####
```
# 문제: 전처리 중 임시 객체가 해제 안 됨
class BadDataset(Dataset):
    def __init__(self):
        self.cache = {}  # 계속 커지는 캐시
    
    def __getitem__(self, idx):
        if idx not in self.cache:
            self.cache[idx] = heavy_preprocess(idx)  # 메모리 누수
        return self.cache[idx]

# 해결: 캐시 크기 제한
from functools import lru_cache

class BetterDataset(Dataset):
    @lru_cache(maxsize=1000)  # 최대 1000개만 캐시
    def __getitem__(self, idx):
        return heavy_preprocess(idx)
```

### Linux OOM Killer ###
CPU 메모리가 진짜 바닥나면 Linux OOM Killer가 프로세스를 강제 종료:

```
# OOM Killer 로그 확인
dmesg | grep -i "oom\|killed"

# 출력 예시:
# [12345.678] Out of memory: Killed process 9876 (python) 
#             total-vm:1234567kB, anon-rss:987654kB, file-rss:0kB
# 어떤 프로세스가 메모리를 많이 쓰는지
ps aux --sort=-%mem | head -20

# 또는 상세하게
smem -t -k -s rss | tail -20
```

#### OOM Killer 방지 설정 ####
```
# 학습 프로세스의 OOM 점수 낮추기 (죽일 우선순위 낮춤)
echo -17 > /proc/<PID>/oom_adj

# 또는 학습 스크립트에서
import os
with open(f'/proc/{os.getpid()}/oom_score_adj', 'w') as f:
    f.write('-1000')  # OOM Killer 대상에서 제외
# swap 설정 (OOM 방지용 안전장치)
# 하지만 학습 성능이 크게 저하되므로 비추
sudo fallocate -l 64G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# swap 사용 최소화 (메모리가 진짜 부족할 때만)
sudo sysctl vm.swappiness=1
```

#### 모니터링 ####
```
# 실시간 메모리 확인
watch -n 1 free -h

# 프로세스별 메모리
htop  # RES 컬럼 확인

# Python 프로세스 메모리 상세
py-spy dump --pid <PID>

# 학습 코드 내에서 모니터링
import psutil
import os

def print_cpu_memory():
    process = psutil.Process(os.getpid())
    mem = process.memory_info()
    system = psutil.virtual_memory()
    print(f"Process RSS: {mem.rss / 1024**3:.1f}GB | "
          f"System: {system.used / 1024**3:.1f}/{system.total / 1024**3:.1f}GB "
          f"({system.percent}%)")
```

```
# Prometheus (Node Exporter)
# 시스템 메모리 사용률
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90

# OOM Kill 발생 감지
rate(node_vmstat_oom_kill[5m]) > 0
```

## 정리 ##
#### CPU OOM의 주요 원인 ###
* DataLoader 워커가 데이터셋을 각각 복사 (fork + CoW)
* 체크포인트 로딩 시 CPU에 전체 모델 임시 적재
* ZeRO CPU Offload로 optimizer 상태가 CPU에 올라감

#### DataLoader 메모리 문제 해결 ###
* num_workers 줄이기
* 데이터를 numpy memmap이나 WebDataset으로 변경
* Python list 대신 numpy array로 저장 (CoW 방지)

#### OOM Killer가 학습 프로세스를 죽이면 ####
* dmesg로 확인, 어떤 프로세스가 얼마나 쓰고 있었는지 파악
* 근본 원인 해결 (메모리 사용량 줄이기)
* 임시 방편으로 oom_score_adj 조정은 가능하지만 권장하지 않음 (다른 시스템 프로세스가 대신 죽을 수 있음)

dmesg로 확인, 어떤 프로세스가 얼마나 쓰고 있었는지 파악
근본 원인 해결 (메모리 사용량 줄이기)
임시 방편으로 oom_score_adj 조정은 가능하지만 권장하지 않음 (다른 시스템 프로세스가 대신 죽을 수 있음)
