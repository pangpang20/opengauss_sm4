#!/bin/bash
# SM4 Extension Build Script
# 在容器运行时编译（如果构建阶段失败）

set -e

export OGHOME=/usr/local/opengauss
export PATH=$OGHOME/bin:$PATH
export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH

echo "======================================"
echo "检查 SM4 扩展状态..."
echo "======================================"

# 检查 .so 文件是否存在
if [ ! -f "$OGHOME/lib/postgresql/sm4.so" ]; then
    echo "SM4 扩展未编译，开始编译..."
    
    cd /opt/sm4_extension
    
    # 检查编译工具
    if ! command -v gcc &> /dev/null; then
        echo "错误: gcc 未安装"
        exit 1
    fi
    
    if ! command -v g++ &> /dev/null; then
        echo "错误: g++ 未安装"
        exit 1
    fi
    
    # 编译
    echo "清理旧文件..."
    make clean || true
    
    echo "编译 SM4 扩展..."
    make
    
    echo "安装 SM4 扩展..."
    make install
    
    echo "======================================"
    echo "✓ SM4 扩展编译安装完成！"
    echo "======================================"
else
    echo "✓ SM4 扩展已存在，无需重新编译"
fi

# 验证文件
echo ""
echo "文件检查:"
echo "- sm4.so: $(ls -lh $OGHOME/lib/postgresql/sm4.so 2>/dev/null || echo '未找到')"
echo "- sm4.control: $(ls -lh $OGHOME/share/postgresql/extension/sm4.control 2>/dev/null || echo '未找到')"
echo "- sm4--1.0.sql: $(ls -lh $OGHOME/share/postgresql/extension/sm4--1.0.sql 2>/dev/null || echo '未找到')"
