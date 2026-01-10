#!/bin/bash
set -e

export GAUSSHOME=/usr/local/opengauss
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH

if [ -f /var/lib/opengauss/data/postgresql.conf ]; then
    if ! grep -q "openGauss.enable_sm4" /var/lib/opengauss/data/postgresql.conf; then
        echo "openGauss.enable_sm4 = on" >> /var/lib/opengauss/data/postgresql.conf
    fi
fi

exec /entrypoint.sh "$@"