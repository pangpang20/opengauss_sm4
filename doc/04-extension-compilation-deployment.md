# 第4篇:OpenGauss SM4 扩展编译与部署

## 课程目标

这篇教程实战开发一个完整的 SM4 加密扩展，学习如何将前面章节的 SM4 算法集成到 OpenGauss 数据库中，掌握扩展的编译、安装、测试全流程。

## 项目结构概览

一个完整的 OpenGauss SM4 扩展包含以下文件:

```
opengauss_sm4/
├── sm4.h                   # SM4 算法头文件
├── sm4.c                   # SM4 核心算法实现
├── sm4_ext.cpp             # OpenGauss 扩展接口
├── sm4.control             # 扩展元数据
├── sm4--1.0.sql            # SQL 函数定义
├── Makefile                # 编译配置
└── fio_device_com.h        # OpenGauss 头文件依赖
```

## 准备开发环境

### 创建项目目录

```bash
mkdir -p ~/opengauss_sm4
cd ~/opengauss_sm4
```

### 启动开发容器

```bash
docker run -d --name opengauss-dev \
  -p 5432:5432 \
  -e GS_PASSWORD=Enmo@123 \
  -v $(pwd):/workspace \
  enmotech/opengauss:6.0.3

# 进入容器
docker exec -it opengauss-dev bash

# 安装编译工具
yum install -y gcc gcc-c++ make
```

### 设置环境变量

```bash
export GAUSSHOME=/usr/local/opengauss
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
```

## 创建扩展元数据文件

### 1. 创建sm4.control

```bash
cat > sm4.control << 'EOF'
# SM4 extension
comment = 'SM4 encryption/decryption functions (Chinese National Standard)'
default_version = '1.0'
module_pathname = '$libdir/sm4'
relocatable = true
EOF
```

字段说明
- `comment`:扩展描述，显示在 `\dx` 命令中
- `default_version`:默认版本号
- `module_pathname`:动态库路径
  - `$libdir` 是 OpenGauss 变量，指向 `/usr/local/opengauss/lib/postgresql/`
  - 实际加载时会尝试 `$libdir/proc_srclib/sm4`
- `relocatable`:是否可以在不同 schema 间移动

### 2. 创建sm4--1.0.sql

```sql
-- sm4--1.0.sql
-- SM4 Extension SQL Definitions

-- ECB 模式加密（返回 bytea）
CREATE OR REPLACE FUNCTION sm4_c_encrypt(plaintext text, key text)
RETURNS bytea
AS 'sm4', 'sm4_encrypt'
LANGUAGE C STRICT IMMUTABLE;

COMMENT ON FUNCTION sm4_c_encrypt(text, text) IS 
'SM4 ECB模式加密。参数: plaintext-明文, key-密钥(16字节或32位十六进制)';

-- ECB 模式解密
CREATE OR REPLACE FUNCTION sm4_c_decrypt(ciphertext bytea, key text)
RETURNS text
AS 'sm4', 'sm4_decrypt'
LANGUAGE C STRICT IMMUTABLE;

-- CBC 模式加密
CREATE OR REPLACE FUNCTION sm4_c_encrypt_cbc(plaintext text, key text, iv text)
RETURNS bytea
AS 'sm4', 'sm4_encrypt_cbc'
LANGUAGE C STRICT IMMUTABLE;

-- CBC 模式解密
CREATE OR REPLACE FUNCTION sm4_c_decrypt_cbc(ciphertext bytea, key text, iv text)
RETURNS text
AS 'sm4', 'sm4_decrypt_cbc'
LANGUAGE C STRICT IMMUTABLE;

-- 十六进制版本（便于展示）
CREATE OR REPLACE FUNCTION sm4_c_encrypt_hex(plaintext text, key text)
RETURNS text
AS 'sm4', 'sm4_encrypt_hex'
LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt_hex(ciphertext_hex text, key text)
RETURNS text
AS 'sm4', 'sm4_decrypt_hex'
LANGUAGE C STRICT IMMUTABLE;
```

SQL 定义要点:
- `AS 'sm4'`:对应 `module_pathname` 中的库名
- `'sm4_encrypt'`:C 函数名，必须与 `PG_FUNCTION_INFO_V1` 声明的函数名一致
- `LANGUAGE C`:声明为 C 语言函数
- `STRICT`:任何参数为 NULL 时直接返回 NULL
- `IMMUTABLE`:相同输入保证相同输出（有利于查询优化）

## 编写扩展接口代码

### 创建sm4_ext.cpp

