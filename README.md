# SM4 Extension for OpenGauss

国密SM4分组密码算法扩展，基于GB/T 32907-2016标准实现。

## 快速开始

### 🐳 Docker 部署（推荐）

#### 1. 一键启动

```bash
# 停止并清理旧容器（如果存在）
docker compose down -v

# 拉取最新代码（可选）
git pull

# 构建镜像（不使用缓存，确保使用最新代码）
docker compose build --no-cache

# 启动容器
docker compose up -d

# 查看容器状态
docker ps

# 查看启动日志（等待数据库启动完成）
docker logs -f opengauss_sm4
# 看到 "server started" 后按 Ctrl+C 退出日志查看
```

#### 2. 安装 SM4 扩展

```bash
# 进入容器
docker exec -it opengauss_sm4 bash

# 在容器内运行安装脚本
cd /opt/sm4_extension
./install-sm4.sh

# 创建 SM4 函数
gsql -d postgres -p 5432 -W Enmo@123 -f /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql

# 测试 SM4 加密
gsql -d postgres -p 5432 -W Enmo@123 -c "SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');"

# 退出容器
exit
```

#### 3. 常用 Docker 命令

```bash
# 查看容器日志
docker logs -f opengauss_sm4

# 进入容器执行命令
docker exec -it opengauss_sm4 bash

# 连接数据库（从容器外）
docker exec -it opengauss_sm4 gsql -d postgres -p 5432

# 停止容器
docker compose stop

# 启动容器
docker compose start

# 完全清理（删除容器、网络、卷）
docker compose down -v
```

**详细说明**: 
- [快速开始指南](QUICKSTART.md)
- [Docker 完整部署文档](DOCKER_DEPLOY.md)

### 📦 传统部署

如果需要在现有 OpenGauss 实例上安装，请参考下面的编译安装章节。

## 文件结构

```text
├── sm4.h               # SM4算法头文件
├── sm4.c               # SM4算法实现
├── sm4_ext.c           # OpenGauss扩展接口
├── sm4.control         # 扩展控制文件
├── sm4--1.0.sql        # SQL函数定义
├── Makefile            # 编译配置
├── test_sm4.sql        # 测试脚本
├── test_sm4_gcm.sql    # GCM模式测试脚本
├── demo_citizen_data.sql # 示例数据
└── README.md           # 使用文档（包含GCM模式详细说明）
```

## 编译安装

```bash
# 进入代码目录(根据实际调整用户和目录)
# 把opengauss_sm4上传到OpenGauss数据库服务器，并授权所有者为数据库用户

su - omm
cd /path/to/sm4_c

# 设置环境变量
export OGHOME=/usr/local/opengauss # 根据实际调整
export PATH=$OGHOME/bin:$PATH
export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH

# 编译
make clean
make

# 安装
make install

# 重启数据库加载新扩展
gs_ctl restart
```

## 启用扩展

OpenGauss支持CREATE EXTENSION语法，但建议直接执行SQL创建函数。

**注意**: 函数是数据库级别对象，需在每个要使用的数据库中单独创建。.so文件是共享的，只需安装一次。

```bash
# 在postgres库中创建函数
gsql -d postgres -f $OGHOME/share/postgresql/extension/sm4--1.0.sql

# 在其他库中创建...
gsql -d testdb -f $OGHOME/share/postgresql/extension/sm4--1.0.sql
```

或手动执行（可选）：

```sql
-- 连接数据库
gsql -d testdb

-- 创建SM4函数 (使用sm4_c_前缀避免冲突)
CREATE OR REPLACE FUNCTION sm4_c_encrypt(plaintext text, key text)
RETURNS bytea AS 'sm4', 'sm4_encrypt' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt(ciphertext bytea, key text)
RETURNS text AS 'sm4', 'sm4_decrypt' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_encrypt_hex(plaintext text, key text)
RETURNS text AS 'sm4', 'sm4_encrypt_hex' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt_hex(ciphertext_hex text, key text)
RETURNS text AS 'sm4', 'sm4_decrypt_hex' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_encrypt_cbc(plaintext text, key text, iv text)
RETURNS bytea AS 'sm4', 'sm4_encrypt_cbc' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt_cbc(ciphertext bytea, key text, iv text)
RETURNS text AS 'sm4', 'sm4_decrypt_cbc' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_encrypt_gcm(plaintext text, key text, iv text, aad text DEFAULT NULL)
RETURNS bytea AS 'sm4', 'sm4_encrypt_gcm' LANGUAGE C IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt_gcm(ciphertext_with_tag bytea, key text, iv text, aad text DEFAULT NULL)
RETURNS text AS 'sm4', 'sm4_decrypt_gcm' LANGUAGE C IMMUTABLE;
```

## 停用扩展

如果需要删除SM4扩展函数，执行以下命令：

```sql
-- 连接数据库
gsql -d testdb

-- 删除所有SM4 C扩展函数
DROP FUNCTION IF EXISTS sm4_c_encrypt(text, text);
DROP FUNCTION IF EXISTS sm4_c_decrypt(bytea, text);
DROP FUNCTION IF EXISTS sm4_c_encrypt_hex(text, text);
DROP FUNCTION IF EXISTS sm4_c_decrypt_hex(text, text);
DROP FUNCTION IF EXISTS sm4_c_encrypt_cbc(text, text, text);
DROP FUNCTION IF EXISTS sm4_c_decrypt_cbc(bytea, text, text);
DROP FUNCTION IF EXISTS sm4_c_encrypt_gcm(text, text, text, text);
DROP FUNCTION IF EXISTS sm4_c_decrypt_gcm(bytea, text, text, text);
```

