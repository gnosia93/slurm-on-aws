## GPU 관련 ##

gpu-st-ml-1 GPU 노드로 로그인 한 후 아래 명려어들을 실행한다.  
```
sinfo -N
ssh gpu-st-ml-1
```

### GPU 온도 파워 등 ###
```
nvidia-smi --query-gpu=index,name,temperature.gpu,power.draw,power.limit,\
ecc.errors.corrected.volatile.total,ecc.errors.uncorrected.volatile.total --format=csv
```
[결과]
```
index, name, temperature.gpu, power.draw [W], power.limit [W], ecc.errors.corrected.volatile.total, ecc.errors.uncorrected.volatile.total
0, NVIDIA RTX PRO 6000 Blackwell Server Edition, 25, 30.39 W, 600.00 W, 0, 0
1, NVIDIA RTX PRO 6000 Blackwell Server Edition, 25, 28.54 W, 600.00 W, 0, 0
```

### GPU 쓰로틀링 ###
```
nvidia-smi --query-gpu=index,name,clocks_throttle_reasons.active,clocks_throttle_reasons.gpu_idle,\
clocks_throttle_reasons.hw_thermal_slowdown,clocks_throttle_reasons.sw_thermal_slowdown,\
clocks_throttle_reasons.sw_power_cap --format=csv
```
[결과]
```
index, name, clocks_event_reasons.active, clocks_event_reasons.gpu_idle, clocks_event_reasons.hw_thermal_slowdown, clocks_event_reasons.sw_thermal_slowdown, clocks_event_reasons.sw_power_cap
0, NVIDIA RTX PRO 6000 Blackwell Server Edition, 0x0000000000000004, Not Active, Not Active, Not Active, Active
1, NVIDIA RTX PRO 6000 Blackwell Server Edition, 0x0000000000000004, Not Active, Not Active, Not Active, Active
```

아래 명령어로 실시간으로 전력, 온도 및 쓰로틀링을 모니터링 할 수 있다. (파라미터 p: 전력/온도, t: 쓰로틀링 상태, -d 1: 1초 간격)   
```
nvidia-smi dmon -s pt -d 1
```
[결과]
```
# gpu    pwr  gtemp  mtemp  rxpci  txpci 
# Idx      W      C      C   MB/s   MB/s 
    0     30     25      -      0      0 
    1     28     25      -      0      0 
    0     30     25      -      0      0 
    1     28     25      -      0      0 
    0     30     25      -      0      0 
    1     28     25      -      0      0 
    0     30     25      -      0      0 
    1     27     25      -      0      0 
    0     30     25      -      0      0 
    1     28     25      -      0      0 
    0     30     25      -      0      0 
    1     27     25      -      1      0 
```
  

### GPU 토폴로지 ###
```
nvidia-smi topo -mp
```
[결과]
```
        GPU0    GPU1    CPU Affinity    NUMA Affinity   GPU NUMA ID
GPU0     X      PIX     0-47    0               N/A
GPU1    PIX      X      0-47    0               N/A

Legend:

  X    = Self
  SYS  = Connection traversing PCIe as well as the SMP interconnect between NUMA nodes (e.g., QPI/UPI)
  NODE = Connection traversing PCIe as well as the interconnect between PCIe Host Bridges within a NUMA node
  PHB  = Connection traversing PCIe as well as a PCIe Host Bridge (typically the CPU)
  PXB  = Connection traversing multiple PCIe bridges (without traversing the PCIe Host Bridge)
  PIX  = Connection traversing at most a single PCIe bridge
```

