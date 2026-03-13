#!/bin/bash
set -e

# ============================================
# DCGM + DCGM Exporter + Node Exporter + SLURM Exporter Install Script
# Target: Amazon Linux 2 / Ubuntu 22.04
# All exporters run as Docker containers
# ============================================

OS=$(cat /etc/os-release | grep "^NAME=" | sed 's/NAME="//' | sed 's/"//')

# --- DCGM 설치 ---
if [ "${OS}" = "Amazon Linux" ]; then
  distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
  yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${distribution}/x86_64/cuda-${distribution}.repo
  yum install -y datacenter-gpu-manager
elif [ "${OS}" = "Ubuntu" ]; then
  distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
  wget -q https://developer.download.nvidia.com/compute/cuda/repos/${distribution}/x86_64/cuda-keyring_1.1-1_all.deb
  dpkg -i cuda-keyring_1.1-1_all.deb
  apt-get update
  apt-get install -y datacenter-gpu-manager
fi

systemctl enable nvidia-dcgm
systemctl start nvidia-dcgm

# --- DCGM Exporter (포트: 9400) ---
docker run -d --restart always \
  --name dcgm-exporter \
  --gpus all \
  --cap-add SYS_ADMIN \
  -p 9400:9400 \
  nvcr.io/nvidia/k8s/dcgm-exporter:3.3.9-3.6.1-ubuntu22.04

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
echo "All exporters installed successfully"
echo "============================================"
echo "DCGM Exporter:  http://localhost:9400/metrics"
echo "Node Exporter:  http://localhost:9100/metrics"
echo "SLURM Exporter: http://localhost:9341/metrics"
