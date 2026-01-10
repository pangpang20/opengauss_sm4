# 第2篇:PostgreSQL/OpenGauss 扩展开发基础

## 什么是数据库扩展?

数据库扩展（Extension）是一种模块化机制，允许开发者向数据库添加自定义功能，而无需修改数据库内核代码。

常见扩展类型:
- 函数扩展:添加自定义 SQL 函数（如加密、地理计算）
- 数据类型扩展:添加新的数据类型（如 JSON、UUID）
- 操作符扩展:添加自定义操作符（如全文搜索）
- 索引扩展:添加新的索引类型（如 GiST、GIN）

著名的 PostgreSQL 扩展:
- PostGIS:地理空间数据支持
- pg_trgm:模糊搜索和相似度匹配
- hstore:键值对存储
- pgcrypto:加密函数库

## 扩展的核心组件

一个完整的 PostgreSQL/OpenGauss 扩展通常包含:

```
myext/
├── myext.c          # C 源代码（核心逻辑）
├── myext.control    # 扩展元数据
├── myext--1.0.sql   # SQL 定义文件
├── Makefile         # 编译配置
└── README.md        # 文档
```

### 1. Control 文件（.control）

定义扩展的元数据:

```conf
# myext.control
comment = 'My first PostgreSQL extension'
default_version = '1.0'
module_pathname = '$libdir/myext'
relocatable = true
```

关键字段说明
- `comment`:扩展描述
- `default_version`:默认版本号
- `module_pathname`:动态库路径（`$libdir` 是系统变量）
- `relocatable`:是否可以在不同 schema 间移动

### 2. SQL 定义文件（.sql）

定义对外暴露的 SQL 接口:

```sql
-- myext--1.0.sql

-- 声明 C 函数
CREATE FUNCTION myext_add(integer, integer)
RETURNS integer
AS 'MODULE_PATHNAME', 'myext_add'
LANGUAGE C STRICT;

-- 创建SQL 函数包装
CREATE FUNCTION add_numbers(a int, b int)
RETURNS int
AS $$
    SELECT myext_add(a, b);
$$
LANGUAGE SQL;
```

### 3. C 源代码（.c/.cpp）

实现具体功能逻辑:

```c
#include "postgres.h"
#include "fmgr.h"

PG_MODULE_MAGIC;  // 必需的魔术宏

PG_FUNCTION_INFO_V1(myext_add);

Datum
myext_add(PG_FUNCTION_ARGS)
{
    int32 arg1 = PG_GETARG_INT32(0);
    int32 arg2 = PG_GETARG_INT32(1);
    
    PG_RETURN_INT32(arg1 + arg2);
}
```

## 动手实践:创建第一个扩展

### 准备开发环境

```bash
# 创建项目目录
mkdir -p ~/myext
cd ~/myext

# 启动带开发工具的 OpenGauss 容器
docker run -d --name opengauss-dev \
  -p 5432:5432 \
  -e GS_PASSWORD=Enmo@123 \
  -v $(pwd):/workspace \
  enmotech/opengauss:6.0.3

# 进入容器安装编译工具
docker exec -it opengauss-dev bash
yum install -y gcc make
```

### 编写扩展代码

创建`myext.c`:

```c
/ myext.c - 简单的数学运算扩展 /

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

/ 函数声明 /
PG_FUNCTION_INFO_V1(myext_add);
PG_FUNCTION_INFO_V1(myext_multiply);
PG_FUNCTION_INFO_V1(myext_power);

/ 加法函数 /
Datum
myext_add(PG_FUNCTION_ARGS)
{
    int32 a = PG_GETARG_INT32(0);
    int32 b = PG_GETARG_INT32(1);
    
    PG_RETURN_INT32(a + b);
}

/ 乘法函数 /
Datum
myext_multiply(PG_FUNCTION_ARGS)
{
    int32 a = PG_GETARG_INT32(0);
    int32 b = PG_GETARG_INT32(1);
    
    PG_RETURN_INT32(a  b);
}

/ 幂运算函数 /
Datum
myext_power(PG_FUNCTION_ARGS)
{
    int32 base = PG_GETARG_INT32(0);
    int32 exponent = PG_GETARG_INT32(1);
    int32 result = 1;
    
    / 简单的幂运算实现/
    for (int i = 0; i < exponent; i++) {
        result = base;
    }
    
    PG_RETURN_INT32(result);
}
```

