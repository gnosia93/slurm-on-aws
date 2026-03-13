echo "
###################################
# BEGIN: post-install enroot/pyxis
###################################
"

# enroot 설치
ENROOT_VERSION=3.5.0
curl -fSsL -o /tmp/enroot_${ENROOT_VERSION}-1_amd64.deb \
    https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot_${ENROOT_VERSION}-1_amd64.deb
curl -fSsL -o /tmp/enroot+caps_${ENROOT_VERSION}-1_amd64.deb \
    https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot+caps_${ENROOT_VERSION}-1_amd64.deb
apt-get install -y /tmp/enroot_${ENROOT_VERSION}-1_amd64.deb /tmp/enroot+caps_${ENROOT_VERSION}-1_amd64.deb
rm -f /tmp/enroot*.deb

# pyxis 설치
PYXIS_VERSION=0.20.0
mkdir -p /tmp/pyxis && cd /tmp/pyxis
curl -fSsL -o pyxis.tar.gz \
    https://github.com/NVIDIA/pyxis/archive/refs/tags/v${PYXIS_VERSION}.tar.gz
tar xzf pyxis.tar.gz
cd pyxis-${PYXIS_VERSION}
SLURM_DIR=/opt/slurm make install
echo "required /usr/local/lib/slurm/spank_pyxis.so" > /opt/slurm/etc/plugstack.conf

echo "
###################################
# END: post-install enroot/pyxis
###################################
"
