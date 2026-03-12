
헤드 노드로 로그인해서 아래와 같은 slurm job 파일을 생성한다.
```
cat <<EOF > nccl-test.sbatch
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
8 바이트부터 1GB 까지 메시지 크기를 2배씩 늘려가며 all_reduce 성능을 측정한다.
* -b 8: begin, 시작 메시지 크기 8 bytes
* -e 1G: end, 최대 메시지 크기 1GB
* -f 2: factor, 매 반복마다 크기를 2배씩 증가 (8B → 16B → 32B → ... → 1GB)
* -g 1: 노드당 사용할 GPU 수 1개


sbatch 로 nccl 테스트를 실행한다. 
```
sbatch nccl-test.sbatch
```

결과를 확인한다.
```
# 실시간 확인
squeue
# 완료 후
cat nccl-test-*.out
```
