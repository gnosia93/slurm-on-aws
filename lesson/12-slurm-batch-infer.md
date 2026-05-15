## Slurm 배치 인퍼런스 ##
Slurm 환경에서는 AI 모델을 실시간으로 켜놓는 '서버' 형태보다는, "데이터 입력을 받아서 추론을 끝내고 결과 파일을 저장한 뒤 종료하는 배치(Batch) 작업" 형태로 구동하는 것이 정석이다. 여기서는 g7e.24xlarge (4GPU, VRAM 96GB * 4EA) 1대로 Cohere Command R+ 104B 모델을 서빙한다. 모델은 TP 또는 PP 를 이용하여 4 GPU 로 구성할 예정이다. 

> [!WARNING]
> 예제에서는 g 인스턴스 타입을 사용하여 PP 또는 TP를 구현하고 있으나, 실제 운영환경에서 NVSwitch 를 활용한 TP 구성이 필요하다. 
> 이 모델의 경우 Forward Pass 1회시 발생하는 GPU 간의 통신은 64 레이어 × 2 회 = 128번 이상의 all-reduece 통신이 발생하기 때문에 NVSwitch를 지원하지 않는 인스턴스 타입을 사용하는 경우 인퍼런스 속도면에서 불리하다.


### 1. g7e.24xlarge 파티션 추가 ###
g7e.24xlarge 2대로 구성된 gpu-g7e-24x slurm 파티션을 생성한다. 

cluster-config.yaml 예시 수정본
```
Scheduling:
  Scheduler: slurm
  SlurmQueues:
    # ... 기존에 있던 다른 큐들 ...

    # 1. 신규 파티션(큐) 추가
    - Name: gpu-g7e-24x
      CapacityType: ONDEMAND # 또는 SPOT (비용 절감시)
      ComputeResources:
        - Name: g7e-24xlarge-nodes
          InstanceType: g7e.24xlarge
          MinCount: 0 # 평소에는 0대로 유지하여 비용 절감 (오토스케일링)
          MaxCount: 2 # 최대 2대까지 자동으로 켜지도록 설정
      Networking:
        SubnetIds:
          - subnet-xxxxxx # 인스턴스가 생성될 VPC 서브넷 ID
```

yaml 파일을 수정한후 vscode 터미널(pcluster CLI가 설치된 곳)에서 아래 명령어를 실행하여 pcluster 에 반영한다.
```
# 1. 수정된 설정 파일이 문법에 맞는지 검증
pcluster update-cluster --cluster-name 내클러스터이름 --cluster-configuration cluster-config.yaml --dryrun

# 2. 검증이 통과되면 실제 클러스터에 반영
pcluster update-cluster --cluster-name 내클러스터이름 --cluster-configuration cluster-config.yaml
```

> [!NOTE]
> AWS ParallelCluster(pcluster)와 달리, 일반 Slurm 환경에서는 아래의 단계를 거쳐 수동으로 신규 파티션을 추가해야 합니다
> #### 1. 노드(NodeName) 및 파티션(PartitionName) 정의 ####
> /etc/slurm/slurm.conf 에 노드 및 파티션을 정의한다.
> ```
> # /etc/slurm/slurm.conf 예시
> # 노드 정의
> NodeName=gpu-node[01-02] CPUs=96 RealMemory=380000 Gres=gpu:blackwell:4
> # 파티션 정의
> PartitionName=gpu-g7e-24x Nodes=gpu-node[01-02] MaxTime=INFINITE State=UP Default=NO
> ```
> * Default=NO: 사용자가 명시적으로 -p gpu-g7e-24x를 지정했을 때만 이 파티션이 사용된다. 만약 기본 파티션으로 바꾸고 싶다면 Default=YES로 수정한다.
> 
> #### 2. gres.conf 설정 확인하기 (GPU 인식) ####
> Slurm이 노드 안의 GPU를 올바르게 바인딩할 수 있도록 Compute 노드들의 /etc/slurm/gres.conf 파일도 설정한다.
> ```
> # /etc/slurm/gres.conf 예시
> Name=gpu Type=blackwell File=/dev/nvidia0
> Name=gpu Type=blackwell File=/dev/nvidia1
> Name=gpu Type=blackwell File=/dev/nvidia2
> Name=gpu Type=blackwell File=/dev/nvidia3
> ```
>   
> #### 3. 설정 반영 및 활성화 (가장 중요) ####
> 설정 파일을 저장한 후, Slurm 데몬이 이 정보를 새로 읽도록 동기화해야 한다. 헤드 노드 터미널에서 아래 명령어를 실행한다.
> ```
> sudo scontrol reconfigure
> ```
> 만약 신규 노드(gpu-node01,02)의 상태가 DOWN이나 DRAIN으로 되어 있다면 아래 명령어로 IDLE(대기) 상태로 깨워준다.
> ```
> sudo scontrol update NodeName=gpu-node[01-02] State=RESUME
> ```
> 설정이 완료되었다면 사용자들이 파티션을 볼 수 있는지 확인한다.
> ```
> sinfo
> ```


