___테라폼으로 VPC를 빌드하는데 대략 25 ~ 30분 정도의 시간이 소요된다.___

### VPC 아키텍처 ###
![](https://github.com/gnosia93/training-on-eks/blob/main/appendix/images/terraform-vpc.png)
* VPC
* Subnets (Public / Private)
* Graviton EC2 for Code-Server
* Security Groups
* FSx for Lustre
* S3 bucket 

### [테라폼 설치](https://developer.hashicorp.com/terraform/install) ###
mac 의 경우 아래의 명령어로 설치할 수 있다. 
```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### VPC 생성 ###
테파롬을 초기화한다.
```
git pull https://github.com/gnosia93/training-on-eks.git
cd training-on-eks/tf
terraform init
```
[결과]
```
Initializing the backend...
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Finding latest version of hashicorp/http...
- Installing hashicorp/aws v6.27.0...
...
```
VPC 를 생성한다. 
```
terraform apply -auto-approve
```

### VPC 삭제 ###
```
terraform destroy --auto-approve
```

















```
terraform apply -var="gpu_worker_count=8"
```

```
# hosts.ini 파일과 AWS 키 페어 파일을 베스천으로 전송하는 예시
scp -i your-keypair.pem hosts.ini ec2-user@<Bastion_Public_IP>:/home/ec2-user/
scp -i your-keypair.pem your-keypair.pem ec2-user@<Bastion_Public_IP>:/home/ec2-user/.ssh/

```
