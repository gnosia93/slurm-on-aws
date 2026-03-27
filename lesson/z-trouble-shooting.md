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

