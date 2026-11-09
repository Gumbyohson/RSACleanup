<#
.SYNOPSIS
    HPLHAgent-Cleanup.ps1 v1.0.0
    Removes the HP WXP Insights / Touchpoint analytics components that leak RSA machine keys
    into C:\ProgramData\Microsoft\Crypto\RSA\S-1-5-18 (about 4 files per minute).

.DESCRIPTION
    Default is REPORT-ONLY: shows what is installed and what would be removed.
    Add -Remove to actually do it. Order: disable tasks, disable + stop services, kill processes,
    uninstall apps, then delete any service/task left behind.

    Scope (only the WXP Insights / analytics chain):
      Services : hpLHAgent (WXP Insights Agent), HpTouchpointAnalyticsService
      Tasks    : WxpInsightsDeviceLogon, WXPInsightsUpdater (any task matching WXP*Insights*)
      Processes: LHAgent, TouchpointAnalyticsClientService
      Apps     : WXP Insights Agent, WXP Insights Analytics, WXP Insights Analytics - Dependencies
    NOT touched: HP One Agent and any other HP software. Existing RSA key files are not cleaned
    up here; use Clear-MachineKeys.ps1 for that.

.PARAMETER Remove
    Perform the removal. Without it nothing is changed.

.NOTES
    Run elevated or as SYSTEM. Exit code: 0 = ok / report only, 1 = something remains or failed.
    Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "c:\temp\HPLHAgent-Cleanup.ps1" -Remove
#>
[CmdletBinding()]
param([switch]$Remove)

$ScriptName = 'HPLHAgent-Cleanup.ps1'
$Version    = '1.0.0'
$Services   = 'hpLHAgent', 'HpTouchpointAnalyticsService'
$TaskFilter = 'WXP*Insights*'
$Processes  = 'LHAgent', 'TouchpointAnalyticsClientService'
# Uninstall order: agent first, shared dependencies last
$AppNames   = 'WXP Insights Agent', 'WXP Insights Analytics', 'WXP Insights Analytics - Dependencies'

"$ScriptName v$Version  |  Executing PC: $env:COMPUTERNAME  |  $(Get-Date -Format s)"
if ($Remove) { 'Mode: REMOVE' } else { 'Mode: REPORT ONLY (add -Remove to make changes)' }

$failed = $false

function Get-TargetApps {
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    foreach ($name in $AppNames) {
        Get-ItemProperty $keys -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $name }
    }
}

"`n== Found before =="
$apps = @(Get-TargetApps)
$apps | Select-Object DisplayName, DisplayVersion, PSChildName | Format-Table -AutoSize | Out-String
Get-Service $Services -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String
Get-ScheduledTask -TaskName $TaskFilter -ErrorAction SilentlyContinue | Select-Object TaskPath, TaskName, State | Format-Table -AutoSize | Out-String

if (-not $Remove) { exit 0 }

"== 1. Disable tasks =="
Get-ScheduledTask -TaskName $TaskFilter -ErrorAction SilentlyContinue | ForEach-Object {
    "  Disable task $($_.TaskName)"
    $_ | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
}

"== 2. Disable and stop services =="
foreach ($s in $Services) {
    if (Get-Service $s -ErrorAction SilentlyContinue) {
        "  Disable/stop $s"
        Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service $s -Force -ErrorAction SilentlyContinue
    }
}

"== 3. Stop processes =="
Get-Process $Processes -ErrorAction SilentlyContinue | ForEach-Object {
    "  Kill $($_.Name) (PID $($_.Id))"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

"== 4. Uninstall apps =="
foreach ($app in $apps) {
    $cmd = $null; $arguments = $null
    if ($app.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') {
        $cmd = "$env:SystemRoot\System32\msiexec.exe"
        $arguments = "/x $($app.PSChildName) /qn /norestart"
    }
    elseif ($app.QuietUninstallString) {
        if ($app.QuietUninstallString -match '^\s*"([^"]+)"\s*(.*)$') { $cmd = $Matches[1]; $arguments = $Matches[2] }
    }
    if (-not $cmd) {
        "  $($app.DisplayName): no silent uninstall method found. Manual uninstall string: $($app.UninstallString)"
        $failed = $true
        continue
    }
    "  Uninstalling $($app.DisplayName) $($app.DisplayVersion)"
    $p = Start-Process $cmd -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    "    exit code $($p.ExitCode)"
    if ($p.ExitCode -notin 0, 1605, 1641, 3010) { $failed = $true }
}

"== 5. Remove leftovers =="
foreach ($s in $Services) {
    if (Get-Service $s -ErrorAction SilentlyContinue) {
        "  Deleting leftover service $s"
        & sc.exe delete $s | Out-Null
    }
}
Get-ScheduledTask -TaskName $TaskFilter -ErrorAction SilentlyContinue | ForEach-Object {
    "  Unregistering leftover task $($_.TaskName)"
    $_ | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
}

"`n== Found after =="
$left = @(Get-TargetApps)
$left | Select-Object DisplayName, DisplayVersion | Format-Table -AutoSize | Out-String
Get-Service $Services -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String
Get-ScheduledTask -TaskName $TaskFilter -ErrorAction SilentlyContinue | Select-Object TaskName, State | Format-Table -AutoSize | Out-String

if ($left.Count -gt 0) { $failed = $true }
if ($failed) { 'RESULT: items remain or an uninstall failed. Review output above.'; exit 1 }
'RESULT: WXP Insights / HP LHAgent components removed.'
exit 0
