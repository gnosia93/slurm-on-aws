output "slurm_vscode" {
    value = "http://${aws_instance.x86_box.public_dns}:9090"
    description = "브라우저에서 VS Code 서버에 접속할 수 있는 URL (PW: 'password' by default)"
}

output "slurm_monitor" {
    value = "http://${aws_instance.x86_monitor.public_dns}:9090"
    description = "브라우저에서 VS Code 서버에 접속할 수 있는 URL (PW: 'password' by default)"
}



