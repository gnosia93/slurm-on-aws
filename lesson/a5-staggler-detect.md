## Straggler detection ##

#### 1. GPU 하드웨어 열화 (메모리 에러, 클럭 다운 등) ####
GPU 열화는 그래픽 카드(특히 GPU와 메모리)가 장시간 고온에 노출되면서 성능 저하나 안정성 문제를 일으키는 현상을 뜻한다.
```
# 실시간 클럭/온도 확인
nvidia-smi dmon -s pcut -d 1

# 출력:
gpu  pwr  temp  sm   mem   enc  dec  clk   mclk
   0  350   65  98    45    0    0  1980  2619   ← 정상
   1  350   64  97    43    0    0  1980  2619   ← 정상
   2  400   82  99    52    0    0  1410  2619   ← 클럭 다운!
   3  350   66  98    44    0    0  1980  2619   ← 정상

# PCIe 링크 상태 확인
nvidia-smi -q -d PCIE

# 정상:
 Link Generation
   Current: 5        ← PCIe Gen5
   Max:     5
 Link Width
   Current: 16x      ← 16레인
   Max:     16x

# 비정상:
 Link Generation
   Current: 4        ← Gen4로 다운그레이드!
   Max:     5
 Link Width
   Current: 8x       ← 8레인으로 감소!
   Max:     16x
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/gpu-degredation%20failure.png)

#### 2. 특정 노드의 스토리지 I/O 병목 (Lustre OST 불균형 등) ####
```
학습 파이프라인:
스토리지(Lustre) → CPU(DataLoader) → GPU(학습)
      ↑
  여기가 느리면 GPU가 데이터를 기다림 (GPU starvation)


Lustre OST 불균형 - Lustre는 파일 데이터를 여러 OST에 분산 저장하는데, 특정 OST에 I/O가 몰리면 병목 발생 :
정상 (균형):
┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐
│ OST 0 │ │ OST 1 │ │ OST 2 │ │ OST 3 │
│ 25%   │ │ 25%   │ │ 25%   │ │ 25%   │  ← I/O 부하 균등
└───────┘ └───────┘ └───────┘ └───────┘

불균형:
┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐
│ OST 0 │ │ OST 1 │ │ OST 2 │ │ OST 3 │
│ 80%   │ │ 5%    │ │ 10%   │ │ 5%    │  ← OST 0에 몰림
└───────┘ └───────┘ └───────┘ └───────┘
     ↑
  이 OST에서 읽는 노드들이 straggler
```
* 불균형이 발생하는 원인
```
1. stripe count = 1 (가장 흔함)
# 파일이 단일 OST에만 저장됨
lfs getstripe /shared/dataset/train_00001.tfrecord
# stripe_count: 1
# stripe_size:  1048576
# obdidx   objid   ...
#   0       12345   ...    ← OST 0에만 있음

2. 데이터셋 파일 배치 편향 - Lustre는 round-robin으로 OST를 배정하지만, 파일 생성 시점의 OST 여유 공간에 따라 편향될 수 있음
dataset/
├── shard_0000.tar  → OST 0
├── shard_0001.tar  → OST 0   ← 같은 OST에 연속 배치
├── shard_0002.tar  → OST 0
├── shard_0003.tar  → OST 1
├── shard_0004.tar  → OST 1
...

3. 용량 불균형 - OST 0이 거의 차면 새 파일이 다른 OST로 가지만, 기존 파일의 읽기는 여전히 OST 0에 집중.
lfs df -h /shared
# UUID                  bytes   Used  Available  Use%  Mounted on
# OST0000             1.7T    1.6T     100G      94%   /shared[OST:0]  ← 거의 꽉 참
# OST0001             1.7T    800G     900G      47%   /shared[OST:1]
# OST0002             1.7T    200G     1.5T      12%   /shared[OST:2]
# OST0003             1.7T    300G     1.4T      18%   /shared[OST:3]
```

#### 3. 백그라운드 프로세스 (OS 업데이트, 로그 수집 등) ####
```
64노드 분산 학습 중:

Node 31에서 unattended-upgrades가 갑자기 실행
→ CPU 4코어를 30초간 점유
→ DataLoader worker가 CPU를 못 받음
→ GPU에 다음 배치 데이터 공급 지연
→ Node 31의 step time: 2.1초 → 3.5초
→ AllReduce에서 나머지 63노드가 1.4초 대기
→ 전체 학습 1.4초 × 63노드 = 88.2 GPU·초 낭비 (한 step에)
```

#### 4. NCCL 통신 경로 이슈 ####
* GPU간 통신경로
```
같은 노드 내 GPU 간:
┌─────────────────────────────────────────┐
│  GPU 0 ←──NVLink──→ GPU 1              │
│    ↕                   ↕                │
│  GPU 2 ←──NVLink──→ GPU 3              │
│                                         │
│  NVLink: 600~900 GB/s (H100 기준)       │
│  NVSwitch: 모든 GPU 간 full bisection   │
└─────────────────────────────────────────┘

