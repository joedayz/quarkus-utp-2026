# PowerShell script to simulate traffic to the expense service
$ENDPOINT = "http://localhost:8080/expenses"

# GET requests
Write-Host "Making GET requests..."
Invoke-RestMethod -Uri $ENDPOINT -Method GET -ErrorAction SilentlyContinue | Out-Null
Write-Host "GET Response Code: 200"

Invoke-RestMethod -Uri $ENDPOINT -Method GET -ErrorAction SilentlyContinue | Out-Null
Write-Host "GET Response Code: 200"

Invoke-RestMethod -Uri $ENDPOINT -Method GET -ErrorAction SilentlyContinue | Out-Null
Write-Host "GET Response Code: 200"

# POST request
Write-Host "Making POST request..."
$body = @{
    name = "Podman in Action"
    paymentMethod = "CASH"
    amount = 33
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri $ENDPOINT -Method POST -Body $body -ContentType "application/json"
    Write-Host "POST Response Code: 200"
} catch {
    Write-Host "POST Response Code: $($_.Exception.Response.StatusCode.value__)"
}
