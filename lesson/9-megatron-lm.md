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

## 70B GPT 모델 훈련(32 GPUs) ##

### 1. 클러스터 생성 ###
기존 클러스터를 삭제한다.
```
export PREV_CLUSTER_NAME=slurm-on-aws
pcluster delete-cluster -n ${PREV_CLUSTER_NAME}
```
g7e.48xlarge (8 GPUs) * 4 EA 노드로 구성된 megatron-cluster 클러스터를 생성한다.
```
export CLUSTER_NAME=megatron-cluster
export AZ="2"
export GPU_NODE_COUNT=4

export AWS_DEFAULT_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${PREV_CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
export PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SOA-pub-subnet-${AZ}" \
  --query "Subnets[0].SubnetId" --output text)
export PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SOA-priv-subnet-${AZ}" \
  --query "Subnets[0].SubnetId" --output text)
export SECURITY_GROUP=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ec2-host-sg" \
  --query "SecurityGroups[0].GroupId" --output text)
export LOKI_URL="http://$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=slurm-monitor" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].PrivateIpAddress" --output text):3100"

echo " "
echo "CLUSTER_NAME: ${CLUSTER_NAME}"
echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
echo "AWS_ACCOUNT_ID: ${AWS_ACCOUNT_ID}"
echo "VPC_ID: ${VPC_ID}"
echo "PUBLIC_SUBNET_ID: ${PUBLIC_SUBNET_ID}"
echo "PRIVATE_SUBNET_ID: ${PRIVATE_SUBNET_ID}"
echo "SECURITY_GROUP: ${SECURITY_GROUP}"
echo "LOKI_URL: ${LOKI_URL}"
echo "KEY_NAME: ${KEY_NAME}"
```
설정파일을 다운로드 받아 클러스터를 생성한다.
```
curl -o cluster-large.yaml https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/lesson/conf/cluster-large.yaml
envsubst < cluster-large.yaml > megatron-cluster.yaml
cat megatron-cluster.yaml

pcluster create-cluster -n ${CLUSTER_NAME} -c megatron-cluster.yaml --rollback-on-failure false
```

헤드 노드로 로그인하여 파티션 정보를 조회한다. 
```
pcluster ssh -n ${CLUSTER_NAME} -i ~/${KEY_NAME}.pem

sinfo -N
```
[결과]
```
NODELIST                 NODES  PARTITION STATE 
gpu-large-st-ml-large-1      1 gpu-large* idle  
gpu-large-st-ml-large-2      1 gpu-large* idle  
gpu-large-st-ml-large-3      1 gpu-large* idle  
gpu-large-st-ml-large-4      1 gpu-large* idle  
```

### 2. Megatron-LM 설치 ###
헤드 노드에 파이썬 패키지 매니저인 uv 와 megatron-core 라이브러리 및 학습 스크립트를 설치한다. 
```
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

cd ~
uv venv .venv --system-site-packages
source .venv/bin/activate

uv pip install megatron-core
uv pip install pybind11

git clone https://github.com/NVIDIA/Megatron-LM.git
```
* --system-site-packages 옵션을 사용하면 시스템에 설치된 PyTorch를 venv 안에서도 사용할 수 있다.

> [!TIP]
> 가상환경(.venv) 삭제 방법:
> 
> deactivate && rm -rf ~/.venv
                                                                                                                                                                     
