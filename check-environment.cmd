@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\vault.ps1" doctor
set "vaultExit=%errorlevel%"
pause
exit /b %vaultExit%
