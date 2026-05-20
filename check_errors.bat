@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "LOG_DIR=%APPDATA%\Godot\app_userdata\Combat Demo\logs"

if not exist "%LOG_DIR%" (
    echo [ERROR] Log directory not found: %LOG_DIR%
    echo Is Godot editor running? Has the project been opened at least once?
    pause
    exit /b 1
)

:: Find the most recent log file (godot.log = current session, godot*.log = rotated)
set "LATEST="
for /f "delims=" %%f in ('dir /b /o-d "%LOG_DIR%\godot*.log" 2^>nul') do (
    set "LATEST=%LOG_DIR%\%%f"
    goto :found
)

:found
if "%LATEST%"=="" (
    echo [ERROR] No log files found in %LOG_DIR%
    pause
    exit /b 1
)

echo =============================================
echo  Reading: %LATEST%
echo =============================================
echo.

:: Extract ERROR and WARNING lines with 1 line of context after each
findstr /i /c:"ERROR:" /c:"SCRIPT ERROR:" /c:"WARNING:" /c:"Parser Error:" "%LATEST%"

echo.
echo =============================================
echo  Done. Run Godot and trigger the error, then re-run this script.
echo =============================================
pause
