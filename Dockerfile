# Dockerfile for OpenGauss with SM4 Extension
# 使用 enmotech/opengauss 镜像（带自动初始化功能）

FROM enmotech/opengauss:latest

USER root

# 尝试安装编译工具（如果失败则跳过）
RUN yum install -y gcc gcc-c++ make 2>/dev/null || echo "Build tools may already be installed or unavailable"

# 创建必要的目录
RUN mkdir -p /opt/sm4_extension && \
    mkdir -p /usr/local/opengauss/lib/postgresql && \
    mkdir -p /usr/local/opengauss/share/postgresql/extension

# 复制SM4扩展源码
COPY sm4.h /opt/sm4_extension/
COPY sm4.c /opt/sm4_extension/
COPY sm4_ext.c /opt/sm4_extension/
COPY sm4.control /opt/sm4_extension/
COPY sm4--1.0.sql /opt/sm4_extension/
COPY Makefile.docker /opt/sm4_extension/Makefile
COPY build-sm4.sh /opt/sm4_extension/

# 赋予脚本执行权限
RUN chmod +x /opt/sm4_extension/build-sm4.sh

# 设置工作目录
WORKDIR /opt/sm4_extension

# 尝试编译安装SM4扩展（如果编译失败，将在容器启动时处理）
RUN export OGHOME=/usr/local/opengauss && \
    export PATH=$OGHOME/bin:$PATH && \
    export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH && \
    (make clean && make && make install) || \
    (echo "Compilation failed in build stage, will retry at runtime" && \
     cp sm4.control /usr/local/opengauss/share/postgresql/extension/ && \
     cp sm4--1.0.sql /usr/local/opengauss/share/postgresql/extension/)

# 复制测试脚本
COPY test_sm4.sql /opt/
COPY test_sm4_gcm.sql /opt/
COPY demo_citizen_data.sql /opt/

# 复制初始化脚本
COPY init-and-start.sh /usr/local/bin/
COPY docker-entrypoint-wrapper.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-and-start.sh && \
    chmod +x /usr/local/bin/docker-entrypoint-wrapper.sh

# 暴露数据库端口
EXPOSE 5432

# 使用我们的包装脚本作为入口点
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-wrapper.sh"]
