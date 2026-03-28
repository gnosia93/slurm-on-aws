## 1. EC2 Init Pending ##
pcluster 생성시 ec2 할당 받고 나서 init 상태에서 pending 발생.

![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/ec2-init-pending.png)
```
vscode $ pcluster list-clusters
{
  "clusters": [
    {
      "clusterName": "slurm-on-aws",
      "cloudformationStackStatus": "CREATE_IN_PROGRESS",
      "cloudformationStackArn": "arn:aws:cloudformation:ap-northeast-2:499514681453:stack/slurm-on-aws/73bbea40-297a-11f1-8800-0ab6bb3a940b",
      "region": "ap-northeast-2",
      "version": "3.15.0",
      "clusterStatus": "CREATE_IN_PROGRESS",
      "scheduler": {
        "type": "slurm"
      }
    }
  ]
}
```
* Compute 노드 생성후 initialize 단계에서 pending 상태로 유지되다가, terminate 되고 다시 새로운 인스턴스가 만들어 지는 과정을 수차례 반복함. 
* 최종적으로는 Fail 상태로 종료됨.

### 확인 방법 ###
* cloudwath logs 에서 error 로 조회한다.
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/cloudwath-logs-error.png)

* 에러 메시지를 확인한다.
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/cloudwath-logs-error-2.png)

* compute_70 아키텍처를 지원하지 않는 CUDA 버전 문제로 판명됨
```
nvcc fatal: Unsupported gpu architecture 'compute_70'
```

### 해결 방법 ###
postinstall 스크립트인 nccl.sh 을 수정한다. (CUDA 툴킷과 GPU 아키텍처간의 버전 Miss Match) 
```
# 변경 전 (compute_70 포함)
NVCC_GENCODE="-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_80,code=sm_80 -gencode=arch=compute_90,code=sm_90 -gencode=arch=compute_120,code=sm_120"

# 변경 후 (compute_70 제거)
NVCC_GENCODE="-gencode=arch=compute_80,code=sm_80 -gencode=arch=compute_89,code=sm_89 -gencode=arch=compute_90,code=sm_90 -gencode=arch=compute_120,code=sm_120"
```
* CUDA GPU Compute Capability - https://developer.nvidia.com/cuda/gpus
* GPU에서 직접 확인:
```
nvidia-smi --query-gpu=compute_cap --format=csv
# 8.9
```

## 2. torch.OutOfMemoryError: CUDA out of memory ##
slurm Job 로그  
```
[rank6]: torch.OutOfMemoryError: CUDA out of memory. Tried to allocate 2.00 GiB. GPU 6 has a total capacity of 94.97 GiB of which 1.21 GiB is free. Including non-PyTorch memory, this process has 93.75 GiB memory in use. Of the allocated memory 91.23 GiB is allocated by PyTorch, and 1.40 GiB is reserved by PyTorch but unallocated. If reserved but unallocated memory is large try setting PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True to avoid fragmentation.  See documentation for Memory Management  (https://docs.pytorch.org/docs/stable/notes/cuda.html#optimizing-memory-usage-with-pytorch-cuda-alloc-conf)
```
