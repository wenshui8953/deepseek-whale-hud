# DS 鲸鱼娘 · 一键安装脚本
# 双击 install.bat 运行；或: powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ps1  = Join-Path $root 'whale-hud.ps1'
$icon = Join-Path $root 'assets\whale.ico'
$pwsh = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$argsStr = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $ps1 + '"'

Write-Host ''
Write-Host '===== DS 鲸鱼娘 · 安装 =====' -ForegroundColor Cyan
Write-Host ''

# 1. API Key
$keyFile = Join-Path $root '.key'
if (-not (Test-Path $keyFile)) {
    Write-Host '首次使用需要配置 DeepSeek API Key'
    Write-Host '（在 https://platform.deepseek.com/api_keys 创建）'
    $k = Read-Host '请粘贴你的 API Key (sk-...)'
    if (-not $k -or -not $k.Trim().StartsWith('sk-')) {
        Write-Host '[X] Key 无效，安装中止' -ForegroundColor Red
        exit 1
    }
    [System.IO.File]::WriteAllText($keyFile, $k.Trim())
    Write-Host '[OK] .key 已创建' -ForegroundColor Green
} else {
    Write-Host '[OK] .key 已存在，跳过' -ForegroundColor Green
}

# 2. 桌面快捷方式
$ws = New-Object -ComObject WScript.Shell
$desktop = $ws.SpecialFolders('Desktop')
$lnkPath = Join-Path $desktop '鲸鱼娘.lnk'
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = $pwsh
$lnk.Arguments = $argsStr
$lnk.WorkingDirectory = $root
if (Test-Path $icon) { $lnk.IconLocation = $icon + ',0' }
$lnk.WindowStyle = 7
$lnk.Description = 'DS 鲸鱼娘 - DeepSeek 余额挂件'
$lnk.Save()
Write-Host "[OK] 桌面快捷方式已创建: $lnkPath" -ForegroundColor Green

# 3. 开机自启（可选）
$ans = Read-Host '设置开机自启？(y/n)'
if ($ans -match '^[Yy]') {
    $startup = [Environment]::GetFolderPath('Startup')
    $autoLnk = Join-Path $startup 'WhaleHUD.lnk'
    $al = $ws.CreateShortcut($autoLnk)
    $al.TargetPath = $pwsh
    $al.Arguments = $argsStr
    $al.WorkingDirectory = $root
    if (Test-Path $icon) { $al.IconLocation = $icon + ',0' }
    $al.WindowStyle = 7
    $al.Description = 'DS 鲸鱼娘 - 开机自启'
    $al.Save()
    Write-Host "[OK] 已设置开机自启（删除 $autoLnk 可取消）" -ForegroundColor Green
} else {
    Write-Host '[i] 已跳过开机自启'
}

# 4. 立即启动
Write-Host ''
Write-Host '正在启动鲸鱼娘...' -ForegroundColor Cyan
Start-Process -FilePath $pwsh -ArgumentList $argsStr -WorkingDirectory $root
Write-Host '[OK] 完成！鲸鱼娘应该已经出现在屏幕右下角了' -ForegroundColor Green
Write-Host ''
