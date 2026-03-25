# slurm-on-aws (pcluster)
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/pcluster-arch.png)

* [C1. VPC 생성](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/1-vpc.md)

* [C2. 스토리지 및 네트워크 구성](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/9-shared-fs.md)

* [C3. Parallel Cluster 설치](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/2-pcluster.md) 

* [C4. nccl-test 실행하기](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/3-nccl-test.md) 
    
* [C5. 클러스터 진단](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/4-system-diag.md)   
     
* [C6. 컨테이너 사용하기 (enroot/pyxis)](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/5-slurm-container.md)

* > [C7. Custom AMI 만들기 (packer)](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/6-custom-ami.md)
  
* [C8. 모니터링 설정하기 (prometheus/loki/grafana)](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/7-monitoring.md)

* [C9. Megatron-LM](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/8-megatron-lm.md)
  
* [C10. 클러스터 변경 / 삭제](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/10-cluster-delete.md)


### _Appendix_ ##
* [C11. Slurm 의 이해](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/11-slurm-deepdive.md)
* [A. DCGM 메트릭](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/a2-dcgm-metric.md)
* [B. GPU OOM 대응](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/a3-gpu-oom.md)
* [C. CPU OOM 대응](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/a4-cpu-oom.md)
* [D. Straggler Detection](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/a5-staggler-detect.md)
* [E. 좀비 프로세스 방지](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/a6-zombie-detect.md)


  
### _AWS P-Instance Architecture_ ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/aws-p5en.png)

* Job 설정
```
# 1. GRES (Generic Resources) - GPU 할당
#SBATCH --gpus-per-node=2          # 노드당 GPU 2장 요청

# 2. CPU-GPU affinity
#SBATCH --gpu-bind=closest         # GPU와 가장 가까운 CPU 코어에 바인딩, cf> gpus-per-node=8 인 경우는 의미 없음.

# 3. 네트워크 토폴로지 
#SBATCH --switches=1@00:10:00      # 온프람인 경우 - 1는 TOR 스위치 하나의 의미, 할당될때 까지 10분까지 기다릴수 있음.
                                   # AWS 인 경우 - Placement Group 으로 처리, PCluster 생성시 설정해야 함. PlacementGroup.Enabled: true  

#SBATCH --exclusive                # 노드 독점 (다른 잡과 공유 안 함)
```
* NIC 의 경우 NCCL 알아서 가까운 경로에 있는 NIC을 사용한다.
```
# slurm.conf
# topology.conf - 네트워크 토폴로지 정의
# On-Prom 에 해당, AWS 의 경우 PlacementGroup 으로 대체
TopologyPlugin=topology/tree

# gres.conf - p5en.48xlarge (8× H200, 듀얼 소켓)
# NUMA 0 — CPU Socket 0 (Cores 0-47)
Name=gpu Type=h200 File=/dev/nvidia0 Cores=0-47
Name=gpu Type=h200 File=/dev/nvidia1 Cores=0-47
Name=gpu Type=h200 File=/dev/nvidia2 Cores=0-47
Name=gpu Type=h200 File=/dev/nvidia3 Cores=0-47

# NUMA 1 — CPU Socket 1 (Cores 48-95)
Name=gpu Type=h200 File=/dev/nvidia4 Cores=48-95
Name=gpu Type=h200 File=/dev/nvidia5 Cores=48-95
Name=gpu Type=h200 File=/dev/nvidia6 Cores=48-95
Name=gpu Type=h200 File=/dev/nvidia7 Cores=48-95
```

### _GPU Cluster Resilience Architecture_ ###
AI 클러스터의 GPU 하드웨어 Fail 로 인한 "GPU 클러스터 자동 장애 복구 아키텍처" 는 다음과 같다. XID 

* 감지(Detect) -> 격리(Isolate) -> 복구(Job Recover)
* 프로메테우스 스택 : 감지와 webhook 을 통한 노드 격리 담당
* Job 복구 : slurm 의 #SBATCH --requeue 활동 
* 체크 포인트 : 매 epoch 또는 일정 step 마다 체크포인트 저장 / Job 재시작시 읽음
* srun torchrun 를 활용하여 slurm job 구성 --> fast fail 유도   
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/detect-isolate-recover.png)

[프로메테우스 룰설정]
```
# 1. prometheus-rules.yaml — Alert 룰 (Prometheus 쪽)
groups:
  - name: gpu-xid-alerts
    rules:
      # 치명적 Xid 감지
      # Xid 48: ECC Uncorrectable Error (HBM 메모리 데이터 손상, 복구 불가)
      # Xid 63: Row Remap Failure (ECC 복구용 Row Remap 한계 초과)
      # Xid 74: NVLink Error (NVLink 통신 장애)
      # Xid 79: Fallen Off Bus (GPU가 PCIe 버스에서 사라짐)
      # Xid 94: SRAM ECC Uncorrectable - Contained (GPU 내부 SRAM 손상, 격리됨)
      # Xid 95: SRAM ECC Uncorrectable - Uncontained (GPU 내부 SRAM 손상, 전파됨)
      - alert: GPUCriticalXid
        expr: >
          DCGM_FI_DEV_XID_ERRORS == 48
          or DCGM_FI_DEV_XID_ERRORS == 63
          or DCGM_FI_DEV_XID_ERRORS == 74
          or DCGM_FI_DEV_XID_ERRORS == 79
          or DCGM_FI_DEV_XID_ERRORS == 94
          or DCGM_FI_DEV_XID_ERRORS == 95
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Xid {{ $value }} on {{ $labels.instance }} GPU {{ $labels.gpu }}"
          action: drain

      # ECC UE 카운트 증가
      - alert: GPUEccUncorrectable
        expr: DCGM_FI_DEV_ECC_DBE_VOL_TOTAL > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "ECC UE on {{ $labels.instance }} GPU {{ $labels.gpu }}"
          action: drain

      # GPU 온도 이상 (idle인데 높음)
      - alert: GPUTempHigh
        expr: DCGM_FI_DEV_GPU_TEMP > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "GPU temp {{ $value }}C on {{ $labels.instance }}"
```
[AlertManager 라우팅]
```
# 2. alertmanager.yaml — 알림 라우팅 (AlertManager 쪽)
global:
  resolve_timeout: 5m

route:
  receiver: default
  routes:
    # critical → drain + Slack
    - match:
        severity: critical
      receiver: gpu-drain
      continue: true           # 다음 룰도 평가 (Slack도 보내기 위해)

    # critical → Slack 알림
    - match:
        severity: critical
      receiver: slack-critical

    # warning → Slack만
    - match:
        severity: warning
      receiver: slack-warning

receivers:
  # drain 자동화
  - name: gpu-drain
    webhook_configs:
      - url: http://drain-controller:8080/drain
        send_resolved: false

  # Slack 알림 (긴급)
  - name: slack-critical
    slack_configs:
      - channel: '#gpu-alerts-critical'
        title: '{{ .CommonAnnotations.summary }}'
        text: 'Action: {{ .CommonAnnotations.action }}'

  # Slack 알림 (경고)
  - name: slack-warning
    slack_configs:
      - channel: '#gpu-alerts-warning'
        title: '{{ .CommonAnnotations.summary }}'

  - name: default
    slack_configs:
      - channel: '#gpu-alerts'
```

## See Also ##

* [slurm-on-ec2 with ansible](https://github.com/gnosia93/slurm-on-ec2)
* [slurm-on-eks with slinky](https://github.com/gnosia93/slurm-on-eks)
