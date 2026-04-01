## 분산 학습 CPU/GPU 작업 분류 ##

| 작업 | 실행 횟수 | 실행 위치 | 비고 |
|------|-----------|-----------|------|
| NCCL 초기화 | 1회 | CPU + GPU | 토폴로지 탐색, 채널/알고리즘 선택 |
| 모델 생성/배치 | 1회 | CPU → GPU | TP/PP에 따라 파라미터 분배 |
| 데이터 로딩 | 매 micro-batch | CPU (DataLoader) | num_workers 만큼 병렬, PCIe로 GPU 전달 |
| Forward | 매 micro-batch | GPU (CPU가 launch) | Attention + MLP 연산 |
| Backward | 매 micro-batch | GPU | gradient 계산, activation 재계산(checkpointing 시) |
| TP All-Reduce | 매 micro-batch | GPU (NVLink) | 레이어당 2회 (Attention + MLP) |
| PP P2P | 매 micro-batch | GPU (EFA) | 스테이지 간 activation/gradient 전달 |
| Gradient Accumulation | 매 micro-batch | GPU | GBS/(MBS×DP) 번 누적 |
| DP All-Reduce | 매 step | GPU (EFA) | 모든 DP 복제본 gradient 합산 |
| Optimizer Step | 매 step | GPU | Adam: m, v, 파라미터 업데이트 |
| LR 스케줄링 | 매 step | CPU | warmup, cosine decay |
| 로깅 | N step마다 | CPU | loss, throughput, 메모리 출력 |
| 체크포인트 저장 | N step마다 | CPU + 디스크 | VRAM → RAM → Lustre/S3 |
| 평가 | N step마다 | GPU | validation loss 측정 (forward만) |

### CPU 에게 부하를 주는 작업 ###

#### 1. 체크포인트 저장 (N step마다) ####
* 가장 큰 CPU 부하
* 수십 GB 직렬화 + 디스크 쓰기
* 저장 중 학습 일시 정지

#### 2. 데이터 로딩 (매 micro-batch) ####
* Megatron-LM은 바이너리 읽기만 → CPU 부하 거의 없음
* 이미지/멀티모달이면 부하 높을 수 있음 

## 병렬화 기법별 통신 특성 비교 (네트워크 유형별 성능 및 병렬화 적합도) ##

| 병렬화 | 통신 패턴 | 메시지 크기 | 빈도 | 민감도 | 네트워크 | 장점 | 단점 |
|--------|-----------|-------------|------|--------|----------|------|------|
| TP | All-Reduce | 수 MB~GB | 레이어당 2회 (매 micro-batch) | 레이턴시 | NVLink 필수 | 모델 가중치 분할 → 메모리 절감 | 통신 빈번, 노드 내로 제한 |
| SP | Reduce-Scatter + All-Gather | TP와 동일 | TP와 동일 | 레이턴시 | NVLink (TP와 공유) | Activation 메모리 절감, 추가 통신 비용 0 | TP 없이 단독 사용 불가 |
| PP | Point-to-Point | 수 MB (activation) | 스테이지 간 (매 micro-batch) | 레이턴시 | EFA/IB | 레이어 분할 → 메모리 절감 | Pipeline bubble, 구현 복잡 |
| DP | All-Reduce | 수 GB (gradient) | step당 1회 | 대역폭 | EFA/IB | 구현 간단, 스케일링 쉬움 | 모델 전체 복제 → 메모리 절감 없음 |
| FSDP | All-Gather + Reduce-Scatter | 수 GB (파라미터/gradient) | 매 micro-batch | 대역폭 | EFA/IB | DP + 메모리 절감 (ZeRO-3) | 통신량 DP보다 많음 |
| EP | All-to-All | 수 KB~MB (토큰 단위) | 레이어당 2회 (매 micro-batch) | 레이턴시 | NVLink(EP≤8) / IB(EP>8) | MoE Expert 분할 | 작은 메시지 빈번, EFA에서 불리 |
| CP | Ring Attention (P2P) | 수 MB (KV 블록) | Attention마다 | 대역폭 | EFA/IB | 긴 시퀀스(64K+) 분할 | 시퀀스 짧으면 의미 없음 |

```
레이턴시 민감 + 큰 메시지 (TP):
  → NVLink (대역폭도 높고 레이턴시도 낮음)

레이턴시 민감 + 작은 메시지 빈번 (EP):
  → NVLink(노드 내) 또는 IB+IBGDA(노드 간)
  → EFA는 CPU proxy 오버헤드로 불리

대역폭 민감 + 큰 메시지 (DP, FSDP):
  → IB든 EFA든 대역폭만 충분하면 OK
  → 레이턴시 차이 영향 적음
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/rdma-ibgda-efa.png)
* latency 는 기술 간의 상대적 차이를 설명하기 위한 정확한 수치가 아님.
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/moe-comm.png)

## GPU 학습 및 클러스터 최적화 ##
### 학습코드 최적화 ###
* 분산 체크 포인팅
```
빠른 체크포인트 (로컬 NVMe):
  → 학습 중 빈번하게 저장 (매 10 step)
  → 같은 노드에서 재시작할 때만 유효

안전한 체크포인트 (Lustre/S3):
  → 덜 빈번하게 저장 (매 100 step)
  → 어떤 노드에서든 읽기 가능
  → 노드 장애 시 여기서 복구
```
* 비동기 체크 포인팅
* Mixed Precision / Gradient Accumulation 
* Batch Size / Flash Attention

### 네트워크 최적화 ###
* NCCL 알고리즘 확인 (Ring/Tree/NVLS)
* GPUDirect RDMA 활성화 확인
* 멀티 NIC 전부 활용되는지 확인
* 토폴로지 기반 잡 배치 (같은 스위치 아래)
* 업링크 오버서브스크립션 확인 (최소 TOR ~ Aggr SWitch 간의 1 대 1 필요)

### GPU 활용률 최적화 ###
* sm 사용률 모니터링 → 데이터 로딩 병목 식별
* pclk 모니터링 → 스로틀링 식별

### 데이터 로딩 최적화 ###
* 학습 데이터 sharding (/w WebTAR, Parque, TFRecord 등)
* DataLoader num_workers / prefetch_factor 튜닝
* 로컬 NVMe 캐시 활용
* /dev/shm 크기 조정

### 스케줄링 최적화 ###
* 백필 스케줄링 활성화 (GPU 유휴 시간 최소화)
* Fair Share 설정 (팀 간 공정 분배)
* Gang scheduling (멀티노드 잡 동시 할당)
* NUMA affinity

### 스토리지 최적화 ###
* 체크포인트 저장 속도 (스트라이핑 -c -1 / 사이즈)
* OST 추가 / 더 높은 IOPS 할당 

### OS 레벨 최적화 ###
* memlock unlimited (RDMA)
* Huge Pages (RDMA)
* GPU Persistence Mode
* 커널 버전 고정 (GPU 드라이버 오동작 방지)

### 측정 도구 ###
* nccl-test → 네트워크 대역폭
* IOR / dd → 스토리지 처리량
* nvidia-smi dmon → GPU 상태 실시간
* Prometheus + Grafana → 트렌드 분석
* throughput (tokens/sec) → 학습 효율 최종 지표
