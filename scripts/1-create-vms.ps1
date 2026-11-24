# Скрипт 2: создание 4 виртуальных машин Hyper-V (исправленная версия)

$ErrorActionPreference = "Stop"
$labDir = "E:\vm-lab"
$isoServer = "$labDir\iso\ubuntu-24.04.5-live-server-amd64.iso"
$isoDesktop = "$labDir\iso\ubuntu-24.04.5.1-desktop-amd64.iso"

$vms = @(
    @{ Name = "VM1"; Iso = $isoDesktop; Cpu = 2; RamGB = 4;  DiskGB = 40 },
    @{ Name = "VM2"; Iso = $isoServer;  Cpu = 1; RamGB = 1;  DiskGB = 20 },
    @{ Name = "VM3"; Iso = $isoServer;  Cpu = 2; RamGB = 2;  DiskGB = 30 },
    @{ Name = "VM4"; Iso = $isoServer;  Cpu = 4; RamGB = 8;  DiskGB = 40 }
)

foreach ($v in $vms) {
    $dir = "$labDir\vms\$($v.Name)"
    if (Get-VM -Name $v.Name -ErrorAction SilentlyContinue) {
        Write-Host "[SKIP] $($v.Name) exists"
        continue
    }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    Write-Host "[..] Creating $($v.Name)"
    New-VM -Name $v.Name -Generation 2 -MemoryStartupBytes ($v.RamGB * 1GB) -NewVHDPath "$dir\$($v.Name).vhdx" -NewVHDSizeBytes ($v.DiskGB * 1GB) -SwitchName "LabSwitch" | Out-Null

    Set-VM -Name $v.Name -ProcessorCount $v.Cpu -StaticMemory
    Set-VMFirmware -VMName $v.Name -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
    Add-VMDvdDrive -Name $v.Name -Path $v.Iso
    $dvd = Get-VMDvdDrive -VMName $v.Name
    Set-VMFirmware -VMName $v.Name -FirstBootDevice $dvd
    Set-VM -Name $v.Name -AutomaticCheckpointsEnabled $false -CheckpointType Disabled

    Write-Host "[OK] $($v.Name): CPU=$($v.Cpu) RAM=$($v.RamGB)GB Disk=$($v.DiskGB)GB ISO=$(Split-Path $v.Iso -Leaf)"
}
Get-VM | Format-Table Name, State, ProcessorCount, MemoryAssigned
