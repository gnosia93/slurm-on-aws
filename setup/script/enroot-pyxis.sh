echo "
###################################
# BEGIN: post-install enroot/pyxis
###################################
"

# https://github.com/NVIDIA/enroot
ENROOT_VERSION=4.1.1
OS=$(. /etc/os-release; echo $NAME)

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
    rm -f enroot*.deb
else
    echo "Unsupported OS: ${OS}" && exit 1
fi

# https://github.com/NVIDIA/pyxis
PYXIS_VERSION=0.21.0
OS=$(. /etc/os-release; echo $NAME)

cd /tmp
curl -fSsL -o pyxis.tar.gz \
    https://github.com/NVIDIA/pyxis/archive/refs/tags/v${PYXIS_VERSION}.tar.gz
tar xzf pyxis.tar.gz
cd pyxis-${PYXIS_VERSION}

if [ "${OS}" = "Amazon Linux" ]; then
    make install
    mkdir -p /opt/slurm/etc/plugstack.conf.d
    ln -sf /usr/local/share/pyxis/pyxis.conf /opt/slurm/etc/plugstack.conf.d/pyxis.conf
elif [ "${OS}" = "Ubuntu" ]; then
    apt-get install -y make gcc libslurm-dev
    make orig
    make deb
    dpkg -i ../nvslurm-plugin-pyxis_*_amd64.deb
    mkdir -p /opt/slurm/etc/plugstack.conf.d
    ln -sf /usr/share/pyxis/pyxis.conf /opt/slurm/etc/plugstack.conf.d/pyxis.conf
else
    echo "Unsupported OS: ${OS}" && exit 1
fi

rm -rf /tmp/pyxis*
systemctl restart slurmd

echo "
###################################
# END: post-install enroot/pyxis
###################################
"
