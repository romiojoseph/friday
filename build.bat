@echo off
title Friday Build Pipeline
echo ===================================================
echo             FRIDAY BUILD PIPELINE
echo ===================================================
echo.

echo [1/3] Building React Frontend...
cd frontend
call npm.cmd run build
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Frontend build failed!
    pause
    exit /b %ERRORLEVEL%
)
cd ..
echo [SUCCESS] Frontend built successfully.
echo.

echo [2/3] Compiling Go Backend...
if exist "%USERPROFILE%\go\bin\go-winres.exe" (
    echo [INFO] Generating Windows resources...
    "%USERPROFILE%\go\bin\go-winres.exe" make || echo [WARN] go-winres make failed, continuing
)
go build -ldflags="-s -w -H=windowsgui" -o dist/Friday.exe .
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Go backend compilation failed!
    pause
    exit /b %ERRORLEVEL%
)
echo [SUCCESS] Backend compiled to dist/Friday.exe successfully.
echo.

echo [3/3] UPX Compression Choice...
cd dist
if not exist "upx.exe" (
    echo [INFO] upx.exe not found in dist. Skipping compression option.
    goto end
)

set /p choice="Do you want to run UPX compression on Friday.exe? (y/n): "
if /i "%choice%"=="y" (
    echo.
    echo Running UPX compression...
    upx.exe --best Friday.exe
    echo.
    echo [SUCCESS] Compression complete.
) else (
    echo.
    echo Skipping UPX compression.
)

:end
cd ..
echo.
echo ===================================================
echo             BUILD PROCESS COMPLETE!
echo ===================================================
pause
