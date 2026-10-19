@echo off
REM Launcher for PZ Mod Manager — double-click this file.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PZModManager.ps1"
REM Only pause on a crash (non-zero exit), so a clean close exits with no console window.
if errorlevel 1 pause
