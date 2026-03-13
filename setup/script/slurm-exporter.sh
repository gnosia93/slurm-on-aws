#!/bin/bash
set -e

# Docker 데몬 준비 대기
for i in $(seq 1 30); do
  docker info &>/dev/null && break
  echo "Waiting for Docker daemon... ($i/30)"
  sleep 5
done

# --- Node Exporter (포트: 9100) ---
docker run -d --restart always \
  --name node-exporter \
  --net host \
  --pid host \
  -v /:/host:ro,rslave \
  quay.io/prometheus/node-exporter:v1.8.2 \
  --path.rootfs=/host


# --- SLURM Exporter (포트: 9341) - Head Node 전용 ---
# Go 설치
sudo snap install go --classic

# prometheus-slurm-exporter 빌드
cd /tmp
git clone https://github.com/vpenso/prometheus-slurm-exporter.git
cd prometheus-slurm-exporter
go mod download
sudo go build -o /usr/local/bin/prometheus-slurm-exporter

# systemd 서비스 등록
sudo tee /etc/systemd/system/slurm-exporter.service <<EOF
[Unit]
Description=Prometheus SLURM Exporter
After=network.target slurmd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/prometheus-slurm-exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable slurm-exporter
sudo systemctl start slurm-exporter

echo "============================================"
echo "SLURM exporter installed successfully"
echo "============================================"
echo "SLURM Exporter: http://localhost:9341/metrics"