### 3. 훈련 작업 실행 ### 
* TP=4, PP=4, DP=2 => 4 × 4 × 2 = 32 GPUs
* CP는 긴 시퀀스(32K+)에서 사용.
```
cat <<'EOF' > gpt-70b.sh
#!/bin/bash
#SBATCH --job-name=gpt-70b
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=8
#SBATCH --partition=gpu-large
#SBATCH --exclusive
#SBATCH --time=72:00:00
#SBATCH --output=%x_%j.log

export MASTER_ADDR=$(scontrol show hostnames $SLURM_NODELIST | head -n1)
export MASTER_PORT=29500

# Triton 캐시를 로컬 디스크로 (NFS 충돌 방지)
export TRITON_CACHE_DIR=/tmp/.triton
export TORCHINDUCTOR_CACHE_DIR=/tmp/.inductor

source /home/ubuntu/.venv/bin/activate
cd /home/ubuntu/Megatron-LM
srun torchrun --nproc_per_node=8 \
  --nnodes=$SLURM_NNODES \
  --rdzv_backend=c10d \
  --rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT \
  --tee 0 \
  pretrain_gpt.py \
    --tensor-model-parallel-size 4 \
    --pipeline-model-parallel-size 4 \
    --num-layers 80 \
    --num-attention-heads 64 \
    --hidden-size 8192 \
    --max-position-embeddings 4096 \
    --seq-length 4096 \
    --micro-batch-size 1 \
    --global-batch-size 512 \
    --bf16 \
    --save /fsx/checkpoints/gpt-70b \
    --load /fsx/checkpoints/gpt-70b \
    --save-interval 100 \
    --lr 1e-4 \
    --min-lr 1e-5 \
    --lr-warmup-iters 500 \
    --lr-decay-iters 100000 \
    --train-iters 1000 \
    --eval-interval 500 \
    --eval-iters 10 \
    --recompute-granularity full \
    --recompute-method uniform \
    --recompute-num-layers 1 \
    --mock-data \
    --vocab-size 32000 \
    --tokenizer-type NullTokenizer \
    --no-gradient-accumulation-fusion \
    --use-mcore-models \
    --transformer-impl local \
    --no-persist-layer-norm
  
#    --data-path /fsx/data/my-dataset_text_document \
EOF
```
* --mock-data 옵션을 사용하여 데이터 전처리 과정은 생략.
* --sequence-parallel 은 TP와 함께 사용되어 LayerNorm/Dropout의 activation 메모리를 감소 시킴.
* --sequence-parallel이 torch LayerNorm에서 지원 안됨. Apex/TE 설치 필요.
* --use-distributed-optimizer 옵션 ON/OFF 해서 테스트 필요
* --train-iters 1000 step 학습

```
sbatch gpt-70b.sh
squeue
```
[결과]
```
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
   1 gpu-large  gpt-70b   ubuntu  R       0:07      4 gpu-large-st-ml-large-[1-4]
```
훈련 작업 로그를 조회한다.
```
tail -f gpt-70b_1.log
```
[결과]
```
W0328 12:22:55.173000 52842 torch/distributed/run.py:851] Setting OMP_NUM_THREADS environment variable for each process to be 1 in default, to avoid your system being overloaded, please further tune the variable for optimal performance in your application as needed. 
W0328 12:22:55.173000 52842 torch/distributed/run.py:851] *****************************************
W0328 12:22:55.176000 52641 torch/distributed/run.py:851] 
W0328 12:22:55.176000 52641 torch/distributed/run.py:851] *****************************************
W0328 12:22:55.176000 52641 torch/distributed/run.py:851] Setting OMP_NUM_THREADS environment variable for each process to be 1 in default, to avoid your system being overloaded, please further tune the variable for optimal performance in your application as needed. 
W0328 12:22:55.176000 52641 torch/distributed/run.py:851] *****************************************
W0328 12:22:55.177000 52968 torch/distributed/run.py:851] 
W0328 12:22:55.177000 52968 torch/distributed/run.py:851] *****************************************
W0328 12:22:55.177000 52968 torch/distributed/run.py:851] Setting OMP_NUM_THREADS environment variable for each process to be 1 in default, to avoid your system being overloaded, please further tune the variable for optimal performance in your application as needed. 
W0328 12:22:55.177000 52968 torch/distributed/run.py:851] *****************************************
```

