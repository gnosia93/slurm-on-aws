## Slurm Batch Inference ##
Slurm 환경에서는 AI 모델을 실시간으로 켜놓는 '서버' 형태보다는, "데이터 입력을 받아서 추론을 끝내고 결과 파일을 저장한 뒤 종료하는 배치(Batch) 작업" 형태로 구동하는 것이 정석이다. 여기서는 g7e.24xlarge (4GPU, VRAM 96GB * 4EA) 1대로 Cohere Command R+ 104B 모델을 서빙한다. 모델은 TP 또는 PP 를 이용하여 4 GPU 로 구성할 예정이다. 

> [!WARNING]
> 예제에서는 g 인스턴스 타입을 사용하여 TP를 구현하고 있으나, 실제 운영환경에서 NVSwitch 를 활용한 TP 구성이 필요하다. 
> 이 모델의 경우 Forward Pass 1회시 발생하는 GPU 간의 통신은 64 레이어 × 2 회 = 128번 이상의 all-reduece 통신이 발생한다.



### 1.	인퍼런스 파이썬 스크립트 (inference.py) ###
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

#### 2.	Slurm 작업 제출용 셸 스크립트 (submit_inference.sh) ####




### 참고 - GPU Memory ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/gpu-memory.png)



## 레퍼런스 ##
