# Скрипт 1: сеть лабы на хосте Hyper-V
# Создаёт Internal switch LabSwitch, назначает хосту 192.168.100.1, включает NAT.
# Запуск: PowerShell от имени администратора.

$ErrorActionPreference = "Stop"

# 1. Internal switch
if (-not (Get-VMSwitch -Name "LabSwitch" -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name "LabSwitch" -SwitchType Internal | Out-Null
    Write-Host "[OK] LabSwitch (Internal) создан"
} else {
    Write-Host "[SKIP] LabSwitch уже существует"
}

# 2. IP хоста на vEthernet (LabSwitch)
$ifIndex = (Get-NetAdapter | Where-Object Name -like "*LabSwitch*").ifIndex
$ip = (Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
       Where-Object IPAddress -eq "192.168.100.1")
if (-not $ip) {
    New-NetIPAddress -IPAddress 192.168.100.1 -PrefixLength 24 -InterfaceIndex $ifIndex | Out-Null
    Write-Host "[OK] хосту назначен 192.168.100.1"
} else {
    Write-Host "[SKIP] 192.168.100.1 уже назначен"
}

# 3. NAT
if (-not (Get-NetNat -Name "LabNAT" -ErrorAction SilentlyContinue)) {
    New-NetNat -Name "LabNAT" -InternalIPInterfaceAddressPrefix 192.168.100.0/24 | Out-Null
    Write-Host "[OK] NAT LabNAT (192.168.100.0/24) создан"
} else {
    Write-Host "[SKIP] NAT LabNAT уже существует"
}
