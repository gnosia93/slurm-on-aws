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

좌측 Explore 메뉴 선택 -> Prometheus 선택 -> 쿼리작성
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/grafana-explorer.png)


### 표현식 설명 ###
```
DCGM_FI_DEV_GPU_TEMP{instance="10.0.11.206:9400", gpu="0"}
```
```
DCGM_FI_DEV_GPU_TEMP{instance=~"${instance}", gpu=~"${gpu}"}
DCGM_FI_DEV_GPU_TEMP   → 메트릭 이름 (GPU 온도)

instance=~"${instance}" → instance 라벨을 Grafana 변수로 필터
                          =~ 는 정규식 매칭
                          ${instance}는 Grafana 대시보드 상단 드롭다운 값

gpu=~"${gpu}"           → gpu 라벨을 Grafana 변수로 필터
                          드롭다운에서 "0", "1" 등 선택
Grafana 변수가 동작하는 흐름:

1. 대시보드 상단에 드롭다운 생성됨
   [instance ▼] [gpu ▼]

2. 사용자가 선택:
   instance = "10.0.11.206:9400"
   gpu = "0"

3. 쿼리가 치환됨:
   DCGM_FI_DEV_GPU_TEMP{instance=~"10.0.11.206:9400", gpu=~"0"}

4. 해당 GPU의 온도 그래프 표시
=~는 정규식이라 .*로 전체 선택도 가능:

${instance} = ".*"  → 모든 인스턴스
${gpu} = ".*"       → 모든 GPU
Prometheus UI에서 테스트할 때는 변수가 없으니 직접 값을 넣어야 합니다:

DCGM_FI_DEV_GPU_TEMP{instance=~".*", gpu=~".*"}
```
