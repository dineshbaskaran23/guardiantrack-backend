@echo off
REM ============================================================
REM  GuardianTrack — One-command GitHub push script for Windows
REM  Run this AFTER setting up GitHub remote (Step 3 below)
REM ============================================================

echo.
echo ============================================
echo   GuardianTrack Auto-Deploy
echo ============================================
echo.

REM Check if git is installed
git --version >nul 2>&1
IF ERRORLEVEL 1 (
  echo ERROR: Git is not installed.
  echo Download it from: https://git-scm.com/download/win
  pause
  exit /b 1
)

REM Check if we're in the right folder
IF NOT EXIST "server.js" (
  echo ERROR: Run this script from inside the guardian-backend folder.
  echo Example: cd C:\Users\YourName\GuardianTrack\guardian-backend
  pause
  exit /b 1
)

REM Stage all changes
echo [1/4] Staging files...
git add -A

REM Commit with timestamp
set TIMESTAMP=%date% %time%
echo [2/4] Committing...
git commit -m "Deploy: %TIMESTAMP%"

REM Push to GitHub (triggers auto-deploy on Render)
echo [3/4] Pushing to GitHub...
git push origin main

IF ERRORLEVEL 1 (
  echo.
  echo ERROR: Push failed. Check your GitHub credentials.
  echo Make sure you set the remote with:
  echo   git remote add origin https://github.com/YOUR_USERNAME/guardiantrack-backend.git
  pause
  exit /b 1
)

echo [4/4] Done!
echo.
echo ============================================
echo   Code pushed to GitHub!
echo   Render will auto-deploy in ~2 minutes.
echo   Check status at: https://render.com/dashboard
echo ============================================
echo.
pause
