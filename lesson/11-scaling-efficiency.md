## Scaling Efficiency ##
GPU 노드를 늘려도 훈련 효율은 선형으로 증가하지 않고, 노드가 늘어날수록 효율이 떨어진다.
```
이상적 (선형 스케일링):
  GPU 2배 → 훈련 시간 1/2

현실:
  GPU 2배 → 훈련 시간 1/2 + 통신 오버헤드 + 동기화 대기
```
```
Scaling Efficiency = (실제 처리량 / (단일 GPU 처리량 × GPU 수)) × 100%
```

### 효율을 떨어뜨리는 주요 원인 ###
* Communication Overhead:	All-Reduce, All-Gather 등 집합 통신 시간
* Synchronization Barrier: 	가장 느린 GPU를 기다림 (straggler 문제)	
* Pipeline Bubble: 	PP에서 스테이지 간 유휴 시간	
* Batch Size Scaling:	배치 크기 증가 시 수렴 품질 저하 가능	
* Memory Overhead:	NCCL 버퍼, 통신용 임시 메모리 증가	

### 실제 Scaling Efficiency 예시 ###
```
GPU 수     이상적 속도    실제 속도     효율
1          1x            1x           100%
8          8x            7.5x         ~94%
64         64x           55x          ~86%
256        256x          200x         ~78%
1024       1024x         700x         ~68%
4096       4096x         2400x        ~59%
```

### 이걸 개선하는 방법들 ###
* Computation-Communication Overlap:	연산과 통신을 동시에 수행
* Gradient Compression:	통신 데이터량 감소
* Async All-Reduce:	동기화 대기 시간 감소
* 최적 병렬화 전략 조합 (3D/4D Parallelism):	통신 패턴 최적화
* Placement Group (AWS): 노드 간 네트워크 레이턴시 최소화
* Topology-Aware Scheduling: GPU-NIC 근접 배치
  
결론적으로 GPU를 무한히 늘린다고 무한히 빨라지지 않고, 어느 시점부터는 통신 오버헤드가 연산 이득을 잡아먹는다. 그래서 대규모 학습에서는 "GPU를 몇 개 쓸까"보다 "통신을 어떻게 줄일까"가 더 중요한 엔지니어링 과제이다.
