echo "
###################################
# BEGIN: post-install docker
###################################
"

OS=$(. /etc/os-release; echo $NAME)

if [ "${OS}" = "Amazon Linux" ]; then
    yum -y update
    yum search docker
    yum info docker
    yum -y install docker
    chgrp docker $(which docker)
    chmod g+s $(which docker)
    systemctl enable docker.service
    systemctl start docker.service
elif [ "${OS}" = "Ubuntu" ]; then
    apt-get -y update
    apt-get -y install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get -y update
    apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    chgrp docker $(which docker)
    chmod g+s $(which docker)
    systemctl enable docker.service
    systemctl start docker.service

else
        echo "Unsupported OS: ${OS}" && exit 1;
fi

echo "
###################################
# END: post-install docker
###################################
"

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
