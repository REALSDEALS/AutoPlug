# Restarts the Wi-Fi adapter (disable, then enable) and flushes the DNS cache as a precaution. 

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'This script needs administrator rights. Start it through RestartWifi.bat.' -ForegroundColor Red
    exit 1
}

# NdisPhysicalMedium 9 = Native 802.11 (Wi-Fi), 1 = older wireless LAN drivers. Locale-independent, unlike the adapter name.
$adapters = @(Get-NetAdapter -Physical | Where-Object { $_.NdisPhysicalMedium -in 9, 1 })
if (-not $adapters) {
    Write-Host 'No Wi-Fi adapter found on this computer.' -ForegroundColor Yellow
    exit 1
}

$failed = 0
foreach ($a in $adapters) {
    Write-Host ''
    Write-Host "Adapter: $($a.Name) ($($a.InterfaceDescription))" -ForegroundColor Cyan

    try {
        if ($a.Status -eq 'Disabled') {
            Write-Host 'Adapter was disabled; enabling it.'
        } else {
            Write-Host 'Disabling...'
            Disable-NetAdapter -Name $a.Name -Confirm:$false
            Start-Sleep -Seconds 3
        }

        Write-Host 'Enabling...'
        Enable-NetAdapter -Name $a.Name -Confirm:$false
    } catch {
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
        # Is the adapter turned back on? If not: 
        try { Enable-NetAdapter -Name $a.Name -Confirm:$false } catch { }
        $failed++
        continue
    }

    # Wait for Wi-Fi to reconnect (up to 30 seconds (Legacy Latency)) then report to user:
    Write-Host 'Waiting for connection...'
    $up = $false
    foreach ($i in 1..30) {
        if ((Get-NetAdapter -Name $a.Name).Status -eq 'Up') { $up = $true; break }
        Start-Sleep -Seconds 1
    }

    if ($up) {
        Write-Host '  Connected.' -ForegroundColor Green
    } else {
        Write-Host '  Adapter is enabled but not connected (no known network in range, or Wi-Fi is switched off).' -ForegroundColor Yellow
        $failed++
    }
}

# Flushing the DNS as a last step: 
Write-Host ''
Write-Host 'Flushing DNS cache...'
Clear-DnsClientCache
Write-Host '  Done.' -ForegroundColor Green

# Writeback summary and result to user:
Write-Host ''
if ($failed -eq 0) {
    Write-Host 'Wi-Fi restarted successfully.' -ForegroundColor Green
} else {
    Write-Host 'Wi-Fi was restarted, but the adapter is not connected. Check the network, airplane mode and the physical Wi-Fi switch.' -ForegroundColor Yellow
    exit 1
}
