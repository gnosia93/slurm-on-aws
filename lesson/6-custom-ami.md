
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




## 레퍼런스 ##
* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US/08-amis
