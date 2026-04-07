Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
$ErrorActionPreference = "Continue"

Clear-Host
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   GuardianTrack - Automated Deployer" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You need 4 things. Get them from:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  A) GitHub Token: github.com > Settings > Developer settings" -ForegroundColor White
Write-Host "     > Personal access tokens > Tokens classic > Generate new" -ForegroundColor Gray
Write-Host "     > Tick: repo + workflow > Copy token (starts with ghp_)" -ForegroundColor Gray
Write-Host ""
Write-Host "  B) Render API Key: render.com > Account Settings > API Keys" -ForegroundColor White
Write-Host "     > Create API Key > Copy it" -ForegroundColor Gray
Write-Host ""
Write-Host "  C) MongoDB URI: mongodb.com/atlas > Connect > Drivers" -ForegroundColor White
Write-Host "     > Copy string starting with mongodb+srv://" -ForegroundColor Gray
Write-Host ""
Write-Host "  D) Fast2SMS Key: fast2sms.com > Dev API > API Key" -ForegroundColor White
Write-Host ""
Write-Host "------------------------------------------------" -ForegroundColor Cyan

$GITHUB_TOKEN  = Read-Host "Enter GitHub Token"
$RENDER_APIKEY = Read-Host "Enter Render API Key"
$MONGO_URI     = Read-Host "Enter MongoDB URI"
$FAST2SMS_KEY  = Read-Host "Enter Fast2SMS API Key"
$REPO_NAME     = "guardiantrack-backend"

