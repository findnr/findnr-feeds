# 快速部署脚本 (Windows PowerShell)
# 用法: .\deploy.ps1 <router_ip> [user]
# 示例: .\deploy.ps1 192.168.1.1 root

param(
    [string]$RouterIP = "192.168.1.1",
    [string]$RouterUser = "root"
)

$AppDir = Join-Path $PSScriptRoot "root"

Write-Host "========================================"
Write-Host "部署 luci-app-cymonline 到 ${RouterUser}@${RouterIP}"
Write-Host "========================================"

if (-not (Test-Path $AppDir)) {
    Write-Host "错误: 找不到 root 目录" -ForegroundColor Red
    exit 1
}

Write-Host "[1/4] 复制配置文件..."
scp "$AppDir\etc\config\cymonline" "${RouterUser}@${RouterIP}:/etc/config/"

Write-Host "[2/4] 复制服务脚本..."
scp "$AppDir\etc\init.d\cymonline" "${RouterUser}@${RouterIP}:/etc/init.d/"
ssh "${RouterUser}@${RouterIP}" "chmod +x /etc/init.d/cymonline"

Write-Host "[3/4] 复制核心文件..."
ssh "${RouterUser}@${RouterIP}" "mkdir -p /usr/lib/cymonline /usr/lib/lua/cymonline /usr/lib/lua/luci/controller /usr/lib/lua/luci/view/cymonline"

scp "$AppDir\usr\lib\cymonline\network.sh" "${RouterUser}@${RouterIP}:/usr/lib/cymonline/"
ssh "${RouterUser}@${RouterIP}" "chmod +x /usr/lib/cymonline/network.sh"

scp "$AppDir\usr\lib\lua\cymonline\core.lua" "${RouterUser}@${RouterIP}:/usr/lib/lua/cymonline/"
scp "$AppDir\usr\lib\lua\luci\controller\cymonline.lua" "${RouterUser}@${RouterIP}:/usr/lib/lua/luci/controller/"
scp "$AppDir\usr\lib\lua\luci\view\cymonline\status.htm" "${RouterUser}@${RouterIP}:/usr/lib/lua/luci/view/cymonline/"

Write-Host "[4/4] 重启 LuCI 服务..."
ssh "${RouterUser}@${RouterIP}" "/etc/init.d/cymonline enable 2>/dev/null; /etc/init.d/cymonline restart 2>/dev/null; /etc/init.d/uhttpd restart; rm -rf /tmp/luci-*"

Write-Host ""
Write-Host "========================================"
Write-Host "部署完成！" -ForegroundColor Green
Write-Host "访问: http://${RouterIP}/cgi-bin/luci/admin/status/cymonline"
Write-Host "========================================"
