Packer는 HashiCorp에서 만든 AMI 자동 빌드 도구로 CUDA 버전, 특정 NCCL 또는 NVIDIA 드라이버 버전 등 소프트웨어 스택을 세밀하게 제어할 수 있고, 자체 소프트웨어를 AMI에 패키징할 수 있다. Packer는 다음과 같은 과정을 거쳐서 AMI를 생성하게 된다. 
* 임시 EC2 인스턴스를 생성
* 정의된 스크립트(Ansible, Shell 등)를 실행하여 소프트웨어 설치
* 인스턴스를 스냅샷 떠서 AMI로 저장
* 임시 인스턴스 및 리소스 삭제

![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/ami-container-layers.png)

vscode 웹 콘솔에서 아래 명령어를 실행한다. 

### 1. 소프트웨어 설치 ###
```
sudo dnf install -y git make ansible
sudo dnf install -y dnf-utils
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo dnf install -y packer
```

### 2. Packer 레서피 ###
```
git clone https://github.com/aws-samples/awsome-distributed-training.git
cd awsome-distributed-training/2.ami_and_containers/1.amazon_machine_image
```
다음 명령을 실행하여 Packer를 초기화하고 플러그인을 설치합니다.
```
packer init -upgrade packer-ami.pkr.hcl
```
[결과]
```
Installed plugin github.com/hashicorp/amazon v1.8.0 in "/home/ec2-user/.config/packer/plugins/github.com/hashicorp/amazon/packer-plugin-amazon_v1.8.0_x5.0_linux_amd64"
Installed plugin github.com/hashicorp/ansible v1.1.4 in "/home/ec2-user/.config/packer/plugins/github.com/hashicorp/ansible/packer-plugin-ansible_v1.1.4_x5.0_linux_amd64"
```

### 3. AMI 빌드 ###
```
make ami_pcluster_gpu
```
Packer는 인스턴스와 관련 리소스(EC2 키, 보안 그룹 등)를 생성하고, 설치 스크립트를 실행한 뒤, 인스턴스를 종료하고 이미지(AMI)를 생성한 다음 인스턴스를 삭제한다.
이 과정은 자동으로 진행되며 터미널에 출력되고 이미지 빌드가 완료되면 새 클러스터 생성 시 사용할 수 있다. 생성된 이미지는 Amazon EC2 콘솔의 "Images → AMIs"에서 확인할 수 있다.



## 레퍼런스 ##
* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US/08-amis
