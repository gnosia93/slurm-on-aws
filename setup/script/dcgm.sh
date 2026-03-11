#!/bin/bash
set -e

# ============================================
# DCGM + DCGM Exporter Install Script
# Target: Amazon Linux 2 / Ubuntu 22.04
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

# --- DCGM Exporter 설치 (Docker 컨테이너) ---
docker pull nvcr.io/nvidia/k8s/dcgm-exporter:3.3.9-3.6.1-ubuntu22.04

docker run -d --restart always \
  --name dcgm-exporter \
  --gpus all \
  --cap-add SYS_ADMIN \
  -p 9400:9400 \
  nvcr.io/nvidia/k8s/dcgm-exporter:3.3.9-3.6.1-ubuntu22.04

echo "DCGM and DCGM Exporter installed successfully"
echo "DCGM Exporter metrics: http://localhost:9400/metrics"

