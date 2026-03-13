#!/bin/bash
set -e

# ============================================
# Grafana Alloy Install Script (Compute Node)
# Docker container 방식
# ============================================

# Alloy 설정 디렉토리 생성
mkdir -p /opt/alloy

# config.alloy 파일이 이미 존재한다고 가정
# 없으면 위의 config.alloy 내용을 /opt/alloy/config.alloy 에 작성

# --- Grafana Alloy (포트: 12345 - UI, 4318 - OTLP) ---
docker run -d --restart always \
  --name grafana-alloy \
  --network host \
  --hostname $(hostname) \
  -e HOSTNAME=$(hostname) \
  -v /opt/alloy/config.alloy:/etc/alloy/config.alloy:ro \
  -v /var/log:/var/log:ro \
  -v /opt/alloy/data:/var/lib/alloy/data \
  grafana/alloy:v1.5.1 \
  run /etc/alloy/config.alloy

echo "============================================"
echo "Grafana Alloy installed successfully"
echo "============================================"
echo "Alloy UI:  http://localhost:12345"
echo "Collecting logs from:"
echo "  - /var/log/slurm/"
echo "  - /var/log/syslog or /var/log/messages"
echo "  - /var/log/parallelcluster/"
echo "  - /var/log/nvidia*.log"
