@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_all.ps1" %*
set EXIT_CODE=%ERRORLEVEL%

exit /b %EXIT_CODE%
