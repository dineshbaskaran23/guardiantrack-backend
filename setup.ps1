# GuardianTrack Setup - PowerShell version
# Right-click this file and choose "Run with PowerShell"

$Host.UI.RawUI.WindowTitle = "GuardianTrack Setup"

function Pause-Script {
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Yellow
    Read-Host
}

function Exit-WithError($msg) {
    Write-Host ""
    Write-Host "ERROR: $msg" -ForegroundColor Red
    Write-Host ""
    Pause-Script
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  GuardianTrack - Setup Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This window will stay open the whole time."
Pause-Script

# STEP 1 - Check we are in the right folder
Write-Host "[STEP 1/5] Checking folder..." -ForegroundColor Cyan
if (-not (Test-Path "server.js")) {
    Exit-WithError "Wrong folder. Run this from INSIDE the guardian-backend folder.`nRight-click setup.ps1 inside guardian-backend and choose Run with PowerShell."
}
Write-Host "Correct folder. OK." -ForegroundColor Green

# STEP 2 - Check Node.js
Write-Host ""
Write-Host "[STEP 2/5] Checking Node.js..." -ForegroundColor Cyan
$nodePath = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodePath) {
    Write-Host ""
    Write-Host "Node.js is not installed." -ForegroundColor Red
    Write-Host "Opening nodejs.org for you now..."
    Start-Process "https://nodejs.org"
    Exit-WithError "Install Node.js LTS, then run this script again."
}
$nodeVer = node --version
Write-Host "Node.js $nodeVer found. OK." -ForegroundColor Green

# STEP 3 - Check Git
Write-Host ""
Write-Host "[STEP 3/5] Checking Git..." -ForegroundColor Cyan
$gitPath = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitPath) {
    Write-Host ""
    Write-Host "Git is not installed." -ForegroundColor Red
    Write-Host "Opening git-scm.com for you now..."
    Start-Process "https://git-scm.com/download/win"
    Exit-WithError "Install Git, then run this script again."
}
$gitVer = git --version
Write-Host "$gitVer found. OK." -ForegroundColor Green

# STEP 4 - npm install
Write-Host ""
Write-Host "[STEP 4/5] Installing npm packages (1-2 minutes)..." -ForegroundColor Cyan
Write-Host ""
npm install
if ($LASTEXITCODE -ne 0) {
    Exit-WithError "npm install failed. See error above."
}
Write-Host ""
Write-Host "Packages installed. OK." -ForegroundColor Green

# STEP 5 - .env file
Write-Host ""
Write-Host "[STEP 5/5] Setting up .env file..." -ForegroundColor Cyan

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host ""
    Write-Host "Opening .env in Notepad. Fill in your credentials then close it." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  MONGO_URI=   <- your MongoDB Atlas connection string" -ForegroundColor Yellow
    Write-Host "  FAST2SMS_KEY= <- your Fast2SMS API key" -ForegroundColor Yellow
    Write-Host ""
    # /wait = script waits until Notepad is closed
    Start-Process notepad.exe -ArgumentList ".env" -Wait
} else {
    Write-Host ".env already exists." -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "================================================"
Write-Host ""
Write-Host "Now run push_to_github.ps1 to deploy." -ForegroundColor Cyan
Write-Host ""
Pause-Script
