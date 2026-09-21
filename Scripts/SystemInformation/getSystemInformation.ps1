# This script will show the user what the specifications of the computer are:

$ErrorActionPreference = 'Stop'

function Write-Section($title) {
    Write-Host ''
    Write-Host $title -ForegroundColor Cyan
    Write-Host ('-' * $title.Length) -ForegroundColor Cyan
}

function Write-Row($label, $value) {
    Write-Host ("{0,-16}{1}" -f "${label}:", $value)
}

# From SMBIOS memory type codes to a human-readable name:
$memoryTypes = @{ 24 = 'DDR3'; 26 = 'DDR4'; 27 = 'LPDDR'; 28 = 'LPDDR2'; 29 = 'LPDDR3'; 30 = 'LPDDR4'; 34 = 'DDR5'; 35 = 'LPDDR5' }

$cs   = Get-CimInstance -ClassName Win32_ComputerSystem
$bios = Get-CimInstance -ClassName Win32_BIOS
$os   = Get-CimInstance -ClassName Win32_OperatingSystem

Write-Section 'System'
Write-Row 'Computer' $env:COMPUTERNAME
Write-Row 'Manufacturer' $cs.Manufacturer
Write-Row 'Model' $cs.Model
Write-Row 'Serial number' $bios.SerialNumber
Write-Row 'BIOS' "$($bios.SMBIOSBIOSVersion) ($($bios.ReleaseDate.ToString('yyyy-MM-dd')))"
Write-Row 'Windows' (($os.Caption -replace '^Microsoft\s+', '') + " ($($os.OSArchitecture))")

Write-Section 'Processor'
foreach ($cpu in Get-CimInstance -ClassName Win32_Processor) {
    Write-Row 'CPU' ($cpu.Name -replace '\s+', ' ').Trim()
    Write-Row 'Cores' "$($cpu.NumberOfCores) cores, $($cpu.NumberOfLogicalProcessors) threads"
}

Write-Section 'Memory'
$modules = @(Get-CimInstance -ClassName Win32_PhysicalMemory)
$totalGB = [math]::Round(($modules | Measure-Object -Property Capacity -Sum).Sum / 1GB)
Write-Row 'Installed' "$totalGB GB"
foreach ($m in $modules) {
    $type  = $memoryTypes[[int]$m.SMBIOSMemoryType]
    $speed = if ($m.ConfiguredClockSpeed) { $m.ConfiguredClockSpeed } else { $m.Speed }
    $desc  = (@("$([math]::Round($m.Capacity / 1GB)) GB", $type, $(if ($speed) { "$speed MHz" })) | Where-Object { $_ }) -join ' '
    Write-Row 'Module' $desc
}

Write-Section 'Storage'
# Differentiating and deciding what is a physical disk or a volume.
# Physical disk sizes use decimal GB's (links/matches the label on the drive); volumes use binary GB's (links/matches File Explorer):
foreach ($disk in Get-PhysicalDisk | Sort-Object DeviceId) {
    $type = if ($disk.MediaType -in 'SSD', 'HDD') { $disk.MediaType } else { $disk.BusType }
    Write-Row 'Disk' "$($disk.FriendlyName) - $([math]::Round($disk.Size / 1e9)) GB $type"
}
foreach ($vol in Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3') {
    $sizeGB = [math]::Round($vol.Size / 1GB)
    $freeGB = [math]::Round($vol.FreeSpace / 1GB)
    Write-Row "Drive $($vol.DeviceID.TrimEnd(':'))" "$freeGB GB free of $sizeGB GB"
}

Write-Section 'Graphics'
foreach ($gpu in Get-CimInstance -ClassName Win32_VideoController) {
    Write-Row 'GPU' $gpu.Name
}
