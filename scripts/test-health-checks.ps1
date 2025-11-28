# Script PowerShell pour tester les health checks des services Cinephoria
param(
    [string]$BackendUrl = "http://localhost:5000",
    [string]$FrontendUrl = "http://localhost:4200",
    [int]$MaxRetries = 30,
    [int]$RetryDelay = 5
)

Write-Host "=== Test des Health Checks Cinephoria ===" -ForegroundColor Green
Write-Host "Backend: $BackendUrl" -ForegroundColor Yellow
Write-Host "Frontend: $FrontendUrl" -ForegroundColor Yellow
Write-Host ""

# Fonction pour tester un endpoint avec retry
function Test-Endpoint {
    param(
        [string]$Url,
        [string]$ServiceName
    )
    
    Write-Host "Test de $ServiceName ($Url)..." -ForegroundColor Cyan
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "✓ $ServiceName est opérationnel (tentative $i/$MaxRetries)" -ForegroundColor Green
                return $true
            }
        }
        catch {
            Write-Host "  Tentative $i/$MaxRetries: $($_.Exception.Message)" -ForegroundColor Gray
        }
        
        if ($i -lt $MaxRetries) {
            Start-Sleep -Seconds $RetryDelay
        }
    }
    
    Write-Host "✗ $ServiceName n'est pas accessible après $MaxRetries tentatives" -ForegroundColor Red
    return $false
}

# Tests des health checks backend
Write-Host "`n=== Tests Backend ===" -ForegroundColor Magenta

$backendLive = Test-Endpoint -Url "$BackendUrl/health/live" -ServiceName "Backend Live"
$backendReady = Test-Endpoint -Url "$BackendUrl/health/ready" -ServiceName "Backend Ready"

# Tests du frontend
Write-Host "`n=== Tests Frontend ===" -ForegroundColor Magenta

$frontendHealth = Test-Endpoint -Url "$FrontendUrl/health" -ServiceName "Frontend Health"
$frontendRoot = Test-Endpoint -Url "$FrontendUrl" -ServiceName "Frontend Root"

# Résumé
Write-Host "`n=== Résumé ===" -ForegroundColor Green

if ($backendLive -and $backendReady -and $frontendHealth -and $frontendRoot) {
    Write-Host "✓ Tous les services sont opérationnels !" -ForegroundColor Green
    Write-Host "  Backend API: $BackendUrl" -ForegroundColor Yellow
    Write-Host "  Frontend: $FrontendUrl" -ForegroundColor Yellow
    Write-Host "  pgAdmin: http://localhost:5050" -ForegroundColor Yellow
} else {
    Write-Host "✗ Certains services ne répondent pas correctement" -ForegroundColor Red
    Write-Host "  Vérifiez les logs avec: docker compose logs" -ForegroundColor Yellow
}

# Vérification des conteneurs
Write-Host "`n=== État des conteneurs ===" -ForegroundColor Magenta
docker compose ps

Write-Host "`n=== Logs récents ===" -ForegroundColor Magenta
docker compose logs --tail=10