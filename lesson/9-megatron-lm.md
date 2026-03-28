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

### 1. GPU 파티션 추가 ###
기존 슬럼 클러스터에 g7e.48xlarge (8 GPUs) * 8 EA 로 구성된 gpu-large 파티션을 생성한다.
```
export CLUSTER_NAME=slurm-on-aws
export AZ="2"

export AWS_DEFAULT_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
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
새로운 클러스터 설정파일을 다운로드 받는다.
```
curl -o cluster-large.yaml https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/lesson/conf/cluster-large.yaml
envsubst < cluster-large.yaml > cluster-large-resolved.yaml
cat cluster-large-resolved.yaml
```

기존 gpu 파티션을 삭제하고 gpu-large 파티션을 추가한다. 이를 위해서는 기존 컴퓨트 플릿 중지가 필요하다 
```
pcluster update-compute-fleet -n ${CLUSTER_NAME} --status STOP_REQUESTED
pcluster describe-compute-fleet -n ${CLUSTER_NAME}
```

"status" 값이 "STOPPED" 된것을 확인한 후 클러스터를 업데이트 한다. 
```
pcluster update-cluster -n ${CLUSTER_NAME} -c cluster-large-resolved.yaml
watch -n 3 pcluster describe-cluster -n ${CLUSTER_NAME} --query "clusterStatus"
```
UPDATE_COMPLTE 이 될때 까지 대기 후 완료되면, 헤드 노드로 로인하여 파티션 정보를 조회한다. 
```
pcluster ssh -n ${CLUSTER_NAME} -i ~/${KEY_NAME}.pem

sinfo -N
```
[결과]
```
NODELIST                 NODES  PARTITION STATE 
gpu-large-dy-ml-large-1      1 gpu-large* idle~ 
gpu-large-dy-ml-large-2      1 gpu-large* idle~ 
gpu-large-dy-ml-large-3      1 gpu-large* idle~ 
gpu-large-dy-ml-large-4      1 gpu-large* idle~ 
gpu-large-dy-ml-large-5      1 gpu-large* idle~ 
gpu-large-dy-ml-large-6      1 gpu-large* idle~ 
gpu-large-dy-ml-large-7      1 gpu-large* idle~ 
gpu-large-dy-ml-large-8      1 gpu-large* idle~ 
```
gpu-large-dy-ml-large-1 노드의 상세 정보를 조회한다. 
```
scontrol show node gpu-large-dy-ml-large-1
```
[결과]
```
NodeName=gpu-large-dy-ml-large-1 CoresPerSocket=1 
   CPUAlloc=0 CPUEfctv=192 CPUTot=192 CPULoad=0.00
   AvailableFeatures=dynamic,g7e.48xlarge,ml-large,efa,gpu
   ActiveFeatures=dynamic,g7e.48xlarge,ml-large,efa,gpu
   Gres=gpu:rtxproserver6000:8
   NodeAddr=gpu-large-dy-ml-large-1 NodeHostName=gpu-large-dy-ml-large-1 
   RealMemory=1992294 AllocMem=0 FreeMem=N/A Sockets=192 Boards=1
   State=IDLE+CLOUD+POWERED_DOWN ThreadsPerCore=1 TmpDisk=0 Weight=1000 Owner=N/A MCS_label=N/A
   Partitions=gpu-large 
   BootTime=None SlurmdStartTime=None
   LastBusyTime=Unknown ResumeAfterTime=None
   CfgTRES=cpu=192,mem=1992294M,billing=192
   AllocTRES=
   CurrentWatts=0 AveWatts=0
   Reason=stopping cluster [root@2026-03-28T08:18:20]
```

### 2. Megatron 설치 ###
헤드 노드에 파이썬 패키지 매니저인 uv 와 megatron-core 라이브러리 및 학습 스크립트를 설치한다. 
```
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

cd ~
uv venv .venv --system-site-packages
source .venv/bin/activate

uv pip install megatron-core
git clone https://github.com/NVIDIA/Megatron-LM.git
```
PyTorch, CUDA가 시스템 레벨에 설치되어 있는데, --system-site-packages 옵션을 이용하면 시스템에 설치된 PyTorch를 venv 안에서도 사용할 수 있다.

> [!TIP]
> 가상환경(.venv) 삭제 방법:
> 
> deactivate && rm -rf ~/.venv
                                                                                                    
                                                                                                    
### 3. 훈련 작업 실행 ### 
* TP=4, PP=4, CP=2, DP=2 => 4 × 4 × 2 × 2 = 64 GPUs
```
cat <<'EOF' > gpt-70b.sh
#!/bin/bash
#SBATCH --job-name=gpt-70b
#SBATCH --nodes=8
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=8
#SBATCH --partition=gpu-large
#SBATCH --exclusive
#SBATCH --time=72:00:00
#SBATCH --output=%x_%j.log

export MASTER_ADDR=$(scontrol show hostnames $SLURM_NODELIST | head -n1)
export MASTER_PORT=29500

source /home/ubuntu/.venv/bin/activate
cd /home/ubuntu/Megatron-LM
srun torchrun --nproc_per_node=8 \
  --nnodes=$SLURM_NNODES \
  --rdzv_backend=c10d \
  --rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT \
  pretrain_gpt.py \
    --tensor-model-parallel-size 4 \
    --pipeline-model-parallel-size 4 \
    --context-parallel-size 2 \
    --num-layers 80 \
    --hidden-size 8192 \
    --num-attention-heads 64 \
    --seq-length 8192 \
    --micro-batch-size 1 \
    --global-batch-size 512 \
    --bf16 \
    --save /fsx/checkpoints/gpt-70b \
    --load /fsx/checkpoints/gpt-70b \
    --save-interval 1000 \
    --mock-data
 
#    --data-path /fsx/data/my-dataset_text_document \
EOF
```
* mock-data 옵션을 사용하여 데이터 전처리 과정은 생략한다.

```
sudo scontrol update partition=gpu-large State=UP

sbatch gpt-70b.sh
```
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
>   - 512 × 8192(seq_length) = ~4M tokens → LLaMA와 비슷한 규모

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


