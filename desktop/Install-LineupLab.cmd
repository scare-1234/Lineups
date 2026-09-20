@echo off
setlocal enabledelayedexpansion
title LineupLab - build and install

cd /d "%~dp0"

echo.
echo  ==========================================================
echo    LineupLab for Windows
echo    Builds the app and launches the installer.
echo    First run takes a few minutes and downloads about 250 MB.
echo  ==========================================================
echo.

if not exist "package.json" goto :wrongfolder

where node >nul 2>nul
if errorlevel 1 goto :nonode

for /f "tokens=*" %%v in ('node --version 2^>nul') do set "NODEVER=%%v"
set "NODENUM=!NODEVER:v=!"
for /f "tokens=1 delims=." %%a in ("!NODENUM!") do set "NODEMAJOR=%%a"
if "!NODEMAJOR!"=="" goto :nonode
if !NODEMAJOR! LSS 20 goto :oldnode

echo Using Node !NODEVER!
echo.
echo [1/3] Installing dependencies...
call npm install
if errorlevel 1 goto :fail

echo.
echo [2/3] Building LineupLab. This is the slow part...
call npm run dist:win
if errorlevel 1 goto :fail

echo.
echo [3/3] Finding the installer...
set "SETUP="
for /f "delims=" %%f in ('dir /b /a-d "release\*Setup*.exe" 2^>nul') do set "SETUP=%%f"
if not defined SETUP goto :nosetup

echo Found release\!SETUP!
echo.
echo Starting the installer now.
echo If Windows shows a blue SmartScreen warning, choose More info, then Run anyway.
echo The app is not code signed, which is why that warning appears.
echo.
start "" "release\!SETUP!"

echo Once the installer finishes, LineupLab is on your desktop and in the Start menu.
echo Open it and paste your API-Football key into the Settings screen.
echo.
pause
exit /b 0

:wrongfolder
echo ERROR: this file must stay inside the project's desktop folder.
echo Download the whole project from https://github.com/scare-1234/Lineups
echo and run this file from there.
echo.
pause
exit /b 1

:nonode
echo ERROR: Node.js was not found.
echo.
echo Install it, then run this file again:
echo   - Download the LTS installer from https://nodejs.org
echo   - Or in a terminal: winget install OpenJS.NodeJS.LTS
echo.
pause
exit /b 1

:oldnode
echo ERROR: Node !NODEVER! is too old. LineupLab needs Node 20 or newer.
echo Update from https://nodejs.org and run this file again.
echo.
pause
exit /b 1

:fail
echo.
echo Build failed. The error above says why.
echo Common causes: no internet connection, or a virus scanner blocking npm.
echo.
pause
exit /b 1

:nosetup
echo.
echo The build finished but no installer was found in the release folder.
echo You can still run the app directly:
echo   release\win-unpacked\LineupLab.exe
echo.
pause
exit /b 1
