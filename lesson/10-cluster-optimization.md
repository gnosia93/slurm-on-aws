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
#### 1. 데이터 로딩 (매 micro-batch) ####
* 가장 큰 CPU 부하
* 디스크 I/O + 전처리 + PCIe 전송
* num_workers 수만큼 CPU 코어 사용

#### 2. 체크포인트 저장 (N step마다) ####
* 순간적으로 높은 부하
* 수십 GB를 VRAM → RAM → 디스크 직렬화
* 저장 중 학습 일시 정지

#### 3. NCCL 초기화 (1회) ####
* 시작 시 토폴로지 탐색
* 부트스트랩 TCP 연결
* 1회라 영향 적음

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
