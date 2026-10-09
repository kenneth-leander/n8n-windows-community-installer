@echo off
setlocal
title Stop n8n
echo.
echo   Stopping n8n (container "@@DOCKER_NAME@@")...
docker stop @@DOCKER_NAME@@
echo.
echo   n8n has stopped. Your workflows are kept in the Docker volume "@@DOCKER_VOLUME@@".
if not defined N8N_NO_PAUSE pause
