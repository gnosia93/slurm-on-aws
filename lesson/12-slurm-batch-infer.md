## Slurm Batch Inference ##
Slurm 환경에서는 AI 모델을 실시간으로 켜놓는 '서버' 형태보다는, "데이터 입력을 받아서 추론을 끝내고 결과 파일을 저장한 뒤 종료하는 배치(Batch) 작업" 형태로 구동하는 것이 정석이다. 여기서는 g7e.24xlarge (4GPU, VRAM 96GB * 4EA) 1대로 Cohere Command R+ 104B 모델을 서빙한다. 모델은 TP 또는 PP 를 이용하여 4 GPU 로 구성할 예정이다. 

> [!WARNING]
> 예제에서는 g 인스턴스 타입을 사용하여 TP를 구현하고 있으나, 실제 운영환경에서 NVSwitch 를 활용한 TP 구성이 필요하다. 
> 이 모델의 경우 Forward Pass 1회시 발생하는 GPU 간의 통신은 64 레이어 × 2 회 = 128번 이상의 all-reduece 통신이 발생한다.


### 1. 신규 파티션 생성 ###

g7e.24xlarge 2대로 구성된 gpu-g7e-24x slurm 파티션을 생성한다. 


### 2. 인퍼런스 파이썬 스크립트 (inference.py) ###
아래는 Hugging Face의 transformers 라이브러리를 사용해 구글 Gemma 2 모델로 추론을 수행하는 간단한 예시이다. (Cohere 로 교체 필요)
```
# inference.py
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM

def main():
    model_id = "google/gemma-2-9b-it"  # 사용할 오픈소스 모델
    
    # GPU 사용 가능 여부 확인
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(self, f"Using device: {device}")

    # 모델 및 토크나이저 로드 (bfloat16으로 메모리 절약)
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForCausalLM.from_pretrained(
        model_id, 
        torch_dtype=torch.bfloat16, 
        device_map="auto"
    )

    # 추론할 질문
    prompt = "인공지능의 미래에 대해 한 문장으로 요약해줘."
    inputs = tokenizer(prompt, return_tensors="pt").to(device)

    # 답변 생성
    print("Generating response...")
    outputs = model.generate(**inputs, max_new_tokens=100)
    response = tokenizer.decode(outputs[0], skip_special_tokens=True)

    # 결과 출력 (Slurm 로그 파일에 기록됨)
    print("\n=== Result ===")
    print(response)

if __name__ == "__main__":
    main()
```

### 3.	Slurm 작업 제출용 셸 스크립트 (submit_inference.sh) ###
```
#!/bin/bash
#SBATCH --job-name=gemma_inference   # 작업 이름
#SBATCH --nodes=1                    # 사용할 노드 수
#SBATCH --ntasks-per-node=1          # 노드당 태스크 수
#SBATCH --gres=gpu:4                 # 필요한 GPU 개수 (예: gpu:a100:1 또는 gpu:1)
#SBATCH --cpus-per-task=16           # 데이터 처리를 위한 CPU 코어 수
#SBATCH --mem=32G                    # 시스템 메모리 신청
#SBATCH --time=00:30:00              # 최대 실행 시간 (hh:mm:ss) - 30분 제한
#SBATCH --output=logs/infer_%j.out   # 표준 출력 로그 파일 (%j는 작업 ID)
#SBATCH --error=logs/infer_%j.err    # 에러 로그 파일

# 1. 환경 오염 방지를 위해 가상환경 활성화 (Conda 등)
# 클러스터 환경에 맞게 조정 필요
source ~/miniconda3/etc/profile.d/conda.sh
conda activate ai_env

# 2. Hugging Face 모델 캐시 디렉토리 지정 (필요시 공유 스토리지로 설정)
export HF_HOME="/scratch/$USER/hf_cache"

# 3. 인퍼런스 스크립트 실행
python inference.py
```

### 4.  Slurm에 작업 제출 및 모니터링 ###

```bash
sbatch submit_inference.sh
squeue -u $USER
```
생성된 작업 ID(123456) 에 로그를 출력한다.
```bash
cat logs/infer_123456.out
```


### 참고 - GPU Memory ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/gpu-memory.png)



## 레퍼런스 ##
