
---
cgroup(Control Groups)은 Linux 커널이 프로세스 그룹별로 시스템 리소스를 제한/격리하는 기능입니다.

제어 가능한 리소스:

CPU: 사용량 제한, 특정 코어에 바인딩
메모리: 최대 사용량 제한
디스크 I/O: 읽기/쓰기 대역폭 제한
네트워크: 대역폭 제한
Docker 컨테이너가 대표적인 cgroup 활용 사례입니다:

# Docker에서 메모리 2GB, CPU 2코어 제한
docker run --memory=2g --cpus=2 nginx
이게 내부적으로 cgroup을 통해 제한되는 겁니다. SLURM도 cgroup을 사용해서 잡별로 리소스를 격리합니다.

Credits used: 0.31
Elapsed time: 9s



Linux Namespace는 프로세스가 볼 수 있는 시스템 리소스의 범위를 격리하는 커널 기능입니다.

종류:

PID: 프로세스 ID 격리 (컨테이너 안에서 PID 1부터 시작)
Network: 네트워크 인터페이스, IP, 포트 격리
Mount: 파일시스템 마운트 포인트 격리
UTS: 호스트명 격리
User: UID/GID 격리
IPC: 프로세스 간 통신 격리
cgroup과의 차이:

cgroup = 리소스 "얼마나" 쓸 수 있는지 제한
namespace = 리소스 "무엇을" 볼 수 있는지 격리
Docker 컨테이너 = namespace(격리) + cgroup(제한)으로 만들어진 겁니다.
