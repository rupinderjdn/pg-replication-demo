# Script to start Docker Desktop
Write-Host "Attempting to start Docker Desktop..." -ForegroundColor Yellow

$dockerPaths = @(
    "$env:LOCALAPPDATA\Docker\Docker Desktop.exe",
    "C:\Program Files\Docker\Docker\Docker Desktop.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe"
)

$found = $false
foreach ($path in $dockerPaths) {
    if (Test-Path $path) {
        Write-Host "Found Docker Desktop at: $path" -ForegroundColor Green
        Start-Process $path
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Host "Docker Desktop not found in common locations." -ForegroundColor Red
    Write-Host "Please start Docker Desktop manually from the Start menu." -ForegroundColor Yellow
    exit 1
}

Write-Host "Docker Desktop is starting. Please wait for it to fully initialize..." -ForegroundColor Yellow
Write-Host "You can check if it's ready by running: docker ps" -ForegroundColor Cyan

# Wait a bit and check if Docker is responding
Start-Sleep -Seconds 5
$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts) {
    try {
        $result = docker ps 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nDocker Desktop is now running! ✓" -ForegroundColor Green
            exit 0
        }
    } catch {
        # Continue waiting
    }
    $attempt++
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 2
}

Write-Host "`nDocker Desktop is taking longer than expected to start." -ForegroundColor Yellow
Write-Host "Please check the Docker Desktop window and wait for it to fully initialize." -ForegroundColor Yellow

