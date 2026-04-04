## Scaling Efficiency ##
GPU 노드를 늘려도 훈련 효율은 선형으로 증가하지 않고, 노드가 늘어날수록 효율이 떨어진다.
```
이상적 (선형 스케일링):
  GPU 2배 → 훈련 시간 1/2

현실:
  GPU 2배 → 훈련 시간 1/2 + 통신 오버헤드 + 동기화 대기
```

### 효율을 떨어뜨리는 주요 원인: ###
* Communication Overhead:	All-Reduce, All-Gather 등 집합 통신 시간
* Synchronization Barrier: 	가장 느린 GPU를 기다림 (straggler 문제)	
* Pipeline Bubble: 	PP에서 스테이지 간 유휴 시간	
* Batch Size Scaling:	배치 크기 증가 시 수렴 품질 저하 가능	
* Memory Overhead:	NCCL 버퍼, 통신용 임시 메모리 증가	

