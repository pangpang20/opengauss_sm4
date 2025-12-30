# OpenGauss SM4 扩展 - Docker 部署指南

本文档详细说明如何使用 Docker 部署和验证 OpenGauss SM4 扩展。

## 前置要求

- Docker 已安装 (建议 20.10+)
- Docker Compose 已安装 (建议 2.0+)
- 至少 2GB 可用内存
- 至少 5GB 可用磁盘空间

## 快速开始

### 1. 构建并启动容器

在项目根目录执行：

```bash
# 构建并启动OpenGauss容器（包含SM4扩展）
docker compose up -d

# 查看容器状态
docker compose ps

# 查看容器日志
docker compose logs -f opengauss-sm4
```

### 2. 等待数据库启动

首次启动需要初始化数据库，大约需要 30-60 秒。可以通过以下命令检查状态：

```bash
# 检查容器健康状态
docker ps | grep opengauss-sm4

# 等待数据库完全启动
docker compose logs -f opengauss-sm4 | grep "ready to accept connections"
```

### 3. 运行验证脚本

#### Linux/Mac 环境：

```bash
# 给脚本添加执行权限
chmod +x verify_sm4.sh

# 运行验证脚本
./verify_sm4.sh
```

#### Windows 环境 (PowerShell)：

```powershell
# 使用 Docker 执行验证
docker exec opengauss-sm4 bash -c "
export PGPASSWORD=Enmo@123
gsql -d postgres -U gaussdb -f /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql
gsql -d postgres -U gaussdb -c '\df sm4_c*'
"
```

## 手动验证步骤

### 1. 连接到数据库

```bash
# 从主机连接（需要安装 gsql 客户端）
PGPASSWORD=Enmo@123 gsql -h localhost -p 15432 -d postgres -U gaussdb

# 或者进入容器内部连接
docker exec -it opengauss-sm4 bash
su - omm
gsql -d postgres
```

### 2. 创建 SM4 扩展函数

```sql
-- 执行扩展安装脚本
\i /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql

-- 查看已创建的函数
\df sm4_c*
```

### 3. 测试基本功能

```sql
-- ECB 模式测试
SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');
SELECT sm4_c_decrypt_hex(
    sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef'), 
    '1234567890abcdef'
);

-- CBC 模式测试
SELECT sm4_c_decrypt_cbc(
    sm4_c_encrypt_cbc('测试数据', '1234567890abcdef', 'abcdef1234567890'),
    '1234567890abcdef',
    'abcdef1234567890'
);

-- GCM 模式测试
SELECT sm4_c_decrypt_gcm(
    sm4_c_encrypt_gcm('Secret', '1234567890123456', '123456789012'),
    '1234567890123456',
    '123456789012'
);
```

### 4. 运行完整测试套件

```bash
# 在容器内运行测试
docker exec -it opengauss-sm4 bash -c "
export PGPASSWORD=Enmo@123
gsql -d postgres -U gaussdb -f /opt/test_sm4.sql
gsql -d postgres -U gaussdb -f /opt/test_sm4_gcm.sql
"
```

## 配置说明

### Docker Compose 配置参数

编辑 `docker-compose.yml` 修改以下参数：

- **GS_PASSWORD**: 数据库管理员密码（默认: Enmo@123）
- **端口映射**: 主机端口 15432 映射到容器 5432
- **数据卷**: `opengauss_data` 持久化数据库数据

### 环境变量

| 变量名      | 说明       | 默认值        |
| ----------- | ---------- | ------------- |
| GS_PASSWORD | 管理员密码 | Enmo@123      |
| GS_NODENAME | 节点名称   | opengauss-sm4 |
| GS_USERNAME | 数据库用户 | gaussdb       |

## 故障排除

### 问题 1: 容器启动失败

**解决方法**:

```bash
# 查看详细日志
docker compose logs opengauss-sm4

# 重新构建镜像
docker compose down
docker compose build --no-cache
docker compose up -d
```

### 问题 2: 编译扩展失败

**可能原因**:
- g++ 编译器未安装
- OpenGauss 头文件路径不正确

**解决方法**:

```bash
# 进入容器检查
docker exec -it opengauss-sm4 bash

# 检查编译工具
which g++
g++ --version

# 检查头文件路径
ls /usr/local/opengauss/include/postgresql/server/
```

### 问题 3: 函数创建失败

**错误信息**: `could not load library "sm4"`

**解决方法**:

```bash
# 检查 .so 文件是否存在
docker exec opengauss-sm4 ls -l /usr/local/opengauss/lib/postgresql/sm4.so

# 如果不存在，手动编译安装
docker exec -it opengauss-sm4 bash
cd /opt/sm4_extension
export OGHOME=/usr/local/opengauss
make clean && make && make install
```

### 问题 4: 连接数据库超时

**解决方法**:

```bash
# 检查容器是否运行
docker ps | grep opengauss-sm4

# 检查端口映射
netstat -tulpn | grep 15432

# 检查数据库进程
docker exec opengauss-sm4 ps aux | grep gaussdb
```

## 数据持久化

数据库数据存储在 Docker 卷 `opengauss_data` 中，即使容器删除数据也不会丢失。

### 备份数据

```bash
# 导出数据库
docker exec opengauss-sm4 bash -c "
export PGPASSWORD=Enmo@123
gs_dump -h localhost -U gaussdb -d postgres -f /tmp/backup.sql
"

# 复制备份文件到主机
docker cp opengauss-sm4:/tmp/backup.sql ./backup.sql
```

### 恢复数据

```bash
# 复制备份文件到容器
docker cp ./backup.sql opengauss-sm4:/tmp/backup.sql

# 恢复数据库
docker exec opengauss-sm4 bash -c "
export PGPASSWORD=Enmo@123
gsql -h localhost -U gaussdb -d postgres -f /tmp/backup.sql
"
```

## 清理环境

```bash
# 停止并删除容器（保留数据卷）
docker compose down

# 停止并删除容器和数据卷
docker compose down -v

# 删除镜像
docker rmi sm4_c-opengauss-sm4
```

## 性能优化

### 1. 调整容器资源限制

编辑 `docker-compose.yml` 添加资源限制：

```yaml
services:
  opengauss-sm4:
    # ... 其他配置
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          memory: 1G
```

### 2. 优化数据库参数

```bash
# 进入容器
docker exec -it opengauss-sm4 bash

# 编辑配置文件
vi /var/lib/opengauss/data/postgresql.conf

# 常用优化参数
# shared_buffers = 256MB
# max_connections = 200
# work_mem = 4MB
```

## 生产环境建议

1. **修改默认密码**: 不要使用默认的 `Enmo@123` 密码
2. **启用 TLS**: 配置 SSL/TLS 加密连接
3. **限制网络访问**: 使用防火墙限制数据库端口访问
4. **定期备份**: 设置自动备份任务
5. **监控日志**: 配置日志收集和监控告警
6. **资源限制**: 根据实际负载设置合理的 CPU 和内存限制

## 技术支持

- OpenGauss 官方文档: https://docs.opengauss.org/
- Docker 官方文档: https://docs.docker.com/
- 项目 Issues: 在项目仓库提交问题

## 版本信息

- OpenGauss 版本: 5.0.0
- SM4 扩展版本: 1.0
- 文档更新日期: 2025-12-30
