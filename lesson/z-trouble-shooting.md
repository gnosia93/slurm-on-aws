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
* 노드 상태 확인
```
sinfo -N -l
```
[결과]
```
NODELIST     NODES PARTITION       STATE CPUS    S:C:T MEMORY TMP_DISK WEIGHT AVAIL_FE REASON              
gpu-st-ml-1      1      gpu*       down~ 48     48:1:1 498073        0      1 static,g inactive partition  
gpu-st-ml-2      1      gpu*       down~ 48     48:1:1 498073        0      1 static,g inactive partition  
```

* 부트스트랩 로그 확인
```
$ ls -la /var/log/parallelcluster/
total 836
drwxrwxrwt  2 root           root             4096 Mar 27 04:22 .
drwxrwxr-x 23 root           syslog           4096 Mar 27 03:58 ..
-rw-r--r--  1 root           root              310 Mar 27 04:22 bootstrap_error_msg
-rw-r--r--  1 root           root            32841 Mar 27 04:56 cfn-hup-runner.log
-rw-r--r--  1 root           root           137808 Mar 27 04:57 clustermgtd
-rw-------  1 pcluster-admin pcluster-admin  30110 Mar 27 04:57 clustermgtd.events
-rw-r-----  1 root           root            21687 Mar 27 04:57 clusterstatusmgtd
-rw-------  1 pcluster-admin pcluster-admin 590148 Mar 27 04:27 compute_console_output.log
-rw-r-----  1 pcluster-admin pcluster-admin      0 Mar 27 03:56 slurm_fleet_status_manager.log
-rw-r--r--  1 pcluster-admin pcluster-admin      0 Mar 27 03:56 slurm_resume.events
-rw-r--r--  1 pcluster-admin pcluster-admin      0 Mar 27 03:56 slurm_resume.log
-rw-r--r--  1 pcluster-admin pcluster-admin      0 Mar 27 03:56 slurm_suspend.log

$ cat /var/log/parallelcluster/bootstrap_error_msg
Cluster has been set to PROTECTED mode due to failures detected in static node provisioning.
Please check /var/log/chef-client.log in the head node, or check the chef-client.log in CloudWatch logs. Please refer to https://docs.aws.amazon.com/parallelcluster/latest/ug/troubleshooting-v3.html for more details.




```
# 3. FSx 상태 확인
aws fsx describe-file-systems --query "FileSystems[].[FileSystemId,Lifecycle]" --output table
# AVAILABLE이어야 함, CREATING이면 아직 준비 안 됨

# 4. 컴퓨트 노드에 SSH 가능하면
ssh compute-node
cat /var/log/cloud-init-output.log
cat /var/log/parallelcluster/bootstrap.log
```
