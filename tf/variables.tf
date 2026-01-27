variable "aws_region" {
  default = "ap-northeast-2"
}

variable "key_name" {
  description = "AWS 콘솔에 등록된 SSH 키 페어 이름"
  type        = string
}

variable "my_ip" {
  description = "관리자 접속 허용 공인 IP (예: 1.2.3.4/32)"
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

# 노드 대수 설정
variable "cpu_node_count" {
  default = 4
}

variable "gpu_node_count" {
  default = 4
}
