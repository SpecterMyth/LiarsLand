param(
    [switch]$SkipExport,
    [switch]$NoOpen,
    [int]$Port = 8097
)

$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$RepoDir = Split-Path -Parent $ProjectDir
$WorkspaceDir = Split-Path -Parent $RepoDir
$GodotExe = Join-Path $WorkspaceDir "Tools\godot\Godot_v4.6.2-stable_win64_console.exe"
$WebDir = Join-Path $ProjectDir "web"
$IndexPath = Join-Path $WebDir "index.html"
$ServerScript = Join-Path $ProjectDir "tools\serve_web.py"
$ServerOut = Join-Path $ProjectDir "web_server.log"
$ServerErr = Join-Path $ProjectDir "web_server.err.log"
$Url = "http://127.0.0.1:$Port/index.html"

function Stop-PortListener {
    param([int]$PortToStop)

    $listeners = netstat -ano | Select-String ":$PortToStop\s" | Select-String "LISTENING"
    foreach ($line in $listeners) {
        $parts = ($line.ToString() -split "\s+") | Where-Object { $_ }
        if ($parts.Length -gt 0) {
            $processId = [int]$parts[-1]
            if ($processId -gt 0) {
                Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Host "LiarsLand web launcher"
Write-Host "Project: $ProjectDir"

if (-not (Test-Path $ServerScript)) {
    throw "Missing server script: $ServerScript"
}

if (-not (Test-Path (Join-Path $ProjectDir "config.local.json"))) {
    Write-Warning "config.local.json not found. The web game can open, but real LLM calls will fail until it is configured."
}

if (-not $SkipExport) {
    if (-not (Test-Path $GodotExe)) {
        throw "Godot console executable not found: $GodotExe"
    }

    New-Item -ItemType Directory -Force $WebDir | Out-Null
    Write-Host "Exporting Godot Web build..."
    & $GodotExe --headless --path $ProjectDir --export-release Web "web\index.html"
    if ($LASTEXITCODE -ne 0) {
        throw "Godot web export failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path $IndexPath)) {
    throw "Web build not found: $IndexPath. Run without -SkipExport first."
}

Write-Host "Starting local web/proxy server on port $Port..."
Stop-PortListener -PortToStop $Port
Start-Sleep -Milliseconds 500

Remove-Item $ServerOut -Force -ErrorAction SilentlyContinue
Remove-Item $ServerErr -Force -ErrorAction SilentlyContinue

$server = Start-Process `
    -FilePath "python" `
    -ArgumentList @($ServerScript) `
    -WorkingDirectory $ProjectDir `
    -RedirectStandardOutput $ServerOut `
    -RedirectStandardError $ServerErr `
    -WindowStyle Hidden `
    -PassThru

Start-Sleep -Seconds 2

try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -ne 200) {
        throw "Unexpected HTTP status: $($response.StatusCode)"
    }
} catch {
    Write-Host "Server stdout:"
    Get-Content $ServerOut -Tail 40 -ErrorAction SilentlyContinue
    Write-Host "Server stderr:"
    Get-Content $ServerErr -Tail 80 -ErrorAction SilentlyContinue
    throw "Server failed to respond at $Url. $($_.Exception.Message)"
}

Write-Host "Ready: $Url"
Write-Host "Server PID: $($server.Id)"
Write-Host "Logs: $ServerOut"

if (-not $NoOpen) {
    Start-Process $Url
}