### 创建Control 文件

创建`myext.control`:

```conf
# myext extension
comment = 'Simple math operations extension'
default_version = '1.0'
module_pathname = '$libdir/myext'
relocatable = true
```

### 创建SQL 定义文件

创建`myext--1.0.sql`:

```sql
-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION myext" to load this file. \quit

-- 加法函数
CREATE FUNCTION myext_add(integer, integer)
RETURNS integer
AS 'MODULE_PATHNAME', 'myext_add'
LANGUAGE C STRICT IMMUTABLE;

-- 乘法函数
CREATE FUNCTION myext_multiply(integer, integer)
RETURNS integer
AS 'MODULE_PATHNAME', 'myext_multiply'
LANGUAGE C STRICT IMMUTABLE;

-- 幂运算函数
CREATE FUNCTION myext_power(integer, integer)
RETURNS integer
AS 'MODULE_PATHNAME', 'myext_power'
LANGUAGE C STRICT IMMUTABLE;
```

### 创建Makefile

创建`Makefile`:

```makefile
# Makefile for myext extension

MODULE_big = myext
OBJS = myext.o

EXTENSION = myext
DATA = myext--1.0.sql

# 用PGXS 构建系统
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
```

对于 OpenGauss，需要调整路径:

```makefile
# Makefile for OpenGauss
MODULE_big = myext
OBJS = myext.o

EXTENSION = myext
DATA = myext--1.0.sql

# OpenGauss 特定路径
GAUSSHOME = /usr/local/opengauss
PG_CONFIG = $(GAUSSHOME)/bin/pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)

include $(PGXS)
```

### 编译和安装

```bash
# 在容器内编译
cd /workspace
export PATH=/usr/local/opengauss/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/opengauss/lib:$LD_LIBRARY_PATH

make clean
make
make install
```

输出:
```
gcc -Wall -Wmissing-prototypes -Wpointer-arith ...
gcc -shared -o myext.so myext.o
/usr/bin/install -c -m 755 myext.so '/usr/local/opengauss/lib/postgresql/'
/usr/bin/install -c -m 644 myext.control '/usr/local/opengauss/share/extension/'
/usr/bin/install -c -m 644 myext--1.0.sql '/usr/local/opengauss/share/extension/'
```

### 测试扩展

```bash
# 连接数据库
su - omm
gsql -d postgres -U omm -W Enmo@123
```

```sql
-- 创建扩展
CREATE EXTENSION myext;

-- 测试加法
SELECT myext_add(10, 20);
-- 结果:30

-- 测试乘法
SELECT myext_multiply(7, 8);
-- 结果:56

-- 测试幂运算
SELECT myext_power(2, 10);
-- 结果:1024

-- 查看已安装的扩展
\dx

-- 查看扩展提供的函数
\df myext_

-- 删除扩展
DROP EXTENSION myext;
```

## 核心概念深入

### 1. PG_MODULE_MAGIC

这是一个必需的宏，用于版本检查:

```c
#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif
```

作用 确保扩展与数据库版本兼容，防止加载不兼容的动态库。

### 2. PG_FUNCTION_INFO_V1

声明函数的元信息:

```c
PG_FUNCTION_INFO_V1(myext_add);
```

作用 告诉 PostgreSQL 这是一个版本 1 的函数接口。

### 3. 函数参数和返回值

获取参数:
```c
int32 arg = PG_GETARG_INT32(0);  // 第一个参数
text arg = PG_GETARG_TEXT_PP(1); // 第二个参数（文本类型）
```

返回值:
```c
PG_RETURN_INT32(result);    // 返回整数
PG_RETURN_TEXT_P(result);   // 返回文本
PG_RETURN_NULL();           // 返回 NULL
```

