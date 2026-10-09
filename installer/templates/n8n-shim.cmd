@echo off
rem Lets you type "n8n" in any terminal. It runs the n8n of this install, with this install's settings.
setlocal
call "%~dp0..\n8n-env.cmd"
@@SHIM_RUN_LINE@@
