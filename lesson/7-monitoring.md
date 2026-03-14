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
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
export SLURM_HEAD_NODE=$(pcluster describe-cluster --cluster-name ${CLUSTER_NAME} --query "headNode.privateIpAddress")
export PUBLIC_HOSTNAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname)

echo "region: ${AWS_REGION}"
echo "vpc: ${VPC_ID}"
echo "slurm head: ${SLURM_HEAD_NODE}"
echo "public hostname: ${PUBLIC_HOSTNAME}"


mkdir -p ~/monitoring
cd ~/monitoring
```

[프로메테우스]
```
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

#  - job_name: 'slurm-exporter'
#    static_configs:
#      - targets:
#          - '${SLURM_HEAD_NODE}:9341'
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
  delete_request_store: filesystem
EOF
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
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - loki

  prometheus:
    image: prom/prometheus:v2.54.1
    container_name: prometheus
    restart: always
    ports:
      - "9091:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus

volumes:
  loki-data:
  grafana-data:
  prometheus-data:
EOF
```
docker-compose.yml 최하단의 volumes: 섹션은 Docker named volume을 선언하는 부분으로, 각 볼륨은 호스트의 /var/lib/docker/volumes/<이름>/_data/에 실제 저장되고, 
docker compose down으로 컨테이너를 삭제해도 데이터는 유지된다. 볼륨까지 삭제하려면 docker compose down -v를 써야 한다. prometheus-data 볼륨의 경우 호스트 경로는 /var/lib/docker/volumes/prometheus-data/_data/ 이며 컨테이너 내부에서는 /prometheus 에 저장된다. 


### 모니터링 스택 설치 ###
restart always 모드로 도커 컴포즈를 실행한다. EC2가 재부팅되더라도 모니터링 에이전트들은 재실행된다. 
```
docker compose up -d

echo "============================================"
echo "Monitoring stack installed"
echo "============================================"
echo "Grafana:    http://${PUBLIC_HOSTNAME}:3000"
echo "Loki:       http://${PUBLIC_HOSTNAME}:3100"
echo "Prometheus: http://${PUBLIC_HOSTNAME}:9091"
```

docker 컨테이너 실행여부를 확인한다. 
```
docker ps -a
```
[결과]
```
CONTAINER ID   IMAGE                     COMMAND                  CREATED          STATUS          PORTS                                       NAMES
7f2b43a2dbd7   grafana/grafana:11.4.0    "/run.sh"                11 seconds ago   Up 10 seconds   0.0.0.0:3000->3000/tcp, :::3000->3000/tcp   grafana
9d56ea36bf6a   prom/prometheus:v2.54.1   "/bin/prometheus --c…"   11 seconds ago   Up 10 seconds   0.0.0.0:9091->9090/tcp, :::9091->9090/tcp   prometheus
91f67606c727   grafana/loki:3.3.2        "/usr/bin/loki -conf…"   11 seconds ago   Up 10 seconds   0.0.0.0:3100->3100/tcp, :::3100->3100/tcp   loki
```

### 그라파나 설정 ###
* step 1 - http://<EC2_IP>:3000 접속 (admin/admin) 한다.
* step 2 - 그라파나 대시보드 화면에서 Data Sources 를 추가한다.
  * Loki: http://loki:3100
  * Prometheus: http://prometheus:9090
* Explore에서 로그/메트릭 조회한다.

