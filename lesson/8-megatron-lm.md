Megatron-LM은 NVIDIA가 만든 대규모 LLM 학습 프레임워크로, 수천 GPU에서 LLM을 효율적으로 학습시키는 엔진이다. 6D Parallelism(DP + TP + PP + SP + EP + CP)을 지원한다.

### Megatron-LM 실행 ###
```
python pretrain_gpt.py \
  --tensor-model-parallel-size 8 \     # TP=8 (노드 내 GPU 8장)
  --pipeline-model-parallel-size 4 \   # PP=4 (4개 스테이지)
  --sequence-parallel \                # SP 활성화
  --context-parallel-size 2 \          # CP=2
  --expert-model-parallel-size 4 \     # EP=4 (MoE 모델일 때)
  --data-parallel-size 16 \            # DP=16
  --num-layers 80 \
  --hidden-size 8192 \
  --num-attention-heads 64 \
  --micro-batch-size 1 \
  --global-batch-size 1024
```
* 총 GPU = TP × PP × DP = 8 × 4 × 16 = 512 GPU

### Framework 비교 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/framework-compare.png)
* Megatron-LM: 모델을 쪼개는 데 특화 (TP/PP). GPU 효율 최고
* DeepSpeed: 메모리를 아끼는 데 특화 (ZeRO). 적은 GPU로 큰 모델
* FSDP: 가장 쉬움. 중소 규모 학습에 적합
```
[소규모: GPU 1~8장]
→ PyTorch FSDP 또는 DeepSpeed ZeRO

[중규모: GPU 8~64장]
→ DeepSpeed ZeRO + TP

[대규모: GPU 64~수천장]
→ Megatron-LM (TP + PP + DP)
   또는 Megatron-DeepSpeed (Megatron의 TP/PP + DeepSpeed의 ZeRO)
```

## 설계 예시 ##
```
Llama 3 405B 학습 (Meta):
TP=8 × PP=16 × DP=? = 16,384 GPU
→ DP = 16384 / (8×16) = 128

GPT-4 급 (추정):
TP=8 × PP=8 × DP=? = 25,000+ GPU
→ DP = 수백
```

### DP 사이즈 설계 ### 

* DP가 크면 좋은 점
  * 배치 사이즈가 커짐 → 학습 step 수 줄어듦 → 학습 시간 단축
  * GPU 활용률 높음 (버블 없음)
* DP가 너무 크면 문제
  * gradient All-Reduce 통신량 증가 (대역폭 병목)
  * 배치가 너무 커지면 학습 수렴이 불안정해질 수 있음

이러한 문제를 방지하기 위해서 global batch size를 먼저 정하고, 거기서 역산한다.
```
global_batch_size = micro_batch_size × DP × gradient_accumulation_steps

예: global_batch=1024, micro_batch=1, grad_accum=4
→ DP = 1024 / (1 × 4) = 256
```
* DP=16~32 정도면 중규모, 100+ 이면 대규모 학습


## 레퍼런스 ##

* https://www.nvidia.com/en-us/ai-data-science/products/nemo/get-started/
* [GPT‑OSS 20B 미세 조정 방법](https://www.youtube.com/watch?v=AFhDi1ACB0k)
