# --- 아웃풋 설정 ---

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "베스천 호스트의 공인 IP 주소입니다."
}

output "ssh_connect_command" {
  value       = "ssh -i ${var.key_file_path} ec2-user@${aws_instance.bastion.public_ip}"
  description = "베스천 호스트에 접속하기 위한 SSH 명령어입니다."
}

output "ssh_agent_forwarding_command" {
  value       = "ssh -A -i ${var.key_file_path} ec2-user@${aws_instance.bastion.public_ip}"
  description = "프라이빗 서브넷 노드에 접속하기 위해 Agent Forwarding을 사용하는 명령어입니다."
}

output "cluster_private_ips" {
  value = {
    master     = aws_instance.nodes["master"].private_ip
    accounting = aws_instance.nodes["accounting"].private_ip
    monitor    = aws_instance.nodes["monitor"].private_ip
    cpu_nodes  = aws_instance.cpu_worker[*].private_ip
    gpu_nodes  = aws_instance.gpu_worker[*].private_ip
  }
  description = "클러스터 내부 노드들의 프라이빗 IP 목록입니다."
}
