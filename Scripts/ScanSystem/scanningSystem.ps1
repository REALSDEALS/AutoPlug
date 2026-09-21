# Scans Windows for corrupted system files and repairs what it can, this makes use of the standard Windows modules:
#   1. DISM  - checks the Windows component store and repairs it when needed.
#   2. SFC   - checks the protected system files and repairs them from the component store.
#   3. CHKDSK - read-only scan of the system drive for file system errors.
## Warning! Since this is a combined 'search, check and repair' script it can take multiple minutes, estimated between 5 to 15 minutes.

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'This script needs administrator rights. Start it through ScanSystem.bat.' -ForegroundColor Red
    exit 1
}

function Write-Step($text) {
    Write-Host ''
    Write-Host $text -ForegroundColor Cyan
    Write-Host ('-' * $text.Length) -ForegroundColor Cyan
}

$problems = 0

Write-Host 'Keep the computer plugged in and do not close this window. This can take 5-15 minutes.'

# --- 1. DISM: component store -------------------------------------------------------------
Write-Step 'Step 1/3: DISM - checking the Windows component store'
try {
    $state = "$((Repair-WindowsImage -Online -ScanHealth).ImageHealthState)"

    if ($state -eq 'Repairable') {
        Write-Host 'Corruption found. Repairing (this needs an internet connection)...' -ForegroundColor Yellow
        $state = "$((Repair-WindowsImage -Online -RestoreHealth).ImageHealthState)"
        if ($state -eq 'Healthy') {
            Write-Host 'Component store repaired.' -ForegroundColor Green
        } else {
            Write-Host "Repair did not fully succeed (state: $state)." -ForegroundColor Red
            $problems++
        }
    } elseif ($state -eq 'Healthy') {
        Write-Host 'No component store corruption detected.' -ForegroundColor Green
    } else {
        Write-Host "Component store cannot be repaired (state: $state). An in-place repair install of Windows is needed." -ForegroundColor Red
        $problems++
    }
} catch {
    Write-Host "DISM failed: $($_.Exception.Message)" -ForegroundColor Red
    $problems++
}

# --- 2. SFC: system files -----------------------------------------------------------------
# SFC's own message is shown as-is:
Write-Step 'Step 2/3: SFC - checking protected system files'
sfc /scannow
Write-Host ''
Write-Host 'Read the SFC result above. Details: %WinDir%\Logs\CBS\CBS.log'

# --- 3. CHKDSK: file system ---------------------------------------------------------------
Write-Step "Step 3/3: CHKDSK - scanning $env:SystemDrive for file system errors (read-only)"
chkdsk $env:SystemDrive /scan
if ($LASTEXITCODE -eq 0) {
    Write-Host 'No file system errors found.' -ForegroundColor Green
} else {
    Write-Host "CHKDSK reported a problem (exit code $LASTEXITCODE). To repair, run 'chkdsk $env:SystemDrive /f' and restart." -ForegroundColor Yellow
    $problems++
}

# Writeback to the user:
Write-Host ''
if ($problems -eq 0) {
    Write-Host 'Scan finished. DISM and CHKDSK found no problems; check the SFC message above.' -ForegroundColor Green
} else {
    Write-Host "Scan finished. $problems step(s) reported problems - see the messages above." -ForegroundColor Yellow
    exit 1
}
