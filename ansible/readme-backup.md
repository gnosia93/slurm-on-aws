## slurm 설치 ##

베스천 호스를 경유하여 필요한 slurm 을 설치할 예정이다.

### SSH 설정 파일 수정 (~/.ssh/config) ###
```
export BASTION_IP=$(cd ~/slurm-on-aws/tf && terraform output | grep bastion | cut -d '"' -f2)

cd ~/slurm-on-aws/ansible
cp ~/.ssh/config ~/.ssh/config-$(date +%Y%m%d_%H%M%S) 2>/dev/null
```

로컬 머신의 ssh 설정에 베스천을 경유지로 등록하면 ansible이 자동으로 이를 사용한다.
```
cat <<EOF > ~/.ssh/config
# 베스천 호스트 설정
Host slurm-bastion
    HostName ${BASTION_IP}       
    User ubuntu
    IdentityFile ~/aws-kp-2.pem

# 프라이빗 서브넷 노드들 (10.0.1.x)
Host 10.0.1.*
    User ubuntu
    IdentityFile ~/aws-kp-2.pem
    ProxyJump slurm-bastion  # 베스천을 거쳐서 접속
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

cat ~/.ssh/config
```

ansible 플레이북으로 설치한다. 
```
ansible-playbook -i ../tf/hosts.ini slurm-deploy.yml
```
* 확인: 마스터 노드에서 sinfo를 입력하여 노드들이 idle 상태인지 확인합니다.


### (참고) slurm 설정시 고려사항 ###
Slurm 클러스터 구축의 핵심은 보안 키 공유와 설정 파일(slurm.conf) 동기화 이다. 아래와 같은 고려사항은 이미 ansible 스크립에 적용되어져 있다.

* MUNGE 키 공유
  * 모든 노드가 동일한 /etc/munge/munge.key를 가지고 있어야 인증이 성공.
  * 방법: 마스터에서 생성된 키를 로컬로 가져온(fetch) 후, 모든 워커 노드에 배포(copy)해야 한다.
  * 권한: 키 파일은 반드시 0400 혹은 0600이어야 하며 소유자는 munge.
* slurm.conf 설정 및 배포
  * Slurm은 마스터와 워커 노드가 완벽히 동일한 설정 파일을 공유.
  * ControlMachine(마스터 호스트명), NodeName(노드 리스트), PartitionName(큐 설정)이 포함된 slurm.conf를 작성하여 모든 노드의 /etc/slurm/ 경로에 뿌려줘야 한다.
* 호스트네임 해제 (Name Resolution)
각 노드가 10.0.1.x 주소가 아닌 master, node01 같은 호스트네임으로 서로를 찾을 수 있어야 한다. /etc/hosts 파일에 모든 노드의 IP와 이름을 등록하는 작업이 필요하다.


## GPU 노드 설정 ##
```
ansible-playbook -i hosts.ini gpu-setup.yml
```

```
import torch
import sys

print(f"Python version: {sys.version}")
print(f"PyTorch version: {torch.__version__}")

# GPU 사용 가능 여부 확인
cuda_available = torch.cuda.is_available()
print(f"CUDA Available: {cuda_available}")

if cuda_available:
    print(f"GPU Device Name: {torch.cuda.get_device_name(0)}")
    print(f"Current Device ID: {torch.cuda.current_device()}")
    
    # 실제 텐서 연산 테스트
    x = torch.rand(5, 3).cuda()
    print("\n[Success] Tensor on GPU:")
    print(x)
else:
    print("[Fail] CUDA is not available.")
    sys.exit(1)
```

```
#!/bin/bash
#SBATCH --job-name=gpu_check      # 작업 이름
#SBATCH --nodes=1                 # 사용할 노드 수
#SBATCH --ntasks=1                # 실행할 태스크 수
#SBATCH --gres=gpu:1              # 요청할 GPU 개수 (필수)
#SBATCH --partition=compute       # 테라폼에서 설정한 파티션 이름
#SBATCH --output=gpu_result_%j.out # 로그 출력 파일 (%j는 Job ID)

echo "Job started at: $(date)"
echo "Running on node: $(hostname)"

# 1. 드라이버 상태 확인
nvidia-smi

# 2. 파이썬 테스트 코드 실행
# (PyTorch가 설치된 환경이어야 함. 없으면 'pip install torch' 필요)
python3 gpu_test.py

echo "Job finished at: $(date)"
```

```
# 작업 제출
sbatch submit_test.sh

# 작업 상태 확인
squeue

# 결과 출력 (작업 완료 후 생성된 .out 파일 확인)
cat gpu_result_*.out
```
