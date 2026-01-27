
```
terraform apply -var="gpu_worker_count=8"
```

```
# hosts.ini 파일과 AWS 키 페어 파일을 베스천으로 전송하는 예시
scp -i your-keypair.pem hosts.ini ec2-user@<Bastion_Public_IP>:/home/ec2-user/
scp -i your-keypair.pem your-keypair.pem ec2-user@<Bastion_Public_IP>:/home/ec2-user/.ssh/

```
