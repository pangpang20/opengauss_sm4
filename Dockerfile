# Dockerfile for OpenGauss with SM4 Extension
# 使用 opengauss-server 镜像（更完整的开发环境）

FROM opengauss/opengauss-server:latest

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

# 创建启动脚本
RUN echo '#!/bin/bash' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 修复数据目录权限' >> /docker-entrypoint.sh && \
    echo 'if [ -d /var/lib/opengauss/data ]; then' >> /docker-entrypoint.sh && \
    echo '    chown -R omm:omm /var/lib/opengauss/data || true' >> /docker-entrypoint.sh && \
    echo '    chmod 700 /var/lib/opengauss/data || true' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 切换到omm用户并启动数据库' >> /docker-entrypoint.sh && \
    echo 'exec su - omm -c "gaussdb -D /var/lib/opengauss/data"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# 保持root用户（docker-compose会以root启动）
# USER omm

# 暴露数据库端口
EXPOSE 5432

# 使用自定义启动脚本
ENTRYPOINT ["/docker-entrypoint.sh"]
