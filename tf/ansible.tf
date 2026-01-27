# 7. 베스천으로 hosts.ini 자동 전송 및 Ansible 환경 세팅
resource "null_resource" "ansible_sync" {
  # 인스턴스들과 인벤토리 파일이 생성된 후에 실행되도록 종속성 설정
  depends_on = [
    aws_instance.bastion, 
    aws_instance.head_node, 
    aws_instance.cpu_workers, 
    aws_instance.gpu_workers, 
    local_file.ansible_inventory
  ]

  # 베스천 호스트 접속 정보
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${var.key_name}.pem") # 로컬에 있는 .pem 파일 경로
    host        = aws_instance.bastion.public_ip
  }

  # 1. 파일 전송 (로컬 -> 베스천)
  provisioner "file" {
    source      = "hosts.ini"
    destination = "/home/ec2-user/hosts.ini"
  }

  # 2. 베스천 내부에서 Ansible 설치 및 SSH 설정 (베스천 -> 프라이빗 노드 접속용)
  provisioner "remote-exec" {
    inline = [
      "sudo dnf install -y ansible-core", # Ansible 설치
      "chmod 600 /home/ec2-user/hosts.ini",
      "echo 'StrictHostKeyChecking no' >> ~/.ssh/config" # SSH 지문 확인 비활성화 (자동화용)
    ]
  }
}
