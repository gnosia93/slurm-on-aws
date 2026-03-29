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
loki.source.file "syslog" {
    targets    = [{
      __path__ = "/var/log/syslog",
      job      = "syslog",
      node     = env("HOSTNAME"),
    }]
    forward_to = [loki.write.default.receiver]
}

// slurmd
loki.source.file "slurmd" {
    targets    = [{
      __path__ = "/var/log/slurmd.log",
      job      = "slurmd",
      node     = env("HOSTNAME"),
    }]
    forward_to = [loki.write.default.receiver]
}

// job_logs
loki.source.file "job_logs" {
    targets    = [{
      __path__ = "/var/log/slurm/job-*.log",
      job      = "slurm-job",
      node     = env("HOSTNAME"),
    }]
    forward_to = [loki.write.default.receiver]
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
