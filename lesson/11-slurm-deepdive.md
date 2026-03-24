## Architecture ##
```mermaid
graph TB
    %% 외부 레이어: Config (중앙 상단 배치)
    subgraph Config ["⚙️ 전역 설정 (Configuration)"]
        CONF_ALL["slurm.conf / gres.conf / cgroup.conf / topology.conf / slurmdbd.conf / plugstack.conf"]
    end

    %% 메인 노드 그룹
    subgraph Login ["🔑 Login Node"]
        CLI["srun / sbatch / squeue / sacct"]
        MUNGE_L["munged (Auth)"]
    end

    subgraph Controller ["🧠 Controller Node"]
        SLURMCTLD["slurmctld<br/>(Scheduler)"]
        SLURMDBD["slurmdbd<br/>(Accounting)"]
        DB[(MySQL / MariaDB)]
        SLURMDBD --> DB
    end

    subgraph Compute ["🚀 Compute Nodes (gpu-node-001~N)"]
        SLURMD["slurmd + munged"]
        GPU["GPU 0~7 (H100 x 8)"]
        PYXIS["Enroot + pyxis"]
        
        subgraph Scripts ["Scripts"]
            PROLOG["prolog.sh<br/>(Health Check)"]
            EPILOG["epilog.sh<br/>(Reset/Cleanup)"]
        end

        DCGM["DCGM Exporter<br/>(Port :9400)"]
        
        SLURMD --> GPU
        SLURMD --> PROLOG
        SLURMD --> EPILOG
        GPU --> DCGM
    end

    subgraph Monitoring ["📊 Monitoring Stack"]
        PROM[Prometheus]
        GRAFANA[Grafana]
        ALERT[AlertManager]
        WEBHOOK["drain-controller<br/>(scontrol drain)"]
        
        PROM --> GRAFANA
        PROM --> ALERT
        ALERT --> WEBHOOK
    end

    subgraph Storage ["📁 Shared Storage"]
        CKPT["/shared/checkpoints"]
        DATA["/shared/datasets"]
        MODEL["/shared/models"]
    end

    %% 연결 관계 (Flow)
    CLI -->|"1. Job Submit"| SLURMCTLD
    SLURMCTLD -->|"2. Job Dispatch"| SLURMD
    SLURMDBD <-->|"Job History"| SLURMCTLD
    
    DCGM -.->|"3. Metrics"| PROM
    WEBHOOK -.->|"4. Auto Drain"| SLURMCTLD
    
    Compute ==>|"I/O"| Storage

    %% 스타일링 (Flat Design)
    style Login fill:#e7f5ff,stroke:#4a9eff,stroke-width:2px
    style Controller fill:#fff5f5,stroke:#ff6b6b,stroke-width:2px
    style Compute fill:#ebfbee,stroke:#51cf66,stroke-width:2px
    style Monitoring fill:#fff9db,stroke:#fab005,stroke-width:2px
    style Storage fill:#f8f0fc,stroke:#cc5de8,stroke-width:2px
    style Config fill:#f1f3f5,stroke:#868e96,stroke-dasharray: 5 5

```


```mermaid
graph TB
    subgraph Login["Login Node"]
        CLI["srun / sbatch / squeue / sacct"]
        MUNGE_L["munged"]
    end

    subgraph Controller["Controller Node"]
        SLURMCTLD["slurmctld<br/>(스케줄러)"]
        SLURMDBD["slurmdbd<br/>(어카운팅)"]
        MUNGE_C["munged"]
        DB["MySQL / MariaDB"]
        SLURMDBD --> DB
    end

    subgraph Compute["Compute Nodes (gpu-node-001 ~ N)"]
        SLURMD["slurmd + munged"]
        GPU["GPU 0~7 (H100 × 8)"]
        DCGM["DCGM + DCGM Exporter :9400"]
        PYXIS["Enroot + pyxis"]
        PROLOG["prolog.sh<br/>(GPU 헬스체크)"]
        EPILOG["epilog.sh<br/>(GPU 리셋/정리)"]
        SLURMD --> GPU
        SLURMD --> PROLOG
        SLURMD --> EPILOG
        GPU --> DCGM
    end

    subgraph Monitoring["Monitoring Stack"]
        PROM["Prometheus"]
        GRAFANA["Grafana"]
        ALERT["AlertManager"]
        WEBHOOK["drain-controller<br/>(scontrol drain)"]
        PROM --> GRAFANA
        PROM --> ALERT
        ALERT --> WEBHOOK
    end

    subgraph Storage["Shared Storage (Lustre / GPFS / NFS)"]
        CKPT["/shared/checkpoints"]
        DATA["/shared/datasets"]
        MODEL["/shared/models"]
    end

    CLI -->|"sbatch train.sh"| SLURMCTLD
    SLURMCTLD -->|"잡 분배"| SLURMD
    DCGM -->|"메트릭"| PROM
    WEBHOOK -->|"scontrol drain"| SLURMCTLD
    Compute -->|"체크포인트 R/W"| Storage
    SLURMDBD -->|"잡 이력 기록"| DB

    subgraph Config["설정 파일 (Controller + Compute 공유)"]
        CONF1["slurm.conf"]
        CONF2["gres.conf"]
        CONF3["cgroup.conf"]
        CONF4["topology.conf"]
        CONF5["slurmdbd.conf"]
        CONF6["plugstack.conf"]
    end

    style Login fill:#4a9eff,color:#fff
    style Controller fill:#ff6b6b,color:#fff
    style Compute fill:#51cf66,color:#fff
    style Monitoring fill:#ffd43b,color:#000
    style Storage fill:#cc5de8,color:#fff
    style Config fill:#868e96,color:#fff
```


## Configuration ##

ParallelCluster 의 설정 파일은 온프램 slurm(/etc/slurm/) 와 달리 /opt/slurm/etc/ 에 있다. 
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/slurm-conf.png)
* [slurm.conf 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/slurm.conf)
* [gres.conf 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/gres.conf)
* [cgroup.conf 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/cgroup.conf)
* [prolog.sh 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/prolog.sh)
* [epilog.sh 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/epilog.sh)