#### GPU 모니터링 ####
```
sh gpu-large-st-ml-large-1 "nvidia-smi dmon -s pcut -d 10"
```
[결과]
```
# gpu    pwr  gtemp  mtemp   mclk   pclk     sm    mem    enc    dec    jpg    ofa  rxpci  txpci 
# Idx      W      C      C    MHz    MHz      %      %      %      %      %      %   MB/s   MB/s 
    0    365     55      -  12481   2415     99     58      0      0      0      0  21846   6849 
    1    372     53      -  12481   2407    100     58      0      0      0      0  19397  11676 
    2    369     53      -  12481   2415    100     54      0      0      0      0  11370  17936 
    3    367     53      -  12481   2415    100     51      0      0      0      0   8846  23359 
    4    371     56      -  12481   2400    100     63      0      0      0      0   8425  16998 
    5    372     51      -  12481   2400    100     59      0      0      0      0  12939      2 
    6    374     51      -  12481   2407    100     62      0      0      0      0  12887   5256 
    7    368     55      -  12481   2415    100     58      0      0      0      0  25966   5846 
    0    367     56      -  12481   2415    100     61      0      0      0      0  11369  14767 
    1    373     53      -  12481   2407    100     58      0      0      0      0  14517   9245 
    2    371     54      -  12481   2407     99     39      0      0      0      0  22249  10596 
    3    364     51      -  12481   2407     99     58      0      0      0      0  15395  11682 
    4    374     53      -  12481   2400    100     66      0      0      0      0  11368  18996 
    5    376     55      -  12481   2400    100     60      0      0      0      0   7038      1 
    6    373     56      -  12481   2407    100     53      0      0      0      0  18443  14775 
    7    375     52      -  12481   2407    100     57      0      0      0      0  12940  11680 
    0    369     52      -  12481   2415    100     64      0      0      0      0  11368  16232 
    1    374     52      -  12481   2407     99     64      0      0      0      0  10202  22874 
    2    367     52      -  12481   2415    100     45      0      0      0      0   4767  22883 
    3    362     52      -  12481   2415    100     52      0      0      0      0  12943  11675 
    4    390     58      -  12481   2400    100     59      0      0      0      0  11368  14814 
    5    379     51      -  12481   2407    100     67      0      0      0      0  12951      5 
    6    378     51      -  12481   2400    100     57      0      0      0      0  18874  10986 
    7    372     58      -  12481   2407    100     58      0      0      0      0  15137  11682 
    0    364     52      -  12481   2415    100     58      0      0      0      0  11368  20400 
```
* nvidia-smi -q -d CLOCK | grep -A 5 "Max Clocks"

> [!NOTE]
> * micro-batch-size = 1 (GPU당 배치) / DP = 2 (데이터 병렬 수)
>   * → 1 step에 실제 처리: 1 × 2 = 2
> * global-batch-size = 512
>   * → gradient accumulation = 512 / 2 = 256번
>   * → 256번 forward/backward 후 1번 파라미터 업데이트
> * global-batch-size 설정:
>   - 512는 예시 값이고, 실제로는 모델 크기와 GPU 메모리에 맞춰 조정
>   - LLM 학습은 큰 배치가 안정적 (loss 수렴이 부드러움)
>   - GPT-3: 3.2M tokens per batch
>   - LLaMA: 4M tokens per batch
>   - 512 × 4096(seq_length) = ~2M tokens → LLaMA 의 1/2 수준

## 4. 메모리 계산 ##
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/70b-train-arch.png)

* 70B 모델 메모리 요구량 (BF16):
  * 파라미터:     70B × 2 bytes = 140GB
  * 옵티마이저:   70B × 12 bytes = 840GB (Adam: 파라미터 원본 + 모멘텀 + 분산)
  * 그래디언트:   70B × 4 bytes = 280GB
  * 총:          ~ 1260GB
* GPU 32대 × 96GB = 3,072GB 총 메모리
* TP=4, PP=4 로 분할하면: 1260GB / (4×4) = 78.75GB~


## 참고 - Megatron-LM 훈련 데이터셋 ##

Megatron-LM은 자체 데이터 포맷을 쓰기 때문에 전처리가 필요하다.

### 1. 데이터셋 다운로드 ###
```
# Wikipedia (가장 흔한 사전학습 데이터)
pip install datasets
python -c "
from datasets import load_dataset
ds = load_dataset('wikipedia', '20220301.en', split='train')
ds.to_json('/fsx/data/wiki.json', lines=True)
"
```
또는 [The Pile (대규모 사전학습 데이터셋)](https://huggingface.co/datasets/EleutherAI/pile) 를 사용한다. GPT-NeoX, Pythia 등 오픈소스 LLM 학습에 사용된 대표적인 사전학습 데이터셋으로, 22개 소스로 구성되어 있으며 825GB 영문 텍스트 데이터이다. 


### 2. Megatron 포맷으로 변환 ###
Megatron-LM은 .bin + .idx 포맷을 사용하므로, 변환이 필요하다 
```
cd Megatron-LM

python tools/preprocess_data.py \
  --input /fsx/data/wiki.json \
  --output-prefix /fsx/data/my-dataset \
  --tokenizer-type GPTSentencePieceTokenizer \
  --tokenizer-model /path/to/tokenizer.model \
  --workers 32 \
  --append-eod
```
* 결과:
  * /fsx/data/my-dataset_text_document.bin  (토큰 데이터)
  * /fsx/data/my-dataset_text_document.idx  (인덱스)
    
## 레퍼런스 ##
* https://docs.nvidia.com/megatron-core/developer-guide/latest/user-guide/index.html#quick-start


