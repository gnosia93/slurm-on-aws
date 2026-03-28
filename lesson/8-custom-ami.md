Packer는 HashiCorp에서 만든 AMI 자동 빌드 도구로 CUDA 버전, 특정 NCCL 또는 NVIDIA 드라이버 버전 등 소프트웨어 스택을 세밀하게 제어할 수 있고, 자체 소프트웨어를 AMI에 패키징할 수 있다. Packer는 다음과 같은 과정을 거쳐서 AMI를 생성하게 된다. 
* 임시 EC2 인스턴스를 생성
* 정의된 스크립트(Ansible, Shell 등)를 실행하여 소프트웨어 설치
* 인스턴스를 스냅샷 떠서 AMI로 저장
* 임시 인스턴스 및 리소스 삭제

![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/packer-arch.png)

```
vm.max_map_count:
  프로세스가 만들 수 있는 메모리 매핑(mmap) 최대 수
  기본값: 65536
  설정값: 262144

  PyTorch/NCCL이 GPU 메모리, 공유 메모리 등을 mmap으로 매핑하는데
  기본값이면 부족해서 에러 발생 가능

nofile:
  프로세스가 열 수 있는 파일 디스크립터 최대 수
  기본값: 1024
  설정값: 1048576

  분산 학습에서 소켓 연결, 데이터 파일, 로그 파일 등
  동시에 여는 파일이 많아서 기본값이면 "Too many open files" 에러

```
vscode 웹 콘솔에서 아래 명령어를 실행한다. 

### 1. packer 설치 ###
```
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo dnf install -y packer
```

### 2. AMI 빌드 ###
```
curl -o gpu-ami.pkr.hcl https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/lesson/conf/gpu-ami.pkr.hcl

packer init gpu-ami.pkr.hcl
packer build \
  -var 'nccl_version=v2.30.0-1' \
  -var 'enroot_version=3.6.0' \
  gpu-ami.pkr.hcl
```


## 레퍼런스 ##
* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US/08-amis
