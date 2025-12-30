# Dockerfile for OpenGauss with SM4 Extension
# 使用 opengauss-server 镜像（更完整的开发环境）

FROM opengauss/opengauss-server:latest

USER root

# 安装编译工具
RUN yum install -y gcc gcc-c++ make && \
    yum clean all

# 创建扩展目录
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

# 编译安装SM4扩展
RUN export OGHOME=/usr/local/opengauss && \
    export PATH=$OGHOME/bin:$PATH && \
    export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH && \
    make clean && \
    make && \
    make install

# 复制测试脚本
COPY test_sm4.sql /opt/
COPY test_sm4_gcm.sql /opt/
COPY demo_citizen_data.sql /opt/

# 切换回omm用户
USER omm

# 暴露数据库端口
EXPOSE 5432

# 启动数据库
CMD ["gaussdb", "-D", "/var/lib/opengauss/data"]
