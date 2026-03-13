### 컴퓨트 노드 줄이기 ###
#### 1. 변경전 ####
```
sinfo -N
```
[결과]
```
NODELIST     NODES PARTITION STATE 
gpu-st-ml-1      1      gpu* idle  
gpu-st-ml-2      1      gpu* idle  
gpu-st-ml-3      1      gpu* idle  
gpu-st-ml-4      1      gpu* idle  
gpu-st-ml-5      1      gpu* idle  
gpu-st-ml-6      1      gpu* idle  
gpu-st-ml-7      1      gpu* idle  
gpu-st-ml-8      1      gpu* idle  
```

#### 2. 노드 수 변경 ####
```
pcluster update-compute-fleet --cluster-name slurm-on-aws --status STOP_REQUESTED --region ap-northeast-2
pcluster describe-compute-fleet --cluster-name slurm-on-aws --region ap-northeast-2

sed -i 's/MinCount: 8/MinCount: 1/' cluster.yaml
sed -i 's/MaxCount: 8/MaxCount: 1/' cluster.yaml

pcluster update-cluster --cluster-name slurm-on-aws --cluster-configuration cluster.yaml --region ap-northeast-2
pcluster describe-cluster --cluster-name slurm-on-aws --region ap-northeast-2 | grep clusterStatus

pcluster update-compute-fleet --cluster-name slurm-on-aws --status START_REQUESTED --region ap-northeast-2
pcluster describe-compute-fleet --cluster-name slurm-on-aws --region ap-northeast-2
```
[결과]
```
{
  "status": "RUNNING",
  "lastStatusUpdatedTime": "2026-03-13T01:17:52.312Z"
}
```

#### 3. 변경 후 ####
```
sinfo -N
```
[결과]
```
NODELIST     NODES PARTITION STATE 
gpu-st-ml-1      1      gpu* idle~ ```
```


### 클러스터 삭제 ###
```
pcluster delete-cluster -n ${CLUSTER_NAME} 
```
