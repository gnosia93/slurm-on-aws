### GPU 관련 ###

```
nvidia-smi --query-gpu=index,name,temperature.gpu, power.draw, power.limit,ecc.errors.corrected.volatile.total, ecc.errors.uncorrected.volatile.total --format=csv
```

* nvidia-smi — GPU 상태, 온도, 전력, ECC 에러
* nvidia-smi topo -m — GPU/NVLink/PCIe 토폴로지
* dcgmi diag -r 3 — GPU 전체 진단
* dcgmi health -c — GPU health 모니터링 설정


### GPU 진단 ###
```
srun --partition=gpu --nodes=2 --ntasks-per-node=1 dcgmi diag -r 3
```
![](https://github.com/gnosia93/slurm-on-aws/blob/main/lesson/images/dcgmi-diag.png)





### 네트워크 관련 ###

* fi_info -p efa — EFA provider 상태
* ethtool -S <efa_device> — EFA 카운터 (drop, error 등)
* nccl-test all_reduce — 노드 간 실제 bandwidth/latency

### 스토리지 관련 ###

* lsblk — 디스크 구성
* df -h — 마운트/용량
* fio — 디스크 I/O 벤치마크 (데이터 로딩 병목 확인)

### 시스템 관련 ###

* dmesg | grep -i error — 커널 에러
* lspci | grep -i nvidia — PCIe 장치 인식
* lspci -vv -s <gpu_bus_id> | grep -i width — PCIe bandwidth (x16 확인)
* numactl --hardware — NUMA 토폴로지 (GPU-CPU affinity)
* ulimit -a — 리소스 제한 (memlock 등)


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

