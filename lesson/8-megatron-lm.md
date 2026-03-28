## [Megatron-LM](https://arxiv.org/pdf/1909.08053) ##

NVIDIA가 개발한 대규모 언어 모델 학습 프레임워크로, 수천 대의 GPU에서 수십~수백 billion 파라미터 규모의 Transformer 모델을 효율적으로 학습시키기 위해 만들어졌다. 2019년 NVIDIA 연구팀이 Tensor Parallelism 논문과 함께 처음 공개했고, 이후 Pipeline Parallelism, Sequence Parallelism, Context Parallelism, Expert Parallelism까지 점진적으로 추가되면서 현재는 DP, TP, PP, SP, CP, EP 6가지 병렬화를 동시에 조합할 수 있는 이른바 6D Parallelism을 지원한다.  

핵심 설계 철학은 "모델 아키텍처를 코드로 짜지 않고 CLI 파라미터로 설정한다"는 것으로, num-layers, hidden-size, num-attention-heads, ffn-hidden-size 같은 하이퍼파라미터만 지정하면 Transformer 구조가 자동으로 구성되고, SwiGLU, GQA, RoPE, RMSNorm, FlashAttention, MoE 같은 최신 기법들도 전부 플래그 하나로 켜고 끌 수 있다. 

학습 파이프라인은 크게 3단계로 구성되는데, 먼저 preprocess_data.py로 JSONL 형태의 원본 텍스트를 토큰화하여 바이너리 포맷으로 변환하고, 그 다음 pretrain_gpt.py를 torchrun이나 Slurm sbatch로 실행하여 분산 학습을 수행하며, 학습 중 주기적으로 체크포인트를 저장한다.  
내부 구조를 보면 pretrain_gpt.py가 진입점이고, 이 안에서 megatron-core 라이브러리의 GPTModel, TransformerLayer, Attention, MLP 등의 모듈을 조립한다. 실제 병렬화 로직은 megatron-core에 구현되어 있어서, TP는 가중치 행렬을 column-wise로 분할하고 All-Reduce로 동기화하며, PP는 레이어를 스테이지별로 나누어 마이크로배치 파이프라이닝으로 bubble을 줄이고, SP는 LayerNorm과 Dropout을 시퀀스 차원으로 분할하여 TP와 함께 메모리를 절감한다.

### Megatron-LM 예시 ###
```
python pretrain_gpt.py \
  --data-parallel-size 8 \             # DP=8
  --tensor-model-parallel-size 8 \     # TP=8 (노드 내 GPU 8장)
  --sequence-parallel \                # SP 활성화 (TP 의 보조기법 - LayerNorm, Dropout 등을 시퀀스 축으로 분할) 
  --pipeline-model-parallel-size 4 \   # PP=4 (4개 스테이지)
  --context-parallel-size 2 \          # CP=2
  --expert-model-parallel-size 4 \     # EP=4 (MoE 모델일 때)
  --num-layers 80 \
  --hidden-size 8192 \
  --num-attention-heads 64 \
  --micro-batch-size 1 \
  --global-batch-size 1024
```
* 총 GPU = DP x TP × PP × CP x EP = 8 × 8 x 4 × 2 x 4 = 2048 GPU


### Framework / API 비교 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/framework-compare.png)

## 70B GPT 모델 훈련(64 GPUs) ##

### 1. 사전준비 ###
헤드 노드에 파이썬 패키지 매니저인 uv 와 meagron-core 라이브러리를 설치한다. 
```
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

uv pip install megatron-core
```
학습 스크립트 다운로드 한다.
```
git clone https://github.com/NVIDIA/Megatron-LM.git
cd Megatron-LM
```

### 2. GPU 파티션 추가 ###
g7e.48xlarge (8 GPUs) * 8 EA 로 구성된 슬럼 파티션을 생성한다.
```

```

### 3. 훈련 작업 실행 ### 
```
# TP=4, PP=4, CP=2, DP=2 => 4 × 4 × 2 × 2 = 64 GPUs
torchrun --nproc_per_node=8 pretrain_gpt.py \
    --tensor-model-parallel-size 4 \
    --pipeline-model-parallel-size 4 \
    --context-parallel-size 2 \
    --num-layers 80 \
    --hidden-size 8192 \
    --num-attention-heads 64 \
    --seq-length 8192 \
    --micro-batch-size 1 \
    --global-batch-size 512 \
    --bf16
```

## 레퍼런스 ##
* https://docs.nvidia.com/megatron-core/developer-guide/latest/user-guide/index.html#quick-start