### 2. 인퍼런스 스크립트 (bulk_inference.py) ###
아래는 Hugging Face의 transformers 라이브러리를 이용한 추론을 예시이다. 
```
# bulk_inference.py
import json
import os
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM

def main():
    model_id = "CohereForAI/c4ai-command-r-plus"
    input_file = "inputs.jsonl"
    output_file = f"outputs_{os.environ.get('SLURM_JOB_ID', 'local')}.jsonl"
    
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Using device: {device}")

    # 1. 모델 및 패딩 토크나이저 로드
    # 대량 배치 처리를 할 때는 문장 길이를 맞추기 위해 padding 설정이 필수입니다.
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
        
    print("Loading 104B Model into multiple GPUs...")
    model = AutoModelForCausalLM.from_pretrained(
        model_id, 
        torch_dtype=torch.bfloat16, 
        device_map="auto"
    )

    # 2. 대량의 입력 데이터 읽기
    requests = []
    with open(input_file, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                requests.append(json.loads(line))
    
    print(f"Total data loaded: {len(requests)} items.")

    # 3. 배치 처리 루프 (Batch Size 설정)
    # GPU 메모리(VRAM) 상황에 맞춰 조정하세요. 104B 모델은 배치를 크게 잡으면 터지므로 2~4 정도가 적당합니다.
    BATCH_SIZE = 2 
    
    print("Starting bulk inference...")
    with open(output_file, "w", encoding="utf-8") as out_f:
        for i in range(0, len(requests), BATCH_SIZE):
            batch_data = requests[i:i+BATCH_SIZE]
            prompts = [item["prompt"] for item in batch_data]
            
            # 입력 토큰화 및 패딩 처리
            inputs = tokenizer(prompts, return_tensors="pt", padding=True, truncation=True).to(device)
            
            # 대량 추론 수행
            with torch.no_grad():
                outputs = model.generate(
                    **inputs, 
                    max_new_tokens=200,
                    temperature=0.3,
                    do_sample=True
                )
            
            # 결과 디코딩 및 파일 기록
            for idx, output in enumerate(outputs):
                # 입력 프롬프트 부분을 제외하고 생성된 답변만 추출하기 위해 기존 입력 길이를 계산
                input_len = inputs["input_ids"][idx].shape[0]
                generated_text = tokenizer.decode(output[input_len:], skip_special_tokens=True)
                
                result = {
                    "id": batch_data[idx]["id"],
                    "prompt": batch_data[idx]["prompt"],
                    "response": generated_text.strip()
                }
                
                # 한 줄씩 즉시 저장 (작업이 도중에 끊겨도 데이터 보존)
                out_f.write(json.dumps(result, ensure_ascii=False) + "\n")
            
            print(f"Progress: {i + len(batch_data)} / {len(requests)} processed.")

    print(f"Bulk inference completed! Results saved to {output_file}")

if __name__ == "__main__":
    main()
```