常用类型宏:
| PostgreSQL 类型 | 获取参数 | 返回值 |
|-----------------|----------|--------|
| `integer` | `PG_GETARG_INT32(n)` | `PG_RETURN_INT32(x)` |
| `bigint` | `PG_GETARG_INT64(n)` | `PG_RETURN_INT64(x)` |
| `text` | `PG_GETARG_TEXT_PP(n)` | `PG_RETURN_TEXT_P(x)` |
| `bytea` | `PG_GETARG_BYTEA_PP(n)` | `PG_RETURN_BYTEA_P(x)` |
| `bool` | `PG_GETARG_BOOL(n)` | `PG_RETURN_BOOL(x)` |

### 4. 内存管理

PostgreSQL 使用自己的内存上下文系统:

```c
#include "utils/palloc.h"

// 分配内存
char buffer = palloc(1024);

// 释放内存
pfree(buffer);

// 复制字符串
char copy = pstrdup(original);
```

重要 不要用`malloc`/`free`，始终用`palloc`/`pfree`。

## 常见错误和调试

### 错误1:找不到动态库

```
ERROR: could not load library "$libdir/myext.so": 
No such file or directory
```

解决方案:
```bash
# 检查文件是否存在
ls -la /usr/local/opengauss/lib/postgresql/myext.so

# 检查权限
chmod 755 /usr/local/opengauss/lib/postgresql/myext.so
```

### 错误2:符号未定义

```
ERROR: could not find function "myext_add" in file "$libdir/myext.so"
```

原因: SQL 文件中的函数名与 C 代码不匹配

解决方案: 确保 `PG_FUNCTION_INFO_V1(myext_add)` 的函数名与 SQL 中的 `'myext_add'` 一致

### 错误3:版本不兼容

```
ERROR: incompatible library: version mismatch
```

解决方案: 确保扩展使用正确的 PostgreSQL/OpenGauss 头文件编译

### 调试技巧

1. 用elog 输出日志:
```c
#include "elog.h"

elog(NOTICE, "arg1=%d, arg2=%d", arg1, arg2);
elog(WARNING, "This is a warning");
elog(ERROR, "This will abort the transaction");
```

2. 查看日志文件:
```bash
docker exec opengauss-dev tail -f /var/lib/opengauss/data/pg_log/gaussdb-.log
```

3. 用gdb 调试:
```bash
# 安装 gdb
yum install -y gdb

# 附加到 gaussdb 进程
gdb -p $(pgrep gaussdb)
```

## 练习

### 字符串反转扩展

创建一个扩展，实现字符串反转功能:

```sql
SELECT myext_reverse('hello');
-- 结果:'olleh'
```




```c
PG_FUNCTION_INFO_V1(myext_reverse);

Datum
myext_reverse(PG_FUNCTION_ARGS)
{
    text input = PG_GETARG_TEXT_PP(0);
    char str = text_to_cstring(input);
    int len = strlen(str);
    char result = palloc(len + 1);
    
    for (int i = 0; i < len; i++) {
        result[i] = str[len - 1 - i];
    }
    result[len] = '\0';
    
    text output = cstring_to_text(result);
    pfree(str);
    pfree(result);
    
    PG_RETURN_TEXT_P(output);
}
```

SQL 定义:
```sql
CREATE FUNCTION myext_reverse(text)
RETURNS text
AS 'MODULE_PATHNAME', 'myext_reverse'
LANGUAGE C STRICT IMMUTABLE;
```


### 计算斐波那契数列

创建函数计算第 n 个斐波那契数:

```sql
SELECT myext_fibonacci(10);
-- 结果:55
```

### JSON 键提取

创建函数从简单 JSON 字符串中提取指定键的值（不使用现有 JSON 库）。


- [PostgreSQL Extension Building Infrastructure](https://www.postgresql.org/docs/current/extend-pgxs.html)
- [PostgreSQL C Language Functions](https://www.postgresql.org/docs/current/xfunc-c.html)
- [OpenGauss 扩展开发指南](https://docs.opengauss.org/zh/docs/latest/docs/Developerguide/C-API.html)
