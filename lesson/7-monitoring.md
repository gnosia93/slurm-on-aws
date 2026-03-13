
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