```cpp
/
  SM4 Extension for OpenGauss
  PostgreSQL/OpenGauss 扩展接口
 /

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "mb/pg_wchar.h"
#include "sm4.h"
#include <string.h>
#include <stdlib.h>

PG_MODULE_MAGIC;

/ 函数声明 /
PG_FUNCTION_INFO_V1(sm4_encrypt);
PG_FUNCTION_INFO_V1(sm4_decrypt);
PG_FUNCTION_INFO_V1(sm4_encrypt_hex);
PG_FUNCTION_INFO_V1(sm4_decrypt_hex);

/ 工具函数:十六进制转字节 /
static int hex_to_bytes(const char hex, size_t hex_len, 
                        uint8_t bytes, size_t bytes_len)
{
    if (hex_len % 2 != 0) {
        return -1;
    }
    
    for (size_t i = 0; i < hex_len; i += 2) {
        char buf[3] = {hex[i], hex[i + 1], 0};
        bytes[i / 2] = (uint8_t)strtol(buf, NULL, 16);
    }
    
    bytes_len = hex_len / 2;
    return 0;
}

/ 工具函数:字节转十六进制 /
static void bytes_to_hex(const uint8_t bytes, size_t bytes_len, char hex)
{
    static const char hex_chars[] = "0123456789abcdef";
    
    for (size_t i = 0; i < bytes_len; i++) {
        hex[i  2] = hex_chars[(bytes[i] >> 4) & 0x0f];
        hex[i  2 + 1] = hex_chars[bytes[i] & 0x0f];
    }
    hex[bytes_len  2] = '\0';
}

/ 获取密钥字节（支持原始字节和十六进制） /
static int get_key_bytes(text key_text, uint8_t key_bytes)
{
    char key_str = text_to_cstring(key_text);
    size_t key_len = strlen(key_str);
    int ret = 0;

    if (key_len == SM4_KEY_SIZE) {
        / 16 字节原始密钥 /
        memcpy(key_bytes, key_str, SM4_KEY_SIZE);
    } else if (key_len == SM4_KEY_SIZE_HEX) {
        / 32 字符十六进制密钥 /
        size_t bytes_len;
        if (hex_to_bytes(key_str, SM4_KEY_SIZE_HEX, key_bytes, &bytes_len) != 0) {
            ret = -1;
        }
    } else {
        ereport(ERROR,
                (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                 errmsg("SM4 key must be 16 bytes or 32 hex characters, got %zu", key_len)));
        ret = -1;
    }

    pfree(key_str);
    return ret;
}

/ ECB 加密函数 /
Datum
sm4_encrypt(PG_FUNCTION_ARGS)
{
    text plaintext = PG_GETARG_TEXT_PP(0);
    text key_text = PG_GETARG_TEXT_PP(1);
    
    / 提取明文 /
    char plain_str = text_to_cstring(plaintext);
    size_t plain_len = strlen(plain_str);
    
    / 提取密钥 /
    uint8_t key[SM4_KEY_SIZE];
    if (get_key_bytes(key_text, key) != 0) {
        pfree(plain_str);
        PG_RETURN_NULL();
    }
    
    / 分配输出缓冲区 /
    size_t cipher_len;
    uint8_t cipher = (uint8_t )palloc(plain_len + SM4_BLOCK_SIZE);
    
    / 调用 SM4 加密 /
    if (sm4_ecb_encrypt(key, (uint8_t )plain_str, plain_len, 
                        cipher, &cipher_len) != 0) {
        pfree(plain_str);
        pfree(cipher);
        ereport(ERROR,
                (errcode(ERRCODE_EXTERNAL_ROUTINE_EXCEPTION),
                 errmsg("SM4 encryption failed")));
    }
    
    / 转换为 bytea 返回 /
    bytea result = (bytea )palloc(VARHDRSZ + cipher_len);
    SET_VARSIZE(result, VARHDRSZ + cipher_len);
    memcpy(VARDATA(result), cipher, cipher_len);
    
    pfree(plain_str);
    pfree(cipher);
    
    PG_RETURN_BYTEA_P(result);
}

/ ECB 解密函数 /
Datum
sm4_decrypt(PG_FUNCTION_ARGS)
{
    bytea ciphertext = PG_GETARG_BYTEA_PP(0);
    text key_text = PG_GETARG_TEXT_PP(1);
    
    / 提取密文 /
    uint8_t cipher = (uint8_t )VARDATA_ANY(ciphertext);
    size_t cipher_len = VARSIZE_ANY_EXHDR(ciphertext);
    
    / 提取密钥 /
    uint8_t key[SM4_KEY_SIZE];
    if (get_key_bytes(key_text, key) != 0) {
        PG_RETURN_NULL();
    }
    
    / 分配输出缓冲区 /
    uint8_t plain = (uint8_t )palloc(cipher_len);
    size_t plain_len;
    
    / 调用 SM4 解密 /
    if (sm4_ecb_decrypt(key, cipher, cipher_len, plain, &plain_len) != 0) {
        pfree(plain);
        ereport(ERROR,
                (errcode(ERRCODE_EXTERNAL_ROUTINE_EXCEPTION),
                 errmsg("SM4 decryption failed")));
    }
    
    / 转换为 text 返回 /
    text result = cstring_to_text_with_len((char )plain, plain_len);
    
    pfree(plain);
    
    PG_RETURN_TEXT_P(result);
}

/ 十六进制加密函数（便于展示） /
Datum
sm4_encrypt_hex(PG_FUNCTION_ARGS)
{
    text plaintext = PG_GETARG_TEXT_PP(0);
    text key_text = PG_GETARG_TEXT_PP(1);
    
    char plain_str = text_to_cstring(plaintext);
    size_t plain_len = strlen(plain_str);
    
    uint8_t key[SM4_KEY_SIZE];
    if (get_key_bytes(key_text, key) != 0) {
        pfree(plain_str);
        PG_RETURN_NULL();
    }
    
    size_t cipher_len;
    uint8_t cipher = (uint8_t )palloc(plain_len + SM4_BLOCK_SIZE);
    
    if (sm4_ecb_encrypt(key, (uint8_t )plain_str, plain_len, 
                        cipher, &cipher_len) != 0) {
        pfree(plain_str);
        pfree(cipher);
        ereport(ERROR,
                (errcode(ERRCODE_EXTERNAL_ROUTINE_EXCEPTION),
                 errmsg("SM4 encryption failed")));
    }
    
    / 转换为十六进制字符串 /
    char hex_str = (char )palloc(cipher_len  2 + 1);
    bytes_to_hex(cipher, cipher_len, hex_str);
    
    text result = cstring_to_text(hex_str);
    
    pfree(plain_str);
    pfree(cipher);
    pfree(hex_str);
    
    PG_RETURN_TEXT_P(result);
}
```

