@echo off
title GuardianTrack Setup
color 0A

echo.
echo  ================================================
echo    GuardianTrack - Windows Setup
echo  ================================================
echo.
echo  Window will stay open the whole time.
echo.
pause

REM ── STEP 1: Check Git ────────────────────────────────────────
echo.
echo  [STEP 1 of 6] Checking Git is installed...
git --version
IF ERRORLEVEL 1 (
  echo.
  echo  ERROR: Git not found.
  echo  Download from: https://git-scm.com/download/win
  echo  Install it then run this script again.
  echo.
  pause
  exit /b 1
)
echo  Git is OK.

REM ── STEP 2: Check Node ───────────────────────────────────────
echo.
echo  [STEP 2 of 6] Checking Node.js is installed...
node --version
IF ERRORLEVEL 1 (
  echo.
  echo  ERROR: Node.js not found.
  echo  Download from: https://nodejs.org  (LTS version)
  echo  Install it then run this script again.
  echo.
  pause
  exit /b 1
)
echo  Node.js is OK.

REM ── STEP 3: Check correct folder ─────────────────────────────
IF NOT EXIST "server.js" (
  echo.
  echo  ERROR: Wrong folder.
  echo  Run this script from INSIDE the guardian-backend folder.
  echo.
  pause
  exit /b 1
)

REM ── STEP 4: npm install ──────────────────────────────────────
echo.
echo  [STEP 3 of 6] Installing packages - please wait...
echo.
call npm install
IF ERRORLEVEL 1 (
  echo.
  echo  ERROR: npm install failed. See error above.
  echo.
  pause
  exit /b 1
)
echo.
echo  Packages installed OK.

REM ── STEP 5: Open .env ────────────────────────────────────────
echo.
echo  [STEP 4 of 6] Opening .env in Notepad...
echo.

IF NOT EXIST ".env" (
  copy .env.example .env >nul
)

echo  Fill in MONGO_URI and FAST2SMS_KEY then close Notepad.
echo.
start /wait notepad.exe .env
echo  Notepad closed. Good.
echo.
pause

REM ── STEP 6: GitHub input ─────────────────────────────────────
echo.
echo  [STEP 5 of 6] GitHub setup
echo.
echo  You need 3 things from GitHub:
echo    1. Your USERNAME
echo    2. An empty REPO NAME you created
echo    3. A Personal Access Token (ghp_...)
echo.
echo  To get a token: github.com - Settings - Developer settings
echo  - Personal access tokens - Tokens classic - Generate new
echo  - Tick "repo" - Generate - Copy the ghp_... token
echo.

set /p GH_USER=Enter GitHub username: 
set /p GH_REPO=Enter repo name: 
set /p GH_TOKEN=Enter token (ghp_...): 

echo.
echo  Configuring git remote...
git remote remove origin >nul 2>&1
git remote add origin https://%GH_TOKEN%@github.com/%GH_USER%/%GH_REPO%.git
git branch -M main

REM ── STEP 7: Push ─────────────────────────────────────────────
echo.
echo  [STEP 6 of 6] Pushing to GitHub...
echo.
git add -A
git commit -m "Initial deploy: GuardianTrack backend"
git push -u origin main

IF ERRORLEVEL 1 (
  echo.
  echo  PUSH FAILED. Common reasons:
  echo    - Token wrong or expired - regenerate it
  echo    - Repo not empty - delete all files in the repo
  echo    - Username or repo name typo
  echo.
  pause
  exit /b 1
)

git remote set-url origin https://github.com/%GH_USER%/%GH_REPO%.git

echo.
echo  ================================================
echo    SUCCESS - Code is now on GitHub!
echo  ================================================
echo.
echo  NOW GO TO render.com and:
echo    1. Sign up with GitHub
echo    2. New plus - Web Service - connect your repo
echo    3. Render reads render.yaml automatically
echo    4. Add MONGO_URI and FAST2SMS_KEY manually
echo    5. Click Deploy
echo.
echo  Your live URL: https://%GH_REPO%.onrender.com
echo.
pause
