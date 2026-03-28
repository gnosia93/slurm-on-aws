## 프로메테우스 ##

모니터링 대상 호스트에 각종 exporter 가 먼저 설치되어져 있어야 한다. (해당 포트에 대한 INBOUND 방화벽 오픈 필요)


### 1. 스크랩 설정 ### 
```
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    ec2_sd_configs:
      - region: ${AWS_REGION}
        port: 9100
        filters:
          - name: vpc-id
            values: ["${VPC_ID}"]
          - name: instance-state-name
            values: ["running"]
          - name: tag:Name
            values: ["Compute", "HeadNode"]          # GPU 노드, 헤드노드 필터링
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: "\$1:9100"
      - source_labels: [__meta_ec2_tag_Name]
        target_label: node
```

#### 규칙 1: 스크래핑 주소 설정 ####
```
- source_labels: [__meta_ec2_private_ip]    # EC2 private IP 가져와서
  target_label: __address__                 # 스크래핑 주소로 설정
  replacement: "$1:9400"                    # IP:9400 형태로

# 예: __meta_ec2_private_ip = 10.0.11.46
# → __address__ = 10.0.11.46:9400
# → Prometheus가 http://10.0.11.46:9400/metrics 를 스크래핑
```

#### 규칙 2: 라벨 설정 ####
```
- source_labels: [__meta_ec2_tag_Name]     # EC2 Name 태그 가져와서
  target_label: node                        # node 라벨로 설정

# 예: EC2 태그 Name = "Compute"
# → node = "Compute"
# → PromQL에서 {node="Compute"} 로 필터 가능
```

### 2. 등록 Target 확인 ###
Status -> Targets 
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/prometheus-target.png)

### 3. 메트릭 조회 ###
Graph 메뉴 선택후 -> 메트릭 입력 -> Execute 
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/prometheus-graph-query.png)


## 그라파나 ##

### 쿼리 테스트 ###
```
Grafana Explore
   http://<slurm-monitor-ip>:3000
   → 왼쪽 메뉴 → Explore (나침반 아이콘)
   → Data source: Prometheus 선택
   → 쿼리 입력
```

```
DCGM_FI_DEV_GPU_TEMP{instance="10.0.11.206:9400", gpu="0"}
```
