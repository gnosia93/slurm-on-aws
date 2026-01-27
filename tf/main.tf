provider "aws" {
  region = var.aws_region
}

# --- 1. 네트워크 인프라 ---
resource "aws_vpc" "slurm_vpc" {
  cidr_block           = "10.0.0.0/23"
  enable_dns_hostnames = true
  tags = {
    Name = "slurm-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.slurm_vpc.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.slurm_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.slurm_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.slurm_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

# --- 2. 보안 그룹 ---
resource "aws_security_group" "slurm_sg" {
  name   = "slurm-cluster-sg"
  vpc_id = aws_vpc.slurm_vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana 접속용 (3000)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/23"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 3. EC2 인스턴스 (관리 노드) ---
resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags = {
    Name = "slurm-bastion"
  }
}

resource "aws_instance" "master" {
  ami                    = var.ami_id
  instance_type          = var.master_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags = {
    Name = "slurm-master"
  }
}

resource "aws_instance" "accounting" {
  ami                    = var.ami_id
  instance_type          = var.accounting_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags = {
    Name = "slurm-accounting"
  }
}

resource "aws_instance" "client" {
  ami                    = var.ami_id
  instance_type          = var.client_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags = {
    Name = "slurm-client"
  }
}

resource "aws_instance" "monitor" {
  ami                    = var.ami_id
  instance_type          = var.monitor_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags = {
    Name = "slurm-monitor"
  }
}

# --- 4. EC2 인스턴스 (워커 노드) ---
resource "aws_instance" "cpu_workers" {
  count                  = var.cpu_worker_count
  ami                    = var.ami_id
  instance_type          = var.cpu_worker_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags = {
    Name = "cpu-worker-${count.index}"
  }
}

resource "aws_instance" "gpu_workers" {
  count                  = var.gpu_worker_count
  ami                    = var.ami_id
  instance_type          = var.gpu_worker_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags = {
    Name     = "gpu-worker-${count.index}"
    GpuCount = "1"
  }
}

# --- 5. Ansible Inventory 생성 ---
resource "local_file" "ansible_inventory" {
  content = <<-EOT
    [master]
    ${aws_instance.master.private_ip}

    [accounting]
    ${aws_instance.accounting.private_ip}

    [clients]
    ${aws_instance.client.private_ip}

    [monitoring]
    ${aws_instance.monitor.private_ip}

    [cpu_workers]
    %{ for ip in aws_instance.cpu_workers[*].private_ip ~}
    ${ip}
    %{ endfor ~}

    [gpu_workers]
    %{ for inst in aws_instance.gpu_workers ~}
    ${inst.private_ip} gpu_count=${inst.tags.GpuCount}
    %{ endfor ~}

    [slurm_cluster:children]
    master
    accounting
    clients
    monitoring
    cpu_workers
    gpu_workers
  EOT
  filename = "hosts.ini"
}

# --- 6. Bastion 동기화 자동화 ---
resource "null_resource" "sync_bastion" {
  depends_on = [local_file.ansible_inventory]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = aws_instance.bastion.public_ip
    private_key = file("${var.key_name}.pem")
  }

  provisioner "file" {
    source      = "hosts.ini"
    destination = "/home/ec2-user/hosts.ini"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf install -y ansible-core",
      "echo 'StrictHostKeyChecking no' >> ~/.ssh/config",
      "chmod 600 /home/ec2-user/hosts.ini"
    ]
  }
}
