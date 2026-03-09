Param(
  [string]$Url = "http://localhost:8080/q/health",
  [int]$IntervalSeconds = 2,
  [switch]$NoClear
)

$ErrorActionPreference = "SilentlyContinue"
$previous = $null

Write-Host "Monitoreando $Url (Ctrl+C para salir)" -ForegroundColor Cyan

while ($true) {
  $current = $null
  try {
    $obj = Invoke-RestMethod -Uri $Url -TimeoutSec 5
    $current = ($obj | ConvertTo-Json -Depth 20)
  } catch {
    $current = "ERROR: no se pudo conectar a $Url"
  }

  if (-not $NoClear) { Clear-Host }

  if ($null -ne $previous -and $current -ne $previous) {
    Write-Host $current -ForegroundColor Yellow
  } elseif ($current -like "ERROR*") {
    Write-Host $current -ForegroundColor Red
  } else {
    Write-Host $current
  }

  $previous = $current
  Start-Sleep -Seconds $IntervalSeconds
}


