FROM enmotech/opengauss:latest

RUN yum install -y gcc gcc-c++ make libxml2 || apt-get update && apt-get install -y gcc g++ make libxml2

COPY . /app
WORKDIR /app

RUN mkdir -p /usr/local/opengauss/include/postgresql/server/storage/file && \
    cp fio_device_com.h /usr/local/opengauss/include/postgresql/server/storage/file/ && \
    make -f Makefile.docker && \
    make -f Makefile.docker install DOCKER_BUILD=1 && \
    cp /usr/local/opengauss/lib/postgresql/sm4.so /usr/local/opengauss/lib/postgresql/proc_srclib/sm4 && \
    chown omm:omm /usr/local/opengauss/lib/postgresql/proc_srclib/sm4

COPY docker-entrypoint-wrapper.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint-wrapper.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint-wrapper.sh"]
CMD ["gaussdb"]