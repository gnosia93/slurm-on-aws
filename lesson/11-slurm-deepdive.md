## Architecture ##
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
