# get_token.ps1 - PowerShell script to retrieve bearer token from OIDC server
# Usage: . .\get_token.ps1 <username> <password>

param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$Password
)

# OIDC server configuration (matching your Keycloak setup)
$OIDC_SERVER_URL = "http://localhost:8888"
$REALM = "quarkus"
$CLIENT_ID = "backend-service"
$CLIENT_SECRET = "secret"

Write-Host "Authenticating with OIDC server..." -ForegroundColor Green
Write-Host "Server: $OIDC_SERVER_URL" -ForegroundColor Yellow
Write-Host "Realm: $REALM" -ForegroundColor Yellow
Write-Host "Client: $CLIENT_ID" -ForegroundColor Yellow
Write-Host "Username: $Username" -ForegroundColor Yellow

# Get the token endpoint URL
$TOKEN_URL = "$OIDC_SERVER_URL/realms/$REALM/protocol/openid-connect/token"

# Allow self-signed certs (equivalent to curl --insecure)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Prepare the request body
$body = @{
    grant_type = "password"
    username = $Username
    password = $Password
}

try {
    # Request the token using password grant flow (Basic auth like curl script)
    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${CLIENT_ID}:${CLIENT_SECRET}"))
    $headers = @{ Authorization = "Basic $basic" }
    $response = Invoke-RestMethod -Uri $TOKEN_URL -Method Post -Headers $headers -Body $body -ContentType "application/x-www-form-urlencoded"

    # Extract the access token
    $TOKEN = $response.access_token

    if ($TOKEN) {
        # Set the token as an environment variable
        $env:TOKEN = $TOKEN

        Write-Host "Token successfully retrieved." -ForegroundColor Green
    } else {
        Write-Host "Error: No access token found in response" -ForegroundColor Red
        Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error: Failed to retrieve token" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    try {
        $resp = $_.Exception.Response
        if ($resp -ne $null) {
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $body = $reader.ReadToEnd()
            Write-Host "Response body: $body" -ForegroundColor DarkYellow
        }
    } catch {}
    # Fallback to curl if available (mirrors get_token.sh exactly)
    $curl = (Get-Command curl.exe -ErrorAction SilentlyContinue)
    if ($curl) {
        Write-Host "Falling back to curl..." -ForegroundColor Yellow
        $urls = @(
            "$TOKEN_URL",
            ("http://localhost:8888/realms/$REALM/protocol/openid-connect/token")
        )
        foreach ($url in $urls) {
            $curlArgs = @(
                "--insecure",
                "-s",
                "-X", "POST", $url,
                "--user", "${CLIENT_ID}:${CLIENT_SECRET}",
                "-H", "Content-Type: application/x-www-form-urlencoded",
                "--http1.1",
                "-d", "username=${Username}",
                "-d", "password=${Password}",
                "-d", "grant_type=password"
            )
            $raw = & $curl @curlArgs 2>&1
            try {
                $json = $raw | ConvertFrom-Json
                $TOKEN = $json.access_token
            } catch {
                $TOKEN = $null
            }
            if ($TOKEN) {
                $env:TOKEN = $TOKEN
                Write-Host "Token successfully retrieved (curl)." -ForegroundColor Green
                return
            }
        }
        Write-Host "Curl fallback failed. Raw response:" -ForegroundColor Red
        Write-Host $raw -ForegroundColor DarkYellow
    }
    Write-Host "Make sure the SSO server is running at $OIDC_SERVER_URL" -ForegroundColor Yellow
    exit 1
}