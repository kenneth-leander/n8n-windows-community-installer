@echo off
setlocal
title Stop n8n
echo.
echo   Stopping n8n inside Linux (@@DISTRO@@)...
rem Only the n8n of this install is stopped: its full path is part of the search text.
rem The dot stands for the space in "n8n start". The shell is replaced by pkill (exec), so
rem it cannot find itself; "sh" also tells us when pkill is missing (code 127).
"%SystemRoot%\System32\wsl.exe" -d @@DISTRO@@ --exec sh -c "exec pkill -f @@WSL_N8N@@.start"
set "N8N_RC=%errorlevel%"
echo.
if "%N8N_RC%"=="0" (
    echo   n8n was told to stop. It needs a few seconds to close.
    echo   Your workflows are kept inside @@DISTRO@@, in @@WSL_DATA@@
) else if "%N8N_RC%"=="1" (
    echo   n8n was not running.
) else if "%N8N_RC%"=="127" (
    echo   The program pkill was not found inside @@DISTRO@@, so n8n cannot be stopped from here.
    echo   Close the window that runs n8n, or press Ctrl+C in it.
) else (
    echo   Could not reach @@DISTRO@@ ^(code %N8N_RC%^).
    echo   If n8n is running, close the window that runs it.
)
echo.
if not defined N8N_NO_PAUSE pause
exit /b 0
