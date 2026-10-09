@echo off
setlocal
title n8n
echo.
echo   Starting n8n in Docker (container "@@DOCKER_NAME@@")...
docker start @@DOCKER_NAME@@ >nul 2>&1
if errorlevel 1 (
    echo.
    echo   Could not start the container. Is Docker Desktop running?
    echo   Start Docker Desktop, wait until it is running, then try again.
    echo.
    if not defined N8N_NO_PAUSE pause
    exit /b 1
)
echo   It opens in your browser as soon as it is ready: @@URL@@
set "N8N_OPEN=-Open"
if defined N8N_NO_BROWSER set "N8N_OPEN="
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0support\wait-n8n.ps1" -Url "@@URL@@" %N8N_OPEN%
if errorlevel 1 (
    echo.
    echo   n8n did not answer in time. To see what it says, run:  docker logs @@DOCKER_NAME@@
    echo.
    if not defined N8N_NO_PAUSE pause
    exit /b 1
)
