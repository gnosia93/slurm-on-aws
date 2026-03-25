## 훈련작업 실패 디버깅 (장애 원인파악) ##
```mermaid
flowchart TD
    START["잡 실패"] --> SACCT["sacct -j <jobid><br/>상태 확인"]

    SACCT --> |"FAILED"| JOBLOG["잡 로그 확인<br/>slurm-<jobid>.out"]
    SACCT --> |"TIMEOUT"| JOBLOG
    SACCT --> |"OUT_OF_MEMORY"| DMESG_OOM["dmesg | grep oom<br/>CPU OOM kill 확인"]
    SACCT --> |"NODE_FAIL"| SLURMLOG["slurmctld.log<br/>어떤 노드가 죽었는지"]

    JOBLOG --> |"Python traceback"| FIX_CODE["코드 버그<br/>→ 코드 수정"]
    JOBLOG --> |"CUDA out of memory"| FIX_GPU_OOM["GPU OOM<br/>→ 배치 사이즈 줄이기"]
    JOBLOG --> |"NCCL Timeout"| NCCL_DEBUG["통신 문제<br/>→ dmesg + ibstat"]
    JOBLOG --> |"I/O Error"| STORAGE["스토리지 문제<br/>→ lfs check servers"]
    JOBLOG --> |"원인 불명"| DMESG["dmesg / syslog 확인"]

    DMESG_OOM --> FIX_CPU_OOM["CPU OOM<br/>→ 메모리 늘리기"]

    SLURMLOG --> |"NODE_FAIL"| DMESG
    SLURMLOG --> |"Prolog failed"| PROLOG["GPU 헬스체크 실패<br/>→ 노드 drain"]

    DMESG --> |"Xid 에러"| DRAIN["GPU 장애<br/>→ drain + GPU 교체"]
    DMESG --> |"OOM kill"| FIX_CPU_OOM
    DMESG --> |"Lustre Error"| STORAGE
    DMESG --> |"IB Error"| NETWORK["네트워크 문제<br/>→ ibstat / perfquery"]

    NCCL_DEBUG --> |"IB 링크 에러"| NETWORK
    NCCL_DEBUG --> |"Xid 발견"| DRAIN
    NCCL_DEBUG --> |"재현 안 됨"| MONITOR["모니터링 강화<br/>nccl-test 반복<br/>노드 격리로 범위 좁히기"]

    NETWORK --> NETTEAM["네트워크 팀에 전달<br/>포트/케이블 점검"]

    style START fill:#ff6b6b,color:#fff
    style FIX_CODE fill:#51cf66,color:#fff
    style FIX_GPU_OOM fill:#51cf66,color:#fff
    style FIX_CPU_OOM fill:#51cf66,color:#fff
    style DRAIN fill:#ffd43b,color:#000
    style PROLOG fill:#ffd43b,color:#000
    style STORAGE fill:#cc5de8,color:#fff
    style NETWORK fill:#4a9eff,color:#fff
    style NETTEAM fill:#4a9eff,color:#fff
    style MONITOR fill:#868e96,color:#fff
```
잡 실패 시 sacct로 상태 먼저 확인하고, 잡 로그에서 에러 메시지를 살펴본다. 대부분 여기서 원인이 나오는데, 안 보이면 dmesg에서 Xid나 OOM을 확인하고, 그래도 안 보이면 slurmctld 로그에서 스케줄링/노드 문제를 확인합니다. GPU 하드웨어 문제면 drain, OOM이면 리소스 조정, 네트워크면 ibstat으로 링크 상태 확인한다.

```
sacct -j 12345 --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS,NodeList

# JobID    JobName     State          ExitCode  Elapsed   MaxRSS    NodeList
# 12345    llm-train   FAILED         1:0       02:30:15  450G      gpu-node-[01-04]
```

```
잡 실패
  │
  ▼
sacct → 상태 확인 (FAILED/TIMEOUT/OOM/NODE_FAIL)
  │
  ▼
잡 로그 (slurm-<jobid>.out)
  ├─ Python traceback     → 코드 버그 → 코드 수정
  ├─ CUDA out of memory   → GPU OOM → 배치 사이즈 줄이기
  ├─ NCCL Timeout         → 통신 문제 → Step 3으로
  ├─ I/O Error            → 스토리지 문제 → lfs check servers
  └─ 원인 불명            → Step 3으로
  │
  ▼
dmesg / syslog
  ├─ Xid 에러             → GPU 장애 → drain + GPU 교체
  ├─ OOM kill             → CPU OOM → 메모리 늘리기
  ├─ Lustre Error         → 스토리지 → lfs 진단
  └─ IB Error             → 네트워크 → ibstat/perfquery
  │
  ▼
slurmctld.log
  ├─ NODE_FAIL            → 노드 장애
  └─ Prolog failed        → GPU 헬스체크 실패
```


