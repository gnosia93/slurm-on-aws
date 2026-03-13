#!/bin/bash
set -e

OS=$(cat /etc/os-release | grep "^NAME=" | sed 's/NAME="//' | sed 's/"//')

# Docker 데몬 준비 대기
for i in $(seq 1 30); do
  docker info &>/dev/null && break
  echo "Waiting for Docker daemon... ($i/30)"
  sleep 5
done

# --- Node Exporter (포트: 9100) ---
docker rm -f node-exporter 2>/dev/null || true
docker run -d --restart always \
  --name node-exporter \
  --net host \
  --pid host \
  -v /:/host:ro,rslave \
  quay.io/prometheus/node-exporter:v1.8.2 \
  --path.rootfs=/host
