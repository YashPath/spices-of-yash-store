@echo off
setlocal
cd /d "%~dp0"
echo ==============================================
echo       SPICES OF YASH - LOCAL STARTER
echo ==============================================
where node >nul 2>nul
if errorlevel 1 (
  echo ERROR: Node.js is not installed.
  echo Install Node.js 20 or newer from https://nodejs.org/ then reopen this file.
  pause
  exit /b 1
)
node --version
if not exist package.json (
  echo ERROR: package.json is missing. Extract the complete ZIP first.
  pause
  exit /b 1
)
if not exist .env (
  copy .env.example .env >nul
  echo Created .env from .env.example.
  echo IMPORTANT: Set SESSION_SECRET in .env before using outside local development.
)
if not exist node_modules (
  echo Installing dependencies. This can take a few minutes...
  call npm install
  if errorlevel 1 (
    echo.
    echo Dependency installation failed. Please send a screenshot of this window.
    pause
    exit /b 1
  )
)
echo.
echo Starting store at http://localhost:3000
call npm start
pause
