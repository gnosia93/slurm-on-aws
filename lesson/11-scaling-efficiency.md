## Scaling Efficiency ##
스케일링 효율은 추가된 GPU가 실제 훈련 속도 향상으로 얼마나 효과적으로 전환되는지를 나타내는 지표입니다. 이상적인 선형 스케일링에서는 GPU를 2배로 늘리면 처리량도 2배가 되지만, 실제로는 통신 오버헤드, 동기화 대기, 파이프라인 버블 등으로 인해 이 비율이 줄어들며, 클러스터 규모와 네트워크 토폴로지, 병렬화 전략에 따라 효율이 다르다. 클러스터 규모에 따라 달라지며, 소규모(8-64 GPU)에서는 85-95%, 대규모(1000+ GPU)에서는 60% 이하로 떨어질 수 있다.

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

## MFU(Model FLOPs Utilization) ##
GPU 이론 최대 FLOPS 대비 실제 모델 학습에 사용된 FLOPS 비율을 의미하는 것으로, "모델이 이론적으로 필요한 연산량"과 "실제 처리 속도"를 조합해서 계산한다. 학습 로그에서 tokens/sec이나 samples/sec만 알면 바로 구할 수 있다.

```
MFU = (모델의 실제 FLOPS) / (GPU 이론 최대 FLOPS) × 100%
```

### MFU가 100%가 안 되는 이유 ###
* 단일 GPU 수준:
  - 메모리 I/O 병목 (memory wall)
  - CUDA 커널 런치 오버헤드
  - Activation recomputation
  - 비연산 작업 (데이터 로딩, 전처리)
* 멀티 GPU 수준 (추가 손실):
  - 통신 오버헤드
  - 동기화 대기
  - 파이프라인 버블

```
예시:
  H100 FP16 이론 최대: 990 TFLOPS
  실제 학습 시 달성:    400 TFLOPS
  MFU = 400 / 990 = ~40%
```

### 실제 대규모 학습의 MFU ###

| Model | GPU | MFU |
|-------|-----|-----|
| PaLM (Google) | TPU v4 | ~46-57% |
| LLaMA (Meta) | A100 | ~36-43% |


MFU가 100%가 안 되는 이유가 바로 앞서 말한 통신 오버헤드, 동기화 대기, 파이프라인 버블, 메모리 I/O 병목 등으로, MFU를 높이는 것이 대규모 학습 최적화의 핵심 지표이다.
```
최종 MFU ≈ 단일 GPU MFU × Scaling Efficiency
```

