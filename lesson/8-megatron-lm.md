;; 작성중

;; 테스트 전~ 

---
Megatron-LM은 NVIDIA가 만든 대규모 LLM 학습 프레임워크로, 수천대 GPU에서 LLM을 효율적으로 학습시킬 수 있는 엔진이다. 6D Parallelism(DP + TP + PP + SP + EP + CP)을 지원한다.

### Megatron-LM 실행 ###
```
python pretrain_gpt.py \
  --tensor-model-parallel-size 8 \     # TP=8 (노드 내 GPU 8장)
  --pipeline-model-parallel-size 4 \   # PP=4 (4개 스테이지)
  --sequence-parallel \                # SP 활성화
  --context-parallel-size 2 \          # CP=2
  --expert-model-parallel-size 4 \     # EP=4 (MoE 모델일 때)
  --data-parallel-size 8 \             # DP=8
  --num-layers 80 \
  --hidden-size 8192 \
  --num-attention-heads 64 \
  --micro-batch-size 1 \
  --global-batch-size 1024
```
* 총 GPU = TP × PP × DP x CP x EP = 8 × 4 × 8 x 2 x 4 = 2048 GPU

### Framework / API 비교 ###
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

### DP 사이즈 설계 ###
```
Llama 3 405B 학습 (Meta):
TP=8 × PP=16 × DP=? = 16,384 GPU
→ DP = 16384 / (8×16) = 128

GPT-4 급 (추정):
TP=8 × PP=8 × DP=? = 25,000+ GPU
→ DP = 수백
```

* DP 사이즈가 크면 배치 사이즈가 커짐 → 학습 step 수 줄어듦 → 학습 시간 단축
* DP 증가는 gradient All-Reduce 통신량 증가 (대역폭 병목)
* 배치가 너무 커지면 학습 수렴이 불안정해질 수 있음

DP 사이즈 계산시 global batch size를 먼저 정하고, 거기서 역산한다.
```
global_batch_size = micro_batch_size × DP × gradient_accumulation_steps

예: global_batch=1024, micro_batch=1, grad_accum=4
→ DP = 1024 / (1 × 4) = 256
```
* DP=16~32 정도면 중규모, 100+ 이면 대규모 학습

## 훈련하기 ##
>> 아래 코드는 테스트 전이다...

```
# Megatron-LM 클론
git clone https://github.com/NVIDIA/Megatron-LM.git
cd Megatron-LM

# 학습 데이터를 Megatron 포맷으로 변환 (jsonl → .bin + .idx)
python tools/preprocess_data.py \
  --input training_data.jsonl \
  --output-prefix my-gpt \
  --tokenizer-type GPT2BPETokenizer \
  --vocab-file gpt2-vocab.json \
  --merge-file gpt2-merges.txt \
  --workers 32 \
  --append-eod

# 결과: my-gpt_text_document.bin, my-gpt_text_document.idx
```
```
#!/bin/bash
# pretrain.sh

# 클러스터 설정
NNODES=64                    # 노드 수
GPUS_PER_NODE=8              # 노드당 GPU
WORLD_SIZE=$((NNODES * GPUS_PER_NODE))  # 총 512 GPU

# 병렬화 설정
TP=8
PP=4
DP=$((WORLD_SIZE / (TP * PP)))  # 512 / 32 = 16

# 모델 설정
NUM_LAYERS=80
HIDDEN_SIZE=8192
NUM_ATTENTION_HEADS=64
SEQ_LENGTH=4096
MICRO_BATCH_SIZE=1
GLOBAL_BATCH_SIZE=1024

# 데이터 경로
DATA_PATH="my-gpt_text_document"
TOKENIZER_PATH="gpt2-vocab.json"
MERGE_PATH="gpt2-merges.txt"
CHECKPOINT_PATH="checkpoints/gpt-80layer"

# 분산 실행 (torchrun)
torchrun \
  --nproc_per_node $GPUS_PER_NODE \
  --nnodes $NNODES \
  --node_rank $SLURM_NODEID \
  --master_addr $MASTER_ADDR \
  --master_port 6000 \
  pretrain_gpt.py \
  \
  --tensor-model-parallel-size $TP \
  --pipeline-model-parallel-size $PP \
  --sequence-parallel \
  --context-parallel-size 2 \
  \
  --num-layers $NUM_LAYERS \
  --hidden-size $HIDDEN_SIZE \
  --num-attention-heads $NUM_ATTENTION_HEADS \
  --seq-length $SEQ_LENGTH \
  --max-position-embeddings $SEQ_LENGTH \
  \
  --micro-batch-size $MICRO_BATCH_SIZE \
  --global-batch-size $GLOBAL_BATCH_SIZE \
  \
  --train-iters 100000 \
  --lr 1.5e-4 \
  --min-lr 1.5e-5 \
  --lr-decay-style cosine \
  --lr-warmup-iters 2000 \
  --weight-decay 0.1 \
  --clip-grad 1.0 \
  \
  --fp16 \
  --initial-loss-scale 4096 \
  \
  --data-path $DATA_PATH \
  --vocab-file $TOKENIZER_PATH \
  --merge-file $MERGE_PATH \
  --split 98,2,0 \
  \
  --save $CHECKPOINT_PATH \
  --save-interval 1000 \
  --load $CHECKPOINT_PATH \
  \
  --log-interval 10 \
  --eval-interval 500 \
  --eval-iters 50 \
  \
  --distributed-backend nccl \
  --use-flash-attn
```
```
#!/bin/bash
#SBATCH --job-name=megatron-gpt
#SBATCH --nodes=64
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-node=8
#SBATCH --cpus-per-task=12
#SBATCH --mem=0
#SBATCH --time=72:00:00
#SBATCH --partition=gpu
#SBATCH --exclusive

# NCCL 환경변수
export NCCL_DEBUG=WARN
export NCCL_IB_GID_INDEX=3
export NCCL_IB_TIMEOUT=23
export NCCL_SOCKET_IFNAME=eth0

# 마스터 노드 설정
export MASTER_ADDR=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)
export MASTER_PORT=6000

# 실행
srun bash pretrain.sh
```

## 레퍼런스 ##

* [GPT‑OSS 20B 미세 조정 방법](https://www.youtube.com/watch?v=AFhDi1ACB0k)
