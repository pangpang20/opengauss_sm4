# 第1篇:OpenGauss 入门与 Docker 环境搭建

## 什么是 OpenGauss？

OpenGauss 是华为主导开源的关系型数据库，基于 PostgreSQL 内核改造，主要面向企业级场景。

核心特性:
- 查询引擎优化，支持高并发
- 内置国密算法（SM2、SM3、SM4）
- 主备复制、故障自动切换
- 兼容 PostgreSQL 生态和 SQL 语法

## 环境准备

需要安装:
- Docker 20.10+
- Docker Compose 1.29+

检查安装:

```bash
# 检查 Docker 版本
docker --version

# 检查 Docker Compose 版本
docker-compose --version

# 测试 Docker 是否正常运行
docker run hello-world
```

## 拉取镜像

使用云数科技（Enmotech）提供的 OpenGauss 镜像:

```bash
# 拉取 6.0.3 LTS 版本
docker pull enmotech/opengauss:6.0.3

# 查看镜像
docker images | grep opengauss
```

输出:
```
enmotech/opengauss   6.0.3   abc123def456   2 weeks ago   892MB
```

## 启动容器

直接运行一个测试实例:

```bash
docker run --name opengauss-test \
  -p 5432:5432 \
  -e GS_PASSWORD=Enmo@123 \
  -d enmotech/opengauss:6.0.3

docker ps | grep opengauss
```

参数:
- `--name`:容器名称
- `-p 5432:5432`:端口映射
- `-e GS_PASSWORD`:设置密码
- `-d`:后台运行

## 连接数据库

等 10-15 秒让数据库初始化完成:

```bash
docker exec -it opengauss-test bash
su - omm
gsql -d postgres -U omm -W Enmo@123
```

连接成功后看到:
```
gsql ((openGauss 6.0.3 build aee4abd5) compiled at 2024-09-29 19:31:41)
Type "help" for help.

postgres=#
```

## 基本操作

在 `postgres=#` 提示符下试试这些命令:

### 查看版本

```sql
SELECT version();
```

### 建表插数据

```sql
-- 建表
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 插入数据
INSERT INTO users (username, email) VALUES 
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com');

-- 查询
SELECT  FROM users;
SELECT  FROM users WHERE username = 'alice';

-- 退出
\q
```

## 用 Docker Compose 管理（推荐）

手动敲命令太麻烦，用配置文件管理更方便。

创建`docker-compose.yml`:

```yaml
version: '3.8'

services:
  opengauss:
    image: enmotech/opengauss:6.0.3
    container_name: opengauss_db
    environment:
      - GS_PASSWORD=Enmo@123
    ports:
      - "5432:5432"
    volumes:
      - opengauss_data:/var/lib/opengauss
    restart: unless-stopped

volumes:
  opengauss_data:
```

使用方法:

```bash
# 启动
docker-compose up -d

# 看日志
docker-compose logs -f

# 停止
docker-compose down

# 停止并删除数据
docker-compose down -v
```

## 常用命令

### Docker 命令

```bash
docker ps                          # 看运行中的容器
docker ps -a                       # 看所有容器
docker logs <container>            # 看日志
docker exec -it <container> bash   # 进容器
docker stop <container>            # 停止
docker start <container>           # 启动
docker rm <container>              # 删除
```

### gsql 命令

```
\l              # 列出所有数据库
\c dbname       # 切换数据库
\dt             # 列出所有表
\d tablename    # 查看表结构
\du             # 列出所有用户
\q              # 退出
```

## 常见问题

### 容器启动失败
容器不断重启，查看日志:

```bash
docker logs opengauss-test
```

可能原因:
- 端口被占用:改成 `-p 15432:5432`
- 密码不符合要求:需包含大小写、数字、特殊字符

### 连不上数据库

检查步骤:
```bash
# 1. 容器在运行吗
docker ps | grep opengauss

# 2. 数据库进程起来了吗
docker exec opengauss-test ps -ef | grep gaussdb

# 3. 端口监听了吗
docker exec opengauss-test netstat -tunlp | grep 5432
```

### 权限错误

报 `FATAL: permission denied`，切换到 omm 用户:
```bash
docker exec -it opengauss-test su - omm
```

## 练习

1. 创建`products` 表，包含 id、name、price、stock，插入 5 条数据
2. 用 Docker Compose 部署，配置数据持久化
3. 写个脚本自动检测数据库是否就绪

第 3 题参考答案:

```bash
#!/bin/bash
CONTAINER="opengauss_db"
TIMEOUT=60
COUNTER=0

echo "等待数据库启动..."

until docker exec $CONTAINER su - omm -c "gsql -d postgres -U omm -W Enmo@123 -c 'SELECT 1;'" > /dev/null 2>&1; do
    sleep 1
    COUNTER=$((COUNTER + 1))
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo "超时！"
        exit 1
    fi
    echo -n "."
done

echo "数据库就绪"
docker exec $CONTAINER su - omm -c "gsql -d postgres -U omm -W Enmo@123 -f /path/to/init.sql"
```

## 总结

现在你会了:
- 用 Docker 跑 OpenGauss
- 基本的 SQL 操作
- Docker Compose 管理容器
- 排查常见问题

下一篇讲 PostgreSQL/OpenGauss 扩展开发。

## 参考

- [OpenGauss 官方文档](https://docs.opengauss.org/)
- [OpenGauss Docker 镜像](https://hub.docker.com/r/enmotech/opengauss)
- [Docker 官方文档](https://docs.docker.com/)