provider "aws" {
  region = var.aws_region
}

# --- 데이터 소스: 최신 AMI 및 내 공인 IP 조회 ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
  request_headers = {
    Accept = "text/plain"
  }
}

locals {
  # 자동으로 조회된 IP에 /32를 붙여 CIDR 완성
  my_admin_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# --- 네트워크 (VPC, IGW, NAT GW, Subnets) ---
resource "aws_vpc" "slurm_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "slurm-vpc" }
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

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.slurm_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "slurm-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
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

# --- 보안 그룹 (내 IP 자동 적용) ---
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
    cidr_blocks = [local.my_admin_cidr] # 자동 조회된 IP 적용
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [local.my_admin_cidr] # 자동 조회된 IP 적용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 인스턴스 배치 ---
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_types.bastion
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags                   = { Name = "slurm-bastion" }
}

resource "aws_instance" "nodes" {
  for_each               = { master = var.instance_types.master, accounting = var.instance_types.accounting, client = var.instance_types.client, monitor = var.instance_types.monitor }
  ami                    = data.aws_ami.al2023.id
  instance_type          = each.value
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags                   = { Name = "slurm-${each.key}" }
}

resource "aws_instance" "cpu_worker" {
  count                  = var.cpu_node_count
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_types.cpu_worker
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags                   = { Name = "cpu-worker-${count.index}" }
}

resource "aws_instance" "gpu_worker" {
  count                  = var.gpu_node_count
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_types.gpu_worker
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags                   = { Name = "gpu-worker-${count.index}", GpuCount = "1" }
}

# --- 인벤토리 생성 및 자동 동기화 ---
resource "local_file" "inventory" {
  content  = <<-EOT
    [master]
    ${aws_instance.nodes["master"].private_ip}
    [accounting]
    ${aws_instance.nodes["accounting"].private_ip}
    [monitoring]
    ${aws_instance.nodes["monitor"].private_ip}
    [clients]
    ${aws_instance.nodes["client"].private_ip}
    [cpu_workers]
    ${join("\n", aws_instance.cpu_worker[*].private_ip)}
    [gpu_workers]
    %{ for inst in aws_instance.gpu_worker ~}${inst.private_ip} gpu_count=${inst.tags.GpuCount}
    %{ endfor ~}
  EOT
  filename = "hosts.ini"
}

/*
이 부분은 보안상 이슈가 있으니 수동으로 처리한다. 
resource "null_resource" "sync" {
  depends_on = [local_file.inventory, aws_instance.bastion]
  connection {
    type = "ssh"
    user = "ec2-user"
    host = aws_instance.bastion.public_ip
    private_key = file("${var.key_file_path}")
  }
  provisioner "file" { 
    source = "hosts.ini" 
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
*/
