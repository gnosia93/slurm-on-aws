## GPU 관련 ##

### GPU 온도 파워 등 ###
```
nvidia-smi --query-gpu=index,name,temperature.gpu, power.draw, power.limit,ecc.errors.corrected.volatile.total, ecc.errors.uncorrected.volatile.total --format=csv
```

### GPU 쓰로틀링 ###
```
nvidia-smi --query-gpu=index,name,clocks_throttle_reasons.active,clocks_throttle_reasons.gpu_idle,\
clocks_throttle_reasons.hw_thermal_slowdown,clocks_throttle_reasons.sw_thermal_slowdown,\
clocks_throttle_reasons.sw_power_cap --format=csv
```
아래 명령어로 실시간으로 전력, 온도 및 쓰로틀링을 모니터링 할 수 있다.
```
nvidia-smi dmon -s pt -d 1
```
* p: 전력/온도, t: 쓰로틀링 상태, -d 1: 1초 간격
  
### GPU Clock 비교 (현재 클럭과 최대 클럭) ###
```
nvidia-smi --query-gpu=index,clocks.current.graphics,clocks.max.graphics,clocks.current.mem,clocks.max.mem --format=csv
```
### GPU 토폴로지 ###
```
nvidia-smi topo -m -i all
nvidia-smi topo -mp
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/smi-topology.png)
* NV#	- NVLink (숫자는 링크 수)
* PIX	- 같은 PCIe 스위치	(~32GB/s)
* PHB	- 같은 CPU 소켓, 다른 PCIe 스위치 (~32GB/s)
* SYS	- 다른 CPU 소켓 (~16GB/s)
* NODE - 같은 NUMA 노드	(~32GB/s) 

### GPU 진단 ###
```
srun --partition=gpu --nodes=2 --ntasks-per-node=1 dcgmi diag -r 3
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/dcgmi-diag.png)


### 네트워크 관련 ###

* fi_info -p efa — EFA provider 상태
* ethtool -S <efa_device> — EFA 카운터 (drop, error 등)

### 스토리지 관련 ###

* lsblk — 디스크 구성
* df -h — 마운트/용량
* fio — 디스크 I/O 벤치마크 (데이터 로딩 병목 확인)

## 시스템 ##
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

### 리소스 제한(ulimit) ###
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/ulimit-a.png)

* lspci | grep -i nvidia — PCIe 장치 인식
* lspci -vv -s <gpu_bus_id> | grep -i width — PCIe bandwidth (x16 확인)
* numactl --hardware — NUMA 토폴로지 (GPU-CPU affinity)


---

GPU 분산 훈련을 위한 OS 튜닝 항목들입니다. 확실하지 않은 항목은 표기하겠습니다.

메모리:

vm.zone_reclaim_mode=0 — NUMA 노드의 로컬 메모리가 부족할 때 다른 NUMA 노드에서 할당 허용. 기본값이 0인 경우가 많지만, 일부 시스템에서 1로 설정되어 있으면 GPU 근처 메모리만 쓰다가 OOM 발생 가능.
vm.min_free_kbytes — 커널이 항상 확보해두는 최소 여유 메모리. 대용량 GPU 데이터 전송 시 DMA 버퍼 할당 실패를 방지. 보통 1000000 (1GB) 정도로 설정.
vm.max_map_count=65530 → 262144 이상으로 증가. PyTorch가 많은 메모리 매핑을 사용하므로 기본값이면 부족할 수 있음.
네트워크:

net.core.rmem_max=16777216 — 소켓 수신 버퍼 최대 크기 (16MB)
net.core.wmem_max=16777216 — 소켓 송신 버퍼 최대 크기 (16MB)
net.core.netdev_max_backlog=5000 — 네트워크 인터페이스 수신 큐 크기 증가
net.ipv4.tcp_max_syn_backlog=8096 — TCP 연결 대기열 증가
리소스 제한 (
limits.conf
):

* soft memlock unlimited — GPU Direct RDMA에 필수. pinned memory 제한 해제
* hard memlock unlimited
* soft nofile 1048576 — 열 수 있는 파일 수 증가. 대규모 데이터 로딩 시 필요
* hard nofile 1048576
* soft stack unlimited — 스택 크기 제한 해제
* hard stack unlimited
Hugepages:

vm.nr_hugepages — EFA/RDMA 통신에서 hugepage를 사용하면 TLB miss 감소로 성능 향상. 다만 설정값은 워크로드에 따라 다름.
CPU:

cpufreq governor를 performance로 설정 — CPU가 절전 모드로 빠지지 않도록
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
NUMA:

numactl --interleave=all로 프로세스 실행 — 메모리를 NUMA 노드에 균등 분배. 단, GPU affinity가 중요한 경우 오히려 역효과일 수 있어서 워크로드에 따라 판단 필요.
적용 방법 (
sysctl.conf
에 추가):

vm.zone_reclaim_mode=0
vm.min_free_kbytes=1000000
vm.max_map_count=262144
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.netdev_max_backlog=5000
sudo sysctl -p
memlock unlimited는 ParallelCluster AMI에서 이미 설정되어 있을 수 있습니다. ulimit -l로 확인해보세요.

