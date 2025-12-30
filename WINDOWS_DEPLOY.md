# Windows 环境部署指南

由于您的 Windows 环境中未安装 Docker，本文档提供了在 Windows 上部署 OpenGauss SM4 扩展的替代方案。

## 方案一：安装 Docker Desktop（推荐）

### 1. 安装 Docker Desktop

下载并安装 Docker Desktop for Windows：
https://www.docker.com/products/docker-desktop/

### 2. 启动 Docker Desktop

安装完成后，启动 Docker Desktop，等待其完全启动（右下角图标变绿）。

### 3. 验证安装

```powershell
docker --version
docker-compose --version
```

### 4. 运行部署

```powershell
# 进入项目目录
cd c:\data\code\sm4_c

# 启动容器
docker compose up -d

# 等待数据库启动（约30秒）
Start-Sleep -Seconds 30

# 创建SM4扩展函数
docker exec opengauss-sm4 bash -c "export PGPASSWORD=Enmo@123; gsql -d postgres -U gaussdb -f /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql"

# 测试功能
docker exec opengauss-sm4 bash -c "export PGPASSWORD=Enmo@123; gsql -d postgres -U gaussdb -c 'SELECT sm4_c_encrypt_hex(''Hello OpenGauss!'', ''1234567890abcdef'');'"
```

## 方案二：使用 WSL2 + Docker（推荐）

### 1. 启用 WSL2

```powershell
# 以管理员身份运行 PowerShell
wsl --install
```

### 2. 安装 Ubuntu

```powershell
wsl --install -d Ubuntu-22.04
```

### 3. 在 WSL2 中安装 Docker

```bash
# 进入 WSL2
wsl

# 更新包列表
sudo apt update
sudo apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装 Docker Compose
sudo apt install docker-compose -y

# 启动 Docker
sudo service docker start

# 添加当前用户到 docker 组
sudo usermod -aG docker $USER
```

### 4. 部署 SM4 扩展

```bash
# 复制项目到 WSL2（在 PowerShell 中执行）
# 注意：WSL2 可以访问 Windows 文件系统
cd /mnt/c/data/code/sm4_c

# 启动容器
docker compose up -d

# 运行验证脚本
chmod +x verify_sm4.sh
./verify_sm4.sh
```

## 方案三：直接安装 OpenGauss（Linux 服务器）

如果您有 Linux 服务器或虚拟机，可以直接安装 OpenGauss。

### 1. 下载 OpenGauss

访问 OpenGauss 官网下载最新版本：
https://opengauss.org/zh/download/

### 2. 安装 OpenGauss

参考官方文档进行安装：
https://docs.opengauss.org/zh/docs/latest/docs/installation/installation.html

### 3. 编译安装 SM4 扩展

```bash
# 上传 sm4_c 目录到服务器
scp -r c:\data\code\sm4_c user@server:/path/to/

# SSH 连接到服务器
ssh user@server

# 进入目录
cd /path/to/sm4_c

# 设置环境变量
export OGHOME=/usr/local/opengauss  # 根据实际安装路径调整
export PATH=$OGHOME/bin:$PATH
export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH

# 编译安装
make clean
make
sudo make install

# 重启数据库
gs_ctl restart

# 创建扩展函数
gsql -d postgres -f $OGHOME/share/postgresql/extension/sm4--1.0.sql

# 测试
gsql -d postgres -c "SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');"
```

## 方案四：使用虚拟机

### 1. 安装虚拟机软件

- VirtualBox (免费): https://www.virtualbox.org/
- VMware Workstation Player (免费): https://www.vmware.com/

### 2. 创建 Linux 虚拟机

推荐使用：
- Ubuntu 22.04 LTS
- CentOS 8 Stream
- openEuler 22.03 LTS

### 3. 在虚拟机中部署

按照方案三的步骤在虚拟机中部署 OpenGauss 和 SM4 扩展。

## 快速验证方案（无需安装）

### 使用在线 Docker 环境

可以使用以下在线 Docker 环境测试：

1. **Play with Docker** (需要 Docker Hub 账号)
   https://labs.play-with-docker.com/

2. 操作步骤：
   - 创建新实例
   - 克隆代码：`git clone <your-repo-url>`
   - 进入目录：`cd sm4_c`
   - 运行：`docker-compose up -d`
   - 验证：`./verify_sm4.sh`

## 推荐方案对比

| 方案           | 难度 | 性能 | 隔离性 | 推荐度 |
| -------------- | ---- | ---- | ------ | ------ |
| Docker Desktop | 简单 | 中等 | 好     | ⭐⭐⭐⭐⭐  |
| WSL2 + Docker  | 中等 | 高   | 好     | ⭐⭐⭐⭐⭐  |
| 直接安装       | 较难 | 最高 | 一般   | ⭐⭐⭐    |
| 虚拟机         | 中等 | 中等 | 很好   | ⭐⭐⭐⭐   |

## 后续步骤

部署完成后，请参考以下文档：

- [快速开始指南](QUICKSTART.md) - 快速测试功能
- [Docker 部署文档](DOCKER_DEPLOY.md) - Docker 详细配置
- [README](README.md) - 完整功能说明

## 常见问题

### Q1: Docker Desktop 启动很慢怎么办？

确保启用了 Windows 虚拟化功能（Hyper-V 或 WSL2）。在 BIOS 中启用 VT-x/AMD-V。

### Q2: WSL2 无法启动 Docker？

```bash
# 重启 WSL2
wsl --shutdown
wsl

# 启动 Docker
sudo service docker start
```

### Q3: 端口 15432 被占用？

修改 `docker-compose.yml` 中的端口映射：
```yaml
ports:
  - "25432:5432"  # 改为其他未使用的端口
```

### Q4: 如何在 Windows 上连接 OpenGauss？

1. 安装 PostgreSQL 客户端工具（如 DBeaver, pgAdmin）
2. 连接参数：
   - Host: localhost
   - Port: 15432
   - Database: postgres
   - User: gaussdb
   - Password: Enmo@123

## 技术支持

如遇到问题，请检查：
1. Windows 版本是否支持（Windows 10/11 专业版或企业版）
2. 是否启用了虚拟化技术
3. 防火墙是否允许 Docker 访问
4. 磁盘空间是否足够（至少 5GB）

更多帮助请参考：
- OpenGauss 官方文档：https://docs.opengauss.org/
- Docker 官方文档：https://docs.docker.com/desktop/windows/
