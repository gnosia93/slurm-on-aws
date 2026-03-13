#!/bin/bash
set -e

OS=$(cat /etc/os-release | grep "^NAME=" | sed 's/NAME="//' | sed 's/"//')

# --- SLURM Exporter (포트: 9341) - Head Node 전용 ---
if [ "${OS}" = "Ubuntu" ]; then
  apt-get install -y git golang-go
elif [ "${OS}" = "Amazon Linux" ]; then
  dnf install -y git golang
fi

cd /tmp
rm -rf prometheus-slurm-exporter
git clone https://github.com/vpenso/prometheus-slurm-exporter.git
cd prometheus-slurm-exporter
go mod download
go build -o /usr/local/bin/prometheus-slurm-exporter

tee /etc/systemd/system/slurm-exporter.service <<EOF
[Unit]
Description=Prometheus SLURM Exporter
After=network.target slurmd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/prometheus-slurm-exporter -listen-address :9341
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable slurm-exporter
systemctl start slurm-exporter

echo "SLURM Exporter: http://localhost:9341/metrics"

