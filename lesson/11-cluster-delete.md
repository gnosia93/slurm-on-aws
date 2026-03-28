## 컴퓨트 노드 ##

### 1. 노드수 변경 ###
```
sed -i 's/MinCount: 8/MinCount: 1/' cluster.yaml
sed -i 's/MaxCount: 8/MaxCount: 1/' cluster.yaml
```
```
pcluster update-cluster --cluster-name slurm-on-aws --cluster-configuration cluster.yaml 
pcluster describe-cluster --cluster-name slurm-on-aws | grep clusterStatus

pcluster update-compute-fleet --cluster-name slurm-on-aws --status START_REQUESTED 
pcluster describe-compute-fleet --cluster-name slurm-on-aws
```

### 2. 파티션(큐) 추가하기 ###

#### [cluster.yaml 에 추가할 내용] ####
```
...
SlurmQueues:
  - Name: gpu                          # 기존 파티션
    CapacityType: ONDEMAND
    ComputeResources:
      - Name: ml
        InstanceType: g7e.12xlarge
        MinCount: 0
        MaxCount: 2

  - Name: gpu-h200                     # 신규 파티션
    CapacityType: ONDEMAND
    ComputeResources:
      - Name: ml
        InstanceType: p5en.48xlarge
        MinCount: 2
        MaxCount: 2
...
```
클러스터를 업데이트 한다.
```  
pcluster update-cluster -n ${CLUSTER_NAME} -c cluster.yaml
```

## 클러스터 삭제 ##
```
pcluster delete-cluster -n ${CLUSTER_NAME} 
```

## 참고 - 노드 상태값 ##
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/slurm-node-status.png)


