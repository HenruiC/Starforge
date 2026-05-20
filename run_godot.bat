@echo off
chcp 65001 >nul

set "GODOT_EXE=D:\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe"
set "PROJECT_DIR=%~dp0"
set "LOG_FILE=%PROJECT_DIR%\godot_editor.log"

if not exist "%GODOT_EXE%" (
    echo [ERROR] Godot executable not found: %GODOT_EXE%
    echo Update the GODOT_EXE path in this script if needed.
    pause
    exit /b 1
)

echo Starting Godot with log output to: %LOG_FILE%
echo.
"%GODOT_EXE%" --editor --path "%PROJECT_DIR%" --log-file "%LOG_FILE%"
