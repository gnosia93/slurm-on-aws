variable "aws_region" {
  description = "AWS 리전 설정"
  default     = "ap-northeast-2" # 서울 리전
}

variable "key_name" {
  description = "EC2에 접속할 기존 SSH 키 페어 이름"
  type        = string
}

variable "cpu_worker_count" {
  description = "Intel AMX CPU 워커 노드 개수"
  default     = 4
}

variable "gpu_worker_count" {
  description = "NVIDIA GPU 워커 노드 개수"
  default     = 4
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID (리전별로 확인 필요)"
  default     = "ami-0c02fb55956c7d316" 
}
