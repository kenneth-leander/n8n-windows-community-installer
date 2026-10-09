@echo off
rem ---------------------------------------------------------------------------
rem  Starts n8n inside the Linux distribution "@@DISTRO@@" (WSL2).
rem  Edit the settings below with Notepad, save, and start n8n again.
rem  Created by the n8n Windows Community Installer (unofficial).
rem ---------------------------------------------------------------------------
setlocal
chcp 65001 >nul 2>&1
title n8n (Linux: @@DISTRO@@)

rem The port n8n answers on. n8n also uses the next port up, for its task runner.
set "N8N_PORT=@@PORT@@"

rem Optional settings. To turn one on, remove "rem" at the start of its line.
rem Each one must end with a semicolon, and must not contain a double quote.
set "N8N_EXTRA="
rem set "N8N_EXTRA=%N8N_EXTRA%export EXECUTIONS_DATA_PRUNE=true; "
rem set "N8N_EXTRA=%N8N_EXTRA%export EXECUTIONS_DATA_MAX_AGE=168; "
rem set "N8N_EXTRA=%N8N_EXTRA%export WEBHOOK_URL=https://n8n.example.com/; "
rem Needed only when you open n8n from another device over plain http (see README.txt):
rem set "N8N_EXTRA=%N8N_EXTRA%export N8N_SECURE_COOKIE=false; "

rem The address n8n listens on inside Linux. 0.0.0.0 is what lets Windows open n8n at http://localhost, and the
rem virtual machine of WSL2 sits behind Windows, so other devices cannot reach it (see README.txt).
rem It must be an IPv4 address: with the default of n8n (IPv6) Windows can only open http://[::1]:%N8N_PORT%.
set "N8N_LISTEN=@@WSL_LISTEN@@"

set /a N8N_BROKER_PORT=%N8N_PORT%+1

echo.
echo   Starting n8n inside Linux (@@DISTRO@@)...
echo   Address: http://localhost:%N8N_PORT%
echo   It opens in your browser as soon as it is ready. The first start takes a minute.
echo   Press Ctrl+C in this window, or use "Stop n8n" in the Start menu, to stop n8n.
echo.
rem The browser helper shares this window with n8n, so it must not be started hidden: that would hide this window.
if not defined N8N_NO_BROWSER start "" /b "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0support\wait-n8n.ps1" -Url "http://localhost:%N8N_PORT%" -Open

rem N8N_USER_FOLDER is the home folder; n8n adds the ".n8n" folder inside it by itself.
"%SystemRoot%\System32\wsl.exe" -d @@DISTRO@@ --exec sh -c "PATH=@@WSL_PATH@@; export PATH; cd @@WSL_HOME@@; export N8N_USER_FOLDER=@@WSL_HOME@@; export N8N_PORT=%N8N_PORT%; export N8N_RUNNERS_BROKER_PORT=%N8N_BROKER_PORT%; export N8N_PROTOCOL=http; export N8N_HOST=localhost; export N8N_LISTEN_ADDRESS=%N8N_LISTEN%; export N8N_UNVERIFIED_PACKAGES_ENABLED=true; @@WSL_COOKIE@@ %N8N_EXTRA% exec n8n start"
set "N8N_RC=%errorlevel%"

rem 0 is a normal stop. Linux reports a stop by Ctrl+C as 130 and a stop by "Stop n8n" as 143 (128 plus the signal number).
set "N8N_WAS_STOPPED="
if "%N8N_RC%"=="0" set "N8N_WAS_STOPPED=1"
if "%N8N_RC%"=="130" set "N8N_WAS_STOPPED=1"
if "%N8N_RC%"=="143" set "N8N_WAS_STOPPED=1"

echo.
echo   n8n has stopped.
if not defined N8N_WAS_STOPPED (
    echo   If you did not close it yourself, the lines above tell you why.
    echo   If they say that the distribution "@@DISTRO@@" was not found, it is no longer in WSL.
)
echo.
if not defined N8N_NO_PAUSE pause
exit /b %N8N_RC%
