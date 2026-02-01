variable "aws_region" {
  description = "AWS 배포 리전"
  default     = "ap-northeast-2"
}

variable "key_name" {
  description = "EC2 접속용 SSH 키 페어 이름"
  type        = string
  default     = "aws-kp-2"
}

variable "key_file_path" {
  default     = "~/aws-kp-2.pem"
}

variable "instance_types" {
  type = map(string)
  default = {
    bastion    = "m7i.xlarge"
    controld   = "m7i.xlarge"
    accounting = "m7i.xlarge"
    client     = "m7i.xlarge"
    monitor    = "m7i.xlarge"
    cpu_worker = "r7i.2xlarge"
    gpu_worker = "g6e.2xlarge"
  }
}

variable "cpu_node_count" {
  default = 0
}

variable "gpu_node_count" {
  default = 1
}
