GPU 클러스터 진단 체크리스트:

GPU 관련:

nvidia-smi — GPU 상태, 온도, 전력, ECC 에러
nvidia-smi topo -m — GPU/NVLink/PCIe 토폴로지
dcgmi diag -r 3 — GPU 전체 진단
dcgmi health -c — GPU health 모니터링 설정
네트워크 관련:

fi_info -p efa — EFA provider 상태
ethtool -S <efa_device> — EFA 카운터 (drop, error 등)
nccl-test all_reduce — 노드 간 실제 bandwidth/latency
스토리지 관련:

lsblk — 디스크 구성
df -h — 마운트/용량
fio — 디스크 I/O 벤치마크 (데이터 로딩 병목 확인)
시스템 관련:

dmesg | grep -i error — 커널 에러
lspci | grep -i nvidia — PCIe 장치 인식
lspci -vv -s <gpu_bus_id> | grep -i width — PCIe bandwidth (x16 확인)
numactl --hardware — NUMA 토폴로지 (GPU-CPU affinity)
ulimit -a — 리소스 제한 (memlock 등)
SLURM 관련:

sinfo -N — 노드 상태
scontrol show node — 노드 상세 (Gres, State, Reason)


----

  - dcgm diag -r 3
    - system message 확인 (dmessage / pci bandwidth 확인 등)   
    - efa hw counter 확인 ...
