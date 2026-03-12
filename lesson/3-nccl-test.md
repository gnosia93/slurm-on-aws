## nccl-test ##

헤드 노드로 로그인해서 아래와 같은 slurm job 파일을 생성한다.
* 주의: <<EOF 대신 <<'EOF'를 사용해야 $LD_LIBRARY_PATH가 작성 시점에 치환되지 않고 실행 시점에 평가된다.
```
export GPU_NODES=8

cat <<EOF > nccl-test.sbatch
#!/bin/bash
#SBATCH --job-name=nccl-test
#SBATCH --partition=gpu
#SBATCH --nodes=${GPU_NODES}
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --output=nccl-test-%j.out
#SBATCH --error=nccl-test-%j.err

export LD_LIBRARY_PATH=/opt/amazon/openmpi/lib:/opt/nccl/build/lib:/opt/aws-ofi-nccl/lib:/opt/amazon/efa/lib:\$LD_LIBRARY_PATH
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

#### [nccl-test 결과] ####
```
# Collective test starting: all_reduce_perf
# nThread 1 nGpus 1 minBytes 8 maxBytes 1073741824 step: 2(factor) warmup iters: 1 iters: 20 agg iters: 1 validation: 1 graph: 0
#
# Using devices
#  Rank  0 Group  0 Pid  78499 on gpu-st-ml-1 device  0 [0000:30:00] NVIDIA RTX PRO 6000 Blackwell Server Edition
#  Rank  1 Group  0 Pid  77729 on gpu-st-ml-2 device  0 [0000:30:00] NVIDIA RTX PRO 6000 Blackwell Server Edition
gpu-st-ml-1:78499:78499 [0] NCCL INFO ENV/Plugin: Could not find: libnccl-env.so
gpu-st-ml-1:78499:78499 [0] NCCL INFO Bootstrap: Using enp39s0:10.0.10.221<0>
gpu-st-ml-1:78499:78499 [0] NCCL INFO cudaDriverVersion 12080
gpu-st-ml-2:77729:77729 [0] NCCL INFO ENV/Plugin: Could not find: libnccl-env.so
gpu-st-ml-2:77729:77729 [0] NCCL INFO cudaDriverVersion 12080
gpu-st-ml-2:77729:77729 [0] NCCL INFO Bootstrap: Using enp39s0:10.0.10.226<0>
gpu-st-ml-2:77729:77729 [0] NCCL INFO NCCL version 2.29.2+cuda12.8
gpu-st-ml-2:77729:77729 [0] NCCL INFO NCCL git version HEAD ebd1e92
gpu-st-ml-1:78499:78499 [0] NCCL INFO NCCL version 2.29.2+cuda12.8
gpu-st-ml-1:78499:78499 [0] NCCL INFO NCCL git version HEAD ebd1e92
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/Plugin: Loaded net plugin Libfabric (v11)
gpu-st-ml-2:77729:77729 [0] NCCL INFO Successfully loaded external network plugin /opt/aws-ofi-nccl/lib/libnccl-net.so
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Initializing aws-ofi-nccl 1.18.0
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Using Libfabric version 2.3
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Using CUDA driver version 12080 with runtime 12080
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/Plugin: Loaded net plugin Libfabric (v11)
gpu-st-ml-1:78499:78499 [0] NCCL INFO Successfully loaded external network plugin /opt/aws-ofi-nccl/lib/libnccl-net.so
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Initializing aws-ofi-nccl 1.18.0
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Using Libfabric version 2.3
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Using CUDA driver version 12080 with runtime 12080
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Plugin selected platform: AWS
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Configuring AWS-specific options
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Internode latency set at 35.0 us
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Using transport protocol SENDRECV (platform set)
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Selected provider is efa, fabric is efa (found 1 nics)
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI GUID of rdmap47s0: 733065c100010d00
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI GUID for dev[0]: 00000000000000000a000ae20000010d
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Could not disable CUDA API usage for HMEM, disabling GDR
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Support for global registrations: false
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Support for DMA-BUF registrations: false
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Need to force simple protocol: GDR not supported
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Adding FI_EFA_FORK_SAFE=1 to environment
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Adding NCCL_BUFFSIZE=8388608 to environment
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Adding NCCL_P2P_NET_CHUNKSIZE=524288 to environment
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Adding NCCL_PROTO=simple to environment
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Adding NCCL_TUNER_PLUGIN=libnccl-net.so to environment
gpu-st-ml-2:77729:77729 [0] NCCL INFO Initialized NET plugin Libfabric
gpu-st-ml-2:77729:77729 [0] NCCL INFO Assigned NET plugin Libfabric to comm
gpu-st-ml-2:77729:77729 [0] NCCL INFO Using network Libfabric
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Plugin selected platform: AWS
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Configuring AWS-specific options
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Internode latency set at 35.0 us
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Using transport protocol SENDRECV (platform set)
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Selected provider is efa, fabric is efa (found 1 nics)
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI GUID of rdmap47s0: 9318875e00007500
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI GUID for dev[0]: 00000000000000000a000add00000075
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Could not disable CUDA API usage for HMEM, disabling GDR
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Support for global registrations: false
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Support for DMA-BUF registrations: false
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Need to force simple protocol: GDR not supported
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Adding FI_EFA_FORK_SAFE=1 to environment
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Adding NCCL_BUFFSIZE=8388608 to environment
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Adding NCCL_P2P_NET_CHUNKSIZE=524288 to environment
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Adding NCCL_PROTO=simple to environment
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Adding NCCL_TUNER_PLUGIN=libnccl-net.so to environment
gpu-st-ml-1:78499:78499 [0] NCCL INFO Initialized NET plugin Libfabric
gpu-st-ml-1:78499:78499 [0] NCCL INFO Assigned NET plugin Libfabric to comm
gpu-st-ml-1:78499:78499 [0] NCCL INFO Using network Libfabric
gpu-st-ml-2:77729:77729 [0] NCCL INFO DMA-BUF is available on GPU device 0
gpu-st-ml-2:77729:77729 [0] NCCL INFO [Rank 1] ncclCommInitRank comm 0x5a08c708f110 rank 1 nranks 2 cudaDev 0 nvmlDev 0 busId 30000 commId 0xa84b6ed12d8abe7a - Init START
gpu-st-ml-1:78499:78499 [0] NCCL INFO DMA-BUF is available on GPU device 0
gpu-st-ml-1:78499:78499 [0] NCCL INFO [Rank 0] ncclCommInitRank comm 0x60a09a5c1520 rank 0 nranks 2 cudaDev 0 nvmlDev 0 busId 30000 commId 0xa84b6ed12d8abe7a - Init START
gpu-st-ml-1:78499:78499 [0] NCCL INFO RAS client listening socket at 127.0.0.1<28028>
gpu-st-ml-2:77729:77729 [0] NCCL INFO RAS client listening socket at 127.0.0.1<28028>
gpu-st-ml-2:77729:77729 [0] NCCL INFO Bootstrap timings total 0.001656 (create 0.000022, send 0.000200, recv 0.001019, ring 0.000048, delay 0.000000)
gpu-st-ml-1:78499:78499 [0] NCCL INFO Bootstrap timings total 0.000765 (create 0.000019, send 0.000070, recv 0.000226, ring 0.000117, delay 0.000000)
gpu-st-ml-1:78499:78499 [0] NCCL INFO ncclTopoGetCpuAffinity: Affinity for GPU 0 is 0-31. (GPU affinity = 0-31 ; CPU affinity = 0-31).
gpu-st-ml-2:77729:77729 [0] NCCL INFO ncclTopoGetCpuAffinity: Affinity for GPU 0 is 0-31. (GPU affinity = 0-31 ; CPU affinity = 0-31).
gpu-st-ml-2:77729:77729 [0] NCCL INFO comm 0x5a08c708f110 rank 1 nRanks 2 nNodes 2 localRanks 1 localRank 0 MNNVL 0
gpu-st-ml-2:77729:77729 [0] NCCL INFO Trees [0] -1/-1/-1->1->0 [1] 0/-1/-1->1->-1
gpu-st-ml-2:77729:77729 [0] NCCL INFO NCCL_BUFFSIZE set by environment to 8388608.
gpu-st-ml-2:77729:77729 [0] NCCL INFO NCCL_P2P_NET_CHUNKSIZE set by environment to 524288.
gpu-st-ml-2:77729:77729 [0] NCCL INFO P2P Chunksize set to 524288
gpu-st-ml-1:78499:78499 [0] NCCL INFO comm 0x60a09a5c1520 rank 0 nRanks 2 nNodes 2 localRanks 1 localRank 0 MNNVL 0
gpu-st-ml-1:78499:78499 [0] NCCL INFO Channel 00/02 : 0 1
gpu-st-ml-1:78499:78499 [0] NCCL INFO Channel 01/02 : 0 1
gpu-st-ml-1:78499:78499 [0] NCCL INFO Trees [0] 1/-1/-1->0->-1 [1] -1/-1/-1->0->1
gpu-st-ml-1:78499:78499 [0] NCCL INFO NCCL_BUFFSIZE set by environment to 8388608.
gpu-st-ml-1:78499:78499 [0] NCCL INFO NCCL_P2P_NET_CHUNKSIZE set by environment to 524288.
gpu-st-ml-1:78499:78499 [0] NCCL INFO P2P Chunksize set to 524288
gpu-st-ml-1:78499:78499 [0] NCCL INFO PROFILER/Plugin: Could not find: libnccl-profiler.so
gpu-st-ml-1:78499:78499 [0] NCCL INFO Check P2P Type isAllDirectP2p 1 directMode 0 isAllCudaP2p 1
gpu-st-ml-1:78499:78506 [0] NCCL INFO [Proxy Service] Device 0 CPU core 1
gpu-st-ml-1:78499:78507 [0] NCCL INFO [Proxy Service UDS] Device 0 CPU core 19
gpu-st-ml-1:78499:78499 [0] NCCL INFO NCCL_TUNER_PLUGIN set by environment to libnccl-net.so
gpu-st-ml-1:78499:78499 [0] NCCL INFO TUNER/Plugin: Using nccl_ofi_tuner (v3)
gpu-st-ml-1:78499:78499 [0] NCCL INFO Successfully loaded external tuner plugin /opt/aws-ofi-nccl/lib/libnccl-net.so
gpu-st-ml-2:77729:77729 [0] NCCL INFO PROFILER/Plugin: Could not find: libnccl-profiler.so
gpu-st-ml-2:77729:77729 [0] NCCL INFO Check P2P Type isAllDirectP2p 1 directMode 0 isAllCudaP2p 1
gpu-st-ml-2:77729:77737 [0] NCCL INFO [Proxy Service] Device 0 CPU core 2
gpu-st-ml-2:77729:77738 [0] NCCL INFO [Proxy Service UDS] Device 0 CPU core 4
gpu-st-ml-2:77729:77729 [0] NCCL INFO NCCL_TUNER_PLUGIN set by environment to libnccl-net.so
gpu-st-ml-2:77729:77729 [0] NCCL INFO TUNER/Plugin: Using nccl_ofi_tuner (v3)
gpu-st-ml-2:77729:77729 [0] NCCL INFO Successfully loaded external tuner plugin /opt/aws-ofi-nccl/lib/libnccl-net.so
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI Tuner selected platform: AWS
gpu-st-ml-1:78499:78499 [0] NCCL INFO NET/OFI NCCL_OFI_TUNER is not available for platform : g7e.8xlarge, Fall back to NCCL's tuner
gpu-st-ml-1:78499:78499 [0] NCCL INFO NCCL_PROTO set by environment to simple
gpu-st-ml-1:78499:78499 [0] NCCL INFO Enabled NCCL Func/Proto/Algo Matrix:
     Function |       LL     LL128    Simple   |          Tree           Ring  CollNetDirect   CollNetChain           NVLS       NVLSTree            PAT  
    Broadcast |        0         0         1   |             1              1              1              1              1              1              1  
       Reduce |        0         0         1   |             1              1              1              1              1              1              1  
    AllGather |        0         0         1   |             1              1              1              1              1              1              1  
