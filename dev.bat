@echo off
title Friday Dev Environment
echo ===================================================
echo             STARTING FRIDAY DEV PIPELINE
echo ===================================================
echo.

echo [1/3] Generating Windows resources...
if exist "%USERPROFILE%\go\bin\go-winres.exe" (
    "%USERPROFILE%\go\bin\go-winres.exe" make || echo [WARN] go-winres make failed, continuing
)
echo.

echo [2/3] Launching Go Backend in a new window...
start "Friday Backend" cmd /k "go run ."

echo [3/3] Launching React Dev Server in a new window...
start "Friday React Frontend" cmd /k "cd /d "%~dp0frontend" && npm run dev"

echo.
echo ===================================================
echo          DEV ENVIRONMENT RUNNING IN WINDOWS!
echo ===================================================
echo.
pause
