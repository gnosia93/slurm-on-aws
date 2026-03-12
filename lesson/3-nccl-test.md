
헤드 노드로 로그인해서 아래와 같은 slurm job 파일을 생성한다.
```
cat <<'EOF' > nccl-test.sbatch
#!/bin/bash
#SBATCH --job-name=nccl-test
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --output=nccl-test-%j.out
#SBATCH --error=nccl-test-%j.err

export LD_LIBRARY_PATH=/opt/nccl/build/lib:/opt/aws-ofi-nccl/lib:/opt/amazon/efa/lib:$LD_LIBRARY_PATH
export NCCL_DEBUG=INFO
export FI_PROVIDER=efa
export FI_EFA_USE_DEVICE_RDMA=1

srun /opt/nccl-tests/build/all_reduce_perf -b 8 -e 1G -f 2 -g 1
EOF
```
#### [파라미터 정보] ####
* -b 8: begin, 시작 메시지 크기 8 bytes
* -e 1G: end, 최대 메시지 크기 1GB
* -f 2: factor, 매 반복마다 크기를 2배씩 증가 (8B → 16B → 32B → ... → 1GB)
* -g 1: 노드당 사용할 GPU 수 1개

8 바이트부터 1GB 까지 메시지 크기를 2배씩 늘려가며 all_reduce 성능을 측정한다.
실제 AI 학습에서 all_reduce로 교환하는 gradient 크기가 보통 수백 MB ~ 1GB 수준이라, 1GB까지 테스트하면 실전 성능을 잘 반영하는 것이다
더 큰 사이즈를 테스트하고 싶으면 -e 2G나 -e 4G로 늘릴 수 있지만, 1GB 이후로는 bandwidth 가 거의 일정하게 수렴하기 때문에 큰 의미는 없다.
예를 들어
* 모델 파라미터 1억개 (100M) × FP32 (4 bytes) = 400MB
* 모델 파라미터 3억개 (300M) × FP16 (2 bytes) = 600MB 

각 GPU가 자기 배치에 대한 gradient를 계산한 후, all_reduce로 모든 GPU의 gradient를 합산하는데, 이때 전체 파라미터의 gradient가 한 번에 교환되는 것이다.
다만 실제로는 NCCL이 gradient를 여러 청크로 쪼개서 파이프라인 방식으로 전송하고, PyTorch도 backward 계산과 통신을 오버랩시키기 때문에 1GB를 한 덩어리로 보내는 건 아니다. 하지만 총량 기준으로 그 정도이다.


sbatch 로 nccl-test 를 실행하고, 결과를 확인한다. 
```
sbatch nccl-test.sbatch

squeue
cat nccl-test-*.out
```
squeue 는 실시간 확인용이고, cat 으로는 최종 결과를 확인할 수 있다. 


