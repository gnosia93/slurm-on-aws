variable "aws_region" {
  description = "AWS 배포 리전"
  default     = "ap-northeast-2"
}

variable "key_name" {
  description = "EC2 접속용 SSH 키 페어 이름"
  type        = string
}

variable "instance_types" {
  type = map(string)
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

variable "cpu_node_count" {
  default = 4
}

variable "gpu_node_count" {
  default = 4
}
