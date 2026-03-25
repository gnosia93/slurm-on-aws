### 파일 샤딩 전 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/lustre-non-shard.png)

⚠️ 샤딩 미적용 시 발생하는 문제 
* 메타데이터 폭탄 (MDS 병목): Lustre 상단에 수백만 개의 작은 파일(image_000001.jpg 등)이 흩어져 있어, 각 노드가 파일을 찾을 때마다 메타데이터 서버(MDS)에 과부하가 걸린다.
* 무작위 읽기 경합 (Random I/O): 여러 노드가 동시에 무작위로 작은 파일들을 요청하면서 데이터 저장소(OSS)에서 읽기 속도가 급격히 저하.
* 데이터 로딩 병목: CPU 전처리 단계까지 데이터가 제때 도달하지 못해, GPU가 연산을 멈추고 데이터를 기다리는 현상(Starvation)이 발생.
* 낮은 GPU 활용률: 결과적으로 값비싼 GPU 자원을 60~70%밖에 활용하지 못하는 비효율적인 상태 발생


### 파일 샤딩 후 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/lustre-shard.png)

주요 흐름 상세 설명
* Lustre Filesystem (상단 보라색 구역): 데이터 샤드(.tar)가 저장되어 있으며, 각 노드(Rank)가 본인에게 할당된 파일을 순차적으로 읽음.
* DataLoader: CPU에서 압축 해제 및 전처리를 수행.
* Pinned Memory: CPU와 GPU 사이의 빠른 데이터 전송을 위한 징검다리 역할.
* GPU Cluster: 노드당 8개의 GPU가 실제 모델 연산을 수행하며, DMA 전송을 통해 데이터 로딩 병목을 최소화 (GPU 내부에 있는 복사 엔진(Copy Engine)이 CPU 대산 복사 작업 수행)

### 추가적인 최적화 기법 ###

#### 1. 로컬 NVMe 캐싱 (Local SSD 활용) ####
Lustre 네트워크를 타지 않고 각 노드의 로컬 디스크를 활용하는 전략이다.
* 방법: 학습 시작 전 또는 첫 에포크(Epoch) 동안 Lustre의 데이터를 각 노드의 로컬 NVMe SSD로 복사.
* 효과: 두 번째 에포크부터는 네트워크 I/O 없이 로컬 읽기 속도(수 GB/s)로 데이터를 로드할 수 있어 가장 확실한 성능 향상을 보장.

#### 2. Prefetching & Multi-node Prefetch ####
데이터가 필요하기 직전에 미리 가져오는 설정을 정교화한다.
* Prefetch Factor: DataLoader의 prefetch_factor 값을 높여 CPU가 미리 다음 배치를 준비.
* Async Loading: I/O 작업과 연산 작업을 완벽히 오버랩(Overlap)시켜, 데이터 로딩 시간이 학습 시간에 가려지게(Hiding) 됨.

### 파일 포맷 ###
* WebDataset (.tar)	: 이미지, 오디오	바이너리 파일 묶음에 적합
* Parquet	: 텍스트, 테이블 데이터	컬럼 기반, 압축 효율 좋음
* TFRecord : TensorFlow 생태계	TF 전용
* Arrow	HuggingFace datasets : 메모리 매핑, 빠른 랜덤 접근

## IO 밴치마크 ##
IOR은 멀티노드 병렬 I/O 성능을 정확히 측정할 때 쓰고, 단순 확인은 dd로 충분하다.
### 1. ior ###
```
# 1. IOR 설치 (컴퓨트 노드에서)
sudo apt install ior
# 또는 소스 빌드
git clone https://github.com/hpc/ior.git
cd ior
./configure
make
sudo make install

# 2. FSx for Lustre가 /fsx에 마운트된 상태에서 실행
# 단일 노드 테스트
srun -N 1 ior -t 1m -b 16g -s 1 -F -o /fsx/test_file

# 멀티 노드 테스트 (4노드)
srun -N 4 --ntasks-per-node=8 ior -t 1m -b 4g -s 1 -F -o /fsx/test_file
# 4노드 × 8프로세스 = 32개가 동시에 읽기/쓰기
```
### 2. dd ###
```
# 쓰기 테스트
dd if=/dev/zero of=/fsx/test bs=1M count=10000 oflag=direct
# 10GB 쓰기 → 속도 확인

# 읽기 테스트
dd if=/fsx/test of=/dev/null bs=1M iflag=direct
```

### 3. container ###
```
# IOR 컨테이너로 실행
kubectl run ior-test --image=hpc/ior \
  --overrides='{"spec":{"containers":[{
    "name":"ior",
    "command":["ior","-t","1m","-b","16g","-s","1","-F","-o","/data/test_file"],
    "volumeMounts":[{"name":"fsx","mountPath":"/data"}]
  }],"volumes":[{"name":"fsx","persistentVolumeClaim":{"claimName":"fsx-pvc"}}]}}'
```
## 병목 확인 ##

MDS(메타데이터) 병목 확인
```
# 1. 파일 열기/조회가 느린지 확인
time ls /fsx/training/          # 느리면 MDS 병목
time stat /fsx/training/file    # 느리면 MDS 병목

# 2. CloudWatch (AWS)
MetadataOperations → 급증하면 MDS 과부하
```

OSS(데이터) 병목 확인
```
# 1. 데이터 읽기/쓰기가 느린지 확인
dd if=/fsx/test of=/dev/null bs=1M iflag=direct    # 느리면 OSS 병목

# 2. CloudWatch (AWS)
DataReadBytes / DataWriteBytes → 기대 처리량 대비 낮으면 OSS 병목

# 3. OST별 사용률 확인
lfs df -h
# 특정 OST만 100% 가까우면 → 핫스팟 (데이터 편중)
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/lustre-bottleck-compare.png)
