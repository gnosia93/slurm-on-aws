
* [선형대수학 - 행렬, 벡터, 스칼라, 텐서 등 인공기능 수학 기초](https://www.youtube.com/watch?v=k_yto_vDRF0)


### CUDA ###
* [[Winter school 2019] Week #1-2. Introduction to parallel computing (Part 1) [한국어/KOR]](https://www.youtube.com/watch?v=si3B4mYVWrE&list=PLBrGAFAIyf5pp3QNigbh2hRU5EUD0crgI)
* [CUDA Thread Hierarchy (Introduction to CUDA Week1-3)](https://www.youtube.com/watch?v=my1U4QY59Bg)
* [CUDA Execution Model (Introduction to CUDA Week1-5)](https://www.youtube.com/watch?v=MM04LrNlq2I&list=PLBrGAFAIyf5pp3QNigbh2hRU5EUD0crgI&index=19)

![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/gpu-arch-1.png)

![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/gpu-arch-2.png)

* [CUDA Memory Model (1/4) - CUDA memory hierarchy](https://www.youtube.com/watch?v=ipARGT0HfBM)


### Parallelism ###

* 일반적인 분산 학습(Data Parallel, FSDP, TP, PP)에서는 all-reduce, all-gather, reduce-scatter가 주요 통신 패턴인데, 이것들은 대용량 메시지를 순차적으로 전달하는 방식이라 bandwidth 위주이다.
* latency에 민감한 케이스는 MoE 외에도, Pipeline Parallelism에서 마이크로배치 간 전환 (작은 activation 전송이 빈번), 노드 수가 수천 대 이상일 때 동기화 오버헤드가 이에 해당한다.
#### #### 
* [Megatron-LM: Training Multi-Billion Parameter Language Models Using Model Parallelism](https://arxiv.org/abs/1909.08053)
* [Efficient Large-Scale Language Model Training on GPU Clusters Using Megatron-LM](https://arxiv.org/abs/2104.04473)
* [Attention Is All You Need](https://arxiv.org/abs/1706.03762)


### 트러블 슈팅 ###
* https://docs.aws.amazon.com/parallelcluster/latest/ug/troubleshooting-fc-v3-create-cluster.html
