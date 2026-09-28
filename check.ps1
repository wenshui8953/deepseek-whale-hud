$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$keyPath = Join-Path $PSScriptRoot '.key'
if (-not (Test-Path $keyPath)) {
    Write-Host '未找到 .key 文件，请把 API Key 写入同目录 .key 文件' -ForegroundColor Red
    exit 1
}
$key = (Get-Content $keyPath -Raw).Trim()

try {
    $r = Invoke-RestMethod -Uri 'https://api.deepseek.com/user/balance' `
        -Headers @{ Authorization = "Bearer $key"; Accept = 'application/json' } `
        -TimeoutSec 15
} catch {
    Write-Host ('查询失败: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '  DeepSeek API 余额'
Write-Host '  =============================='
$totalCny = 0.0
foreach ($b in $r.balance_infos) {
    Write-Host ('  [{0}] 总余额 {1}   充值 {2}   赠送 {3}' -f `
        $b.currency, $b.total_balance, $b.topped_up_balance, $b.granted_balance)
    if ($b.currency -eq 'CNY') { $totalCny += [double]$b.total_balance }
    elseif ($b.currency -eq 'USD') { $totalCny += [double]$b.total_balance * 7.2 }
}
Write-Host '  =============================='
if (-not $r.is_available) {
    Write-Host '  状态: 不可用（可能欠费或账户异常）' -ForegroundColor Red
} elseif ($totalCny -lt 5) {
    Write-Host ('  折合约 CNY {0:N2}，余额偏低，注意及时充值' -f $totalCny) -ForegroundColor Yellow
} else {
    Write-Host ('  折合约 CNY {0:N2}，余额充足' -f $totalCny) -ForegroundColor Green
}
Write-Host ''
