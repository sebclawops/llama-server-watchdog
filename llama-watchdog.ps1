# llama-watchdog.ps1
# Monitors llama-server health and restarts it if unresponsive.
# Designed to run as a Windows Scheduled Task on the gaming PC.

# --- Configuration ---
$LlamaDir = "C:\llama-cpp"
$ModelPath = "models\Qwen3.5-9B-Q8_0.gguf"
$Port = 8080
$HealthUrl = "http://localhost:$Port/health"
$CheckInterval = 120          # seconds between health checks
$MaxFailures = 2              # consecutive failures before restart
$LogFile = "$LlamaDir\watchdog.log"
$MaxLogSize = 5MB             # rotate log if it gets too big

# --- Functions ---
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp  $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Test-LlamaHealth {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            return $true
        }
    } catch {
        # any exception = unhealthy
    }
    return $false
}

function Stop-LlamaServer {
    $procs = Get-Process -Name "llama-server" -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Log "Killing llama-server (PID: $($procs.Id -join ', '))"
        $procs | Stop-Process -Force
        Start-Sleep -Seconds 3
    }
}

function Start-LlamaServer {
    Write-Log "Starting llama-server..."
    $startInfo = @{
        FilePath     = "$LlamaDir\llama-server.exe"
        ArgumentList = "-m $ModelPath -ngl 99 -c 32768 --port $Port --host 0.0.0.0"
        WorkingDirectory = $LlamaDir
        WindowStyle  = "Minimized"
    }
    Start-Process @startInfo
    Start-Sleep -Seconds 10

    if (Test-LlamaHealth) {
        Write-Log "llama-server started successfully and responding on port $Port"
        return $true
    } else {
        Write-Log "WARNING: llama-server started but not responding yet"
        return $false
    }
}

function Rotate-Log {
    if (Test-Path $LogFile) {
        $size = (Get-Item $LogFile).Length
        if ($size -gt $MaxLogSize) {
            $backup = "$LogFile.old"
            if (Test-Path $backup) { Remove-Item $backup }
            Rename-Item $LogFile $backup
            Write-Log "Log rotated (previous log was $([math]::Round($size/1MB, 1)) MB)"
        }
    }
}

# --- Main Loop ---
Write-Log "========================================="
Write-Log "Watchdog started. Checking every ${CheckInterval}s, restart after $MaxFailures failures."
Write-Log "Health endpoint: $HealthUrl"
Write-Log "========================================="

$failCount = 0

while ($true) {
    Rotate-Log

    if (Test-LlamaHealth) {
        if ($failCount -gt 0) {
            Write-Log "Health check OK (recovered after $failCount failure(s))"
        }
        $failCount = 0
    } else {
        $failCount++
        Write-Log "Health check FAILED ($failCount/$MaxFailures)"

        if ($failCount -ge $MaxFailures) {
            Write-Log "Max failures reached. Restarting llama-server..."
            Stop-LlamaServer
            Start-LlamaServer
            $failCount = 0
        }
    }

    Start-Sleep -Seconds $CheckInterval
}
