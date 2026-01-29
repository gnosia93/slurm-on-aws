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
