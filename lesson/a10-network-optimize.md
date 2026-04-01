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

## 3.3.4 Reliability and Operational Challenges ##
The complexity and potential failure scenarios of 16K GPU training surpass those of much larger CPU clusters
that we have operated. Moreover, the synchronous nature of training makes it less fault-tolerant—a single
GPU failure may require a restart of the entire job. Despite these challenges, for Llama 3, we achieved higher
than 90% effective training time while supporting automated cluster maintenance, such as firmware and Linux
kernel upgrades (Vigraham and Leonhardi, 2024), which resulted in at least one training interruption daily.
The effective training time measures the time spent on useful training over the elapsed time.
During a 54-day snapshot period of pre-training, we experienced a total of 466 job interruptions. Of these, 47
were planned interruptions due to automated maintenance operations such as firmware upgrades or operator-
initiated operations like configuration or dataset updates. The remaining 419 were unexpected interruptions,
which are classified in Table 5. Approximately 78% of the unexpected interruptions are attributed to confirmed
hardware issues, such as GPU or host component failures, or suspected hardware-related issues like silent data
corruption and unplanned individual host maintenance events. GPU issues are the largest category, accounting
for 58.7% of all unexpected issues. Despite the large number of failures, significant manual intervention was
required only three times during this period, with the rest of issues handled by automation.
To increase the effective training time, we reduced job startup and checkpointing time, and developed tools
for fast diagnosis and problem resolution. We extensively use PyTorch’s built-in NCCL flight recorder (Ansel
et al., 2024), a feature that captures collective metadata and stack traces into a ring buffer, and hence allowing
us to diagnose hangs and performance issues quickly at scale, particularly with regard to NCCLX. Using
this, we efficiently record every communication event and the duration of each collective operation, and also
automatically dump tracing data on NCCLX watchdog or heartbeat timeout. We enable more computationally
intensive tracing operations and metadata collection selectively as needed live in production through online
configuration changes (Tang et al., 2015) without needing a code release or job restart.
Debugging issues in large-scale training is complicated by the mixed use of NVLink and RoCE in our network.
Data transfer over NVLink typically occurs through load/store operations issued by CUDA kernels, and
failures in either the remote GPU or NVLink connectivity often manifest as stalled load/store operations
within CUDA kernels without returning a clear error code. NCCLX enhances the speed and accuracy of failure
detection and localization through a tight co-design with PyTorch, allowing PyTorch to access NCCLX’s
internal state and track relevant information. While stalls due to NVLink failures cannot be completely
prevented, our system monitors the state of the communication library and automatically times out when
such a stall is detected. Additionally, NCCLX traces the kernel and network activities of each NCCLX
communication and provides a snapshot of the failing NCCLX collective’s internal state, including finished
and pending data transfers between all ranks. We analyze this data to debug NCCLX scaling issues.
Sometimes, hardwareissuesmaycausestill-functioningbutslowstragglersthatarehardtodetect. Evenasingle
straggler can slow down thousands of other GPUs, often appearing as functioning but slow communications.
We developed tools to prioritize potentially problematic communications from selected process groups. By
investigating just a few top suspects, we were usually able to effectively identify the stragglers.
One interesting observation is the impact of environmental factors on training performance at scale. For
Llama 3 405B , we noted a diurnal 1-2% throughput variation based on time-of-day. This fluctuation is the
result of higher mid-day temperatures impacting GPU dynamic voltage and frequency scaling.
During training, tens of thousands of GPUs may increase or decrease power consumption at the same time,
for example, due to all GPUs waiting for checkpointing or collective communications to finish, or the startup
or shutdown of the entire training job. When this happens, it can result in instant fluctuations of power
consumption across the data center on the order of tens of megawatts, stretching the limits of the power grid.
This is an ongoing challenge for us as we scale training for future, even larger Llama models.
