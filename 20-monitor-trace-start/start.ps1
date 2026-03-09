# PowerShell script to start all Quarkus microservices
# Equivalent to start.sh for Windows

Write-Host "Starting the 'solver' project" -ForegroundColor Green
Set-Location solver
Start-Process -FilePath "mvn" -ArgumentList "quarkus:dev", "-Ddebug=5005" -WindowStyle Hidden -PassThru | Set-Variable -Name "SOLVER_PROCESS"
Start-Sleep -Seconds 5
Set-Location ..

Write-Host "Starting the 'adder' project" -ForegroundColor Green
Set-Location adder
Start-Process -FilePath "mvn" -ArgumentList "quarkus:dev", "-Ddebug=5006" -WindowStyle Hidden -PassThru | Set-Variable -Name "ADDER_PROCESS"
Start-Sleep -Seconds 5
Set-Location ..

Write-Host "Starting the 'multiplier' project" -ForegroundColor Green
Set-Location multiplier
Start-Process -FilePath "mvn" -ArgumentList "quarkus:dev", "-Ddebug=5007" -WindowStyle Hidden -PassThru | Set-Variable -Name "MULTIPLIER_PROCESS"
Start-Sleep -Seconds 5
Set-Location ..

Write-Host ""
Write-Host "All services started successfully!" -ForegroundColor Cyan
Write-Host "Services are running on:" -ForegroundColor White
Write-Host "  - Solver: http://localhost:8080 (debug: 5005)" -ForegroundColor White
Write-Host "  - Adder: http://localhost:8081 (debug: 5006)" -ForegroundColor White
Write-Host "  - Multiplier: http://localhost:8082 (debug: 5007)" -ForegroundColor White
Write-Host ""

# Check if Maven is available
try {
    $mvnVersion = mvn --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Maven is not installed or not in PATH" -ForegroundColor Red
        Write-Host "Please install Maven from: https://maven.apache.org/download.cgi" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "Error: Maven is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Maven from: https://maven.apache.org/download.cgi" -ForegroundColor Yellow
    exit 1
}

Write-Host "Press Enter to terminate all services..." -ForegroundColor Yellow
Read-Host

Write-Host ""
Write-Host "Terminating all services..." -ForegroundColor Red

# Terminate all processes
if ($SOLVER_PROCESS) {
    Stop-Process -Id $SOLVER_PROCESS.Id -Force -ErrorAction SilentlyContinue
    Write-Host "Solver service terminated" -ForegroundColor Yellow
}

if ($ADDER_PROCESS) {
    Stop-Process -Id $ADDER_PROCESS.Id -Force -ErrorAction SilentlyContinue
    Write-Host "Adder service terminated" -ForegroundColor Yellow
}

if ($MULTIPLIER_PROCESS) {
    Stop-Process -Id $MULTIPLIER_PROCESS.Id -Force -ErrorAction SilentlyContinue
    Write-Host "Multiplier service terminated" -ForegroundColor Yellow
}

Start-Sleep -Seconds 2
Write-Host "All services terminated" -ForegroundColor Green
Write-Host ""
