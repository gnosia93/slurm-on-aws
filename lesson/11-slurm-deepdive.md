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


## Configuration ##

ParallelCluster 의 설정 파일은 온프램 slurm(/etc/slurm/) 와 달리 /opt/slurm/etc/ 에 있다. 
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/slurm-conf.png)
* [slurm.conf 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/slurm.conf)
* [gres.conf 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/gres.conf)
* [cgroup.conf 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/cgroup.conf)
* [prolog.sh 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/prolog.sh)
* [epilog.sh 샘플](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/conf/epilog.sh)
