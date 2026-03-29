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
