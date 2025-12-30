#!/bin/bash
# 检查并安装 SM4 扩展

set -e

export OGHOME=/usr/local/opengauss
export PATH=$OGHOME/bin:$PATH
export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH

echo "======================================"
echo "检查 SM4 扩展状态"
echo "======================================"
echo ""

# 检查 .so 文件
if [ -f "$OGHOME/lib/postgresql/sm4.so" ]; then
    echo "✓ SM4 动态库已存在"
    ls -lh $OGHOME/lib/postgresql/sm4.so
else
    echo "✗ SM4 动态库不存在"
    echo ""
    echo "由于 OpenGauss 镜像缺少完整的开发头文件，无法编译扩展。"
    echo "请使用以下方案之一："
    echo ""
    echo "方案1: 在有完整 OpenGauss 开发环境的机器上编译 sm4.so"
    echo "  1. 编译: make clean && make"
    echo "  2. 复制 sm4.so 到容器: docker cp sm4.so opengauss_sm4:/usr/local/opengauss/lib/postgresql/"
    echo ""
    echo "方案2: 使用包含开发工具的 OpenGauss 镜像"
    echo "  切换到 opengauss/opengauss-server 镜像（但需要手动初始化数据库）"
    echo ""
    exit 1
fi

# 检查 SQL 文件
if [ -f "$OGHOME/share/postgresql/extension/sm4--1.0.sql" ]; then
    echo "✓ SM4 SQL 定义已存在"
    echo ""
    echo "======================================"
    echo "准备创建 SM4 函数"
    echo "======================================"
    echo ""
    echo "运行以下命令创建函数:"
    echo "  gsql -d postgres -p 5432 -c \"\\i $OGHOME/share/postgresql/extension/sm4--1.0.sql\""
    echo ""
    echo "然后测试:"
    echo "  gsql -d postgres -p 5432 -c \"SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');\""
else
    echo "✗ SM4 SQL 定义不存在"
    exit 1
fi