**注意**：

- 删除函数不会删除.so文件，只是在当前数据库中移除函数定义
- 如需在多个数据库中删除，需要分别连接每个数据库执行删除命令
- 如果要完全卸载扩展，还需要删除.so文件：

  ```bash
  rm -f $OGHOME/lib/postgresql/sm4.so
  ```

## 查看已安装的函数

```sql
gsql -d testdb

-- 查看所有SM4 C扩展函数
\df sm4_c*

-- 查看函数详细信息
\df+ sm4_c_encrypt
```

## 函数说明

**重要提示**: 为避免函数名冲突，所有C扩展函数均使用 `sm4_c_` 前缀。

| 函数                                           | 说明                              |
| ---------------------------------------------- | --------------------------------- |
| `sm4_c_encrypt(text, key)`                     | ECB模式加密，返回bytea            |
| `sm4_c_decrypt(bytea, key)`                    | ECB模式解密，返回text             |
| `sm4_c_encrypt_hex(text, key)`                 | ECB模式加密，返回十六进制字符串   |
| `sm4_c_decrypt_hex(hex, key)`                  | ECB模式解密，输入十六进制密文     |
| `sm4_c_encrypt_cbc(text, key, iv)`             | CBC模式加密，返回bytea            |
| `sm4_c_decrypt_cbc(bytea, key, iv)`            | CBC模式解密，返回text             |
| `sm4_c_encrypt_gcm(text, key, iv, aad)`        | GCM模式加密，返回密文+Tag(bytea)  |
| `sm4_c_decrypt_gcm(bytea, key, iv, aad)`       | GCM模式解密，返回text             |
| `sm4_c_encrypt_gcm_base64(text, key, iv, aad)` | GCM模式加密，返回Base64编码(text) |
| `sm4_c_decrypt_gcm_base64(text, key, iv, aad)` | GCM模式解密，接收Base64编码(text) |

**密钥格式**: 16字节字符串 或 32位十六进制字符串

**IV格式**:

- CBC模式: 16字节字符串 或 32位十六进制字符串
- GCM模式: 12或16字节字符串 或 24/32位十六进制字符串（推荐12字节）

## 运行示例

```bash
# 进入数据库
gsql -d testdb

```

```sql
-- ECB模式加密 (返回十六进制)
SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');

-- ECB模式解密
SELECT sm4_c_decrypt_hex(sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef'), '1234567890abcdef');

-- 加解密验证
SELECT sm4_c_decrypt_hex(
    sm4_c_encrypt_hex('测试数据', '1234567890abcdef'),
    '1234567890abcdef'
);

-- bytea格式加解密
SELECT sm4_c_decrypt(
    sm4_c_encrypt('中文测试', '1234567890abcdef'),
    '1234567890abcdef'
);

-- CBC模式 (需要IV)
SELECT sm4_c_decrypt_cbc(
    sm4_c_encrypt_cbc('明文数据', 'key1234567890123', 'iv12345678901234'),
    'key1234567890123',
    'iv12345678901234'
);

-- 使用32位十六进制密钥
SELECT sm4_c_encrypt_hex('敏感数据', '0123456789abcdef0123456789abcdef');

-- GCM模式加密（无AAD）
SELECT encode(sm4_c_encrypt_gcm('Hello GCM!', '1234567890123456', '123456789012'), 'hex');

-- GCM模式加密（带AAD）
SELECT sm4_c_encrypt_gcm('Secret Message', '1234567890123456', '123456789012', 'additional data');

-- GCM模式解密
SELECT sm4_c_decrypt_gcm(
    sm4_c_encrypt_gcm('Test Data', '1234567890123456', '123456789012', 'aad'),
    '1234567890123456',
    '123456789012',
    'aad'
);

-- GCM模式加密（Base64版本）
SELECT sm4_c_encrypt_gcm_base64('Hello World!', '1234567890123456', '1234567890123456');
-- 返回: xChfq83NzMzipO2bh48BLdrD2N8/J8kRcjtVCg==

-- GCM模式加密（Base64版本，带AAD）
SELECT sm4_c_encrypt_gcm_base64(
    'Secret Message',
    '1234567890123456',
    '123456789012',
    'user_id:12345'
);

-- GCM模式解密（Base64版本）
SELECT sm4_c_decrypt_gcm_base64(
    'xChfq83NzMzipO2bh48BLdrD2N8/J8kRcjtVCg==',
    '1234567890123456',
    '1234567890123456'
);
-- 返回: Hello World!

-- GCM模式完整加解密流程（Base64版本）
SELECT sm4_c_decrypt_gcm_base64(
    sm4_c_encrypt_gcm_base64('Test Data', '1234567890123456', '123456789012', 'aad'),
    '1234567890123456',
    '123456789012',
    'aad'
);
-- 返回: Test Data

-- 运行测试脚本
gsql -d testdb -f test_sm4.sql

gsql -d testdb -f test_sm4_gcm.sql

gsql -d testdb -f demo_citizen_data.sql
```
