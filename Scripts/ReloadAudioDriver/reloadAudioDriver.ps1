# Reloads the audio drivers by disabling and re-enabling every audio device.

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'This script needs administrator rights. Start it through ReloadAudioDriver.bat.' -ForegroundColor Red
    exit 1
}

# Class MEDIA = "Sound, video and game controllers". Left out on purpose:
# SW\*   - Windows system components (e.g. Microsoft Streaming Service Proxy)
# ROOT\* - virtual devices from software (Steam, NVIDIA, ...)
# Devices the user has disabled by hand are being skipped so that they aren't switched back on.
$all = @(Get-PnpDevice -Class MEDIA -PresentOnly | Where-Object { $_.InstanceId -notlike 'SW\*' -and $_.InstanceId -notlike 'ROOT\*' })
$devices = @($all | Where-Object { $_.Problem -ne 'CM_PROB_DISABLED' })

if (-not $devices) {
    Write-Host 'No audio devices found.' -ForegroundColor Yellow
    exit 1
}

Write-Host 'Audio devices to reload:'
$devices | ForEach-Object { Write-Host "  - $($_.FriendlyName) [$($_.Status)]" }
foreach ($skipped in $all | Where-Object { $_.Problem -eq 'CM_PROB_DISABLED' }) {
    Write-Host "  (skipped, disabled by user: $($skipped.FriendlyName))" -ForegroundColor DarkGray
}
Write-Host ''
Write-Host 'Sound will be interrupted for a few seconds.'

Write-Host 'Disabling...'
foreach ($d in $devices) {
    try {
        Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false
    } catch {
        Write-Host "  Could not disable $($d.FriendlyName): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
Start-Sleep -Seconds 3

# Re-enable every device that we have disabled in the previous step - also try to re-enable if an error was reported for a device.
Write-Host 'Enabling...'
foreach ($d in $devices) {
    try {
        Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false
    } catch {
        Write-Host "  Could not enable $($d.FriendlyName): $($_.Exception.Message)" -ForegroundColor Red
    }
}
Start-Sleep -Seconds 3

# Writeback the result of the script:
Write-Host ''
Write-Host 'Result:'
$failed = 0
foreach ($d in $devices) {
    $now = Get-PnpDevice -InstanceId $d.InstanceId
    if ($now.Status -eq 'OK') {
        Write-Host "  OK     $($now.FriendlyName)" -ForegroundColor Green
    } else {
        $failed++
        Write-Host "  FAILED $($now.FriendlyName) [$($now.Status), $($now.Problem)]" -ForegroundColor Red
    }
}

Write-Host ''
if ($failed -eq 0) {
    Write-Host 'All audio devices were reloaded successfully.' -ForegroundColor Green
} else {
    Write-Host "$failed device(s) did not come back. Restart the computer or reinstall the audio driver." -ForegroundColor Red
    exit 1
}
