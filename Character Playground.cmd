@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\mocap\play_skinned.ps1" -Playground
if errorlevel 1 pause
