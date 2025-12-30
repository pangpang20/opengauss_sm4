#!/bin/bash
# OpenGauss 初始化和启动脚本

set -e

echo "======================================"
echo "OpenGauss SM4 初始化脚本"
echo "======================================"

# 设置环境变量
export GAUSSHOME=/usr/local/opengauss
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH

# 配置参数
GS_PASSWORD=${GS_PASSWORD:-Enmo@123}
GS_NODENAME=${GS_NODENAME:-opengauss_sm4}
DATA_DIR=/var/lib/opengauss/data

echo "节点名称: $GS_NODENAME"
echo "数据目录: $DATA_DIR"
echo ""

# 确保以 omm 用户身份运行
if [ "$(whoami)" != "omm" ]; then
    echo "错误: 必须以 omm 用户身份运行此脚本"
    echo "提示: 使用 su - omm 切换用户"
    exit 1
fi

# 检查数据库是否已初始化
if [ ! -f "$DATA_DIR/postgresql.conf" ]; then
    echo "======================================"
    echo "初始化数据库..."
    echo "======================================"
    
    # 初始化数据库
    gs_initdb -D $DATA_DIR --nodename=$GS_NODENAME -w $GS_PASSWORD
    
    echo ""
    echo "数据库初始化完成!"
    echo ""
    
    # 配置允许远程连接
    echo "配置远程连接..."
    gs_guc set -D $DATA_DIR -c "listen_addresses='*'"
    gs_guc set -D $DATA_DIR -h "host all all 0.0.0.0/0 md5"
    echo "配置完成!"
    echo ""
else
    echo "数据库已存在，跳过初始化"
    echo ""
fi

# 启动数据库
echo "======================================"
echo "启动 OpenGauss 数据库..."
echo "======================================"

exec gaussdb -D $DATA_DIR