## k8s ##
```mermaid
flowchart TD
    START["Pod 실패"] --> KUBECTL["kubectl describe pod<br/>상태 확인"]

    KUBECTL --> |"Failed/Error"| PODLOG["Pod 로그 확인<br/>kubectl logs <pod>"]
    KUBECTL --> |"OOMKilled"| RESOURCE["CPU/GPU OOM<br/>→ 리소스 리밋 조정"]
    KUBECTL --> |"Pending"| EVENTS["kubectl get events<br/>스케줄링 문제 확인"]
    KUBECTL --> |"CrashLoopBackOff"| PODLOG_PREV["kubectl logs --previous<br/>죽기 전 로그 확인"]

    PODLOG --> |"Python traceback"| FIX_CODE["코드 버그<br/>→ 코드 수정"]
    PODLOG --> |"CUDA out of memory"| FIX_GPU_OOM["GPU OOM<br/>→ 배치 사이즈 줄이기"]
    PODLOG --> |"NCCL Timeout"| NCCL_DEBUG["통신 문제<br/>→ dmesg + ibstat"]
    PODLOG --> |"I/O Error"| STORAGE["스토리지 문제<br/>→ lfs check servers"]
    PODLOG --> |"원인 불명"| DMESG["노드 레벨 확인<br/>dmesg / syslog"]

    PODLOG_PREV --> PODLOG

    EVENTS --> |"FailedScheduling"| NO_RESOURCE["리소스 부족<br/>→ GPU 가용 확인"]
    EVENTS --> |"NodeNotReady"| NODE_DOWN["노드 장애<br/>→ kubectl describe node"]

    DMESG --> |"Xid 에러"| CORDON["GPU 장애<br/>→ kubectl cordon"]
    DMESG --> |"OOM kill"| FIX_CPU_OOM["CPU OOM<br/>→ 메모리 리밋 늘리기"]
    DMESG --> |"Lustre Error"| STORAGE
    DMESG --> |"IB Error"| NETWORK["네트워크 문제<br/>→ ibstat / perfquery"]

    NCCL_DEBUG --> |"IB 링크 에러"| NETWORK
    NCCL_DEBUG --> |"Xid 발견"| CORDON
    NCCL_DEBUG --> |"재현 안 됨"| MONITOR["모니터링 강화<br/>nccl-test 반복<br/>노드 격리로 범위 좁히기"]

    NETWORK --> NETTEAM["네트워크 팀에 전달<br/>포트/케이블 점검"]

    style START fill:#ff6b6b,color:#fff
    style FIX_CODE fill:#51cf66,color:#fff
    style FIX_GPU_OOM fill:#51cf66,color:#fff
    style FIX_CPU_OOM fill:#51cf66,color:#fff
    style RESOURCE fill:#51cf66,color:#fff
    style CORDON fill:#ffd43b,color:#000
    style NODE_DOWN fill:#ffd43b,color:#000
    style STORAGE fill:#cc5de8,color:#fff
    style NETWORK fill:#4a9eff,color:#fff
    style NETTEAM fill:#4a9eff,color:#fff
    style MONITOR fill:#868e96,color:#fff
    style NO_RESOURCE fill:#868e96,color:#fff
```
```
잡 실패
  │
  ▼
kubectl → 상태 확인
  kubectl get pods -n team-a
  kubectl describe pod train-job-worker-0
  # Status: Failed / Error / OOMKilled / CrashLoopBackOff
  │
  ▼
Pod 로그 (= Slurm 잡 로그)
  kubectl logs train-job-worker-0
  kubectl logs train-job-worker-0 --previous   # 죽기 전 로그
  ├─ Python traceback     → 코드 버그
  ├─ CUDA out of memory   → GPU OOM
  ├─ NCCL Timeout         → 통신 문제
  ├─ I/O Error            → 스토리지 문제
  └─ 원인 불명            → 아래로
  │
  ▼
노드 레벨 확인
  kubectl debug node/gpu-node-05 -it --image=ubuntu
  # 또는 SSH로 접속
  dmesg | grep -i "xid\|oom\|lustre"
  ├─ Xid 에러             → GPU 장애 → kubectl cordon
  ├─ OOM kill             → CPU OOM → 리소스 리밋 조정
  └─ IB Error             → 네트워크 → ibstat
  │
  ▼
K8s 이벤트 확인 (= slurmctld.log)
  kubectl get events -n team-a --sort-by='.lastTimestamp'
  # FailedScheduling → 리소스 부족
  # NodeNotReady     → 노드 장애
  # Evicted          → 리소스 초과로 퇴거
```

## 비교 ##
본질은 동일하다. 잡 로그 → 시스템 로그 → 스케줄러 로그 순서로 확인한다.
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/job-incident.png)

