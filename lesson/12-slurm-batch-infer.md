## Slurm Batch Inference ##
Slurm 환경에서는 AI 모델을 실시간으로 켜놓는 '서버' 형태보다는, "데이터 입력을 받아서 추론을 끝내고 결과 파일을 저장한 뒤 종료하는 배치(Batch) 작업" 형태로 구동하는 것이 정석이다.

이 예제에서는 g7e.24xlarge (4GPU, VRAM 96GB * 4EA) 1대로 Cohere Command R+ 104B 모델을 서빙한다. 모델은 TP 또는 PP 를 이용하여 4 GPU 로 구성한다. 

> [!WARNING]
> 예제에서는 g 인스턴스 타입을 사용하여 TP를 구현하고 있으나, 실제 운영환경에서 NVSwitch 를 활용한 TP 구성이 필요하다. 
> 이 모델의 경우 Forward Pass 1회시 발생하는 GPU 간의 통신은 64 레이어 × 2 회 = 128번 이상의 all-reduece 통신이 발생한다.



#### 1.	인퍼런스 파이썬 스크립트 (inference.py) ####
#### 2.	Slurm 작업 제출용 셸 스크립트 (submit_inference.sh) ####




### 참고 - GPU Memory ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/gpu-memory.png)



## 레퍼런스 ##
