# GuardianTrack - Push to GitHub
# Right-click this file and choose "Run with PowerShell"

$Host.UI.RawUI.WindowTitle = "GuardianTrack - Push to GitHub"

function Pause-Script {
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Yellow
    Read-Host
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  GuardianTrack - Push to GitHub" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "server.js")) {
    Write-Host "ERROR: Run from inside guardian-backend folder." -ForegroundColor Red
    Pause-Script
    exit 1
}

Write-Host "You need a GitHub Personal Access Token (ghp_...)." -ForegroundColor Yellow
Write-Host ""
Write-Host "How to get one:"
Write-Host "  1. Go to github.com and log in"
Write-Host "  2. Click profile photo top right - Settings"
Write-Host "  3. Scroll to bottom - Developer settings"
Write-Host "  4. Personal access tokens - Tokens classic"
Write-Host "  5. Generate new token classic"
Write-Host "  6. Tick the repo checkbox only"
Write-Host "  7. Click Generate - COPY the ghp_... value"
Write-Host ""
Write-Host "Also make sure your GitHub repo is EMPTY (no README)."
Write-Host ""
Pause-Script

Write-Host ""
$GH_USER  = Read-Host "Enter your GitHub username"
$GH_REPO  = Read-Host "Enter your repo name"
$GH_TOKEN = Read-Host "Enter your token (ghp_...)"

# Trim any accidental spaces or newlines
$GH_USER  = $GH_USER.Trim()
$GH_REPO  = $GH_REPO.Trim()
$GH_TOKEN = $GH_TOKEN.Trim()

Write-Host ""
Write-Host "Configuring git..." -ForegroundColor Cyan

# Init git if needed
if (-not (Test-Path ".git")) {
    Write-Host "Initialising git..." -ForegroundColor Yellow
    git init
    git config user.email "deploy@guardiantrack.com"
    git config user.name "GuardianTrack"
    Write-Host "Git initialised." -ForegroundColor Green
}

# Use credential helper approach - avoids special chars in URL
git remote remove origin 2>$null

# Set credentials via git config instead of embedding in URL
git config credential.helper store
$credLine = "https://$($GH_TOKEN):x-oauth-basic@github.com"
$credFile = "$env:USERPROFILE\.git-credentials"
# Write credentials to git credentials store
"$credLine" | Out-File -FilePath $credFile -Encoding ascii -Append

# Set clean remote URL with no token embedded
git remote add origin "https://github.com/$GH_USER/$GH_REPO.git"
git branch -M main

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
Write-Host ""

git add -A

# Check if there is anything to commit
$status = git status --porcelain
if ($status) {
    git commit -m "Deploy: GuardianTrack backend"
} else {
    Write-Host "Nothing new to commit - pushing existing commits..." -ForegroundColor Yellow
}

git push -u origin main --force

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "PUSH FAILED." -ForegroundColor Red
    Write-Host ""
    Write-Host "Try these fixes:" -ForegroundColor Yellow
    Write-Host "  1. Make sure the GitHub repo EXISTS and is EMPTY"
    Write-Host "     Go to github.com/new and create it with no README"
    Write-Host "  2. Make sure your token has 'repo' permission"
    Write-Host "  3. Check username and repo name spelling exactly"
    Write-Host "     Your repo URL should be: https://github.com/$GH_USER/$GH_REPO"
    Write-Host ""
    Write-Host "Opening your GitHub profile to verify..." -ForegroundColor Yellow
    Start-Process "https://github.com/$GH_USER/$GH_REPO"
    Write-Host ""
    Pause-Script
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  SUCCESS! Code is on GitHub." -ForegroundColor Green
Write-Host "================================================"
Write-Host ""
Write-Host "NEXT STEPS on render.com:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Go to render.com - sign up free with GitHub"
Write-Host "  2. Click New + then Web Service"
Write-Host "  3. Connect GitHub and select: $GH_REPO"
Write-Host "  4. Render reads render.yaml automatically"
Write-Host "  5. Add 2 environment variables in Render dashboard:"
Write-Host "       MONGO_URI    = your MongoDB Atlas string"
Write-Host "       FAST2SMS_KEY = your Fast2SMS key"
Write-Host "  6. Click Deploy - live in about 2 minutes"
Write-Host ""
Write-Host "  Your live URL will be:" -ForegroundColor Green
Write-Host "  https://$GH_REPO.onrender.com" -ForegroundColor Green
Write-Host ""
Write-Host "Opening render.com for you now..."
Start-Process "https://render.com"
Write-Host ""
Pause-Script
