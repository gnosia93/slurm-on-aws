## FSX for Lustre 파일 시스템 생성 ##

### 1. 스토리지 구성 레이아웃 ###
```
/home (ZFS - Zetta):
  - 소스 코드, 설정 파일, 스크립트
  - 용량 작고, I/O 적음
  - 스냅샷으로 실수 복구 가능
  - 사용자별 환경 관리

/scratch (local NVME)

/fsx (Lustre):
  - 학습 데이터셋 (수 TB)
  - 체크포인트 (수십~수백 GB)
  - 수백 GPU가 동시에 읽기/쓰기
  - 초고속 I/O 필요
```

### 2. Lustre 파일시스템 생성 ###

```
# 서브넷 조회



# FSx for Lustre 생성
aws fsx create-file-system \
  --file-system-type LUSTRE \
  --storage-capacity 1200 \
  --subnet-ids subnet-12345678 \
  --lustre-configuration \
    DeploymentType=PERSISTENT_2,\
    PerUnitStorageThroughput=250,\
    DataCompressionType=LZ4 \
  --tags Key=Name,Value=my-lustre-fs

# S3 연동 (옵션)
aws fsx create-file-system \
  --file-system-type LUSTRE \
  --storage-capacity 1200 \
  --subnet-ids subnet-12345678 \
  --lustre-configuration \
    DeploymentType=PERSISTENT_2,\
    PerUnitStorageThroughput=250,\
    ImportPath=s3://my-bucket/data,\
    ExportPath=s3://my-bucket/output

# 생성 확인
aws fsx describe-file-systems \
  --file-system-ids fs-0123456789abcdef0
```







### 3. OpenSFS 생성하기 ###



## Background ##

### 네트워크 아키텍처 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/network-1.png)
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/network-2.png)
이러면 학습 중 IB2 트래픽이 거의 없어서, IB2를 IB1과 합쳐서 NCCL 전용 IB 1개 + 이더넷 본딩(스토리지+관리)으로 줄일 수도 있다.
결국 로컬 NVMe 캐싱을 얼마나 잘 활용하느냐에 따라 IB 2개가 필요한지 1개로 충분한지가 결정된다.

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

#### 3. Pytorch 비동기 예시 ####
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