### 3.	Slurm 작업 제출용 셸 스크립트 (submit_bulk.sh) ###
```
#!/bin/bash
#SBATCH --job-name=cohere_bulk_infer
#SBATCH --partition=gpu-g7e-24x      # 새로 만든 Blackwell 파티션
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:4                 # Command R+ (104B) 로드를 위해 GPU 4장 모두 사용
#SBATCH --cpus-per-task=8
#SBATCH --mem=350G                   # 시스템 메모리도 넉넉하게 할당
#SBATCH --time=12:00:00              # 대량 처리를 위해 최대 12시간 허용
#SBATCH --output=logs/bulk_%j.out
#SBATCH --error=logs/bulk_%j.err

# 가상환경 활성화 및 실행
source ~/miniconda3/etc/profile.d/conda.sh
conda activate ai_env

python bulk_inference.py
```

### 4.  Slurm에 작업 제출 및 모니터링 ###

```bash
sbatch submit_bulk.sh
squeue -u $USER
```
생성된 작업 ID(123456) 에 로그를 출력한다.
```bash
cat logs/infer_123456.out
```

### 대량 배치 처리 (vLLM 오프라인 배치) ###

위의 예제 코드는 Hugging Face 순정 코드로 구현되어 안정적이지만, 만약 처리해야 할 데이터가 수만 건 이상으로 너무 많다면 인퍼런스 속도가 느릴수 있다. 이때는 서버를 띄우지 않고 오직 대량 배치 속도를 높이기 위해 vLLM의 Offline Inference 기능을 쓰는 것이 유리하다. vLLM은 문장 길이에 따라 GPU 연산을 극도로 압축(PagedAttention 기술)하기 때문에 기존 코드보다 최소 3~5배 이상 속도가 빠르다.

vLLM은 PagedAttention 기술을 활용해 GPU VRAM 안에서 KV 캐시를 효율적으로 관리하므로, 대용량 모델인 Cohere Command R+ (104B)를 돌릴 때 Hugging Face 순정 코드보다 수 배 이상 빠른 압도적인 처리 속도를 보여준다.
아래는 서버를 띄우지 않고, 준비된 JSONL 파일의 데이터를 한 번에 밀어 넣는 대량 배치 스크립트이다.

#### 📝 inputs.jsonl 파일 예시 ####
```
{"id": 1, "prompt": "양자 컴퓨터가 상용화되면 현재의 RSA 암호 체계는 어떻게 되나요? 한 문장으로 요약해 주세요."}
{"id": 2, "prompt": "스타트업이 초기 인프라를 구축할 때 AWS ParallelCluster를 도입하면 얻을 수 있는 비용적 장점은 무엇인가요?"}
{"id": 3, "prompt": "초대형 언어 모델(LLM) 추론 시 vLLM 엔진이 Hugging Face 순정 코드보다 빠른 이유를 핵심 기술명 위주로 설명해줘."}
{"id": 4, "prompt": "기후 변화로 인한 해수면 상승 문제를 해결하기 위해 전 세계 과학자들이 연구 중인 혁신적인 기술 3가지만 나열해 보시오."}
{"id": 5, "prompt": "데이터 분석가 관점에서 파이썬의 Pandas 라이브러리와 Polars 라이브러리의 가장 큰 성능 차이는 어디서 발생하나요?"}
```
> [!NOTE]
> 팁 및 주의사항
>	1. 줄바꿈 주의: 하나의 대화(JSON) 안에서 줄바꿈을 하겠다고 엔터를 치면 파일 읽기 에러가 발생한다. 프롬프트 내부에서 줄바꿈을 표현하고 싶다면 반드시 \n 이라는 이스케이프 문자열을 사용해야 한다.
> 2. 커스텀 필드 확장 가능: 현재 스크립트는 prompt와 결과 매칭을 위한 id 필드만 읽도록 짜여 있지만, 필요하다면 {"id": 1, "category": "it", "prompt": "..."} 처럼 원하는 태그 필드를 추가할 수 있다. 파이썬에서 사전(Dictionary) 형태로 파싱한다.


