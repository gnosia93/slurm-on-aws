#!/bin/bash
LOKI_URL=$1

# Alloy 설치
wget -qO- https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
apt-get update -y
apt-get install -y alloy

# 설정 파일
cat > /etc/alloy/config.alloy << EOF
// syslog 수집 (Xid, OOM 등)
local.file_match "syslog" {
  path_targets = [{"__path__" = "/var/log/syslog"}]
}

loki.source.file "syslog" {
  targets    = local.file_match.syslog.targets
  forward_to = [loki.write.default.receiver]
  labels     = {
    job  = "syslog",
    node = env("HOSTNAME"),
  }
}

// slurmd 로그 수집
local.file_match "slurmd" {
  path_targets = [{"__path__" = "/opt/slurm/log/slurmd.log"}]
}

loki.source.file "slurmd" {
  targets    = local.file_match.slurmd.targets
  forward_to = [loki.write.default.receiver]
  labels     = {
    job  = "slurmd",
    node = env("HOSTNAME"),
  }
}

// 잡 로그 수집
local.file_match "job_logs" {
  path_targets = [{"__path__" = "/home/*/slurm-*.out"}]
}

loki.source.file "job_logs" {
  targets    = local.file_match.job_logs.targets
  forward_to = [loki.write.default.receiver]
  labels     = {
    job  = "slurm-job",
    node = env("HOSTNAME"),
  }
}

// Loki로 전송
loki.write "default" {
  endpoint {
    url = "${LOKI_URL}/loki/api/v1/push"
  }
}
EOF

# 시작
systemctl enable --now alloy
