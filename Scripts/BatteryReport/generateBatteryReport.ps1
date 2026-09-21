# This script generates a Windows battery report (powercfg /batteryreport) and opens it in the default browser.

$ErrorActionPreference = 'Stop'

# It is known that VM's and desktop pc's dopn't have a battery, normally the powercfg module would fail and give a cryptic message back to the user. In this part it will throw an human-readable error back to the user.
if (-not (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)) {
    Write-Host 'No battery detected on this computer.' -ForegroundColor Yellow
    exit 1
}

$reportPath = Join-Path $env:TEMP 'battery-report.html'

Write-Host 'Generating battery report...'
powercfg /batteryreport /output $reportPath | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $reportPath)) {
    Write-Host 'Failed to generate the battery report.' -ForegroundColor Red
    exit 1
}

# Quick health summary in the console (if possible.):
try {
    $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData).DesignedCapacity | Select-Object -First 1
    $full   = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity).FullChargedCapacity | Select-Object -First 1
    if ($design -and $full) {
        $health = [math]::Round(100 * $full / $design, 1)
        Write-Host ''
        Write-Host "Design capacity:      $design mWh"
        Write-Host "Full charge capacity: $full mWh"
        Write-Host "Battery health:       $health %"
    }
} catch {
    # Writeback to the user, a quick summary of the script:
}

Write-Host ''
Write-Host "Report saved to: $reportPath"
Start-Process $reportPath