ReduceScatter |        0         0         1   |             1              1              1              1              1              1              1  
    AllReduce |        0         0         1   |             1              1              1              1              1              1              1  

gpu-st-ml-1:78499:78499 [0] NCCL INFO threadThresholds 8/8/64 | 16/8/64 | 512 | 512
gpu-st-ml-1:78499:78499 [0] NCCL INFO 2 coll channels, 2 collnet channels, 0 nvls channels, 2 p2p channels, 1 p2p channels per peer
gpu-st-ml-1:78499:78499 [0] NCCL INFO Symmetric memory is not supported. cuMemEnable 1, ginSupport 0, globalNicFused 0
gpu-st-ml-1:78499:78499 [0] NCCL INFO CC Off, workFifoBytes 1048576
gpu-st-ml-1:78499:78499 [0] NCCL INFO ncclCommInitRank comm 0x60a09a5c1520 rank 0 nranks 2 cudaDev 0 nvmlDev 0 busId 30000 commId 0xa84b6ed12d8abe7a - Init COMPLETE
gpu-st-ml-1:78499:78499 [0] NCCL INFO Init timings - ncclCommInitRank: rank 0 nranks 2 total 0.26 (kernels 0.18, alloc 0.06, bootstrap 0.00, allgathers 0.00, topo 0.00, graphs 0.00, connections 0.01, rest 0.00)
#
#                                                              out-of-place                       in-place          
#       size         count      type   redop    root     time   algbw   busbw #wrong     time   algbw   busbw #wrong
#        (B)    (elements)                               (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)       
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI Tuner selected platform: AWS
gpu-st-ml-2:77729:77729 [0] NCCL INFO NET/OFI NCCL_OFI_TUNER is not available for platform : g7e.8xlarge, Fall back to NCCL's tuner
gpu-st-ml-2:77729:77729 [0] NCCL INFO NCCL_PROTO set by environment to simple
gpu-st-ml-2:77729:77729 [0] NCCL INFO threadThresholds 8/8/64 | 16/8/64 | 512 | 512
gpu-st-ml-2:77729:77729 [0] NCCL INFO 2 coll channels, 2 collnet channels, 0 nvls channels, 2 p2p channels, 1 p2p channels per peer
gpu-st-ml-2:77729:77729 [0] NCCL INFO Symmetric memory is not supported. cuMemEnable 1, ginSupport 0, globalNicFused 0
gpu-st-ml-2:77729:77729 [0] NCCL INFO ncclCommInitRank comm 0x5a08c708f110 rank 1 nranks 2 cudaDev 0 nvmlDev 0 busId 30000 commId 0xa84b6ed12d8abe7a - Init COMPLETE
gpu-st-ml-2:77729:77729 [0] NCCL INFO Init timings - ncclCommInitRank: rank 1 nranks 2 total 0.26 (kernels 0.18, alloc 0.06, bootstrap 0.00, allgathers 0.00, topo 0.00, graphs 0.00, connections 0.01, rest 0.00)
gpu-st-ml-2:77729:77739 [0] NCCL INFO [Proxy Progress] Device 0 CPU core 21
gpu-st-ml-1:78499:78508 [0] NCCL INFO [Proxy Progress] Device 0 CPU core 18
gpu-st-ml-2:77729:77729 [0] NCCL INFO Channel 00/0 : 0[0] -> 1[0] [receive] via NET/Libfabric/0
gpu-st-ml-2:77729:77729 [0] NCCL INFO Channel 01/0 : 0[0] -> 1[0] [receive] via NET/Libfabric/0
gpu-st-ml-2:77729:77729 [0] NCCL INFO Channel 00/0 : 1[0] -> 0[0] [send] via NET/Libfabric/0
gpu-st-ml-2:77729:77729 [0] NCCL INFO Channel 01/0 : 1[0] -> 0[0] [send] via NET/Libfabric/0
gpu-st-ml-1:78499:78499 [0] NCCL INFO Channel 00/0 : 1[0] -> 0[0] [receive] via NET/Libfabric/0
gpu-st-ml-1:78499:78499 [0] NCCL INFO Channel 01/0 : 1[0] -> 0[0] [receive] via NET/Libfabric/0
gpu-st-ml-1:78499:78499 [0] NCCL INFO Channel 00/0 : 0[0] -> 1[0] [send] via NET/Libfabric/0
gpu-st-ml-1:78499:78499 [0] NCCL INFO Channel 01/0 : 0[0] -> 1[0] [send] via NET/Libfabric/0
gpu-st-ml-2:77729:77729 [0] NCCL INFO Connected all rings, use ring PXN 0 GDR 0
gpu-st-ml-1:78499:78499 [0] NCCL INFO Connected all rings, use ring PXN 0 GDR 0
gpu-st-ml-1:78499:78499 [0] NCCL INFO Connected all trees
gpu-st-ml-2:77729:77729 [0] NCCL INFO Connected all trees
           8             2     float     sum      -1    45.91    0.00    0.00      0    45.49    0.00    0.00      0
          16             4     float     sum      -1    46.86    0.00    0.00      0    46.03    0.00    0.00      0
          32             8     float     sum      -1    47.27    0.00    0.00      0    48.51    0.00    0.00      0
          64            16     float     sum      -1    47.60    0.00    0.00      0    47.77    0.00    0.00      0
         128            32     float     sum      -1    48.09    0.00    0.00      0    47.88    0.00    0.00      0
         256            64     float     sum      -1    45.27    0.01    0.01      0    44.68    0.01    0.01      0
         512           128     float     sum      -1    45.15    0.01    0.01      0    45.11    0.01    0.01      0
        1024           256     float     sum      -1    45.46    0.02    0.02      0    46.17    0.02    0.02      0
        2048           512     float     sum      -1    46.40    0.04    0.04      0    45.96    0.04    0.04      0
        4096          1024     float     sum      -1    49.26    0.08    0.08      0    49.69    0.08    0.08      0
        8192          2048     float     sum      -1    52.41    0.16    0.16      0    52.04    0.16    0.16      0
       16384          4096     float     sum      -1    55.36    0.30    0.30      0    55.05    0.30    0.30      0
       32768          8192     float     sum      -1    59.57    0.55    0.55      0    59.05    0.55    0.55      0
       65536         16384     float     sum      -1    61.91    1.06    1.06      0    61.36    1.07    1.07      0
      131072         32768     float     sum      -1    76.91    1.70    1.70      0    76.64    1.71    1.71      0
      262144         65536     float     sum      -1    136.4    1.92    1.92      0    136.4    1.92    1.92      0
      524288        131072     float     sum      -1    191.3    2.74    2.74      0    183.8    2.85    2.85      0
     1048576        262144     float     sum      -1    272.8    3.84    3.84      0    272.6    3.85    3.85      0
     2097152        524288     float     sum      -1    459.2    4.57    4.57      0    454.0    4.62    4.62      0
     4194304       1048576     float     sum      -1    747.6    5.61    5.61      0    768.8    5.46    5.46      0
     8388608       2097152     float     sum      -1    742.4   11.30   11.30      0    741.9   11.31   11.31      0
    16777216       4194304     float     sum      -1   1397.1   12.01   12.01      0   1378.0   12.17   12.17      0
    33554432       8388608     float     sum      -1   2790.4   12.02   12.02      0   2795.7   12.00   12.00      0
    67108864      16777216     float     sum      -1   5539.7   12.11   12.11      0   5548.1   12.10   12.10      0
   134217728      33554432     float     sum      -1    10928   12.28   12.28      0    10932   12.28   12.28      0
   268435456      67108864     float     sum      -1    21722   12.36   12.36      0    21726   12.36   12.36      0
   536870912     134217728     float     sum      -1    43330   12.39   12.39      0    43385   12.37   12.37      0
  1073741824     268435456     float     sum      -1    86786   12.37   12.37      0    86676   12.39   12.39      0
