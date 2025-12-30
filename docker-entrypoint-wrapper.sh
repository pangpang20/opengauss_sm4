#!/bin/bash
# OpenGauss 容器启动包装脚本（以 root 运行）

set -e

echo "##########################################"
echo "# WRAPPER SCRIPT STARTED"
echo "# Running as: $(whoami)"
echo "# PWD: $(pwd)"
echo "##########################################"

# 设置环境变量
export GAUSSHOME=/usr/local/opengauss
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH

echo "Environment variables set:"
echo "GS_PASSWORD: ${GS_PASSWORD:-Enmo@123}"
echo "GS_NODENAME: ${GS_NODENAME:-opengauss_sm4}"
echo ""

# 确保数据目录存在并设置权限
echo "Creating data directory and setting permissions..."
mkdir -p /var/lib/opengauss/data
chown -R omm:omm /var/lib/opengauss
echo "Done!"
echo ""

# 传递环境变量并以 omm 用户运行初始化脚本
echo "Switching to omm user and running init script..."
exec su - omm -c "
export GS_PASSWORD='${GS_PASSWORD:-Enmo@123}'
export GS_NODENAME='${GS_NODENAME:-opengauss_sm4}'
export GAUSSHOME=/usr/local/opengauss
export PATH=\$GAUSSHOME/bin:\$PATH
export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
/usr/local/bin/init-and-start.sh
"
