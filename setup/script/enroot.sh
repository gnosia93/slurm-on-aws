#!/bin/bash
set -exo pipefail

OS=$(. /etc/os-release; echo $NAME)

##############################
# enroot 설치
##############################
ENROOT_VERSION=4.1.1

if [ "${OS}" = "Amazon Linux" ]; then
    arch=$(uname -m)
    dnf install -y epel-release || true
    dnf install -y \
        https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot-${ENROOT_VERSION}-1.el8.${arch}.rpm \
        https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot+caps-${ENROOT_VERSION}-1.el8.${arch}.rpm
elif [ "${OS}" = "Ubuntu" ]; then
    arch=$(dpkg --print-architecture)
    cd /tmp
    curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot_${ENROOT_VERSION}-1_${arch}.deb
    curl -fSsL -O https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot+caps_${ENROOT_VERSION}-1_${arch}.deb
    apt install -y ./enroot_${ENROOT_VERSION}-1_${arch}.deb ./enroot+caps_${ENROOT_VERSION}-1_${arch}.deb
    rm -f /tmp/enroot*.deb
else
    echo "Unsupported OS: ${OS}" && exit 1
fi

##############################
# enroot 설정
##############################
cat > /etc/enroot/enroot.conf << 'EOF'
ENROOT_RUNTIME_PATH /tmp/enroot/user-$(id -u)
ENROOT_CACHE_PATH /tmp/enroot/cache
ENROOT_DATA_PATH /tmp/enroot/data
ENROOT_TEMP_PATH /tmp
EOF

##############################
# pyxis 빌드 및 설치
##############################
PYXIS_VERSION=0.21.0

if [ "${OS}" = "Amazon Linux" ]; then
    dnf install -y make gcc
elif [ "${OS}" = "Ubuntu" ]; then
    apt-get install -y make gcc
fi

cd /tmp
curl -fSsL -o pyxis.tar.gz \
    https://github.com/NVIDIA/pyxis/archive/refs/tags/v${PYXIS_VERSION}.tar.gz
tar xzf pyxis.tar.gz
cd pyxis-${PYXIS_VERSION}
CPPFLAGS='-I /opt/slurm/include/' make
CPPFLAGS='-I /opt/slurm/include/' make install prefix=/opt/slurm
cp /usr/local/lib/slurm/spank_pyxis.so /opt/slurm/lib/slurm/

##############################
# plugstack 설정
##############################
mkdir -p /opt/slurm/etc/plugstack.conf.d
echo "include /opt/slurm/etc/plugstack.conf.d/*" > /opt/slurm/etc/plugstack.conf
echo "required /opt/slurm/lib/slurm/spank_pyxis.so" > /opt/slurm/etc/plugstack.conf.d/pyxis.conf

rm -rf /tmp/pyxis*

##############################
# slurmd 재시작
##############################
if systemctl is-active slurmctld &>/dev/null; then
    systemctl restart slurmctld
else
    systemctl restart slurmd
fi
