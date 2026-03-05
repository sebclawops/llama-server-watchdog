# llama-server-watchdog

A lightweight PowerShell watchdog that keeps llama-server alive on Windows.

**Version:** 1.1.0 Monitors the health endpoint and automatically restarts the process when it becomes unresponsive.

## Why

llama-server (llama.cpp) on AMD GPUs has a known stability issue where the process crashes or becomes unresponsive after idle periods. This is documented across multiple GitHub issues (llama.cpp #10227, ollama #4492, ROCm #2625) and is related to AMD GPU drivers losing the device during idle. This watchdog catches those failures and restarts automatically.

## How it works

- Pings http://localhost:8080/health every 2 minutes
- After 2 consecutive failures (4 minutes unresponsive), kills and restarts llama-server
- Logs all activity to watchdog.log with timestamps
- Auto-rotates the log at 5MB

## Configuration

Edit the top of llama-watchdog.ps1 to match your setup:

- `$LlamaDir`: path to your llama.cpp install (default: `C:\llama-cpp`)
- `$ModelPath`: relative path to your model file
- `$Port`: server port (default: 8080)
- `$CheckInterval`: seconds between checks (default: 120)
- `$MaxFailures`: consecutive failures before restart (default: 2)

## Install

1. Copy llama-watchdog.ps1 to your llama.cpp directory
2. Open PowerShell as Administrator and run:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\llama-cpp\llama-watchdog.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogon
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$settings.DisallowStartIfOnBatteries = $false
Register-ScheduledTask -TaskName "LlamaWatchdog" -Action $action -Trigger $trigger -Settings $settings -Description "Monitors llama-server health and auto-restarts on failure" -RunLevel Highest
```

3. Disable any existing llama-server scheduled task:

```powershell
Disable-ScheduledTask -TaskName "llama-server"
```

4. Start it:

```powershell
Start-ScheduledTask -TaskName "LlamaWatchdog"
```

## Check status

```powershell
Get-Content C:\llama-cpp\watchdog.log
```

## Tested on

- Windows 11
- AMD RX 9070 XT (16GB VRAM)
- Qwen 3.5 9B Q8_0 quantization
- 32K context window

## Known AMD GPU stability issues

- llama.cpp #10227: Server slows down over time on RX 7900 XT
- ollama #4492: Crashes after idle on AMD GPUs
- ROCm #2625: 100% GPU usage during idle with HIP streams on RDNA3
- AMD driver release notes acknowledge intermittent crashes on 9000 series

## License

MIT
