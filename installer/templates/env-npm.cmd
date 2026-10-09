@echo off
rem ---------------------------------------------------------------------------
rem  n8n settings for this install. Edit this file to change them, then start
rem  n8n again. It is used by Start n8n and by the n8n command.
rem  Created by the n8n Windows Community Installer (unofficial).
rem ---------------------------------------------------------------------------
set "N8N_HOME=%~dp0"
if "%N8N_HOME:~-1%"=="\" set "N8N_HOME=%N8N_HOME:~0,-1%"

rem Where n8n keeps your workflows, passwords and settings. n8n adds a ".n8n"
rem folder inside it, so the data really lives in %N8N_USER_FOLDER%\.n8n
set "N8N_USER_FOLDER=@@USER_FOLDER@@"

rem The address n8n answers on. 127.0.0.1 means this computer only; 0.0.0.0 means other devices can connect too.
set "N8N_PORT=@@PORT@@"
set "N8N_LISTEN_ADDRESS=@@LISTEN@@"
set "N8N_HOST=localhost"
set "N8N_PROTOCOL=http"
@@SECURE_COOKIE@@
rem n8n also uses the next port up, for its task runner.
set "N8N_RUNNERS_BROKER_PORT=@@BROKER_PORT@@"

set "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false"
set "N8N_UNVERIFIED_PACKAGES_ENABLED=true"

rem Optional settings. Remove "rem" at the start of a line to turn one on.
rem set "EXECUTIONS_DATA_PRUNE=true"
rem set "EXECUTIONS_DATA_MAX_AGE=168"
rem set "WEBHOOK_URL=https://n8n.example.com/"
@@PATH_LINE@@