#### vllm_bulk_inference.py ####
```
import json
import os
from vllm import LLM, SamplingParams

def main():
    model_id = "CohereForAI/c4ai-command-r-plus"
    input_file = "inputs.jsonl"
    output_file = f"outputs_vllm_{os.environ.get('SLURM_JOB_ID', 'local')}.jsonl"

    # 1. 입력 데이터 읽기
    prompts = []
    data_records = []
    with open(input_file, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                item = json.loads(line)
                prompts.append(item["prompt"])
                data_records.append(item)
    
    print(f"Total data loaded: {len(prompts)} items.")

    # 2. 생성 파라미터(Sampling Params) 설정
    # vllm은 이 파라미터를 기반으로 최적화된 토큰 생성을 수행합니다.
    sampling_params = SamplingParams(
        temperature=0.3,
        max_tokens=200,      # Hugging Face의 max_new_tokens와 동일
        skip_special_tokens=True
    )

    # 3. vLLM 엔진 초기화 및 104B 모델 로드
    print("Loading 104B Model via vLLM with 4 GPUs...")
    llm = LLM(
        model=model_id,
        tensor_parallel_size=4,       # g7e.24xlarge가 가진 GPU 4장에 모델 분할 (필수)
        dtype="bfloat16",             # 메모리 절약을 위한 데이터 타입
        trust_remote_code=True,        # 일부 모델 구동에 필요한 권한 허용
        gpu_memory_utilization=0.90   # GPU 메모리의 90%를 KV 캐시 및 모델용으로 락(Lock)
    )

    # 4. 대량 오프라인 배치 추론 실행 (vLLM의 핵심 장점)
    # 데이터를 통째로 던지면 내부에서 알아서 실시간으로 묶고 풀며 초고속 연산을 수행합니다.
    print("Starting vLLM bulk offline inference...")
    outputs = llm.generate(prompts, sampling_params)

    # 5. 결과 저장
    print("Writing results to file...")
    with open(output_file, "w", encoding="utf-8") as out_f:
        for idx, output in enumerate(outputs):
            generated_text = output.outputs[0].text
            
            result = {
                "id": data_records[idx]["id"],
                "prompt": data_records[idx].get("prompt", prompts[idx]),
                "response": generated_text.strip()
            }
            out_f.write(json.dumps(result, ensure_ascii=False) + "\n")

    print(f"vLLM Bulk inference completed! Results saved to {output_file}")

if __name__ == "__main__":
    main()
```
*	tensor_parallel_size=4: Hugging Face의 device_map="auto"는 모델의 레이어 단위로 GPU를 쪼개 쓰는 파이프라인 병렬화(PP) 방식이라 병목이 생긴다. 반면 vLLM은 한 단어를 만들 때도 4장의 GPU가 동시에 연산하는 **텐서 병렬화(TP)**를 지원하므로 대형 모델 연산 속도가 극대화된다.
*	배치 루프(for문)의 실종: Hugging Face 코드에서는 메모리가 터지는 걸 막기 위해 우리가 직접 데이터를 2개, 4개씩 쪼개서 for문을 돌렸다.. 하지만 vLLM은 데이터를 llm.generate(prompts)로 통째로 던져주면, 내부의 연속 배치(Continuous Batching) 알고리즘이 GPU 가동률을 100%에 가깝게 유지하며 가장 효율적인 크기로 알아서 묶어 처리한다.
*	지능형 KV 캐시 매니지먼트: 데이터 처리가 끝나는 대로 해당 메모리를 나노초 단위로 바로 회수해 다음 문장에 할당하므로, 메모리 부족(OOM) 에러 확률이 현저히 낮아진다.


### 참고 - GPU Memory ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/gpu-memory.png)


## 레퍼런스 ##




## 레퍼런스 ##
