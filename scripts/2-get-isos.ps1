# Скрипт 3: скачивание ISO Ubuntu 24.04 на E:\vm-lab\iso
# Запуск: PowerShell (можно без админа).

$ErrorActionPreference = "Stop"
$isoDir = "E:\vm-lab\iso"
New-Item -ItemType Directory -Force -Path $isoDir | Out-Null

# Ubuntu Server 24.04.3
$urlServer = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
# Ubuntu Desktop 24.04.3
$urlDesktop = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-desktop-amd64.iso"

foreach ($u in @($urlServer, $urlDesktop)) {
    $dst = Join-Path $isoDir (Split-Path $u -Leaf)
    if (Test-Path $dst) {
        Write-Host "[SKIP] $dst уже есть"
        continue
    }
    Write-Host "[..] Скачиваю $u"
    # curl встроен в Windows 10/11
    curl.exe -L -o $dst $u --progress-bar
    Write-Host "[OK] $dst"
}
Get-ChildItem $isoDir | Select-Object Name, @{n='SizeGB';e={[math]::Round($_.Length/1GB,2)}}
