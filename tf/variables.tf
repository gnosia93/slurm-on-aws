variable "aws_region" {
  default = "ap-northeast-2"
}

variable "key_name" {
  description = "AWS Key Pair Name"
  type        = string
}

# 인스턴스 타입 설정
variable "master_instance_type" {
  default = "t3.medium"
}

variable "cpu_worker_instance_type" {
  default = "r7iz.large" # Intel AMX 지원
}

variable "gpu_worker_instance_type" {
  default = "g4dn.xlarge" # NVIDIA T4
}

# 인스턴스 개수 설정
variable "cpu_worker_count" {
  default = 4
}

variable "gpu_worker_count" {
  default = 4
}

variable "ami_id" {
  default = "ami-0c02fb55956c7d316" # Amazon Linux 2023
}
