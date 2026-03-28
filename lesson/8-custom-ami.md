Packer는 HashiCorp에서 만든 AMI 자동 빌드 도구로 CUDA 버전, 특정 NCCL 또는 NVIDIA 드라이버 버전 등 소프트웨어 스택을 세밀하게 제어할 수 있고, 자체 소프트웨어를 AMI에 패키징할 수 있다. Packer는 다음과 같은 과정을 거쳐서 AMI를 생성하게 된다. 
* 임시 EC2 인스턴스를 생성
* 정의된 스크립트(Ansible, Shell 등)를 실행하여 소프트웨어 설치
* 인스턴스를 스냅샷 떠서 AMI로 저장
* 임시 인스턴스 및 리소스 삭제

![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/packer-arch.png)

```
memlock unlimited:
  프로세스가 RAM에 고정(lock)할 수 있는 메모리 크기 제한
  기본값: 64KB / 설정값: unlimited
  RDMA(GPUDirect RDMA)에서 NIC이 메모리에 직접 DMA 하려면 해당 메모리가 물리 RAM에 고정되어 있어야 함
  → 스왑으로 내려가면 DMA 주소가 무효화 → 크래시
  → unlimited로 설정해야 NCCL이 필요한 만큼 메모리 고정 가능

vm.max_map_count:
  프로세스가 만들 수 있는 메모리 매핑(mmap) 최대 수
  기본값: 65536 / 설정값: 262144
  PyTorch/NCCL이 GPU 메모리, 공유 메모리 등을 mmap으로 매핑하는데 기본값이면 부족해서 에러 발생 가능

nofile:
  프로세스가 열 수 있는 파일 디스크립터 최대 수
  기본값: 1024 / 설정값: 1048576
  분산 학습에서 소켓 연결, 데이터 파일, 로그 파일 등 동시에 여는 파일이 많아서 기본값이면 "Too many open files" 에러

GPU Persistence Mode:
  GPU 드라이버를 항상 로드된 상태로 유지
  잡이 끝나고 다음 잡 시작할 때 드라이버 로드 지연이 없어야 하니까 GPU 클러스터에서는 무조건 켜놓음
```

### 1. packer 설치 ###
vscode 웹 콘솔에서 아래 명령어를 실행한다. 
```
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo dnf install -y packer
```

### 2. 커스텀 AMI 빌드 ###
```
curl -o gpu-ami.pkr.hcl https://raw.githubusercontent.com/gnosia93/slurm-on-aws/refs/heads/main/lesson/conf/gpu-ami.pkr.hcl

packer init gpu-ami.pkr.hcl
packer build \
  -var 'region=ap-northeast-2' \
gpu-ami.pkr.hcl
```

#### 참고 - packer 소프트웨어 스택 ###
```
ParallelCluster AMI에 이미 포함된 것:
  - NVIDIA Driver ✓
  - CUDA Toolkit ✓
  - EFA Driver ✓
  - NCCL (시스템 패키지 버전)

커스텀으로 설치하는 것:
  - NCCL (소스 빌드 → /opt/nccl) → 시스템 NCCL과 경로가 다름
  - Docker + NVIDIA Container Toolkit
  - Enroot + Pyxis
  - DCGM
  - Node Exporter
  - Alloy
```

### 3. Parallel Cluster Yaml 변경 ###
AMI 빌드과정에서 통합된 소프트웨어 스택은 cluster.yaml 의 OnNodeConfigured 섹션에서 제거한다. AMI 프리빌트 이미지를 사용하는 경우 slurm 클러스터의 프러비저닝이 좀더 빨라진다.

[cluster.yaml 예시]
```
CustomActions:
    OnNodeConfigured:
          Sequence:
            - Script: 'https://.../slurm-on-aws/refs/heads/main/setup/script/docker.sh'       <--- 제거
              Args:
                - 1.18.2-1              # NVIDIA_CONTAINER_TOOLKIT_VERSION version
            - Script: 'https://.../slurm-on-aws/refs/heads/main/setup/script/nccl.sh'         <--- 제거
              Args:
                - v2.29.2-1             # NCCL version
                - v1.18.0               # AWS OFI NCCL version
```


## 레퍼런스 ##
* https://catalog.workshops.aws/ml-on-aws-parallelcluster/en-US/08-amis
