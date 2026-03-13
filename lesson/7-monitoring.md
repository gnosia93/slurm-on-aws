>> 모니터링 아키텍처 그림이 필요하다... 

* Head Node: SLURM Exporter + Node Exporter
* Compute Node: DCGM Exporter + Node Exporter
* 모니터링 EC2: Prometheus + Grafana + Loki

### 도커 및 컴포즈 설치 ###
```
sudo dnf install -y docker

sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

docker --version
docker compose version
```

### 설정 파일 생성 ###
```
mkdir -p /opt/monitoring
cd /opt/monitoring
```

[프로메테우스]
```
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
export SLURM_HEAD_NODE=$(pcluster describe-cluster --cluster-name ${CLUSTER_NAME} --query "headNode.privateIpAddress")

echo "region: ${AWS_REGION}"
echo "vpc: ${VPC_ID}"
echo "slurm head: ${SLURM_HEAD_NODE}"

cat <<EOF > prometheus.yml
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
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: "${1}:9100"
      - source_labels: [__meta_ec2_tag_Name]
        target_label: node

  - job_name: 'dcgm-exporter'
    ec2_sd_configs:
      - region: ${AWS_REGION}
        port: 9400
        filters:
          - name: vpc-id
            values: ["${VPC_ID}"]
          - name: instance-state-name
            values: ["running"]
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: "${1}:9400"
      - source_labels: [__meta_ec2_tag_Name]
        target_label: node

  - job_name: 'slurm-exporter'
    static_configs:
      - targets:
          - '${SLURM_HEAD_NODE}:9341'
EOF
```

[LOKI]
```
cat <<EOF > loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 30d

compactor:
  working_directory: /loki/compactor
  retention_enabled: true
```

[docker-compose]
```
cat <<EOF > docker-compose.yml
services:
  loki:
    image: grafana/loki:3.3.2
    container_name: loki
    restart: always
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yaml:/etc/loki/local-config.yaml:ro
      - loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml

  grafana:
    image: grafana/grafana:11.4.0
    container_name: grafana
    restart: always
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=changeme
    depends_on:
      - loki

  prometheus:
    image: prom/prometheus:v2.54.1
    container_name: prometheus
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus

volumes:
  loki-data:
  grafana-data:
  prometheus-data:
EOF
```

도커 컴포즈를 실행한다. 
```
docker compose up -d

echo "============================================"
echo "Monitoring stack installed"
echo "============================================"
echo "Grafana:    http://<EC2_IP>:3000  (admin/changeme)"
echo "Loki:       http://<EC2_IP>:3100"
echo "Prometheus: http://<EC2_IP>:9090"
```


설치 후 Grafana에서 할 일:

http://<EC2_IP>:3000 접속 (admin/changeme)
Data Sources 추가:
Loki: http://loki:3100
Prometheus: http://prometheus:9090
Explore에서 로그/메트릭 조회 가능
Prometheus의 static_configs에 compute 노드 IP를 수동으로 넣어야 하는데, ParallelCluster는 노드가 동적으로 변하니까 file-based service discovery를 쓰는 게 더 좋습니다. 필요하면 그 부분도 안내해 드릴게요.

