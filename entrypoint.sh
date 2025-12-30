#!/bin/bash
# OpenGauss with SM4 Extension Entrypoint Script

set -e

# 设置环境变量
export OGHOME=/usr/local/opengauss
export PATH=$OGHOME/bin:$PATH
export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH

# 编译 SM4 扩展（如果还没编译）
if [ ! -f "$OGHOME/lib/postgresql/sm4.so" ]; then
    echo "======================================"
    echo "编译 SM4 扩展..."
    echo "======================================"
    
    cd /opt/sm4_extension
    
    # 以 root 身份编译
    if [ "$(id -u)" != "0" ]; then
        echo "需要 root 权限编译扩展"
        exit 1
    fi
    
    make clean || true
    make || {
        echo "编译失败，尝试使用简化的头文件包含路径..."
        # 如果失败，尝试修改 Makefile
        exit 1
    }
    make install
    
    echo "======================================"
    echo "SM4 扩展编译完成！"
    echo "======================================"
else
    echo "SM4 扩展已存在，跳过编译"
fi

# 切换到 omm 用户并启动数据库
su - omm -c "gaussdb -D /var/lib/opengauss/data"