gpu-st-ml-1:78499:78499 [0] NCCL INFO TUNER/Plugin: Closing tuner: 'nccl_ofi_tuner'
gpu-st-ml-2:77729:77729 [0] NCCL INFO TUNER/Plugin: Closing tuner: 'nccl_ofi_tuner'
gpu-st-ml-1:78499:78499 [0] NCCL INFO comm 0x60a09a5c1520 rank 0 nranks 2 cudaDev 0 busId 30000 - Destroy COMPLETE
gpu-st-ml-1:78499:78499 [0] NCCL INFO Unloading plugin libnccl-net.so
gpu-st-ml-2:77729:77729 [0] NCCL INFO comm 0x5a08c708f110 rank 1 nranks 2 cudaDev 0 busId 30000 - Destroy COMPLETE
gpu-st-ml-2:77729:77729 [0] NCCL INFO Unloading plugin libnccl-net.so
# Out of bounds values : 0 OK
# Avg bus bandwidth    : 4.26966 
#
# Collective test concluded: all_reduce_perf

gpu-st-ml-2:77729:77729 [0] NCCL INFO ENV/Plugin: Closing env plugin ncclEnvDefault
gpu-st-ml-1:78499:78499 [0] NCCL INFO ENV/Plugin: Closing env plugin ncclEnvDefault
```
* 2노드, rank 0/1, nranks 2 — 멀티노드 통신 정상
* EFA/Libfabric 연결 완료
* #wrong: 0 — 데이터 정합성 OK
* 대용량(1GB) 기준 busbw: ~12.37 GB/s
* Avg bus bandwidth: 4.27 GB/s
* g7e.8xlarge는 EFA NIC 1개(100Gbps)이므로 이론 최대 ~12.5 GB/s 이다. 1GB 사이즈에서 12.37 GB/s가 나왔으니 EFA 대역폭을 거의 100% 활용하고 있다. 
GDR 0 (GPU Direct RDMA 비활성)이라 GPU→CPU→EFA→CPU→GPU 경로로 데이터가 이동하고 있다. 

#### NCCL이 사용 가능한 프로토콜과 알고리즘 조합 ####
* 프로토콜 (데이터 전송 방식):
  * LL: Low Latency. 작은 메시지용, 오버헤드 최소화
  * LL128: Low Latency 128byte. LL의 확장 버전
  * Simple: 대용량 메시지용, 높은 bandwidth
* 알고리즘 (통신 토폴로지):
  * Ring: GPU들이 링 형태로 데이터 전달
  * Tree: 트리 구조로 reduce/broadcast
  * CollNetDirect/CollNetChain: 네트워크 스위치의 in-network reduction 활용
  * NVLS: NVLink Switch (NVSwitch 기반)
  * NVLSTree: NVLS + Tree 조합
  * PAT: Parallel Aggregation Tree




## [참고] srun 으로 bash 실행하기 ##
아래는 srun bash 을 활용하여 gpu 파티션 노드들에 설치되어 있는 nccl-tests 프로그램을 재 컴파일 하는 샘플이다. srun + bash -c 커맨드 조합을 활용하며 slurm 클러스터의 각 노드에서 bash 명령어를 실행할 수 있다.  

```
srun -p gpu -N 2 --ntasks-per-node=1 bash -c "cd /opt/nccl && sudo make clean && sudo make -j \$(nproc) src.build NVCC_GENCODE='-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_80,code=sm_80 -gencode=arch=compute_90,code=sm_90 -gencode=arch=compute_120,code=sm_120'"

srun -p gpu -N 2 --ntasks-per-node=1 bash -c "cd /opt/nccl-tests && sudo make clean && sudo make -j \$(nproc) MPI=1 MPI_HOME=/opt/amazon/openmpi NCCL_HOME=/opt/nccl/build CUDA_HOME=/usr/local/cuda"
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
...
...
make[1]: Leaving directory '/opt/nccl-tests/src'
```
