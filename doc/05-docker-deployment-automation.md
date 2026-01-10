# 第5篇:Docker 化部署与自动化测试

## 课程目标

这篇教程学习如何用Docker 和 Docker Compose 实现SM4 扩展的容器化部署，编写自动化测试脚本，构建可重复、可移植的开发和生产环境。

## 为什么需要 Docker 化？

### 传统部署的痛点

1. 环境不一致:"在我机器上能跑"
2. 依赖复杂:需要手动安装编译工具、库文件
3. 难以复现:从源码到运行需要多个手动步骤
4. 测试困难:每次测试需要重新配置环境

### Docker 化的优势

• 环境隔离:容器内环境与宿主机隔离  
• 一致性:开发、测试、生产环境完全一致  
• 可移植性:一次构建，到处运行 
• 快速部署:秒级启动，自动化构建  
• 易于测试:可快速创建和销毁测试环境  

## 项目 Docker 架构

```
┌─────────────────────────────────────────┐
│         Docker Compose                  │
│  ┌───────────────────────────────────┐  │
│  │    opengauss_sm4 容器             │  │
│  │                                   │  │
│  │  ┌────────────────────────────┐   │  │
│  │  │   OpenGauss 6.0.3          │   │  │
│  │  │   + SM4 Extension          │   │  │
│  │  └────────────────────────────┘   │  │
│  │                                   │  │
│  │  端口: 5432 → 15432               │  │
│  │  卷: test_sm4.sql                │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## 写Dockerfile

### 多阶段构建 Dockerfile

创建`Dockerfile`:

```dockerfile
# 用OpenGauss 6.0.3 作为基础镜像
FROM enmotech/opengauss:6.0.3

# 安装编译工具和依赖
RUN yum install -y gcc gcc-c++ make libxml2 || \
    apt-get update && apt-get install -y gcc g++ make libxml2

# 复制源代码到容器
COPY . /app
WORKDIR /app

# 编译和安装 SM4 扩展
RUN mkdir -p /usr/local/opengauss/include/postgresql/server/storage/file && \
    cp fio_device_com.h /usr/local/opengauss/include/postgresql/server/storage/file/ && \
    make -f Makefile.docker && \
    make -f Makefile.docker install DOCKER_BUILD=1 && \
    cp /usr/local/opengauss/lib/postgresql/sm4.so /usr/local/opengauss/lib/postgresql/proc_srclib/sm4 && \
    chown omm:omm /usr/local/opengauss/lib/postgresql/proc_srclib/sm4

# 复制自定义入口脚本
COPY docker-entrypoint-wrapper.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint-wrapper.sh

# 设置入口点
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-wrapper.sh"]
CMD ["gaussdb"]
```

关键点:

1. 基础镜像:`FROM enmotech/opengauss:6.0.3`
   - 使用官方 OpenGauss 镜像作为基础

2. 安装依赖:`RUN yum install ...`
   - 安装编译所需的 gcc、make 等工具
   - 安装 libxml2（OpenGauss 运行时依赖）

3. 编译扩展:`RUN make ...`
   - 在容器内编译 SM4 扩展
   - 复制到正确的 `proc_srclib` 目录

4. 自定义入口点:`ENTRYPOINT`
   - 使用包装脚本添加自定义初始化逻辑

### 创建入口点包装脚本

创建`docker-entrypoint-wrapper.sh`:

```bash
#!/bin/bash
set -e

# 设置环境变量
export GAUSSHOME=/usr/local/opengauss
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH

# 数据库启动后添加 SM4 配置参数
if [ -f /var/lib/opengauss/data/postgresql.conf ]; then
    if ! grep -q "openGauss.enable_sm4" /var/lib/opengauss/data/postgresql.conf; then
        echo "openGauss.enable_sm4 = on" >> /var/lib/opengauss/data/postgresql.conf
    fi
fi

