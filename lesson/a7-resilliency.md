
### Job Fail의 원인 ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/jobfail-type.png)

> [!NOTE]

> * nccl timeout 의 경우 rank 중 일부가 죽어서 발생하는 케이스가 훨씬 빈번하다.
> * 네트워크 스위치단에서의 문제는 거의 없는 듯 ^^
> * OOM 및 코드버그의 경우 slurm job 로그를 관찰하면 상세한 정보를 확인할 수 있다. 
> * 좀비의 경우 AI클러스터를 구성하는 모든 노드를 살펴보는것이 쉽지 않으므로, slurm job 의 epilog 에서 해당 잡을 Kill 하는 것으로 구현하거나
  srun 을 이용하여 이를 감지하고 KILL 하는 shell script 를 실행할 수도 있다.
> * 실제로는 GPU 장애가 가장 빈번하다. 아래는 GPU 장애시 해당 노드를 자동 drain 하고 학습을 재시작하는 아키텍처에 대한 내용이다. 

### _GPU Cluster Resilience Architecture_ ###

AI 클러스터의 GPU 하드웨어 Fail 로 인한 "GPU 클러스터 자동 장애 복구 아키텍처" 는 다음과 같다. 치명적 GPU XID 를 감지하여 해당 노드를 자동 Drain 한다. 

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
