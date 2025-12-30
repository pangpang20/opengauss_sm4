# OpenGauss SM4 扩展 - 快速开始

## 一键部署（推荐）

### Windows PowerShell

```powershell
# 1. 构建并启动容器
docker compose up -d

# 2. 等待30秒让数据库启动
Start-Sleep -Seconds 30

# 3. 创建SM4扩展函数
docker exec opengauss-sm4 bash -c @"
export PGPASSWORD=Enmo@123
gsql -d postgres -U gaussdb -f /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql
"@

# 4. 测试SM4功能
docker exec opengauss-sm4 bash -c @"
export PGPASSWORD=Enmo@123
gsql -d postgres -U gaussdb -c \"SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');\"
gsql -d postgres -U gaussdb -c \"SELECT sm4_c_decrypt_hex(sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef'), '1234567890abcdef');\"
"@
```

### Linux/Mac Bash

```bash
# 1. 构建并启动容器
docker compose up -d

# 2. 运行验证脚本
chmod +x verify_sm4.sh
./verify_sm4.sh
```

## 手动连接测试

### 从主机连接（需要 gsql 客户端）

```bash
PGPASSWORD=Enmo@123 gsql -h localhost -p 15432 -d postgres -U gaussdb
```

### 进入容器内连接

```bash
docker exec -it opengauss-sm4 bash
su - omm
gsql -d postgres
```

### 测试 SQL

```sql
-- 创建函数（如果尚未创建）
\i /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql

-- ECB 加密测试
SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');

-- 解密验证
SELECT sm4_c_decrypt_hex(
    sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef'), 
    '1234567890abcdef'
);

-- 查看所有函数
\df sm4_c*
```

## 问题排查

查看容器日志：
```bash
docker compose logs -f opengauss-sm4
```

重新构建：
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

## 详细文档

- [完整部署指南](DOCKER_DEPLOY.md)
- [功能说明](README.md)