关键点:

1. PG_MODULE_MAGIC:版本检查宏，必需
2. PG_FUNCTION_INFO_V1:声明函数元信息
3. PG_GETARG_:获取 SQL 参数
4. PG_RETURN_:返回结果给 SQL
5. ereport:报告错误信息
6. palloc/pfree:PostgreSQL 内存管理

## 写Makefile

### 创建Makefile

```makefile
# SM4 Extension Makefile for OpenGauss

OGHOME ?= /usr/local/opengauss

CXX = g++
CXXFLAGS = -O2 -Wall -fPIC -std=c++11

INCLUDES = -I$(OGHOME)/include/postgresql/server \
           -I$(OGHOME)/include/postgresql/internal \
           -I$(OGHOME)/include

OBJS = sm4.o sm4_ext.o
TARGET = sm4.so

LIBDIR = $(OGHOME)/lib/postgresql
EXTDIR = $(OGHOME)/share/postgresql/extension

.PHONY: all clean install

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) -shared -o $@ $(OBJS)

sm4.o: sm4.c sm4.h
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c -o $@ $<

sm4_ext.o: sm4_ext.cpp sm4.h
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c -o $@ $<

install: $(TARGET)
	cp $(TARGET) $(LIBDIR)/
	cp sm4.control $(EXTDIR)/
	cp sm4--1.0.sql $(EXTDIR)/
	@echo "Installation complete!"

clean:
	rm -f $(OBJS) $(TARGET)
```

Makefile 说明
- `OGHOME`:OpenGauss 安装路径
- `INCLUDES`:包含 OpenGauss 头文件路径
- `-fPIC`:生成位置无关代码（共享库必需）
- `-shared`:生成共享库

## 编译和安装

### 1. 编译扩展

```bash
cd /workspace
make clean
make
```

输出:
```
g++ -O2 -Wall -fPIC -std=c++11 -I/usr/local/opengauss/include/postgresql/server ... -c -o sm4.o sm4.c
g++ -O2 -Wall -fPIC -std=c++11 -I/usr/local/opengauss/include/postgresql/server ... -c -o sm4_ext.o sm4_ext.cpp
g++ -shared -o sm4.so sm4.o sm4_ext.o
```

### 2. 安装到 OpenGauss

```bash
make install
```

注意 OpenGauss 期望扩展在 `$libdir/proc_srclib/` 目录:

```bash
# 创建目录并复制
mkdir -p /usr/local/opengauss/lib/postgresql/proc_srclib
cp sm4.so /usr/local/opengauss/lib/postgresql/proc_srclib/sm4
chown omm:omm /usr/local/opengauss/lib/postgresql/proc_srclib/sm4
```

### 3. 验证安装

```bash
# 检查文件是否存在
ls -la /usr/local/opengauss/lib/postgresql/proc_srclib/sm4
ls -la /usr/local/opengauss/share/postgresql/extension/sm4

# 输出:
# -rwxr-xr-x 1 omm omm 98765 Jan 10 10:00 /usr/local/opengauss/lib/postgresql/proc_srclib/sm4
# -rw-r--r-- 1 root root  245 Jan 10 10:00 /usr/local/opengauss/share/postgresql/extension/sm4.control
# -rw-r--r-- 1 root root 1234 Jan 10 10:00 /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql
```

