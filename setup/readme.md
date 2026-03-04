
## 필수 소프트웨어 ##
NVIDA GPU 사용하기 위해서는 아래와 같은 소프트웨어들이 설치되어 있어야 한다. 아래는 라이브러리 설치 여부를 확인하는 스크립트이다.
* 커널 헤더 및 빌드 도구 (Build Essentials) : build-essential, linux-headers-$(uname -r)
  ```
  dpkg -l | grep build-essential
  dpkg -l | grep linux-headers-$(uname -r)
  ```

* MPI(Message Passing Interface)
  ```
  ls -l /opt/amazon/openmpi  # 경로가 존재하는지 확인
  mpirun --version           # MPI 실행 도구가 잡히는지 확인
  ``` 

* NVIDIA Driver (하드웨어 인식)
  ```
  nvidia-smi
  ```

* CUDA Toolkit (컴파일 환경 구축)
  ```
  nvcc --version
  ls -ld /usr/local/cuda
  ```

* EFA Driver (네트워크 가속 준비)
  ```
  fi_info -p efa
  lsmod | grep efa
  /opt/amazon/efa/bin/efa_test.sh
  ```

* Docker & NVIDIA Container Toolkit (컨테이너 환경)
  ```
  sudo systemctl status docker
  dpkg -l | grep nvidia-container-toolkit
  cat /etc/docker/daemon.json
  ```
  cat 의 결과값이 "default-runtime": "nvidia" 와 같은 값으로 표시되어야 함.

* NCCL & aws-ofi-nccl (최종 통신 라이브러리 빌드)
  ```
  ls -l /opt/nccl/build/lib/libnccl.so
  ls -l /opt/aws-ofi-nccl/install/lib/libnccl-net.so
  ```

### AWS OFI NCCL Compile ###
* https://github.com/aws/aws-ofi-nccl/releases/tag/v1.18.0

AWS OFI NCCL v1.18.0 Latest
@github-actions github-actions released this Jan 22
· 81 commits to master since this release
 v1.18.0 
 86ebeaf
v1.18.0 (2026-01)
The 1.18.0 release series supports NCCL v2.29.2-1 while maintaining backward compatibility with older NCCL versions (NCCL v2.17.1 and later).

With this release, building with platform-aws requires Libfabric v1.22.0amzn4.0 or greater.

|Name|Version| latest |
|--- | ---| ---|
|AWS OFI NCCL|v1.18.0 Latest| |
|NCCL|v2.29.2-1| |
|Libfabric|v1.22.0amzn4.0 or greater|v2.4.0|

### NCCL Compile GENCODE ### 
```
make -j src.build NVCC_GENCODE="-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_80,code=sm_80 -gencode=arch=compute_89,code=sm_89 -gencode=arch=compute_90,code=sm_90"
```
* sm_70 (V100): 초기 Tensor Core 활용.
* sm_80 (A100): TF32 연산 및 개선된 스파스 매트릭스 가속.
* sm_89 (LS40/LS40S) : L40 및 L40S의 하드웨어 기능을 직접 활용하는 바이너리를 생성.
* sm_90 (H100): Hopper 아키텍처의 Fourth-gen Tensor Core 및 하드웨어 가속기 활용.


## 레퍼런스 ##
* https://github.com/NVIDIA/nccl
* https://github.com/aws/aws-ofi-nccl
* https://github.com/ofiwg/libfabric
* https://github.com/NVIDIA/nccl-tests
* https://github.com/NVIDIA/nvidia-container-toolkit
