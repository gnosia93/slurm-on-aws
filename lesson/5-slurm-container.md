
### enroot ###
컨테이너는 일반적으로 실행 시 sudo 권한이 필요하다. 하지만 SLURM 클러스터는 POSIX 파일 권한 기반의 다중 사용자 환경이기 때문에, 일반 사용자에게 sudo를 부여하는 것은 보안상 문제가 된다. 이를 해결하기 위해 NVIDIA는 enroot를 만들었고, 이는 리눅스 커널의 chroot 기능을 활용하여 컨테이너를 위한 격리된 런타임 환경을 제공해 준다. 예를 들어 /tmp/container라는 마운트 포인트를 만들어 컨테이너가 자신의 로컬 디렉토리만 볼 수 있게 함으로써, 호스트 OS와 컨테이너의 런타임을 분리한다. 이를 통해 sudo 권한이 필요한 Docker 대신, enroot를 활용해서 루트 권한 없이도 컨테이너를 실행할 수 있다.

도커 허브로 부터 아마존 리눅스 도커 이미지를 다운로드 받아서 SquashFS 포캣의 압축 파일로 패킹징한 후 컨테이너를 실행한다. 
```
enroot import docker://amazonlinux:latest
enroot create amazonlinux+latest.sqsh
enroot start amazonlinux+latest
```
