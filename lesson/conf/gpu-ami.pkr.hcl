# gpu-ami.pkr.hcl

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  default = "ap-northeast-2"
}

variable "pcluster_version" {
  default = "3.15.0"
}

variable "instance_type" {
  default = "g7e.xlarge"
}

variable "volume_size" {
  default = 200
}

variable "nccl_version" {
  default = "v2.29.2-1"
}

variable "aws_ofi_nccl_version" {
  default = "v1.18.0"
}

variable "nvcc_gencode" {
  default = "-gencode=arch=compute_80,code=sm_80 -gencode=arch=compute_89,code=sm_89 -gencode=arch=compute_90,code=sm_90 -gencode=arch=compute_120,code=sm_120"
}

variable "enroot_version" {
  default = "3.5.0"
}

variable "pyxis_version" {
  default = "0.20.0"
}

variable "dcgm_version" {
  default = "3.3.7"
}

variable "node_exporter_version" {
  default = "1.8.2"
}

# ParallelCluster 공식 AMI를 base로 사용
source "amazon-ebs" "gpu-ami" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = "ubuntu"
  ami_name      = "pcluster-gpu-custom-{{timestamp}}"

  source_ami_filter {
    filters = {
      name                = "aws-parallelcluster-${var.pcluster_version}-ubuntu-hvm-2204-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture        = "x86_64"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "pcluster-gpu-custom"
  }
}

build {
  sources = ["source.amazon-ebs.gpu-ami"]

  # 1. 시스템 업데이트
  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y"
    ]
  }

  # 2. NCCL 빌드
  provisioner "shell" {
    inline = [
      "sudo git clone --single-branch --branch ${var.nccl_version} https://github.com/NVIDIA/nccl.git /opt/nccl",
      "cd /opt/nccl",
      "sudo make -j $(nproc) src.build NVCC_GENCODE='${var.nvcc_gencode}'",
      "echo '/opt/nccl/build/lib' | sudo tee /etc/ld.so.conf.d/nccl.conf",
      "sudo ldconfig"
    ]
  }

  # 3. AWS OFI NCCL Plugin
  provisioner "shell" {
    inline = [
      "sudo git clone --single-branch --branch ${var.aws_ofi_nccl_version} https://github.com/aws/aws-ofi-nccl.git /opt/aws-ofi-nccl",
      "cd /opt/aws-ofi-nccl",
      "sudo ./autogen.sh",
      "sudo ./configure --with-libfabric=/opt/amazon/efa --with-nccl=/opt/nccl/build --with-cuda=/usr/local/cuda",
      "sudo make -j $(nproc)",
      "sudo make install"
    ]
  }

  # 4. Docker + NVIDIA Container Toolkit
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable docker",
      "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg",
      "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y nvidia-container-toolkit",
      "sudo nvidia-ctk runtime configure --runtime=docker",
      "sudo systemctl restart docker"
    ]
  }

  # 5. Enroot + Pyxis
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y jq squashfs-tools parallel",
      "curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v${var.enroot_version}/enroot_${var.enroot_version}-1_amd64.deb",
      "curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v${var.enroot_version}/enroot+caps_${var.enroot_version}-1_amd64.deb",
      "sudo dpkg -i enroot_${var.enroot_version}-1_amd64.deb enroot+caps_${var.enroot_version}-1_amd64.deb || sudo apt-get install -f -y",
      "rm -f enroot*.deb",
      "curl -fSsL -O https://github.com/NVIDIA/pyxis/releases/download/v${var.pyxis_version}/nvslurm-plugin-pyxis_${var.pyxis_version}-1_amd64.deb",
      "sudo dpkg -i nvslurm-plugin-pyxis_${var.pyxis_version}-1_amd64.deb || sudo apt-get install -f -y",
      "rm -f nvslurm*.deb"
    ]
  }

  # 6. DCGM
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y datacenter-gpu-manager=${var.dcgm_version} || true",
      "sudo systemctl enable nvidia-dcgm"
    ]
  }

  # 7. Node Exporter
  provisioner "shell" {
    inline = [
      "curl -fSsL -O https://github.com/prometheus/node_exporter/releases/download/v${var.node_exporter_version}/node_exporter-${var.node_exporter_version}.linux-amd64.tar.gz",
      "tar xzf node_exporter-*.tar.gz",
      "sudo mv node_exporter-*/node_exporter /usr/local/bin/",
      "rm -rf node_exporter-*",
      "sudo useradd --no-create-home --shell /bin/false node_exporter || true",
      "cat <<'UNIT' | sudo tee /etc/systemd/system/node_exporter.service",
      "[Unit]",
      "Description=Node Exporter",
      "After=network.target",
      "[Service]",
      "User=node_exporter",
      "ExecStart=/usr/local/bin/node_exporter",
      "Restart=always",
      "[Install]",
      "WantedBy=multi-user.target",
      "UNIT",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable node_exporter"
    ]
  }

  # 8. Alloy (Loki 에이전트) - 바이너리만 설치, 설정은 post-install에서
  provisioner "shell" {
    inline = [
      "wget -qO- https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/grafana.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main' | sudo tee /etc/apt/sources.list.d/grafana.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y alloy"
    ]
  }

  # 9. GPU Persistence Mode + 시스템 튜닝
  provisioner "shell" {
    inline = [
      "sudo nvidia-smi -pm 1 || true",
      "echo '* soft memlock unlimited' | sudo tee -a /etc/security/limits.conf",
      "echo '* hard memlock unlimited' | sudo tee -a /etc/security/limits.conf",
      "echo '* soft nofile 1048576' | sudo tee -a /etc/security/limits.conf",
      "echo '* hard nofile 1048576' | sudo tee -a /etc/security/limits.conf",
      "echo 'vm.max_map_count = 262144' | sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -p"
    ]
  }

  # 10. 정리
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*"
    ]
  }
}
