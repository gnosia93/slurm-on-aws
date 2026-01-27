variable "aws_region" { default = "ap-northeast-2" }
variable "key_name"   { type = string }
variable "my_ip"      { description = "관리자 공인 IP (x.x.x.x/32)" }

# 노드 타입 및 개수
variable "instance_types" {
  default = {
    bastion    = "t3.micro"
    master     = "t3.medium"
    accounting = "t3.medium"
    client     = "t3.small"
    monitor    = "t3.medium"
    cpu_worker = "r7iz.large"
    gpu_worker = "g4dn.xlarge"
  }
}

variable "cpu_count" { default = 4 }
variable "gpu_count" { default = 4 }
variable "ami_id"    { default = "ami-0c02fb55956c7d316" } # AL2023
