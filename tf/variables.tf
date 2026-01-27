variable "aws_region" {
  default = "ap-northeast-2"
}

variable "key_name" {
  description = "AWS 콘솔에 등록된 SSH 키 페어 이름"
  type        = string
}

variable "my_ip" {
  description = "관리자 공인 IP (예: 1.2.3.4/32)"
  type        = string
}

# 인스턴스 타입 설정
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

# 인스턴스 개수 설정
variable "cpu_count" {
  default = 4
}

variable "gpu_count" {
  default = 4
}

variable "ami_id" {
  default = "ami-0c02fb55956c7d316" # Amazon Linux 2023
}
