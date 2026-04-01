## Network Architecture / Optimization ##
Llama 3 405B used RDMA over Converged Ethernet (RoCE) fabric based on the Arista 7800
and Minipack2 Open Compute Project4 OCP rack switches. Smaller models in the Llama 3 family were
trained using Nvidia Quantum2 Infiniband fabric. Both RoCE and Infiniband clusters leverage 400 Gbps
interconnects between GPUs. Despite the underlying network technology differences between these clusters,
we tune both of them to provide equivalent performance for these large training workloads. We elaborate
further on our RoCE network since we fully own its design.

### Network Topology ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/network-optimization-0.png)

Our RoCE-based AI cluster comprises 24K GPUs5 connected by a three-layer Clos
network (Lee et al., 2024). At the bottom layer, each rack hosts 16 GPUs split between two servers and
connected by a single Minipack2 top-of-the-rack (ToR) switch. In the middle layer, 192 such racks are
connected by Cluster Switches to form a pod of 3,072 GPUs with full bisection bandwidth, ensuring no
oversubscription. At the top layer, eight such pods within the same datacenter building are connected via
Aggregation Switches to form a cluster of 24K GPUs. However, network connectivity at the aggregation
layer does not maintain full bisection bandwidth and instead has an oversubscription ratio of 1:7. Our
model parallelism methods (see Section 3.3.2) and training job scheduler (Choudhury et al., 2024) are
all optimized to be aware of network topology, aiming to minimize network communication across pods.

### Load Balancing ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/network-optimization.png)

LLM training produces fat network flows that are hard to load balance across all
available network paths using traditional methods such as Equal-Cost Multi-Path (ECMP) routing. To
address this challenge, we employ two techniques. First, our collective library creates 16 network flows
between two GPUs, instead of just one, thereby reducing the traffic per flow and providing more flows
for load balancing. Second, our Enhanced-ECMP (E-ECMP) protocol effectively balances these 16 flows
across different network paths by hashing on additional fields in the RoCE header of packets.

### Congestion Control ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/network-optimization-3.png)

We use deep-buffer switches in the spine (Gangidi et al., 2024) to accommodate
transient congestion and buffering caused by collective communication patterns. This setup helps
limit the impact of persistent congestion and network back pressure caused by slow servers, which is
common in training. Finally, better load balancing through E-ECMP significantly reduces the chance
of congestion. With these optimizations, we successfully run a 24K GPU cluster without traditional
congestion control methods such as Data Center Quantized Congestion Notification (DCQCN).


## 3.3.3 Collective Communication ##
Our collective communication library for Llama 3 is based on a fork of Nvidia’s NCCL library, called NCCLX.
NCCLX significantly improves the performance of NCCL, especially for higher latency networks. Recall that
the order of parallelism dimensions is [TP, CP, PP, DP], where DP corresponds to FSDP. The outermost
parallelism dimensions, PP and DP, may communicate through a multi-hop network, with latency up to tens
of microseconds. The original NCCL collectives—all-gather and reduce-scatter in FSDP, and point-to-point
in PP—require data chunking and staged data copy. This approach incurs several inefficiencies, including
(1) requiring a large number of small control messages to be exchanged over the network to facilitate data
transfer, (2) extra memory-copy operations, and (3) using extra GPU cycles for communication. For Llama 3
training, we address a subset of these inefficiencies by tuning chunking and data transfer to fit our network
latencies, which can be as high as tens of microseconds for a large cluster. We also allow small control messages
to traverse our network at a higher priority, especially avoiding being head-of-line blocked in deep-buffer
core switches. Our ongoing work for future Llama versions involves making deeper changes in NCCLX to
holistically address all the aforementioned problems.
