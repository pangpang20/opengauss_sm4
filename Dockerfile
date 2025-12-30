# Dockerfile for OpenGauss with SM4 Extension
# 使用官方 OpenGauss 镜像并在运行时安装 SM4 扩展

FROM enmotech/opengauss:latest

USER root

# 安装编译工具（根据镜像的包管理器选择）
RUN if command -v apt-get &> /dev/null; then \
        apt-get update && apt-get install -y gcc g++ make || echo "Build tools installation failed"; \
    elif command -v yum &> /dev/null; then \
        yum install -y gcc gcc-c++ make || echo "Build tools installation failed"; \
    fi

# 创建必要的目录
RUN mkdir -p /opt/sm4_extension

# 复制SM4扩展源码
COPY sm4.h /opt/sm4_extension/
COPY sm4.c /opt/sm4_extension/
COPY sm4_ext.c /opt/sm4_extension/
COPY sm4.control /opt/sm4_extension/
COPY sm4--1.0.sql /opt/sm4_extension/
COPY Makefile.docker /opt/sm4_extension/Makefile

# 设置工作目录
WORKDIR /opt/sm4_extension

# 在构建时尝试编译（如果失败也不影响镜像构建）
RUN export OGHOME=/usr/local/opengauss && \
    export PATH=$OGHOME/bin:$PATH && \
    export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH && \
    echo "尝试编译 SM4 扩展..." && \
    (make clean && make && make install && echo "✓ SM4 扩展编译成功") || \
    (echo "⚠ 编译失败，SM4 扩展将在数据库启动后手动安装" && \
     mkdir -p $OGHOME/share/postgresql/extension && \
     cp sm4.control $OGHOME/share/postgresql/extension/ && \
     cp sm4--1.0.sql $OGHOME/share/postgresql/extension/)

# 复制测试脚本和检查脚本
COPY test_sm4.sql /opt/
COPY test_sm4_gcm.sql /opt/
COPY demo_citizen_data.sql /opt/
COPY install-sm4.sh /opt/sm4_extension/
COPY check-and-install.sh /opt/sm4_extension/
RUN chmod +x /opt/sm4_extension/install-sm4.sh && \
    chmod +x /opt/sm4_extension/check-and-install.sh

# 暴露数据库端口
EXPOSE 5432

# 使用镜像默认的启动方式
