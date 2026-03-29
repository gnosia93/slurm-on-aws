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
### 해결 방법 ###
* 모델 파라미터 + 옵티마이저 + 그래디언트: ~79GB/GPU
* + Activation 메모리 (forward 중간 결과): ~15~20GB
* = 총 ~95GB → 96GB 초과
* SP(Sequence Parallel)가 있으면 activation 메모리를 줄여주는데, SP를 빼서 activation이 커짐.
* 그래서 Gradient Checkpointing으로 activation 메모리를 줄인다.
```
Gradient Checkpointing:
  forward 중간 결과를 저장하지 않고 backward 시 재계산
  → activation 메모리 대폭 감소
  → 속도 약 20~30% 느려짐

스크립트에 추가:
  --recompute-granularity full \
  --recompute-method uniform \
  --recompute-num-layers 1 \
```

## 3. alloy status - failed ##
```
$ systemctl status alloy
× alloy.service - Vendor-agnostic OpenTelemetry Collector distribution with programmable pipelines
     Loaded: loaded (/lib/systemd/system/alloy.service; enabled; vendor preset: enabled)
     Active: failed (Result: exit-code) since Sun 2026-03-29 02:00:11 UTC; 3s ago
       Docs: https://grafana.com/docs/alloy
    Process: 86954 ExecStart=/usr/bin/alloy run $CUSTOM_ARGS --storage.path=/var/lib/alloy/data $CONFIG_FILE (code=exited>
   Main PID: 86954 (code=exited, status=1/FAILURE)
        CPU: 229ms

Mar 29 02:00:11 gpu-large-st-ml-large-1 systemd[1]: alloy.service: Scheduled restart job, restart counter is at 5.
Mar 29 02:00:11 gpu-large-st-ml-large-1 systemd[1]: Stopped Vendor-agnostic OpenTelemetry Collector distribution with pro>
Mar 29 02:00:11 gpu-large-st-ml-large-1 systemd[1]: alloy.service: Start request repeated too quickly.
Mar 29 02:00:11 gpu-large-st-ml-large-1 systemd[1]: alloy.service: Failed with result 'exit-code'.
Mar 29 02:00:11 gpu-large-st-ml-large-1 systemd[1]: Failed to start Vendor-agnostic OpenTelemetry Collector distribution >
```

### 해결방법 ###
```
journalctl -u alloy -n 50 --no-pager
```
```
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: ts=2026-03-29T02:00:11.108415075Z level=error msg="failed to evaluate config" controller_path=/ controller_id="" trace_id=12bd10174598018c55256129c970394f node=loki.source.file.job_logs err="decoding configuration: /etc/alloy/config.alloy:37:3: unrecognized attribute name \"labels\""

Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: Error: /etc/alloy/config.alloy:23:3: unrecognized attribute name "labels"
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 22 |     forward_to = [loki.write.default.receiver]
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 23 |     labels     = {
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]:    |  ___^^^^^^^^^^^^^^
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 24 | |     job  = "slurmd",
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 25 | |     node = env("HOSTNAME"),
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 26 | |   }
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]:    | |_^^^
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 27 |   }
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: Error: /etc/alloy/config.alloy:9:3: unrecognized attribute name "labels"
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]:  8 |     forward_to = [loki.write.default.receiver]
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]:  9 |     labels     = {
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]:    |  ___^^^^^^^^^^^^^^
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 10 | |     job  = "syslog",
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 11 | |     node = env("HOSTNAME"),
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 12 | |   }
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]:    | |_^^^
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 13 |   }
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: Error: /etc/alloy/config.alloy:37:3: unrecognized attribute name "labels"
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 36 |     forward_to = [loki.write.default.receiver]
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 37 |     labels     = {
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]:    |  ___^^^^^^^^^^^^^^
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 38 | |     job  = "slurm-job",
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 39 | |     node = env("HOSTNAME"),
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 40 | |   }
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]:    | |_^^^
Mar 29 02:00:11 gpu-large-st-ml-large-1 alloy[86954]: 41 |   }
```
아래 구조로 수정한다.
```
$ sudo vi /etc/alloy/config.alloy
// 수정
loki.source.file "syslog" {
    targets    = [{
      __path__ = "/var/log/syslog",
      job      = "syslog",
      node     = env("HOSTNAME"),
    }]
    forward_to = [loki.write.default.receiver]
}

$ sudo systemctl restart alloy 
```

### 4. slurm job 로그 지정 ###
example
```
#SBATCH --output=/var/log/slurm/job-%j.log    # stdout
#SBATCH --error=/var/log/slurm/job-%j.err     # stderr
```
