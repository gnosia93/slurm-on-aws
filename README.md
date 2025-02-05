# slurm-on-aws

![](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/images/slurm-ws-arch-2.png)

**This workshop explains about how to use AWS graviton EC2 instances for pytorch distributed training with slurm.** 
AWS Graviton processors are custom-built by AWS to deliver the best price performance for cloud workloads. Graviton-based instance is upto 20% more cheaper than X86-based and provide better performance in same generation. AWS Graviton3 optimized for ML workloads and provide the `Single Instruction Multiple Data (SIMD)` while also supporting `bfloat16`. Slurm is an open source, fault-tolerant, and highly scalable cluster management and job scheduling system for large and small Linux clusters.

We provision AWS infrastructure with terraform and configure slurm cluster with ansible. for distributed training, we need NAS filesystem or Lustre Parallel filesystem. In this workshop, we will use efs filesystem as a shared storage.

## Get Started ##

* [1. slurm cluster provison](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/1.provison.md)

* [2. runnng jupyter notebook in interactive session](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/2.attach-jupyter.md)

* [3. distributed training](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/3.distributed-training.md)

* [4. data wrangling with Open MPI](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/4.open-mpi.md)  --> dist training with cpu nodes.

* [5. cluster monitoring](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/5.cluster-monitoring.md)



### Features to be added ###
  
* [Autoscaling](https://github.com/gnosia93/slurm-on-aws/blob/main/tutorial/6.autoscaling.md)
* fine tune with lora.
* mlflow


## Appendix ##

* [a1. pytorch with cuda toolkit](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/a1.cuda-toolkit.md)
* [a2. slurm commands](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/a2.slurm-basic.md)
  
## Revision History ##
* 2024-12-27 draft version released



