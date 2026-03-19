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

## 레퍼런스 ##

* https://www.nvidia.com/en-us/ai-data-science/products/nemo/get-started/
* [GPT‑OSS 20B 미세 조정 방법](https://www.youtube.com/watch?v=AFhDi1ACB0k)
