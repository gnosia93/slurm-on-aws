
헤드 노드로 로그인해서 아래와 같은 slurm job 파일을 생성한다.
* 주의: <<EOF 대신 <<'EOF'를 사용해야 $LD_LIBRARY_PATH가 작성 시점에 치환되지 않고 실행 시점에 평가된다.
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

export LD_LIBRARY_PATH=/opt/amazon/openmpi/lib:/opt/nccl/build/lib:/opt/aws-ofi-nccl/lib:/opt/amazon/efa/lib:$LD_LIBRARY_PATH
export NCCL_DEBUG=INFO
export FI_PROVIDER=efa
export FI_EFA_USE_DEVICE_RDMA=1

srun --mpi=pmix /opt/nccl-tests/build/all_reduce_perf -b 8 -e 1G -f 2 -g 1
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


## 참고 - srun bash ##
아래는 srun bash 을 활용하여 gpu 파티션 노드들에 설치되어 있는 nccl-tests 프로그램을 재 컴파일 하는 샘플이다. srun + bash -c 커맨드 조합을 활용하며 slurm 클러스터의 각 노드에서 bash 명령어를 실행할 수 있다.  
```
srun -p gpu -N 2 --ntasks-per-node=1 \
bash -c "cd /opt/nccl-tests && sudo make clean && sudo make -j \$(nproc) MPI=1 MPI_HOME=/opt/amazon/openmpi NCCL_HOME=/opt/nccl/build CUDA_HOME=/usr/local/cuda"
```
[결과]
```
bash -c "cd /opt/nccl-tests && sudo make clean && sudo make -j \$(nproc) MPI=1 MPI_HOME=/opt/amazon/openmpi NCCL_HOME=/opt/nccl/build CUDA_HOME=/usr/local/cuda"
make -C src clean BUILDDIR=/opt/nccl-tests/build
make[1]: Entering directory '/opt/nccl-tests/src'
make -C src clean BUILDDIR=/opt/nccl-tests/build
make[1]: Entering directory '/opt/nccl-tests/src'
make[1]: Leaving directory '/opt/nccl-tests/src'
make -C src build BUILDDIR=/opt/nccl-tests/build
make[1]: Entering directory '/opt/nccl-tests/src'
Compiling  timer.cc                            > /opt/nccl-tests/build/timer.o
Compiling /opt/nccl-tests/build/verifiable/verifiable.o
Compiling  all_reduce.cu                       > /opt/nccl-tests/build/all_reduce.o
Compiling  common.cu                           > /opt/nccl-tests/build/common.o
Compiling  all_gather.cu                       > /opt/nccl-tests/build/all_gather.o
Compiling  broadcast.cu                        > /opt/nccl-tests/build/broadcast.o
Compiling  reduce_scatter.cu                   > /opt/nccl-tests/build/reduce_scatter.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  reduce.cu                           > /opt/nccl-tests/build/reduce.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  alltoall.cu                         > /opt/nccl-tests/build/alltoall.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  scatter.cu                          > /opt/nccl-tests/build/scatter.o
Compiling  gather.cu                           > /opt/nccl-tests/build/gather.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  sendrecv.cu                         > /opt/nccl-tests/build/sendrecv.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  hypercube.cu                        > /opt/nccl-tests/build/hypercube.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
make[1]: Leaving directory '/opt/nccl-tests/src'
make -C src build BUILDDIR=/opt/nccl-tests/build
make[1]: Entering directory '/opt/nccl-tests/src'
Compiling  timer.cc                            > /opt/nccl-tests/build/timer.o
Compiling /opt/nccl-tests/build/verifiable/verifiable.o
Compiling  all_reduce.cu                       > /opt/nccl-tests/build/all_reduce.o
Compiling  common.cu                           > /opt/nccl-tests/build/common.o
Compiling  all_gather.cu                       > /opt/nccl-tests/build/all_gather.o
Compiling  broadcast.cu                        > /opt/nccl-tests/build/broadcast.o
Compiling  reduce_scatter.cu                   > /opt/nccl-tests/build/reduce_scatter.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  reduce.cu                           > /opt/nccl-tests/build/reduce.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  alltoall.cu                         > /opt/nccl-tests/build/alltoall.o
Compiling  scatter.cu                          > /opt/nccl-tests/build/scatter.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  gather.cu                           > /opt/nccl-tests/build/gather.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  sendrecv.cu                         > /opt/nccl-tests/build/sendrecv.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Compiling  hypercube.cu                        > /opt/nccl-tests/build/hypercube.o
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Linking  /opt/nccl-tests/build/all_reduce.o  > /opt/nccl-tests/build/all_reduce_perf
Linking  /opt/nccl-tests/build/all_gather.o  > /opt/nccl-tests/build/all_gather_perf
Linking  /opt/nccl-tests/build/broadcast.o   > /opt/nccl-tests/build/broadcast_perf
Linking  /opt/nccl-tests/build/reduce_scatter.o > /opt/nccl-tests/build/reduce_scatter_perf
Linking  /opt/nccl-tests/build/reduce.o      > /opt/nccl-tests/build/reduce_perf
Linking  /opt/nccl-tests/build/alltoall.o    > /opt/nccl-tests/build/alltoall_perf
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Linking  /opt/nccl-tests/build/scatter.o     > /opt/nccl-tests/build/scatter_perf
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Linking  /opt/nccl-tests/build/gather.o      > /opt/nccl-tests/build/gather_perf
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Linking  /opt/nccl-tests/build/sendrecv.o    > /opt/nccl-tests/build/sendrecv_perf
Linking  /opt/nccl-tests/build/hypercube.o   > /opt/nccl-tests/build/hypercube_perf
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Linking  /opt/nccl-tests/build/all_reduce.o  > /opt/nccl-tests/build/all_reduce_perf
Linking  /opt/nccl-tests/build/all_gather.o  > /opt/nccl-tests/build/all_gather_perf
Linking  /opt/nccl-tests/build/broadcast.o   > /opt/nccl-tests/build/broadcast_perf
Linking  /opt/nccl-tests/build/reduce_scatter.o > /opt/nccl-tests/build/reduce_scatter_perf
Linking  /opt/nccl-tests/build/reduce.o      > /opt/nccl-tests/build/reduce_perf
Linking  /opt/nccl-tests/build/alltoall.o    > /opt/nccl-tests/build/alltoall_perf
Linking  /opt/nccl-tests/build/scatter.o     > /opt/nccl-tests/build/scatter_perf
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Linking  /opt/nccl-tests/build/gather.o      > /opt/nccl-tests/build/gather_perf
Linking  /opt/nccl-tests/build/sendrecv.o    > /opt/nccl-tests/build/sendrecv_perf
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
Linking  /opt/nccl-tests/build/hypercube.o   > /opt/nccl-tests/build/hypercube_perf
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
nvcc warning : Support for offline compilation for architectures prior to '<compute/sm/lto>_75' will be removed in a future release (Use -Wno-deprecated-gpu-targets to suppress warning).
make[1]: Leaving directory '/opt/nccl-tests/src'
make[1]: Leaving directory '/opt/nccl-tests/src'
```
