<#
.SYNOPSIS
    Installs PowerPlanSwitcher.ps1 as a scheduled task that runs at logon.

.DESCRIPTION
    Copies PowerPlanSwitcher.ps1 to C:\Scripts (if not already there) and
    registers a Task Scheduler task that launches it silently every time
    you log in. Requires the same GUID parameters as the main script so
    they can be passed through to the scheduled task's action.

.PARAMETER BatteryPlanGUID
    The GUID of the power plan to use on battery.

.PARAMETER ACPlanGUID
    The GUID of the power plan to use on AC power.

.PARAMETER ScriptDestination
    Where to install the script. Default: C:\Scripts\PowerPlanSwitcher.ps1

.EXAMPLE
    .\Install-PowerPlanSwitcher.ps1 -BatteryPlanGUID "a1841308-3541-4fab-bc81-f71556f20b4a" -ACPlanGUID "381b4222-f694-41f0-9685-ff5bb260df2e"

.NOTES
    Must be run as Administrator (task is registered with -RunLevel Highest).
    Run `powercfg /list` first to find your plan GUIDs.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BatteryPlanGUID,

    [Parameter(Mandatory = $true)]
    [string]$ACPlanGUID,

    [Parameter()]
    [string]$ScriptDestination = "C:\Scripts\PowerPlanSwitcher.ps1"
)

$ErrorActionPreference = "Stop"

# Ensure destination folder exists and copy the script there
$destDir = Split-Path -Path $ScriptDestination -Parent
New-Item -Path $destDir -ItemType Directory -Force | Out-Null

$sourceScript = Join-Path $PSScriptRoot "PowerPlanSwitcher.ps1"
Copy-Item -Path $sourceScript -Destination $ScriptDestination -Force

Write-Host "Copied PowerPlanSwitcher.ps1 to $ScriptDestination"

# Build the scheduled task
$argument = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptDestination`" -BatteryPlanGUID `"$BatteryPlanGUID`" -ACPlanGUID `"$ACPlanGUID`""

$action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument
$trigger  = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName "PowerPlanSwitcher" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Force | Out-Null

Write-Host "Scheduled task 'PowerPlanSwitcher' registered to run at logon."

$start = Read-Host "Start the task now? (y/n)"
if ($start -eq "y") {
    Start-ScheduledTask -TaskName "PowerPlanSwitcher"
    Write-Host "Task started."
}
