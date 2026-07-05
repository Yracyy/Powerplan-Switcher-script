# PowerPlan Switcher

A lightweight PowerShell utility that automatically switches your Windows power plan based on whether your laptop is plugged in or running on battery.

## Why I built this

Windows doesn't offer a native way to auto-switch power plans on AC/battery change (only per-app settings like NVIDIA/AMD Optimus profiles). I wanted my performance plan active only while plugged in, and a battery-friendly plan to kick in automatically the moment I unplug — so I built a small background watcher for it.

## How it works

- `PowerPlanSwitcher.ps1` polls the system's battery status every few seconds using `Get-CimInstance`.
- When it detects a change between AC and battery power, it calls `powercfg /setactive` to switch to the plan you've configured for that state.
- Every switch is timestamped and logged to a log file for easy troubleshooting.
- `Install-PowerPlanSwitcher.ps1` copies the script to `C:\Scripts` and registers it as a Task Scheduler task that runs silently at every logon.

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Administrator privileges (for Task Scheduler registration)
- A laptop with a battery (obviously)

## Setup

1. **Find your power plan GUIDs:**

   ```powershell
   powercfg /list
   ```

   This lists all available power plans with their GUIDs. Common built-in ones:

   | Plan             | GUID                                   |
   |------------------|------------------------------------------|
   | Balanced         | `381b4222-f694-41f0-9685-ff5bb260df2e`   |
   | Power saver      | `a1841308-3541-4fab-bc81-f71556f20b4a`   |
   | High performance | `8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`   |

   (Custom plans created by tools like Armoury Crate, MSI Center, etc. will show their own GUIDs.)

2. **Clone this repo:**

   ```powershell
   git clone https://github.com/<your-username>/powerplan-switcher.git
   cd powerplan-switcher
   ```

3. **Run the installer** (as Administrator), passing in your chosen GUIDs:

   ```powershell
   .\Install-PowerPlanSwitcher.ps1 -BatteryPlanGUID "a1841308-3541-4fab-bc81-f71556f20b4a" -ACPlanGUID "381b4222-f694-41f0-9685-ff5bb260df2e"
   ```

   This copies the script to `C:\Scripts\PowerPlanSwitcher.ps1` and registers a scheduled task that runs it at every logon.

## Usage

Once installed, it runs silently in the background — no interaction needed. Unplug or plug in your laptop and the active power plan switches automatically within a few seconds.

Logs are written to:
```
C:\Logs\PowerPlanSwitcher\switcher.log
```

## Manually running without installing

You can also just run the script directly, without registering a scheduled task:

```powershell
.\PowerPlanSwitcher.ps1 -BatteryPlanGUID "<your-battery-guid>" -ACPlanGUID "<your-ac-guid>"
```

## Uninstall

```powershell
Unregister-ScheduledTask -TaskName "PowerPlanSwitcher" -Confirm:$false
Remove-Item "C:\Scripts\PowerPlanSwitcher.ps1"
```

## Troubleshooting

**The switcher doesn't seem to run when I log in on battery**

By default, tasks created with `Register-ScheduledTask` include a condition that says *"Start the task only if the computer is on AC power."* Since the entire point of this script is to react to battery power, that default setting will silently prevent it from ever starting if you log in unplugged.

To fix this:
1. Open **Task Scheduler** (`taskschd.msc`)
2. Find **PowerPlanSwitcher** in the Task Scheduler Library
3. Right-click → **Properties**
4. Go to the **Conditions** tab
5. Under **Power**, untick **"Start the task only if the computer is on AC power"**
6. Click **OK**

This is a one-time fix — worth doing right after install, since otherwise the switcher only ever works if you happen to log in while plugged in.

**The task also stops when I unplug mid-session**

Same Conditions tab — there's a related setting: *"Stop if the computer switches to battery power."* Make sure that one is unticked too, or the watcher will kill itself the moment you unplug, which defeats the purpose.

**Nothing happens at all, even on AC**

Check the log at `C:\Logs\PowerPlanSwitcher\switcher.log` for an `ERROR` line — usually this means `Get-CimInstance` couldn't find `Win32_Battery` (rare, but can happen on some OEM battery drivers). Confirm your device shows a battery by running `Get-CimInstance -ClassName Win32_Battery` manually first.

**"Cannot be loaded because running scripts is disabled on this system"**

Same fix as any PowerShell script:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
or unblock the specific file:
```powershell
Unblock-File -Path "C:\Scripts\PowerPlanSwitcher.ps1"
```

## Notes

- Execution policy: if you get a "running scripts is disabled" error, unblock the downloaded files first:
  ```powershell
  Get-ChildItem -Recurse | Unblock-File
  ```
- Tested on my ASUS ROG Strix laptop with hybrid Optimus graphics. Other device should work too.

## License

MIT
