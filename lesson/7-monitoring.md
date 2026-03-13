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

### 커피그 파일 생성 ###
```
cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  # Head Node exporters
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - 'localhost:9100'
        - '10.0.1.10:9100'   # compute node 1
        - '10.0.1.11:9100'   # compute node 2
        # 필요시 추가

  - job_name: 'dcgm-exporter'
    static_configs:
      - targets:
        - '10.0.1.10:9400'
        - '10.0.1.11:9400'

  - job_name: 'slurm-exporter'
    static_configs:
      - targets:
        - 'localhost:9341'
EOF
```

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

### 모니터링 설치 ###
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

```
#!/bin/bash
set -e

# Docker Compose 설치 (없는 경우)
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  mkdir -p ~/.docker/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64 \
    -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose
fi

# 디렉토리 생성 및 실행
mkdir -p /opt/monitoring
cd /opt/monitoring

# config 파일들이 위치에 있다고 가정
docker compose up -d

echo "============================================"
echo "Monitoring stack installed"
echo "============================================"
echo "Grafana:    http://<EC2_IP>:3000  (admin/changeme)"
echo "Loki:       http://<EC2_IP>:3100"
echo "Prometheus: http://<EC2_IP>:9090"
```

