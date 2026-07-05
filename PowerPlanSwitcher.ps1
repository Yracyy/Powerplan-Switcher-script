<#
.SYNOPSIS
    Automatically switches Windows power plans based on AC/battery state.

.DESCRIPTION
    Polls the system's power source every few seconds and switches to a
    designated power plan when the laptop is plugged in (AC) versus running
    on battery. Useful for laptops where you want a performance plan on AC
    and a balanced/power-saver plan on battery, without switching manually.

    Runs in an infinite loop and is intended to be launched at logon via
    Task Scheduler (see Install-PowerPlanSwitcher.ps1).

.PARAMETER BatteryPlanGUID
    The GUID of the power plan to activate when running on battery.
    Run `powercfg /list` to see available plans and their GUIDs.

.PARAMETER ACPlanGUID
    The GUID of the power plan to activate when plugged into AC power.

.PARAMETER PollingIntervalSeconds
    How often (in seconds) to check the power source. Default is 5.

.PARAMETER LogPath
    Optional path to a log file. If provided, plan switches are logged
    with timestamps. Default: C:\Logs\PowerPlanSwitcher\switcher.log

.EXAMPLE
    .\PowerPlanSwitcher.ps1 -BatteryPlanGUID "a1841308-3541-4fab-bc81-f71556f20b4a" -ACPlanGUID "381b4222-f694-41f0-9685-ff5bb260df2e"

    Runs the switcher using the built-in "Power saver" plan on battery and
    "Balanced" plan on AC.

.NOTES
    Author:  Yracy
    Requires: Windows, PowerShell 5.1+ run as a user with permission to
              change the active power plan (admin recommended).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F\-]{36}$')]
    [string]$BatteryPlanGUID,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F\-]{36}$')]
    [string]$ACPlanGUID,

    [Parameter()]
    [int]$PollingIntervalSeconds = 5,

    [Parameter()]
    [string]$LogPath = "C:\Logs\PowerPlanSwitcher\switcher.log"
)

function Write-SwitchLog {
    param([string]$Message)

    $logDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

Write-SwitchLog "PowerPlanSwitcher started. Battery=$BatteryPlanGUID AC=$ACPlanGUID Interval=${PollingIntervalSeconds}s"

$lastState = $null

while ($true) {
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop

        # BatteryStatus 1 = Discharging (on battery). Anything else = plugged in / charging / no battery info.
        $pluggedIn = ($battery.BatteryStatus -ne 1)

        if ($pluggedIn -ne $lastState) {
            $lastState = $pluggedIn

            if ($pluggedIn) {
                powercfg /setactive $ACPlanGUID
                Write-SwitchLog "Switched to AC power plan."
            } else {
                powercfg /setactive $BatteryPlanGUID
                Write-SwitchLog "Switched to Battery power plan."
            }
        }
    } catch {
        Write-SwitchLog "ERROR: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds $PollingIntervalSeconds
}
