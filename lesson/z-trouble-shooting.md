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
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/cloudwath-logs-error.png)
cloudwath logs 에서 error 로 조회한다.
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/cloudwath-logs-error-2.png)
