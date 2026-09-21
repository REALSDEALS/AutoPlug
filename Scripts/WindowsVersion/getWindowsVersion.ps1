# Script that writes back to the user what the version, build number and edition is of their Windows license.
# It will also throwback if the version that the user has installed is still receiving security updates etc. 

$ErrorActionPreference = 'Stop'

# Here I am using 'third-party' sources, I see this function as a 'nice-to-have'. I might delete it at a later stage if it isn't working as intended when the script becomes 'outdated'.
# End of servicing per feature update, split by edition group (Home/Pro vs Enterprise/Education).
# Source: https://endoflife.date/windows (checked 21-09-2026); official dates: https://learn.microsoft.com/lifecycle
## This needs to be updated if Microsoft releases a new version. If a version is missing it will be reported as unknown: (Sorted old to new as Microsoft does the same)
$endOfSupport = @{
    '10-22H2' = @{ Home = '2025-10-14'; Ent = '2025-10-14' }
    '11-22H2' = @{ Home = '2024-10-08'; Ent = '2025-10-14' }
    '11-23H2' = @{ Home = '2025-11-11'; Ent = '2026-11-10' }
    '11-24H2' = @{ Home = '2026-10-13'; Ent = '2027-10-12' }
    '11-25H2' = @{ Home = '2027-10-12'; Ent = '2028-10-10' }
    '11-26H1' = @{ Home = '2028-03-14'; Ent = '2029-03-13' }
}
# If a version is older than the first entry per Windows gen then it is outdated and out of support by definition:
$oldestTrackedBuild = @{ '10' = 19045; '11' = 22621 }

$warnDays = 90

$os  = Get-CimInstance -ClassName Win32_OperatingSystem
$reg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

# Using Win32_OperatingSystem.Caption, to my knowledge this is a reliable source.
$edition = $os.Caption -replace '^Microsoft\s+', ''
# Scouring for two strings 'DisplayVersion' and 'ReleaseId':
## On recent builds (for example 24H2) the string 'DisplayVersion' is being used; on older version the string 'ReleaseId' is being used, (for example 1909).
$version = if ($reg.DisplayVersion) { $reg.DisplayVersion } else { $reg.ReleaseId }
$buildNumber = [int]$reg.CurrentBuildNumber
$build   = "$buildNumber.$($reg.UBR)"

Write-Host ''
Write-Host "Windows:      $edition"
Write-Host "Version:      $version"
Write-Host "OS build:     $build"
Write-Host "Architecture: $($os.OSArchitecture)"
Write-Host "Computer:     $env:COMPUTERNAME"
Write-Host ''

# If rule! If Edition is Pro Education / Pro for Workstations THEN follow the Enterprise/Education lifecycle:
$editionId = $reg.EditionID
$generation = if ($buildNumber -ge 22000) { '11' } else { '10' }

if ($editionId -match 'S(N)?$' -and $editionId -like '*Enterprise*') {
    Write-Host 'Support status: LTSC edition - it follows its own, much longer lifecycle.' -ForegroundColor Cyan
    Write-Host 'Check https://learn.microsoft.com/lifecycle for the exact end date.'
    exit 0
}

$group = if ($editionId -match '^(Enterprise|Education|ProfessionalEducation|ProfessionalWorkstation|IoTEnterprise)') { 'Ent' } else { 'Home' }
$entry = $endOfSupport["$generation-$version"]

if ($entry) {
    $endDate  = [datetime]::ParseExact($entry[$group], 'yyyy-MM-dd', $null)
    $daysLeft = [int][math]::Floor(($endDate - (Get-Date).Date).TotalDays)
    $endText  = $endDate.ToString('d MMMM yyyy', [Globalization.CultureInfo]::InvariantCulture)

    if ($daysLeft -lt 0) {
        Write-Host "Support status: OUT OF SUPPORT since $endText." -ForegroundColor Red
        Write-Host 'This version no longer receives security updates. Upgrade to a supported version.'
        if ($generation -eq '10') { Write-Host 'Extended Security Updates (ESU) may still apply if this device is enrolled.' }
    } elseif ($daysLeft -le $warnDays) {
        Write-Host "Support status: ENDING SOON - support ends on $endText ($daysLeft days left)." -ForegroundColor Yellow
        Write-Host 'Plan an upgrade to a newer version.'
    } else {
        Write-Host "Support status: Supported until $endText ($daysLeft days left)." -ForegroundColor Green
    }
} elseif ($buildNumber -lt $oldestTrackedBuild[$generation]) {
    Write-Host 'Support status: OUT OF SUPPORT - this version is too old to receive security updates.' -ForegroundColor Red
    Write-Host 'Upgrade to a supported version.'
} else {
    Write-Host "Support status: UNKNOWN - version $version is not in this script's table." -ForegroundColor Yellow
    Write-Host 'It is probably newer than the script. Check https://learn.microsoft.com/lifecycle'
}
