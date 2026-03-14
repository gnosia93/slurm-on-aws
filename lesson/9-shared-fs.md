## 스토리지 ##
```
/home (ZFS - Zetta):
  - 소스 코드, 설정 파일, 스크립트
  - 용량 작고, I/O 적음
  - 스냅샷으로 실수 복구 가능
  - 사용자별 환경 관리

/scratch (local NVME) 또는 /fsx (Lustre):
  - 학습 데이터셋 (수 TB)
  - 체크포인트 (수십~수백 GB)
  - 수백 GPU가 동시에 읽기/쓰기
  - 초고속 I/O 필요
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/shared-fs.png)

### 네트워크 아키텍처 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/network-1.png)
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/network-2.png)

### 비동기 체크 포인팅 ###

#### 1. 일반 체크포인트 (동기) ####
```
학습 step 999 → 완료 → 체크포인트 저장 (GPU 대기) → 학습 step 1000
                              ↑ 수십 초~수 분 블로킹
```

#### 2. 비동기 체크포인트 ####
```
학습 step 999 → 완료 → GPU 메모리 → CPU 메모리로 복사 (빠름) → 학습 step 1000 계속
                                         ↓
                              백그라운드 스레드가 디스크에 저장 (GPU 안 기다림)
```

#### 3. Pytorch 예시 ####
```
import torch.distributed.checkpoint as dcp
from torch.distributed.checkpoint.state_dict import get_state_dict

# 비동기 저장
future = dcp.async_save(
    state_dict=get_state_dict(model, optimizer),
    storage_writer=dcp.FileSystemWriter("/scratch/checkpoint"),
)

# 학습 계속 진행
train_step(model, data)

# 필요 시 저장 완료 대기
future.result()
```
핵심은 GPU → CPU 메모리 복사는 빠르고(수 초), CPU → 디스크 저장은 느리지만(수십 초) 백그라운드에서 처리되니까 GPU가 놀지 않는다.

