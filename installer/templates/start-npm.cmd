@echo off
setlocal
call "%~dp0n8n-env.cmd"
title n8n
cd /d "%N8N_HOME%"

echo.
echo   Starting n8n. It opens in your browser when it is ready.
echo   The first start takes a little longer, while n8n sets up its database.
echo   Address: http://localhost:%N8N_PORT%
echo   Close this window, or press Ctrl+C, to stop n8n.
echo.
rem The browser helper shares this window with n8n, so it must not be started hidden: that would hide this window.
if not defined N8N_NO_BROWSER start "" /b "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%N8N_HOME%\support\wait-n8n.ps1" -Url "http://localhost:%N8N_PORT%" -Open
@@RUN_LINE@@
echo.
echo   n8n has stopped.
if not defined N8N_NO_PAUSE pause
