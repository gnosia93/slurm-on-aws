# slurm-on-aws

![](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/images/slurm-ws-arch-2.png)

**This workshop explains about how to use AWS graviton EC2 instances for pytorch distributed training with slurm.** 
AWS Graviton processors are custom-built by AWS to deliver the best price performance for cloud workloads. Graviton-based instance is upto 20% more cheaper than X86-based and provide better performance in same generation. AWS Graviton3 optimized for ML workloads and provide the `Single Instruction Multiple Data (SIMD)` while also supporting `bfloat16`. Slurm is an open source, fault-tolerant, and highly scalable cluster management and job scheduling system for large and small Linux clusters.

We provision AWS infrastructure with terraform and configure slurm cluster with ansible. for distributed training, we need NAS filesystem or Lustre Parallel filesystem. In this workshop, we will use efs filesystem as a shared storage.

## Get Started ##

* [1. slurm cluster provison](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/1.provison.md)

* [2. runnng jupyter notebook in interactive session](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/2.attach-jupyter.md)

* [3. distributed training](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/3.distributed-training.md)

* [4. Open MPI](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/4.open-mpi.md)  --> dist training with cpu nodes.

* [5. cluster monitoring](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/5.cluster-monitoring.md)



### Features to be added ###
  
* [Autoscaling](https://github.com/gnosia93/slurm-on-aws/blob/main/tutorial/6.autoscaling.md)
* fine tune with lora.
* mlflow


## Appendix ##

* [a1. pytorch with cuda toolkit](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/a1.cuda-toolkit.md)
* [a2. slurm commands](https://github.com/gnosia93/slurm-on-grv/blob/main/tutorial/a2.slurm-basic.md)
* [SLURM, 세계에서 가장 빠른 슈퍼컴퓨터 TOP500의 절반 이상이 선택한 작업 스케줄러](https://www.deepgadget.com/blog/slurm-%EC%84%B8%EA%B3%84%EC%97%90%EC%84%9C-%EA%B0%80%EC%9E%A5-%EB%B9%A0%EB%A5%B8-%EC%8A%88%ED%8D%BC%EC%BB%B4%ED%93%A8%ED%84%B0-top500%EC%9D%98-%EC%A0%88%EB%B0%98-%EC%9D%B4%EC%83%81%EC%9D%B4-%EC%84%A0%ED%83%9D%ED%95%9C-%EC%9E%91%EC%97%85-%EC%8A%A4%EC%BC%80%EC%A4%84%EB%9F%AC--25026/)
* https://github.com/dstdev/awesome-hpc
    
## Revision History ##
* 2024-12-27 draft version released



