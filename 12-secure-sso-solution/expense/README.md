
Linux or MacosX
===============

curl -s http://localhost:8080/oidc -H "Authorization: Bearer $TOKEN" | jq

curl -s http://localhost:8080/expense -H "Authorization: Bearer $TOKEN" | jq

UUID = 3f1817f2-3dcf-472f-a8b2-77bfe25e79d1
curl -vX DELETE -H "Authorization: Bearer $TOKEN" http://localhost:8080/expense/$UUID

Windows
===============
Invoke-RestMethod -Uri http://localhost:8080/expense -Headers @{ Authorization = "Bearer $env:TOKEN" }

$UUID = "3f1817f2-3dcf-472f-a8b2-77bfe25e79d1"
Invoke-RestMethod -Uri "http://localhost:8080/expense/$uuid" -Method Delete -Headers @{ Authorization = "Bearer $env:TOKEN" }


Users
=====
.\get_token.ps1 user redhat

.\get_token.ps1 superuser redhat    