### GPU 진단 ###
```
srun --partition=gpu --nodes=1 --ntasks=1 --gpus=2 --exclusive sudo dcgmi diag -r 3
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/dcgmi-diag.png)

[결과]
```
Successfully ran diagnostic for group.
Successfully ran diagnostic for group.
+---------------------------+------------------------------------------------+
| Diagnostic                | Result                                         |
+===========================+================================================+
|-----  Metadata  ----------+------------------------------------------------|
| DCGM Version              | 3.3.9                                          |
| Driver Version Detected   | 570.172.08                                     |
| GPU Device IDs Detected   | 2bb5,2bb5                                      |
|-----  Deployment  --------+------------------------------------------------|
| Denylist                  | Pass                                           |
| NVML Library              | Pass                                           |
| CUDA Main Library         | Pass                                           |
| Permissions and OS Blocks | Pass                                           |
| Persistence Mode          | Pass                                           |
| Environment Variables     | Pass                                           |
| Page Retirement/Row Remap | Pass                                           |
| Graphics Processes        | Pass                                           |
| Inforom                   | Pass                                           |
+-----  Integration  -------+------------------------------------------------+
| PCIe                      | Skip - All                                     |
+-----  Hardware  ----------+------------------------------------------------+
| GPU Memory                | Skip - All                                     |
+-----  Stress  ------------+------------------------------------------------+
| Targeted Stress           | Skip - All                                     |
| Targeted Power            | Skip - All                                     |
| Memory Bandwidth          | Skip - All                                     |
| EUD Test                  | Skip - All                                     |
+---------------------------+------------------------------------------------+
+---------------------------+------------------------------------------------+
| Diagnostic                | Result                                         |
+===========================+================================================+
|-----  Metadata  ----------+------------------------------------------------|
| DCGM Version              | 3.3.9                                          |
| Driver Version Detected   | 570.172.08                                     |
| GPU Device IDs Detected   | 2bb5,2bb5                                      |
|-----  Deployment  --------+------------------------------------------------|
| Denylist                  | Pass                                           |
| NVML Library              | Pass                                           |
| CUDA Main Library         | Pass                                           |
| Permissions and OS Blocks | Pass                                           |
| Persistence Mode          | Pass                                           |
| Environment Variables     | Pass                                           |
| Page Retirement/Row Remap | Pass                                           |
| Graphics Processes        | Pass                                           |
| Inforom                   | Pass                                           |
+-----  Integration  -------+------------------------------------------------+
| PCIe                      | Skip - All                                     |
+-----  Hardware  ----------+------------------------------------------------+
| GPU Memory                | Skip - All                                     |
+-----  Stress  ------------+------------------------------------------------+
| Targeted Stress           | Skip - All                                     |
| Targeted Power            | Skip - All                                     |
| Memory Bandwidth          | Skip - All                                     |
| EUD Test                  | Skip - All                                     |
+---------------------------+------------------------------------------------+
```


## 네트워크 ##

* fi_info -p efa — EFA provider 상태
* ethtool -S <efa_device> — EFA 카운터 (drop, error 등)

## 스토리지 ##

* lsblk — 디스크 구성
* df -h — 마운트/용량
* fio — 디스크 I/O 벤치마크 (데이터 로딩 병목 확인)

## OS 시스템 ##
### dmesg ###
```
# 전체 커널 에러
dmesg | grep -i error

# GPU/NVIDIA 관련 에러만
dmesg | grep -i nvidia

# ECC/Xid 에러 (GPU 하드웨어 에러)
dmesg | grep -i xid

# PCIe 에러
dmesg | grep -i pcie

# EFA 관련 에러
dmesg | grep -i efa

# 최근 에러만 (타임스탬프 포함)
dmesg -T | grep -i error | tail -20
```

### 리소스 제한(ulimit -l) ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/ulimit-a.png)
설정 방법:
```
# /etc/security/limits.conf
*    soft    memlock    unlimited
*    hard    memlock    unlimited
*    soft    nofile     65536
*    hard    nofile     65536
```

### lspci ###
```
# GPU 장치 목록
lspci | grep -i nvidia

# 상세 정보 (PCIe 링크 속도, 폭 포함)
lspci -vvv | grep -A 20 -i nvidia | grep -E "NVIDIA|LnkSta|LnkCap"
```
[출력]
```
00:1e.0 3D controller: NVIDIA Corporation L40S (rev a1)
    LnkCap: Speed 16GT/s, Width x16    ← PCIe 최대 스펙
    LnkSta: Speed 16GT/s, Width x16    ← 현재 실제 링크 상태
```
  
### NUMA ###
```
numactl --hardware
```
[출력]
```
available: 2 nodes (0-1)
node 0 cpus: 0-47
node 0 size: 256000 MB
node 0 free: 240000 MB
node 1 cpus: 48-95
node 1 size: 256000 MB
node 1 free: 245000 MB
node distances:
node   0   1
  0:  10  21
  1:  21  10
```
GPU가 어느 NUMA 노드에 붙어있는지 확인:
```
nvidia-smi topo -m
```
[출력]
```
GPU0-3 → NUMA node 0 (CPU 0-47)
GPU4-7 → NUMA node 1 (CPU 48-95)
```
학습 시 GPU0을 쓰는 프로세스가 NUMA node 1의 CPU에서 돌면, 메모리 접근이 원격(distance 21)이 되어 성능이 저하된다.

* SLURM에서 NUMA affinity 자동 매핑:
```
#SBATCH --gres=gpu:1
#SBATCH --cpu-bind=verbose
```
* 수동으로 NUMA 바인딩:
```
numactl --cpunodebind=0 --membind=0 python train.py  # NUMA node 0에 바인딩
```