## 测试扩展

### 1. 连接数据库

```bash
su - omm
gsql -d postgres -U omm -W Enmo@123
```

### 2. 创建扩展

```sql
-- 创建扩展
CREATE EXTENSION sm4;

-- 查看已安装的扩展
\dx

-- 输出:
--                            List of extensions
--  Name | Version | Schema |               Description                
-- ------+---------+--------+------------------------------------------
--  sm4  | 1.0     | public | SM4 encryption/decryption functions ...

-- 查看扩展提供的函数
\df sm4
```

### 3. 测试加密解密

```sql
-- 测试 ECB 模式（十六进制输出）
SELECT sm4_c_encrypt_hex('Hello, SM4!', '0123456789abcdef') AS encrypted;

-- 输出:
--              encrypted              
-- ------------------------------------
--  fa3a126741cc82e48a7482b42d0e43c5

-- 测试解密
SELECT sm4_c_decrypt_hex('fa3a126741cc82e48a7482b42d0e43c5', '0123456789abcdef') AS decrypted;

-- 输出:
--  decrypted   
-- -------------
--  Hello, SM4!

-- 测试 bytea 版本
SELECT encode(sm4_c_encrypt('test', '0123456789abcdef'), 'hex');

-- 测试 CBC 模式
SELECT sm4_c_encrypt_cbc('Confidential data', '0123456789abcdef', 'abcdef0123456789');
```

### 4. 实际应用场景

```sql
-- 创建包含加密字段的用户表
CREATE TABLE secure_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email_encrypted BYTEA,  -- 加密存储的邮箱
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 插入加密数据
INSERT INTO secure_users (username, email_encrypted)
VALUES ('alice', sm4_c_encrypt('alice@example.com', '0123456789abcdef'));

-- 查询并解密
SELECT 
    id,
    username,
    sm4_c_decrypt(email_encrypted, '0123456789abcdef') AS email,
    created_at
FROM secure_users;

-- 输出:
--  id | username |       email        |         created_at         
-- ----+----------+--------------------+----------------------------
--   1 | alice    | alice@example.com  | 2025-01-10 10:30:45.123456
```

## 常见问题排查

### 问题1:找不到动态库

```
ERROR: could not load library "$libdir/proc_srclib/sm4": 
No such file or directory
```

解决方案:
```bash
# 检查文件路径
find /usr/local/opengauss -name "sm4"

# 确保文件在正确位置
cp sm4.so /usr/local/opengauss/lib/postgresql/proc_srclib/sm4
```

### 问题2:函数符号未找到

```
ERROR: could not find function "sm4_encrypt" in file
```

解决方案:
- 检查 `PG_FUNCTION_INFO_V1(sm4_encrypt)` 是否正确声明
- 确保 SQL 文件中函数名与 C 代码一致
- 用`nm` 命令检查符号:

```bash
nm sm4.so | grep sm4_encrypt
```

### 问题3:编译错误

```
fatal error: postgres.h: No such file or directory
```

解决方案:
```bash
# 检查头文件路径
ls /usr/local/opengauss/include/postgresql/server/postgres.h

# 更新 Makefile 中的 INCLUDES 路径
```

## 性能测试

### 测试脚本

```sql
-- 创建测试函数
CREATE OR REPLACE FUNCTION test_sm4_performance()
RETURNS TABLE(operation text, duration interval, ops_per_sec numeric) AS $$
DECLARE
    start_time timestamp;
    end_time timestamp;
    iterations int := 10000;
BEGIN
    -- 测试加密性能
    start_time := clock_timestamp();
    FOR i IN 1..iterations LOOP
        PERFORM sm4_c_encrypt_hex('test data', '0123456789abcdef');
    END LOOP;
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        'Encryption'::text,
        end_time - start_time,
        iterations / EXTRACT(EPOCH FROM (end_time - start_time));
    
    -- 测试解密性能
    start_time := clock_timestamp();
    FOR i IN 1..iterations LOOP
        PERFORM sm4_c_decrypt_hex('fa3a126741cc82e48a7482b42d0e43c5', '0123456789abcdef');
    END LOOP;
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        'Decryption'::text,
        end_time - start_time,
        iterations / EXTRACT(EPOCH FROM (end_time - start_time));
END;
$$ LANGUAGE plpgsql;

-- 运行测试
SELECT  FROM test_sm4_performance();
```


- [PostgreSQL C Language Functions](https://www.postgresql.org/docs/current/xfunc-c.html)
- [OpenGauss 扩展开发指南](https://docs.opengauss.org/)
- 本项目完整源码:`/workspace/opengauss_sm4/`
