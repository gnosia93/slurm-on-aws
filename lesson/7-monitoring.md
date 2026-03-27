
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/slurm-monitoring-arch.png)

### 도커 및 컴포즈 설치 ###
slurm monitor vscode 서버로 로그인 하여 아래 명령어를 실행한다. 
```
sudo dnf install -y docker

sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
newgrp docker

docker --version
docker compose version
```

### 설정 파일 생성 ###
```
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

export CLUSTER_NAME=slurm-on-aws
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values="${CLUSTER_NAME}" --query "Vpcs[].VpcId" --output text)
export SLURM_HEAD_NODE=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=HeadNode" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].PrivateIpAddress" --output text)
export PUBLIC_HOSTNAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname)

echo "REGION: ${AWS_REGION}"
echo "VPC: ${VPC_ID}"
echo "SLURM HEAD: ${SLURM_HEAD_NODE}"
echo "PUBLIC HOSTNAME: ${PUBLIC_HOSTNAME}"

mkdir -p ~/monitoring
cd ~/monitoring
```

#### [프로메테우스] ####
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

  - job_name: 'slurm-exporter'
    static_configs:
      - targets:
          - '${SLURM_HEAD_NODE}:9341'
EOF
```

#### [LOKI] ####
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

#### [docker-compose] ####
그라파나 데이터 소스로 prometheus 와 loki 를 등록하고 대시보드를 설정한다. 
```
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards

cat <<EOF > grafana/provisioning/datasources/datasources.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    type: loki
    url: http://loki:3100
EOF

cat <<EOF > grafana/provisioning/dashboards/dashboards.yaml
apiVersion: 1
providers:
  - name: default
    folder: ''
    type: file
    options:
      path: /var/lib/grafana/dashboards
EOF

mkdir -p grafana/dashboards
curl -o grafana/dashboards/node-exporter.json \
  "https://grafana.com/api/dashboards/1860/revisions/latest/download"
curl -o grafana/dashboards/dcgm.json \
  "https://grafana.com/api/dashboards/12239/revisions/latest/download"
curl -o grafana/dashboards/slurm.json \
  "https://grafana.com/api/dashboards/4323/revisions/latest/download"
```

> [!TIP]
> ```
> 디렉토리 구조 : 
> /home/ubuntu/monitoring/
>   ├── docker-compose.yml
>   ├── prometheus.yml
>   ├── loki-config.yaml
>   └── grafana/
>        ├── provisioning/
>        └── dashboards/
> ```



도커 컴포우즈 yaml 파일을 만든다.
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
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - loki
      - prometheus

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
> [!TIP]
> docker-compose.yml 최하단의 volumes: 섹션은 Docker named volume을 선언하는 부분으로, 각 볼륨은 호스트의 /var/lib/docker/volumes/<이름>/_data/에 실제 저장되고, 
docker compose down으로 컨테이너를 삭제해도 데이터는 유지된다. 
>
> 볼륨까지 삭제하려면 docker compose down -v를 써야 한다. prometheus-data 볼륨의 경우 호스트 경로는 /var/lib/docker/volumes/prometheus-data/_data/ 이며 컨테이너 내부에서는 /prometheus 에 저장된다. 


### 모니터링 스택 설치 ###
restart always 모드로 도커 컴포즈를 실행되며, EC2가 재부팅되더라도 모니터링 에이전트들은 자동으로 재실행된다. 
```
docker compose up -d
```
[결과]
```
 docker compose up -d
[+] Running 41/41
 ✔ loki Pulled                                                                                                                                   8.6s 
 ✔ grafana Pulled                                                                                                                                7.7s 
 ✔ prometheus Pulled                                                                                                                            11.1s 
[+] Running 7/7
 ✔ Network monitoring_default           Created                                                                                                  0.2s 
 ✔ Volume "monitoring_grafana-data"     Created                                                                                                  0.0s 
 ✔ Volume "monitoring_prometheus-data"  Created                                                                                                  0.0s 
 ✔ Volume "monitoring_loki-data"        Created                                                                                                  0.0s 
 ✔ Container prometheus                 Started                                                                                                  6.0s 
 ✔ Container loki                       Started                                                                                                  6.0s 
 ✔ Container grafana                    Started                                                                                                  1.0s
```

## 그라파나 접속 ##

http://PUBLIC HOSTNAME:3100 접속하여 admin/admin 으로 로그인 한다.