Write-Host ""
Write-Host "[1] Checking Git..." -ForegroundColor Yellow
try {
    git --version | Out-Null
    Write-Host "    Git OK" -ForegroundColor Green
} catch {
    Write-Host "    Git not installed! Download from git-scm.com" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[2] Connecting to GitHub..." -ForegroundColor Yellow
$ghHeaders = @{
    Authorization = "token $GITHUB_TOKEN"
    Accept = "application/vnd.github.v3+json"
    "User-Agent" = "GuardianTrack-Deployer"
}
try {
    $ghUser = Invoke-RestMethod "https://api.github.com/user" -Headers $ghHeaders
    Write-Host "    Logged in as: $($ghUser.login)" -ForegroundColor Green
} catch {
    Write-Host "    GitHub login failed. Check your token." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
$GITHUB_USERNAME = $ghUser.login

Write-Host "[3] Creating GitHub repo..." -ForegroundColor Yellow
$repoBody = '{"name":"' + $REPO_NAME + '","private":true,"auto_init":false}'
try {
    $repo = Invoke-RestMethod "https://api.github.com/user/repos" -Method POST -Headers $ghHeaders -ContentType "application/json" -Body $repoBody
    Write-Host "    Repo created: $($repo.html_url)" -ForegroundColor Green
    $REPO_URL = $repo.clone_url
} catch {
    try {
        $repo = Invoke-RestMethod "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME" -Headers $ghHeaders
        Write-Host "    Using existing repo: $($repo.html_url)" -ForegroundColor Green
        $REPO_URL = $repo.clone_url
    } catch {
        Write-Host "    Could not create or access repo." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "[4] Pushing code to GitHub..." -ForegroundColor Yellow
$AUTH_REPO_URL = $REPO_URL -replace "https://", "https://$($GITHUB_TOKEN)@"
$SCRIPT_DIR = $PSScriptRoot
Set-Location $SCRIPT_DIR
if (Test-Path ".git") { Remove-Item -Recurse -Force ".git" }
cmd /c "git init -b main" 2>$null | Out-Null
git config user.email "deploy@guardiantrack.app" 2>&1 | Out-Null
git config user.name "GuardianTrack Deployer" 2>&1 | Out-Null
git remote add origin $AUTH_REPO_URL 2>&1 | Out-Null
git commit -m "Initial deploy: GuardianTrack backend v1.0" 2>&1 | Out-Null
git push -u origin main --force 2>&1 | Out-Null
Write-Host "    Code pushed to GitHub" -ForegroundColor Green

Write-Host "[5] Connecting to Render..." -ForegroundColor Yellow
$renderHeaders = @{
    Authorization = "Bearer $RENDER_APIKEY"
    Accept = "application/json"
    "Content-Type" = "application/json"
}
try {
    $renderOwners = Invoke-RestMethod "https://api.render.com/v1/owners?limit=1" -Headers $renderHeaders
    $OWNER_ID = $renderOwners[0].owner.id
    Write-Host "    Render connected. Owner: $OWNER_ID" -ForegroundColor Green
} catch {
    Write-Host "    Render login failed. Check your API key." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[6] Creating Render Web Service..." -ForegroundColor Yellow
$envVars = @(
    @{key="NODE_ENV"; value="production"},
    @{key="MONGO_URI"; value=$MONGO_URI},
    @{key="FAST2SMS_KEY"; value=$FAST2SMS_KEY},
    @{key="JWT_SECRET"; value="a132980bb214f05be05d7e154b156eb69591c73b8556b299f0ab33d6dedc6fa8"},
    @{key="JWT_EXPIRES_IN"; value="30d"},
    @{key="DEVICE_SECRET"; value="e88fb9b3328618f62564e6e3dc19fd7671f49fd0b5409c230091e5aafc932aae"},
    @{key="SESSION_SECRET"; value="7700c8b21135b1909501e52661fd7c7cff492f4a4652a394c212c658a1f93ff1"},
    @{key="BATTERY_ALERT_THRESHOLD"; value="20"},
    @{key="OFFLINE_ALERT_MINUTES"; value="15"},
    @{key="DEFAULT_GEOFENCE_RADIUS_M"; value="500"},
    @{key="RATE_LIMIT_WINDOW_MS"; value="900000"},
    @{key="RATE_LIMIT_MAX"; value="100"},
    @{key="USE_FAST2SMS"; value="true"}
)
$servicePayload = @{
    type = "web_service"
    name = $REPO_NAME
    ownerId = $OWNER_ID
    repo = "https://github.com/$GITHUB_USERNAME/$REPO_NAME"
    branch = "main"
    autoDeploy = "yes"
    buildCommand = "npm install"
    startCommand = "node server.js"
    healthCheckPath = "/health"
    plan = "free"
    envVars = $envVars
}
}
$serviceBody = $servicePayload | ConvertTo-Json -Depth 6
try {
    $newService = Invoke-RestMethod "https://api.render.com/v1/services" -Method POST -Headers $renderHeaders -Body $serviceBody
    $SERVICE_ID = $newService.service.id
    $SERVICE_URL = "https://" + $newService.service.serviceDetails.url
    Write-Host "    Render service created!" -ForegroundColor Green
} catch {
    Write-Host "    Render service creation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Go to render.com and connect your GitHub repo manually:" -ForegroundColor Yellow
    Write-Host "    https://github.com/$GITHUB_USERNAME/$REPO_NAME" -ForegroundColor White
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[7] Waiting for deployment (approx 2 minutes)..." -ForegroundColor Yellow
$maxWait = 180
$elapsed = 0
$live = $false
while ($elapsed -lt $maxWait) {
    Start-Sleep 15
    $elapsed += 15
    Write-Host "    Waiting... $elapsed / $maxWait sec" -ForegroundColor Gray
    try {
        $health = Invoke-RestMethod "$SERVICE_URL/health" -TimeoutSec 8 -ErrorAction Stop
        if ($health.status -eq "ok") { $live = $true; break }
    } catch {}
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
if ($live) {
    Write-Host "   DEPLOYMENT SUCCESSFUL - APP IS LIVE!" -ForegroundColor Green
} else {
    Write-Host "   DEPLOYMENT TRIGGERED - Still starting up..." -ForegroundColor Yellow
}
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Live URL : $SERVICE_URL" -ForegroundColor Green
Write-Host "   Health   : $SERVICE_URL/health" -ForegroundColor Green
Write-Host "   GitHub   : https://github.com/$GITHUB_USERNAME/$REPO_NAME" -ForegroundColor Green
Write-Host "   Dashboard: render.com/dashboard" -ForegroundColor Green
Write-Host ""

$info = "Live URL: $SERVICE_URL`nGitHub: https://github.com/$GITHUB_USERNAME/$REPO_NAME`nDate: $(Get-Date)"
$info | Out-File "DEPLOYMENT_INFO.txt" -Encoding utf8
Write-Host "   Saved to DEPLOYMENT_INFO.txt" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to close"

