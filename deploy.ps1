# SM4 Extension Docker Build and Deploy Script
# PowerShell 版本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenGauss SM4 Extension - Docker部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 停止并删除旧容器
Write-Host "清理旧容器和镜像..." -ForegroundColor Yellow
docker compose down -v 2>$null
docker rmi sm4_c-opengauss-sm4 2>$null

# 构建新镜像
Write-Host ""
Write-Host "构建新的Docker镜像..." -ForegroundColor Yellow
docker compose build --no-cache

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ 镜像构建成功!" -ForegroundColor Green
    
    # 启动容器
    Write-Host ""
    Write-Host "启动容器..." -ForegroundColor Yellow
    docker compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ 容器启动成功!" -ForegroundColor Green
        Write-Host ""
        Write-Host "等待数据库初始化（30秒）..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        # 创建扩展函数
        Write-Host ""
        Write-Host "创建SM4扩展函数..." -ForegroundColor Yellow
        docker exec opengauss-sm4 bash -c "export PGPASSWORD=Enmo@123; gsql -d postgres -U gaussdb -f /usr/local/opengauss/share/postgresql/extension/sm4--1.0.sql"
        
        # 测试
        Write-Host ""
        Write-Host "测试SM4功能..." -ForegroundColor Yellow
        docker exec opengauss-sm4 bash -c "export PGPASSWORD=Enmo@123; gsql -d postgres -U gaussdb -c 'SELECT sm4_c_encrypt_hex(''Hello OpenGauss!'', ''1234567890abcdef'');'"
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "部署完成！" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "连接信息:" -ForegroundColor Cyan
        Write-Host "  Host: localhost" -ForegroundColor White
        Write-Host "  Port: 15432" -ForegroundColor White
        Write-Host "  Database: postgres" -ForegroundColor White
        Write-Host "  User: gaussdb" -ForegroundColor White
        Write-Host "  Password: Enmo@123" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "✗ 容器启动失败" -ForegroundColor Red
        docker compose logs
    }
} else {
    Write-Host ""
    Write-Host "✗ 镜像构建失败" -ForegroundColor Red
}
