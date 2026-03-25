### 파일 샤딩 전 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/lustre-non-shard.png)

⚠️ 샤딩 미적용 시 발생하는 문제 
* 메타데이터 폭탄 (MDS 병목): Lustre 상단에 수백만 개의 작은 파일(image_000001.jpg 등)이 흩어져 있어, 각 노드가 파일을 찾을 때마다 메타데이터 서버(MDS)에 과부하가 걸린다.
* 무작위 읽기 경합 (Random I/O): 여러 노드가 동시에 무작위로 작은 파일들을 요청하면서 데이터 저장소(OSS)에서 읽기 속도가 급격히 저하.
* 데이터 로딩 병목: CPU 전처리 단계까지 데이터가 제때 도달하지 못해, GPU가 연산을 멈추고 데이터를 기다리는 현상(Starvation)이 발생.
* 낮은 GPU 활용률: 결과적으로 값비싼 GPU 자원을 60~70%밖에 활용하지 못하는 비효율적인 상태 발생


### 파일 샤딩 후 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/lustre-shard.png)
