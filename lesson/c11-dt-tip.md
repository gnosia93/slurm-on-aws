### 좀비 프로세스 ###

### OOM 방지 ###

## Staggler 노드 detection ##

### Straggler가 발생하는 원인 ###
* GPU 하드웨어 열화 (메모리 에러, 클럭 다운)
* NVLink/EFA 네트워크 성능 저하

#### 특정 노드의 스토리지 I/O 병목 (Lustre OST 불균형 등) ####

#### 백그라운드 프로세스 (OS 업데이트, 로그 수집 등) ####
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

#### NCCL 통신 경로 이슈 ####
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

#### GPU 메모리 ECC(Error Correcting Code) 에러 ####
```
• SBE (Single-Bit Error): ECC가 감지하고 자동 교정 → 빈발 시 오버헤드 누적으로 느려짐
• DBE (Double-Bit Error): ECC가 감지하지만 교정 불가 → 데이터 손상
  ├── 경우 1: 페이지 retire + XID 63 → 프로세스 크래시 → 체크포인트에서 재시작
  └── 경우 2: XID 48 → GPU 크래시 → GPU 교체
```

