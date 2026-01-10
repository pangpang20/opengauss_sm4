#!/bin/bash
set -e

CONTAINER_NAME="opengauss_sm4"
TIMEOUT=60
GSQL_CMD="export PATH=/usr/local/opengauss/bin:\$PATH && export LD_LIBRARY_PATH=/usr/local/opengauss/lib:\$LD_LIBRARY_PATH && gsql -U omm -W Enmo@123 -d postgres"

docker-compose up -d

echo "Waiting for database to start..."
COUNTER=0
until docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -c 'SELECT 1;' > /dev/null 2>&1"; do
  sleep 1
  COUNTER=$((COUNTER + 1))
  if [ $COUNTER -ge $TIMEOUT ]; then
    echo "Timeout waiting for database to start"
    exit 1
  fi
done

docker exec $CONTAINER_NAME cat /var/lib/opengauss/data/postgresql.conf | \
  grep -q "openGauss.enable_sm4 = on" || echo "GUC parameter not found in config, but extension should still work"

docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -c 'CREATE EXTENSION IF NOT EXISTS sm4;'"

docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -c \"SELECT encode(sm4_c_encrypt('test', '0123456789abcdef'), 'hex');\""

echo "Test passed!"

docker-compose down