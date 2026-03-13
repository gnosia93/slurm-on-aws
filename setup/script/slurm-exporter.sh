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
docker run -d --restart always \
  --name slurm-exporter \
  --network host \
  -v /etc/slurm:/etc/slurm:ro \
  -v /usr/bin/sinfo:/usr/bin/sinfo:ro \
  -v /usr/bin/squeue:/usr/bin/squeue:ro \
  -v /usr/bin/sdiag:/usr/bin/sdiag:ro \
  -v /usr/bin/sacctmgr:/usr/bin/sacctmgr:ro \
  -v /usr/lib64:/usr/lib64:ro \
  -v /run/munge:/run/munge:ro \
  ghcr.io/rivosinc/prometheus-slurm-exporter:latest

echo "============================================"
echo "SLURM exporter installed successfully"
echo "============================================"
echo "SLURM Exporter: http://localhost:9341/metrics"
