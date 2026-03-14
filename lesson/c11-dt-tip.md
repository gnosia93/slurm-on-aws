### 좀비 프로세스 ###

### OOM 방지 ###

## Staggler 노드 detection ##

### Straggler가 발생하는 원인 ###
* GPU 하드웨어 열화 (메모리 에러, 클럭 다운)
* NVLink/EFA 네트워크 성능 저하
* 특정 노드의 스토리지 I/O 병목 (Lustre OST 불균형 등)
* CPU throttling (온도, 전력)
* 백그라운드 프로세스 (OS 업데이트, 로그 수집 등)

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



#### GPU 메모리 ECC(Error Correcting Code) 에러 ####
```
• SBE (Single-Bit Error): ECC가 감지하고 자동 교정 → 빈발 시 오버헤드 누적으로 느려짐
• DBE (Double-Bit Error): ECC가 감지하지만 교정 불가 → 데이터 손상
  ├── 경우 1: 페이지 retire + XID 63 → 프로세스 크래시 → 체크포인트에서 재시작
  └── 경우 2: XID 48 → GPU 크래시 → GPU 교체
```

### lustre ###
