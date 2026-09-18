@echo off
pwsh.exe -NoProfile -File "%~dp0Run-Quarter-View.ps1" -DesignCompare
if errorlevel 1 pause
