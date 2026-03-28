
### 규칙 1: 스크래핑 주소 설정 ###
```
- source_labels: [__meta_ec2_private_ip]    # EC2 private IP 가져와서
  target_label: __address__                 # 스크래핑 주소로 설정
  replacement: "$1:9400"                    # IP:9400 형태로

# 예: __meta_ec2_private_ip = 10.0.11.46
# → __address__ = 10.0.11.46:9400
# → Prometheus가 http://10.0.11.46:9400/metrics 를 스크래핑
```

### 규칙 2: 라벨 설정 ###
```
- source_labels: [__meta_ec2_tag_Name]     # EC2 Name 태그 가져와서
  target_label: node                        # node 라벨로 설정

# 예: EC2 태그 Name = "Compute"
# → node = "Compute"
# → PromQL에서 {node="Compute"} 로 필터 가능
```
