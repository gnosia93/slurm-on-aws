```
# Collective test starting: all_reduce_perf
# nThread 1 nGpus 1 minBytes 8 maxBytes 1073741824 step: 2(factor) warmup iters: 1 iters: 20 agg iters: 1 validation: 1 graph: 0
#
# Using devices
#  Rank  0 Group  0 Pid  50292 on gpu-st-ml-1 device  0 [0000:30:00] NVIDIA RTX PRO 6000 Blackwell Server Edition
#  Rank  1 Group  0 Pid  49542 on gpu-st-ml-2 device  0 [0000:30:00] NVIDIA RTX PRO 6000 Blackwell Server Edition
gpu-st-ml-1:50292:50292 [0] NCCL INFO ENV/Plugin: Could not find: libnccl-env.so
gpu-st-ml-1:50292:50292 [0] NCCL INFO Bootstrap: Using enp39s0:10.0.10.221<0>
gpu-st-ml-1:50292:50292 [0] NCCL INFO cudaDriverVersion 12080
gpu-st-ml-2:49542:49542 [0] NCCL INFO ENV/Plugin: Could not find: libnccl-env.so
gpu-st-ml-2:49542:49542 [0] NCCL INFO cudaDriverVersion 12080
gpu-st-ml-2:49542:49542 [0] NCCL INFO Bootstrap: Using enp39s0:10.0.10.226<0>
gpu-st-ml-2:49542:49542 [0] NCCL INFO NCCL version 2.29.2+cuda12.8
gpu-st-ml-2:49542:49542 [0] NCCL INFO NCCL git version HEAD ebd1e92
gpu-st-ml-1:50292:50292 [0] NCCL INFO NCCL version 2.29.2+cuda12.8
gpu-st-ml-1:50292:50292 [0] NCCL INFO NCCL git version HEAD ebd1e92
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/Plugin: Loaded net plugin Libfabric (v11)
gpu-st-ml-2:49542:49542 [0] NCCL INFO Successfully loaded external network plugin /opt/aws-ofi-nccl/lib/libnccl-net.so
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Initializing aws-ofi-nccl 1.18.0
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Using Libfabric version 2.3
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/Plugin: Loaded net plugin Libfabric (v11)
gpu-st-ml-1:50292:50292 [0] NCCL INFO Successfully loaded external network plugin /opt/aws-ofi-nccl/lib/libnccl-net.so
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Initializing aws-ofi-nccl 1.18.0
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Using Libfabric version 2.3
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Using CUDA driver version 12080 with runtime 12080
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Using CUDA driver version 12080 with runtime 12080
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Plugin selected platform: AWS
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Configuring AWS-specific options
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Internode latency set at 35.0 us
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Using transport protocol SENDRECV (platform set)
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Selected provider is efa, fabric is efa (found 1 nics)
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI GUID of rdmap47s0: 733065c100010d00
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI GUID for dev[0]: 00000000000000000a000ae20000010d
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Could not disable CUDA API usage for HMEM, disabling GDR
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Plugin selected platform: AWS
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Configuring AWS-specific options
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Internode latency set at 35.0 us
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Using transport protocol SENDRECV (platform set)
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Selected provider is efa, fabric is efa (found 1 nics)
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI GUID of rdmap47s0: 9318875e00007500
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI GUID for dev[0]: 00000000000000000a000add00000075
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Could not disable CUDA API usage for HMEM, disabling GDR
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Support for global registrations: false
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Support for DMA-BUF registrations: false
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Need to force simple protocol: GDR not supported
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Adding FI_EFA_FORK_SAFE=1 to environment
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Adding NCCL_BUFFSIZE=8388608 to environment
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Adding NCCL_P2P_NET_CHUNKSIZE=524288 to environment
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Adding NCCL_PROTO=simple to environment
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Adding NCCL_TUNER_PLUGIN=libnccl-net.so to environment
gpu-st-ml-2:49542:49542 [0] NCCL INFO Initialized NET plugin Libfabric
gpu-st-ml-2:49542:49542 [0] NCCL INFO Assigned NET plugin Libfabric to comm
gpu-st-ml-2:49542:49542 [0] NCCL INFO Using network Libfabric
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Support for global registrations: false
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Support for DMA-BUF registrations: false
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Need to force simple protocol: GDR not supported
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Adding FI_EFA_FORK_SAFE=1 to environment
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Adding NCCL_BUFFSIZE=8388608 to environment
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Adding NCCL_P2P_NET_CHUNKSIZE=524288 to environment
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Adding NCCL_PROTO=simple to environment
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Adding NCCL_TUNER_PLUGIN=libnccl-net.so to environment
gpu-st-ml-1:50292:50292 [0] NCCL INFO Initialized NET plugin Libfabric
gpu-st-ml-1:50292:50292 [0] NCCL INFO Assigned NET plugin Libfabric to comm
gpu-st-ml-1:50292:50292 [0] NCCL INFO Using network Libfabric
gpu-st-ml-1:50292:50292 [0] NCCL INFO DMA-BUF is available on GPU device 0
gpu-st-ml-1:50292:50292 [0] NCCL INFO [Rank 0] ncclCommInitRank comm 0x630259b432a0 rank 0 nranks 2 cudaDev 0 nvmlDev 0 busId 30000 commId 0xc3d9a10350effd4f - Init START
gpu-st-ml-2:49542:49542 [0] NCCL INFO DMA-BUF is available on GPU device 0
gpu-st-ml-2:49542:49542 [0] NCCL INFO [Rank 1] ncclCommInitRank comm 0x63233dc434d0 rank 1 nranks 2 cudaDev 0 nvmlDev 0 busId 30000 commId 0xc3d9a10350effd4f - Init START
gpu-st-ml-2:49542:49542 [0] NCCL INFO RAS client listening socket at 127.0.0.1<28028>
gpu-st-ml-1:50292:50292 [0] NCCL INFO RAS client listening socket at 127.0.0.1<28028>
gpu-st-ml-2:49542:49542 [0] NCCL INFO Bootstrap timings total 0.000916 (create 0.000022, send 0.000204, recv 0.000289, ring 0.000071, delay 0.000000)
gpu-st-ml-1:50292:50292 [0] NCCL INFO Bootstrap timings total 0.004854 (create 0.000020, send 0.000093, recv 0.004154, ring 0.000055, delay 0.000001)
gpu-st-ml-1:50292:50292 [0] NCCL INFO ncclTopoGetCpuAffinity: Affinity for GPU 0 is 0-31. (GPU affinity = 0-31 ; CPU affinity = 0-31).
gpu-st-ml-2:49542:49542 [0] NCCL INFO ncclTopoGetCpuAffinity: Affinity for GPU 0 is 0-31. (GPU affinity = 0-31 ; CPU affinity = 0-31).
gpu-st-ml-2:49542:49542 [0] NCCL INFO comm 0x63233dc434d0 rank 1 nRanks 2 nNodes 2 localRanks 1 localRank 0 MNNVL 0
gpu-st-ml-1:50292:50292 [0] NCCL INFO comm 0x630259b432a0 rank 0 nRanks 2 nNodes 2 localRanks 1 localRank 0 MNNVL 0
gpu-st-ml-2:49542:49542 [0] NCCL INFO Trees [0] -1/-1/-1->1->0 [1] 0/-1/-1->1->-1
gpu-st-ml-2:49542:49542 [0] NCCL INFO NCCL_BUFFSIZE set by environment to 8388608.
gpu-st-ml-1:50292:50292 [0] NCCL INFO Channel 00/02 : 0 1
gpu-st-ml-1:50292:50292 [0] NCCL INFO Channel 01/02 : 0 1
gpu-st-ml-1:50292:50292 [0] NCCL INFO Trees [0] 1/-1/-1->0->-1 [1] -1/-1/-1->0->1
gpu-st-ml-1:50292:50292 [0] NCCL INFO NCCL_BUFFSIZE set by environment to 8388608.
gpu-st-ml-1:50292:50292 [0] NCCL INFO NCCL_P2P_NET_CHUNKSIZE set by environment to 524288.
gpu-st-ml-1:50292:50292 [0] NCCL INFO P2P Chunksize set to 524288
gpu-st-ml-2:49542:49542 [0] NCCL INFO NCCL_P2P_NET_CHUNKSIZE set by environment to 524288.
gpu-st-ml-2:49542:49542 [0] NCCL INFO P2P Chunksize set to 524288
gpu-st-ml-1:50292:50292 [0] NCCL INFO PROFILER/Plugin: Could not find: libnccl-profiler.so
gpu-st-ml-1:50292:50292 [0] NCCL INFO Check P2P Type isAllDirectP2p 1 directMode 0 isAllCudaP2p 1
gpu-st-ml-1:50292:50299 [0] NCCL INFO [Proxy Service] Device 0 CPU core 0
gpu-st-ml-1:50292:50300 [0] NCCL INFO [Proxy Service UDS] Device 0 CPU core 18
gpu-st-ml-1:50292:50292 [0] NCCL INFO NCCL_TUNER_PLUGIN set by environment to libnccl-net.so
gpu-st-ml-1:50292:50292 [0] NCCL INFO TUNER/Plugin: Using nccl_ofi_tuner (v3)
gpu-st-ml-1:50292:50292 [0] NCCL INFO Successfully loaded external tuner plugin /opt/aws-ofi-nccl/lib/libnccl-net.so
gpu-st-ml-2:49542:49542 [0] NCCL INFO PROFILER/Plugin: Could not find: libnccl-profiler.so
gpu-st-ml-2:49542:49542 [0] NCCL INFO Check P2P Type isAllDirectP2p 1 directMode 0 isAllCudaP2p 1
gpu-st-ml-2:49542:49548 [0] NCCL INFO [Proxy Service] Device 0 CPU core 19
gpu-st-ml-2:49542:49549 [0] NCCL INFO [Proxy Service UDS] Device 0 CPU core 4
gpu-st-ml-2:49542:49542 [0] NCCL INFO NCCL_TUNER_PLUGIN set by environment to libnccl-net.so
gpu-st-ml-2:49542:49542 [0] NCCL INFO TUNER/Plugin: Using nccl_ofi_tuner (v3)
gpu-st-ml-2:49542:49542 [0] NCCL INFO Successfully loaded external tuner plugin /opt/aws-ofi-nccl/lib/libnccl-net.so
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI Tuner selected platform: AWS
gpu-st-ml-2:49542:49542 [0] NCCL INFO NET/OFI NCCL_OFI_TUNER is not available for platform : g7e.8xlarge, Fall back to NCCL's tuner
gpu-st-ml-2:49542:49542 [0] NCCL INFO NCCL_PROTO set by environment to simple
gpu-st-ml-2:49542:49542 [0] NCCL INFO threadThresholds 8/8/64 | 16/8/64 | 512 | 512
gpu-st-ml-2:49542:49542 [0] NCCL INFO 2 coll channels, 2 collnet channels, 0 nvls channels, 2 p2p channels, 1 p2p channels per peer
gpu-st-ml-2:49542:49542 [0] NCCL INFO Symmetric memory is not supported. cuMemEnable 1, ginSupport 0, globalNicFused 0
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI Tuner selected platform: AWS
gpu-st-ml-1:50292:50292 [0] NCCL INFO NET/OFI NCCL_OFI_TUNER is not available for platform : g7e.8xlarge, Fall back to NCCL's tuner
gpu-st-ml-1:50292:50292 [0] NCCL INFO NCCL_PROTO set by environment to simple
gpu-st-ml-1:50292:50292 [0] NCCL INFO Enabled NCCL Func/Proto/Algo Matrix:
     Function |       LL     LL128    Simple   |          Tree           Ring  CollNetDirect   CollNetChain           NVLS       NVLSTree            PAT  
    Broadcast |        0         0         1   |             1              1              1              1              1              1              1  
       Reduce |        0         0         1   |             1              1              1              1              1              1              1  
    AllGather |        0         0         1   |             1              1              1              1              1              1              1  
ReduceScatter |        0         0         1   |             1              1              1              1              1              1              1  
    AllReduce |        0         0         1   |             1              1              1              1              1              1              1  

gpu-st-ml-1:50292:50292 [0] NCCL INFO threadThresholds 8/8/64 | 16/8/64 | 512 | 512
gpu-st-ml-1:50292:50292 [0] NCCL INFO 2 coll channels, 2 collnet channels, 0 nvls channels, 2 p2p channels, 1 p2p channels per peer
gpu-st-ml-1:50292:50292 [0] NCCL INFO Symmetric memory is not supported. cuMemEnable 1, ginSupport 0, globalNicFused 0
gpu-st-ml-2:49542:49542 [0] NCCL INFO ncclCommInitRank comm 0x63233dc434d0 rank 1 nranks 2 cudaDev 0 nvmlDev 0 busId 30000 commId 0xc3d9a10350effd4f - Init COMPLETE
gpu-st-ml-2:49542:49542 [0] NCCL INFO Init timings - ncclCommInitRank: rank 1 nranks 2 total 0.08 (kernels 0.00, alloc 0.06, bootstrap 0.00, allgathers 0.00, topo 0.00, graphs 0.00, connections 0.01, rest 0.00)
gpu-st-ml-1:50292:50292 [0] NCCL INFO CC Off, workFifoBytes 1048576
gpu-st-ml-1:50292:50292 [0] NCCL INFO ncclCommInitRank comm 0x630259b432a0 rank 0 nranks 2 cudaDev 0 nvmlDev 0 busId 30000 commId 0xc3d9a10350effd4f - Init COMPLETE
gpu-st-ml-1:50292:50292 [0] NCCL INFO Init timings - ncclCommInitRank: rank 0 nranks 2 total 0.08 (kernels 0.00, alloc 0.06, bootstrap 0.00, allgathers 0.00, topo 0.00, graphs 0.00, connections 0.01, rest 0.00)
#
#                                                              out-of-place                       in-place          
#       size         count      type   redop    root     time   algbw   busbw #wrong     time   algbw   busbw #wrong
#        (B)    (elements)                               (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)       
gpu-st-ml-1:50292:50301 [0] NCCL INFO [Proxy Progress] Device 0 CPU core 19
gpu-st-ml-2:49542:49550 [0] NCCL INFO [Proxy Progress] Device 0 CPU core 21
gpu-st-ml-1:50292:50292 [0] NCCL INFO Channel 00/0 : 1[0] -> 0[0] [receive] via NET/Libfabric/0
gpu-st-ml-1:50292:50292 [0] NCCL INFO Channel 01/0 : 1[0] -> 0[0] [receive] via NET/Libfabric/0
gpu-st-ml-1:50292:50292 [0] NCCL INFO Channel 00/0 : 0[0] -> 1[0] [send] via NET/Libfabric/0
gpu-st-ml-1:50292:50292 [0] NCCL INFO Channel 01/0 : 0[0] -> 1[0] [send] via NET/Libfabric/0
gpu-st-ml-2:49542:49542 [0] NCCL INFO Channel 00/0 : 0[0] -> 1[0] [receive] via NET/Libfabric/0
gpu-st-ml-2:49542:49542 [0] NCCL INFO Channel 01/0 : 0[0] -> 1[0] [receive] via NET/Libfabric/0
gpu-st-ml-2:49542:49542 [0] NCCL INFO Channel 00/0 : 1[0] -> 0[0] [send] via NET/Libfabric/0
gpu-st-ml-2:49542:49542 [0] NCCL INFO Channel 01/0 : 1[0] -> 0[0] [send] via NET/Libfabric/0
gpu-st-ml-1:50292:50292 [0] NCCL INFO Connected all rings, use ring PXN 0 GDR 0

[2026-03-12 14:17:56] gpu-st-ml-1:50292:50292 [0] enqueue.cc:1694 NCCL WARN Cuda failure 'named symbol not found'
gpu-st-ml-1:50292:50292 [0] NCCL INFO group.cc:319 -> 1
gpu-st-ml-1:50292:50292 [0] NCCL INFO group.cc:643 -> 1
gpu-st-ml-1:50292:50292 [0] NCCL INFO group.cc:781 -> 1
gpu-st-ml-1:50292:50292 [0] NCCL INFO enqueue.cc:3014 -> 1
gpu-st-ml-1: Test NCCL failure all_reduce.cu:44 'unhandled cuda error (run with NCCL_DEBUG=INFO for details) / '
 .. gpu-st-ml-1 pid 50292: Test failure common.cu:404
 .. gpu-st-ml-1 pid 50292: Test failure common.cu:614
 .. gpu-st-ml-1 pid 50292: Test failure all_reduce.cu:90
 .. gpu-st-ml-1 pid 50292: Test failure common.cu:641
 .. gpu-st-ml-1 pid 50292: Test failure common.cu:1206
 .. gpu-st-ml-1 pid 50292: Test failure common.cu:936
gpu-st-ml-2:49542:49542 [0] NCCL INFO Connected all rings, use ring PXN 0 GDR 0

[2026-03-12 14:17:56] gpu-st-ml-2:49542:49542 [0] enqueue.cc:1694 NCCL WARN Cuda failure 'named symbol not found'
gpu-st-ml-2:49542:49542 [0] NCCL INFO group.cc:319 -> 1
gpu-st-ml-2:49542:49542 [0] NCCL INFO group.cc:643 -> 1
gpu-st-ml-2:49542:49542 [0] NCCL INFO group.cc:781 -> 1
gpu-st-ml-2:49542:49542 [0] NCCL INFO enqueue.cc:3014 -> 1
gpu-st-ml-2: Test NCCL failure all_reduce.cu:44 'unhandled cuda error (run with NCCL_DEBUG=INFO for details) / '
 .. gpu-st-ml-2 pid 49542: Test failure common.cu:404
 .. gpu-st-ml-2 pid 49542: Test failure common.cu:614
 .. gpu-st-ml-2 pid 49542: Test failure all_reduce.cu:90
 .. gpu-st-ml-2 pid 49542: Test failure common.cu:641
 .. gpu-st-ml-2 pid 49542: Test failure common.cu:1206
 .. gpu-st-ml-2 pid 49542: Test failure common.cu:936
gpu-st-ml-1:50292:50292 [0] NCCL INFO ENV/Plugin: Closing env plugin ncclEnvDefault
gpu-st-ml-2:49542:49542 [0] NCCL INFO ENV/Plugin: Closing env plugin ncclEnvDefault
```
