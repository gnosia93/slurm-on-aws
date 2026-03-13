
### Enroot/Pyxis 설치 ###
slurm 클러스터 생성시 [enroot.sh post-nstall](https://github.com/gnosia93/slurm-on-aws/blob/main/setup/script/enroot.sh) 스크립트가 실행되어 자동으로 설치된다. 

#### [Enroot](https://github.com/NVIDIA/enroot) ####
컨테이너는 일반적으로 실행 시 sudo 권한이 필요하다. 하지만 SLURM 클러스터는 POSIX 파일 권한 기반의 다중 사용자 환경이기 때문에, 일반 사용자에게 sudo를 부여하는 것은 보안상 문제가 된다. 이를 해결하기 위해 NVIDIA는 enroot를 만들었고, 이는 리눅스 커널의 chroot 기능을 활용하여 컨테이너를 위한 격리된 런타임 환경을 제공해 준다. 예를 들어 /tmp/container라는 마운트 포인트를 만들어 컨테이너가 자신의 로컬 디렉토리만 볼 수 있게 함으로써, 호스트 OS와 컨테이너의 런타임을 분리한다. 이를 통해 sudo 권한이 필요한 Docker 대신, enroot를 활용해서 루트 권한 없이도 컨테이너를 실행할 수 있다.

도커 허브로 부터 아마존 리눅스 도커 이미지를 다운로드 받아서 SquashFS 포캣의 압축 파일로 패킹징한 후 컨테이너를 실행한다. 
```
enroot import docker://amazonlinux:latest
enroot create amazonlinux+latest.sqsh
enroot start amazonlinux+latest
```

#### [Pyxis](https://github.com/NVIDIA/pyxis) ####
SLURM은 OCI 컨테이너를 지원하긴 하지만, 사용자가 직접 컨테이너 이미지를 다운로드하고 OCI 런타임 형식으로 변환한 뒤 SLURM에 경로를 지정해야 하는 번거로운 과정이 필요하다. NVIDIA는 이를 해결하기 위해 Pyxis라는 SLURM 플러그인을 만들었다. Pyxis를 사용하면 srun --container-image=amazonlinux/latest처럼 컨테이너 URI만 지정하면 이미지 다운로드부터 실행까지 자동으로 처리된다.
즉, enroot가 컨테이너 런타임이라면, Pyxis는 SLURM에서 enroot를 편하게 쓸 수 있게 해주는 플러그인이다.
```
#SBATCH --container-image nvcr.io\#nvidia/pytorch:21.12-py3

python -c 'import torch ; print(torch.__version__)'
```



### slurm 에서 컨테이너 실행 ###
```
srun --container-image=nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi
```
또는 
```
#!/bin/bash
#SBATCH --container-image=nvidia/cuda:11.6.2-base-ubuntu20.04

nvidia-smi
```

## 레퍼런스 ##
* https://slurm.schedmd.com/containers.html