같은 노드 내 but NVLink 없는 경우:
┌─────────────────────────────────────────┐
│  GPU 0 ←──PCIe──→ GPU 1                │
│                                         │
│  PCIe Gen5: ~64 GB/s (NVLink의 1/10)   │
└─────────────────────────────────────────┘

노드 간:
┌──────────┐                    ┌──────────┐
│  Node A  │←── EFA/RDMA ──→    │  Node B  │
│  8 GPUs  │    400 Gbps        │  8 GPUs  │
│          │    (~50 GB/s)      │          │
└──────────┘                    └──────────┘

대역폭 : 
NVLink (노드 내) - 600~900 GB/s
PCIe (노드 내)   - ~64 GB/s
EFA (노드 간)    - ~50 GB/s (400Gbps)
TCP (노드 간)    - ~12 GB/s (100Gbps)
```
* NVLink 하나가 죽으면 해당 GPU 쌍의 통신이 PCIe로 fallback → 대역폭 10배 이상 감소 → 해당 노드가 straggler
```
# NVLink 토폴로지 확인
nvidia-smi topo -m

# 정상 출력 예시 (p5.48xlarge, H100 x 8):
#         GPU0  GPU1  GPU2  GPU3  GPU4  GPU5  GPU6  GPU7
# GPU0     X    NV18  NV18  NV18  NV18  NV18  NV18  NV18
# GPU1    NV18   X    NV18  NV18  NV18  NV18  NV18  NV18
# ...
# NV18 = NVLink 18개 연결 (정상)

# 비정상 출력 예시:
# GPU0     X    NV18  NV18  PHB   NV18  NV18  NV18  NV18
#                           ↑
#                     PCIe로 fallback됨 (NVLink 장애)
```
* EFA 네트워크 이슈 (노드 간)
```
# EFA 디바이스 확인
fi_info -p efa

# EFA가 없거나 비정상이면 NCCL이 TCP로 fallback
# → 대역폭 50 GB/s → 12 GB/s로 감소
```
* NUMA Affinity 이슈 - GPU가 어느 CPU 소켓(NUMA 노드)에 가까운지가 중요
```
┌─────────────────────────────────────────────┐
│  NUMA Node 0          NUMA Node 1           │
│  ┌──────┐             ┌──────┐              │
│  │ CPU 0│             │ CPU 1│              │
│  └──┬───┘             └──┬───┘              │
│     │ PCIe                │ PCIe             │
│  ┌──┴───┐ ┌──────┐   ┌──┴───┐ ┌──────┐    │
│  │GPU 0 │ │GPU 1 │   │GPU 2 │ │GPU 3 │    │
│  └──────┘ └──────┘   └──────┘ └──────┘    │
│     │                    │                   │
│  ┌──┴───┐             ┌──┴───┐              │
│  │EFA 0 │             │EFA 1 │              │
│  └──────┘             └──────┘              │
└─────────────────────────────────────────────┘
```
```
# GPU의 NUMA affinity 확인
nvidia-smi topo -m
# 맨 아래에 NUMA 정보 표시

# EFA의 NUMA 확인
cat /sys/class/infiniband/*/device/numa_node

# NCCL에 NUMA 바인딩 힌트
export NCCL_NET_GDR_LEVEL=LOC  # GPU Direct RDMA 레벨
```
[slurm 에서 강제하는 방법]
```
# job 실행시 --gpu-bind=closest 설정
srun --gpus=4 --gpu-bind=closest ./train.sh

# 그리고 gres.conf 에 아애와 같이 Cores 설정
Name=gpu File=/dev/nvidia[0-3] Cores=0-47
Name=gpu File=/dev/nvidia[4-7] Cores=48-95
```

* GPU Direct RDMA 비활성화
```
정상 경로 (GPU Direct RDMA):
Node A GPU → NIC(EFA) → 네트워크 → NIC(EFA) → Node B GPU
(GPU 메모리에서 직접 네트워크로, CPU 메모리 경유 안 함)

비정상 경로 (GPU Direct RDMA 없을 때):
Node A GPU → CPU 메모리 복사 → NIC → 네트워크 → NIC → CPU 메모리 복사 → Node B GPU
(2번의 추가 복사 발생 → 지연 + CPU 부하)
```
```
# GPU Direct RDMA 지원 확인
NCCL_DEBUG=INFO torchrun ...
# 로그에서 확인:
# NCCL INFO NET/OFI GDR is enabled    ← 정상
# NCCL INFO NET/OFI GDR is disabled   ← 문제

# 강제 활성화
export NCCL_NET_GDR_LEVEL=SYS
```

#### 5. GPU 메모리 ECC(Error Correcting Code) 에러 ####
```
• SBE (Single-Bit Error): ECC가 감지하고 자동 교정 → 빈발 시 오버헤드 누적으로 느려짐
• DBE (Double-Bit Error): ECC가 감지하지만 교정 불가 → 데이터 손상
  ├── 경우 1: 페이지 retire + XID 63 → 프로세스 크래시 → 체크포인트에서 재시작
  └── 경우 2: XID 48 → GPU 크래시 → GPU 교체
```


