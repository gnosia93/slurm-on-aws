## Slurm Batch Inference ##

g7e.xlarge (1GPU, VRAM 96GB) 4대로 Cohere Command R+ 104B 모델을 서빙한다. TP/PP 각각을 EFA 로 구성한다.

> [!WARNING]
> 예제에서는 g 인스턴스 타입을 사용하여 TP를 구현하고 있으나, 실제 운영환경에서 NVSwitch 를 활용한 TP 구성이 필요하다. 
> 

### GPU Memory ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/gpu-memory.png)



## 레퍼런스 ##
