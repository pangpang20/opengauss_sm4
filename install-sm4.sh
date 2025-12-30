#!/bin/bash
# SM4 扩展安装脚本（在 OpenGauss 容器启动后运行）

set -e

echo "======================================"
echo "安装 SM4 加密扩展到 OpenGauss"
echo "======================================"

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
    echo ""
    echo "错误: 此脚本需要 root 权限来安装编译工具"
    echo "请使用以下命令运行:"
    echo "  docker exec -it opengauss_sm4 bash -c 'cd /opt/sm4_extension && bash install-sm4.sh'"
    echo ""
    exit 1
fi

# 检查并安装编译工具
echo ""
echo "0. 检查编译工具..."
if ! command -v make &> /dev/null || ! command -v g++ &> /dev/null; then
    echo "   编译工具未安装，正在安装 gcc、g++、make..."
    yum install -y gcc gcc-c++ make || {
        echo "   警告: yum 安装失败，尝试继续..."
    }
else
    echo "   ✓ 编译工具已安装"
fi

# 设置环境变量
export OGHOME=/usr/local/opengauss
export PATH=$OGHOME/bin:$PATH
export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH

# 进入源码目录
cd /opt/sm4_extension

echo ""
echo "1. 清理旧文件..."
make clean || true

echo ""
echo "2. 编译 SM4 扩展..."
make

echo ""
echo "3. 安装 SM4 扩展..."
make install

echo ""
echo "4. 验证安装..."
ls -lh $OGHOME/lib/postgresql/sm4.so
ls -lh $OGHOME/share/postgresql/extension/sm4*

echo ""
echo "======================================"
echo "✓ SM4 扩展安装完成!"
echo "======================================"
echo ""
echo "下一步操作:"
echo ""
echo "5. 创建 SM4 函数:"
echo "   gsql -d postgres -p 5432 -c \"\\\\i /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql\""
echo ""
echo "6. 测试 SM4 加密:"
echo "   gsql -d postgres -p 5432 -c \"SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');\""
echo ""
