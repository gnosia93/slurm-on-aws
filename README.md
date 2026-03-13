# slurm-on-aws

* [C1. VPC 생성](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/1-vpc.md)
  
* [C2. Parallel Cluster 설치](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/2-pcluster.md) 

* [C3. nccl-test 실행하기](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/3-nccl-test.md) 
    
* [C4. 클러스터 상태 진단](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/4-system-diag.md)     
     
* [C5. 컨테이너 사용하기](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/5-slurm-container.md)

* [C6. 커스텀 AMI 만들기](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/6-custom-ami.md)
  
* [C7. 모니터링 설정하기]

* [C8. Megatron]

* [C9. 클러스터 변경/삭제](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/9-cluster-delete.md)



일반적인 분산 학습(Data Parallel, FSDP, TP, PP)에서는 all-reduce, all-gather, reduce-scatter가 주요 통신 패턴인데, 이것들은 대용량 메시지를 순차적으로 전달하는 방식이라 bandwidth 위주입니다. EFA로 충분합니다.

latency에 민감한 케이스는 MoE 외에도:

Pipeline Parallelism에서 마이크로배치 간 전환 (작은 activation 전송이 빈번)
노드 수가 수천 대 이상일 때 동기화 오버헤드
하지만 대부분의 학습 워크로드에서는 EFA로 큰 문제 없습니다.

### _Appendix_ ###

* https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/a1-trouble-shoot.md

## 레퍼런스 ##

* https://aws.amazon.com/ko/hpc/parallelcluster/
* [CUDA Thread Hierarchy (Introduction to CUDA Week1-3) / CUDA 강의](https://www.youtube.com/watch?v=my1U4QY59Bg)
