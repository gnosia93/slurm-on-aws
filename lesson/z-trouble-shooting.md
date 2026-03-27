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

### 주요 원인 ###
```
1. post-install 스크립트 실행 중
   → Docker, NCCL, Enroot, DCGM 설치에 시간 걸림
   → 특히 NCCL 소스 빌드는 수십 분 걸릴 수 있음

2. GPU 드라이버 설치/로드 중
   → Deep Learning AMI가 아닌 경우

3. FSx 마운트 대기
   → Lustre/OpenZFS가 아직 CREATING 상태
   → 마운트 실패하면 노드가 올라오지 않음

4. Placement Group 용량 부족
   → 해당 AZ에 GPU 인스턴스 재고 없음
```

### 확인 방법 ###
```
# 1. 노드 상태 확인
sinfo -N -l
```

```
cat /var/log/parallelcluster/bootstrap_error_msg 
```
[결과]
```
Cluster has been set to PROTECTED mode due to failures detected in static node provisioning. Please check /var/log/chef-client.log in the head node, or check the chef-client.log in CloudWatch logs. Please refer to https://docs.aws.amazon.com/parallelcluster/latest/ug/troubleshooting-v3.html for more details.
```





```
# 3. FSx 상태 확인
aws fsx describe-file-systems --query "FileSystems[].[FileSystemId,Lifecycle]" --output table
# AVAILABLE이어야 함, CREATING이면 아직 준비 안 됨

# 4. 컴퓨트 노드에 SSH 가능하면
ssh compute-node
cat /var/log/cloud-init-output.log
cat /var/log/parallelcluster/bootstrap.log
```
