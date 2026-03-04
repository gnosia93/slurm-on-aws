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