# 调用原始入口点
exec /entrypoint.sh "$@"
```

脚本功能:
- 设置 OpenGauss 环境变量
- 添加 SM4 相关配置参数（可选）
- 调用原始 OpenGauss 入口点脚本

赋予执行权限:
```bash
chmod +x docker-entrypoint-wrapper.sh
```

## 写Docker Compose 配置

### 创建docker-compose.yml

```yaml
services:
  opengauss_sm4:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: opengauss_sm4
    hostname: opengauss_sm4
    privileged: true
    environment:
      - GS_PASSWORD=Enmo@123
      - GS_USERNAME=gaussdb
    ports:
      - "15432:5432"  # 映射到主机 15432 端口
    volumes:
      - ./test_sm4.sql:/opt/test_sm4.sql
      - ./demo_data.sql:/opt/demo_data.sql
    networks:
      - opengauss_network
    healthcheck:
      test: ["CMD-SHELL", "gsql -d postgres -p 5432 -c 'SELECT 1' || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s
    restart: unless-stopped

networks:
  opengauss_network:
    driver: bridge
```

说明

1. build:构建配置
   - `context: .`:构建上下文为当前目录
   - `dockerfile: Dockerfile`:使用的 Dockerfile

2. environment:环境变量
   - `GS_PASSWORD`:数据库密码
   - `GS_USERNAME`:数据库用户名

3. ports:端口映射
   - `15432:5432`:避免与本地 PostgreSQL 冲突

4. volumes:卷挂载
   - 挂载测试 SQL 文件到容器

5. healthcheck:健康检查
   - 每 10 秒检查数据库是否就绪
   - 启动后等待 40 秒开始检查

6. restart:重启策略
   - `unless-stopped`:自动重启（除非手动停止）

## 构建和启动容器

### 1. 构建镜像

```bash
# 清理旧镜像（可选）
docker-compose down -v

# 构建镜像
docker-compose build

# 或者强制重新构建
docker-compose build --no-cache
```

输出:
```
Building opengauss_sm4
Step 1/10 : FROM enmotech/opengauss:6.0.3
Step 2/10 : RUN yum install -y gcc gcc-c++ make libxml2
...
Successfully built abc123def456
Successfully tagged opengauss_sm4:latest
```

### 2. 启动服务

```bash
# 启动服务（后台运行）
docker-compose up -d

# 查看日志
docker-compose logs -f

# 查看容器状态
docker-compose ps
```

输出:
```
NAME              IMAGE            COMMAND         STATUS         PORTS
opengauss_sm4     opengauss_sm4    "/usr/local/bin…"  Up 30 seconds  0.0.0.0:15432->5432/tcp
```

### 3. 等待数据库就绪

```bash
# 用healthcheck 等待
docker-compose ps

# 或手动等待
sleep 30
```

## 编写自动化测试脚本

### 创建测试脚本 test.sh

```bash
#!/bin/bash
set -e

CONTAINER_NAME="opengauss_sm4"
TIMEOUT=60
GSQL_CMD="export PATH=/usr/local/opengauss/bin:\$PATH && \
          export LD_LIBRARY_PATH=/usr/local/opengauss/lib:\$LD_LIBRARY_PATH && \
          gsql -U omm -W Enmo@123 -d postgres"

echo "  SM4 Extension Automated Test"

# 启动服务
echo ""
echo "[1/5] Starting Docker Compose services..."
docker-compose up -d

# 等待数据库启动
echo ""
echo "[2/5] Waiting for database to start..."
COUNTER=0
until docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -c 'SELECT 1;' > /dev/null 2>&1"; do
  sleep 1
  COUNTER=$((COUNTER + 1))
  if [ $COUNTER -ge $TIMEOUT ]; then
    echo "× Timeout waiting for database to start"
    docker-compose logs
    exit 1
  fi
  echo -n "."
done
echo ""
echo "√ Database is ready!"

# 创建扩展
echo ""
echo "[3/5] Creating SM4 extension..."
docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -c 'CREATE EXTENSION IF NOT EXISTS sm4;'"
echo "√ Extension created"

# 运行测试
echo ""
echo "[4/5] Running encryption tests..."

# 测试1:ECB 加密解密
echo "  Test 1: ECB encryption/decryption"
RESULT=$(docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -t -c \"SELECT encode(sm4_c_encrypt('test', '0123456789abcdef'), 'hex');\"" | tr -d ' \n')
EXPECTED="fa3a126741cc82e48a7482b42d0e43c5"
if [ "$RESULT" != "$EXPECTED" ]; then
  echo "  × Failed: Expected $EXPECTED, got $RESULT"
  exit 1
fi
echo "  √ ECB test passed"

# 测试2:十六进制加密解密
echo "  Test 2: Hex encryption/decryption"
ENCRYPTED=$(docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -t -c \"SELECT sm4_c_encrypt_hex('Hello SM4', '0123456789abcdef');\"" | tr -d ' \n')
DECRYPTED=$(docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -t -c \"SELECT sm4_c_decrypt_hex('$ENCRYPTED', '0123456789abcdef');\"" | tr -d ' \n')
if [ "$DECRYPTED" != "HelloSM4" ]; then
  echo "  × Failed: Decrypted text doesn't match"
  exit 1
fi
echo "  √ Hex test passed"

# 测试3:CBC 模式
echo "  Test 3: CBC mode encryption"
docker exec $CONTAINER_NAME bash -c "$GSQL_CMD -c \"SELECT sm4_c_encrypt_cbc('Confidential', '0123456789abcdef', '0123456789abcdef');\"" > /dev/null
echo "  √ CBC test passed"

echo ""
echo "[5/5] All tests passed! √"

# 清理
echo ""
echo "Cleaning up..."
docker-compose down

echo ""
echo "  Test Summary: SUCCESS"
```

赋予执行权限:
```bash
chmod +x test.sh
```

### 运行测试

```bash
./test.sh
```

输出:
```
  SM4 Extension Automated Test

[1/5] Starting Docker Compose services...
Creating network "opengauss_sm4_opengauss_network" ... done
Creating opengauss_sm4 ... done

[2/5] Waiting for database to start...
.........................
√ Database is ready!

[3/5] Creating SM4 extension...
CREATE EXTENSION
√ Extension created

[4/5] Running encryption tests...
  Test 1: ECB encryption/decryption
  √ ECB test passed
  Test 2: Hex encryption/decryption
  √ Hex test passed
  Test 3: CBC mode encryption
  √ CBC test passed

[5/5] All tests passed! √

Cleaning up...
Stopping opengauss_sm4 ... done
Removing opengauss_sm4 ... done
Removing network opengauss_sm4_opengauss_network

  Test Summary: SUCCESS
```

## 创建测试 SQL 文件

### 创建test_sm4.sql

```sql
-- test_sm4.sql
-- SM4 Extension Comprehensive Test Suite

\echo '  SM4 Extension Test Suite'

\echo ''
\echo 'Test 1: Extension Installation'
SELECT COUNT() = 1 AS extension_installed
FROM pg_extension
WHERE extname = 'sm4';

\echo ''
\echo 'Test 2: ECB Encryption (Hex)'
SELECT 
    sm4_c_encrypt_hex('Hello, World!', '0123456789abcdef') AS encrypted,
    sm4_c_decrypt_hex(
        sm4_c_encrypt_hex('Hello, World!', '0123456789abcdef'),
        '0123456789abcdef'
    ) = 'Hello, World!' AS decryption_ok;

\echo ''
\echo 'Test 3: ECB Encryption (Bytea)'
SELECT 
    encode(sm4_c_encrypt('test data', '0123456789abcdef'), 'hex') AS encrypted_hex,
    sm4_c_decrypt(sm4_c_encrypt('test data', '0123456789abcdef'), '0123456789abcdef') = 'test data' AS round_trip_ok;

\echo ''
\echo 'Test 4: CBC Mode'
SELECT 
    sm4_c_decrypt_cbc(
        sm4_c_encrypt_cbc('CBC mode test', '0123456789abcdef', 'abcdef0123456789'),
        '0123456789abcdef',
        'abcdef0123456789'
    ) = 'CBC mode test' AS cbc_ok;

\echo ''
\echo 'Test 5: Long Text Encryption'
WITH long_text AS (
    SELECT repeat('Long text encryption test. ', 10) AS plaintext
)
SELECT 
    length(plaintext) AS plaintext_length,
    length(sm4_c_encrypt_hex(plaintext, '0123456789abcdef')) AS encrypted_length,
    sm4_c_decrypt_hex(
        sm4_c_encrypt_hex(plaintext, '0123456789abcdef'),
        '0123456789abcdef'
    ) = plaintext AS encryption_ok
FROM long_text;

\echo ''
\echo 'Test 6: Performance Test (1000 iterations)'
\timing on
DO $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..1000 LOOP
        PERFORM sm4_c_encrypt_hex('performance test', '0123456789abcdef');
    END LOOP;
END $$;
\timing off

\echo ''
\echo '  All Tests Completed!'
```

### 运行测试 SQL

```bash
# 在容器内执行
docker exec opengauss_sm4 bash -c "gsql -U omm -W Enmo@123 -d postgres -f /opt/test_sm4.sql"
```

## 实际应用场景示例

### 创建演示数据库 demo_data.sql

```sql
-- demo_data.sql
-- 实际应用场景:加密存储敏感用户信息

\echo '  SM4 实战:加密用户敏感信息'

-- 创建用户表
CREATE TABLE IF NOT EXISTS secure_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email_encrypted BYTEA NOT NULL,
    phone_encrypted BYTEA,
    id_number_encrypted BYTEA,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

\echo ''
\echo '1. 插入加密数据...'

-- 插入测试数据（加密邮箱、手机、身份证号）
INSERT INTO secure_users (username, email_encrypted, phone_encrypted, id_number_encrypted)
VALUES 
    ('alice', 
     sm4_c_encrypt('alice@example.com', '0123456789abcdef'),
     sm4_c_encrypt('13800138000', '0123456789abcdef'),
     sm4_c_encrypt('110101199001011234', '0123456789abcdef')),
    ('bob',
     sm4_c_encrypt('bob@company.com', '0123456789abcdef'),
     sm4_c_encrypt('13900139000', '0123456789abcdef'),
     sm4_c_encrypt('110101199202022345', '0123456789abcdef')),
    ('charlie',
     sm4_c_encrypt('charlie@mail.com', '0123456789abcdef'),
     sm4_c_encrypt('13700137000', '0123456789abcdef'),
     sm4_c_encrypt('110101199503033456', '0123456789abcdef'));

\echo '√ 已插入 3 条加密记录'

\echo ''
\echo '2. 查看加密后的原始数据（不可读）...'
SELECT id, username, encode(email_encrypted, 'hex') AS encrypted_email_hex
FROM secure_users
LIMIT 2;

\echo ''
\echo '3. 解密查询（应用层可见明文）...'
SELECT 
    id,
    username,
    sm4_c_decrypt(email_encrypted, '0123456789abcdef') AS email,
    sm4_c_decrypt(phone_encrypted, '0123456789abcdef') AS phone,
    LEFT(sm4_c_decrypt(id_number_encrypted, '0123456789abcdef'), 6) || '' || 
        RIGHT(sm4_c_decrypt(id_number_encrypted, '0123456789abcdef'), 4) AS masked_id_number,
    created_at
FROM secure_users
ORDER BY id;

\echo ''
\echo '4. 创建解密视图（便于应用查询）...'
CREATE OR REPLACE VIEW user_info AS
SELECT 
    id,
    username,
    sm4_c_decrypt(email_encrypted, '0123456789abcdef') AS email,
    sm4_c_decrypt(phone_encrypted, '0123456789abcdef') AS phone,
    created_at
FROM secure_users;

\echo '√ 视图创建成功'

\echo ''
\echo '5. 通过视图查询（对应用透明）...'
SELECT  FROM user_info WHERE username = 'alice';

\echo ''
\echo '  演示完成！'
```

### 运行演示

```bash
docker exec opengauss_sm4 bash -c "gsql -U omm -W Enmo@123 -d postgres -f /opt/demo_data.sql"
```

## 持续集成（CI）配置

### GitHub Actions 示例

创建`.github/workflows/test.yml`:

```yaml
name: SM4 Extension Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Build Docker image
      run: docker-compose build
    
    - name: Run tests
      run: ./test.sh
    
    - name: Upload test results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: test-results/
```

## 常用 Docker 命令速查

### 容器管理

```bash
# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f opengauss_sm4

# 进入容器
docker exec -it opengauss_sm4 bash

# 连接数据库
docker exec -it opengauss_sm4 su - omm -c "gsql -d postgres"

# 停止服务
docker-compose stop

# 停止并删除容器
docker-compose down

# 停止并删除容器和卷
docker-compose down -v
```

### 镜像管理

```bash
# 构建镜像
docker-compose build

# 强制重新构建
docker-compose build --no-cache

# 查看镜像
docker images | grep opengauss

# 删除镜像
docker rmi opengauss_sm4
```

### 调试命令

```bash
# 查看容器状态
docker-compose ps

# 查看健康检查状态
docker inspect opengauss_sm4 | grep -A 10 Health

# 查看容器资源使用
docker stats opengauss_sm4

# 执行SQL 命令
docker exec opengauss_sm4 bash -c "gsql -U omm -W Enmo@123 -d postgres -c 'SELECT version();'"
```

## 练习

### 添加性能测试

修改 `test.sh`，添加性能测试模块，测量 10000 次加密的耗时。

### 多环境配置

创建`docker-compose.prod.yml`，配置生产环境（数据持久化、资源限制）。

```yaml
services:
  opengauss_sm4:
    extends:
      file: docker-compose.yml
      service: opengauss_sm4
    volumes:
      - opengauss_data:/var/lib/opengauss/data
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G

volumes:
  opengauss_data:
```

### 健康检查优化

优化 healthcheck 配置，添加 SM4 扩展加载检查。


- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [OpenGauss Docker Hub](https://hub.docker.com/r/enmotech/opengauss)
- 项目完整代码:`https://github.com/yourusername/opengauss_sm4`

---

## 附录:完整项目文件清单

```
opengauss_sm4/
├── README.md                      # 项目说明
├── Dockerfile                     # Docker 构建文件
├── docker-compose.yml             # Docker Compose 配置
├── docker-entrypoint-wrapper.sh   # 自定义入口脚本
├── test.sh                        # 自动化测试脚本
├── sm4.h                          # SM4 算法头文件
├── sm4.c                          # SM4 核心实现
├── sm4_ext.cpp                    # OpenGauss 扩展接口
├── sm4.control                    # 扩展元数据
├── sm4--1.0.sql                   # SQL 函数定义
├── Makefile                       # 本地编译配置
├── Makefile.docker                # Docker 编译配置
├── fio_device_com.h               # 依赖头文件
├── test_sm4.sql                   # 测试 SQL
├── demo_data.sql                  # 演示数据
└── doc/                           # 培训文档目录
    ├── 01-opengauss-docker-setup.md
    ├── 02-extension-development-basics.md
    ├── 03-sm4-algorithm-implementation.md
    ├── 04-extension-compilation-deployment.md
    └── 05-docker-deployment-automation.md
```

