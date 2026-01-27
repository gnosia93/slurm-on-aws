provider "aws" {
  region = var.aws_region
}

# --- 네트워크 인프라 ---
resource "aws_vpc" "slurm_vpc" {
  cidr_block           = "10.0.0.0/23"
  enable_dns_hostnames = true
  tags                 = { Name = "slurm-vpc" }
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

# --- 보안 그룹 ---
resource "aws_security_group" "slurm_sg" {
  name   = "slurm-sg"
  vpc_id = aws_vpc.slurm_vpc.id
  ingress { from_port = 0; to_port = 0; protocol = "-1"; self = true }
  ingress { from_port = 22; to_port = 22; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

# --- EC2 인스턴스 배치 ---
resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags                   = { Name = "slurm-bastion" }
}

resource "aws_instance" "head_node" {
  ami                    = var.ami_id
  instance_type          = var.master_instance_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags                   = { Name = "slurm-master" }
}

resource "aws_instance" "cpu_workers" {
  count                  = var.cpu_worker_count
  ami                    = var.ami_id
  instance_type          = var.cpu_worker_instance_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags                   = { Name = "cpu-worker-${count.index}" }
}

resource "aws_instance" "gpu_workers" {
  count                  = var.gpu_worker_count
  ami                    = var.ami_id
  instance_type          = var.gpu_worker_instance_type
  subnet_id              = aws_subnet.private.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.slurm_sg.id]
  tags                   = { Name = "gpu-worker-${count.index}", GpuCount = "1" }
}

# --- Ansible Inventory 출력 ---
resource "local_file" "ansible_inventory" {
  content  = <<-EOT
    [master]
    ${aws_instance.head_node.private_ip}

    [cpu_workers]
    %{ for ip in aws_instance.cpu_workers[*].private_ip ~}
    ${ip}
    %{ endfor ~}

    [gpu_workers]
    %{ for inst in aws_instance.gpu_workers ~}
    ${inst.private_ip} gpu_count=${inst.tags.GpuCount}
    %{ endfor ~}
  EOT
  filename = "hosts.ini"
}
