@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\vault.ps1" search -Interactive
set "vaultExit=%errorlevel%"
pause
exit /b %vaultExit%
