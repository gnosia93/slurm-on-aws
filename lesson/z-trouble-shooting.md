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
```
{     "datetime": "2026-03-27T04:22:25.000+00:00",     "version": 0,     "scheduler": "slurm",     "cluster-name": "slurm-on-aws",     "node-role": "ComputeFleet",     "component": "custom-action",     "level": "ERROR",     "instance-id": "i-0b67a7f4ea5a17bbd",     "event-type": "custom-action-error",     "message": "Failed to execute OnNodeConfigured script 2, return code: 2.",     "detail": {         "action": "OnNodeConfigured",         "step": 2,         "stage": "executing",         "error": {             "exit_code": 2,             "stderr": "+ NCCL_VERSION=v2.29.2-1\n+ AWS_OFI_NCCL_VERSION=v1.18.0\n+ '[' '!' -d /opt/nccl ']'\n+ git clone --single-branch --branch v2.29.2-1 https://github.com/NVIDIA/nccl.git /opt/nccl\nCloning into '/opt/nccl'...\nNote: switching to 'ebd1e929285881cb4df02c3459588a2e12b2d8c0'.\n\nYou are in 'detached HEAD' state. You can look around, make experimental\nchanges and commit them, and you can discard any commits you make in this\nstate without impacting any branches by switching back to a branch.\n\nIf you want to create a new branch to retain commits you create, you may\ndo so (now or later) by using -c with the switch command. Example:\n\n  git switch -c <new-branch-name>\n\nOr undo this operation with:\n\n  git switch -\n\nTurn off this advice by setting config variable advice.detachedHead to false\n\n+ cd /opt/nccl\n++ nproc\n+ make -j 48 src.build 'NVCC_GENCODE=-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_80,code=sm_80   -gencode=arch=compute_90,code=sm_90 -gencode=arch=compute_120,code=sm_120'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nnvcc fatal   : Unsupported gpu architecture 'compute_70'\nmake[2]: *** [/opt/nccl/build/obj/device/gensrc/rules.mk:340: /opt/nccl/build/obj/device/genobj/reduce_sum_bf16.cu.o] Error 1\nmake[1]: *** [Makefile:107: /opt/nccl/build/obj/device/manifest] Error 2\nmake[1]: *** Waiting for unfinished jobs....\nmake: *** [Makefile:28: src.build] Error 2\n"         }     },     "compute": {         "name": "gpu-st-ml-2",         "instance-id": "i-0b67a7f4ea5a17bbd",         "instance-type": "g7e.12xlarge",         "availability-zone": "ap-northeast-2b",         "address": "10.0.11.83",         "hostname": "ip-10-0-11-83.ap-northeast-2.compute.internal",         "queue-name": "gpu",         "compute-resource": "ml",         "node-type": "static"     }
```
