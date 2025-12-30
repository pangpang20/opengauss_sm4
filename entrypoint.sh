#!/bin/bash
# OpenGauss with SM4 Extension Entrypoint Script

set -e

echo "======================================"
echo "OpenGauss SM4 Extension Startup"
echo "======================================"

# 设置环境变量
export GAUSSHOME=/usr/local/opengauss
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH

# 获取配置
GS_PASSWORD=${GS_PASSWORD:-Enmo@123}
GS_NODENAME=${GS_NODENAME:-opengauss_sm4}
DATA_DIR=/var/lib/opengauss/data

echo "节点名称: $GS_NODENAME"
echo "数据目录: $DATA_DIR"

# 确保数据目录存在并设置权限
mkdir -p $DATA_DIR
chown -R omm:omm /var/lib/opengauss

# 检查数据库是否已初始化
if [ ! -f "$DATA_DIR/postgresql.conf" ]; then
    echo ""
    echo "====================================="
    echo "正在初始化数据库..."
    echo "====================================="
    
    # 以 omm 用户身份初始化数据库
    su - omm << EOF
export GAUSSHOME=/usr/local/opengauss
export PATH=\$GAUSSHOME/bin:\$PATH
export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH

gs_initdb -D $DATA_DIR --nodename=$GS_NODENAME -w $GS_PASSWORD
EOF

    echo ""
    echo "数据库初始化完成!"
    
    # 配置允许远程连接
    echo ""
    echo "配置远程连接..."
    su - omm << EOF
export GAUSSHOME=/usr/local/opengauss
export PATH=\$GAUSSHOME/bin:\$PATH
export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH

gs_guc set -D $DATA_DIR -c "listen_addresses='*'"
gs_guc set -D $DATA_DIR -h "host all all 0.0.0.0/0 md5"
EOF
    
    echo "配置完成!"
else
    echo ""
    echo "数据库已存在，跳过初始化"
fi

# 启动数据库
echo ""
echo "====================================="
echo "启动OpenGauss数据库..."
echo "====================================="

exec su - omm << EOF
export GAUSSHOME=/usr/local/opengauss
export PATH=\$GAUSSHOME/bin:\$PATH
export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH

gaussdb -D $DATA_DIR
EOF
