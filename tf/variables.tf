variable "aws_region" {
  description = "AWS 배포 리전"
  default     = "ap-northeast-2"
}

variable "key_name" {
  description = "EC2 접속용 SSH 키 페어 이름"
  type        = string
  default     = "aws-kp-2"
}

variable "keyfile_path" {
  default     = "~/aws-kp-2.pem"
}

variable "instance_types" {
  type = map(string)
  default = {
    bastion    = "m7i.2xlarge"
    master     = "m7i.2xlarge"
    accounting = "m7i.2xlarge"
    client     = "m7i.2xlarge"
    monitor    = "m7i.2xlarge"
    cpu_worker = "r7i.4xlarge"
    gpu_worker = "g6e.4xlarge"
  }
}

variable "cpu_node_count" {
  default = 2
}

variable "gpu_node_count" {
  default = 2
}
