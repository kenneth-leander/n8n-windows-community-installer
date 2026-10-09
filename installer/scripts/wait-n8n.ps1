# Waits until n8n is ready, then optionally opens it in the default browser.
#   wait-n8n.ps1 -Url http://localhost:5678 [-TimeoutSec 240] [-Open]
# Exit code 0 = n8n is ready, 1 = gave up waiting (or the window that started this script went away).
#
# The start scripts run this in the background, in the same window that n8n writes to. So it must never be
# started with -WindowStyle Hidden: that hides the shared window, with n8n still running inside it.
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [int]$TimeoutSec = 240,
    [switch]$Open
)
$ErrorActionPreference = 'SilentlyContinue'
try { $Host.UI.RawUI.WindowTitle = 'n8n' } catch { }

# n8n answers its plain health page as soon as it listens, while it is still setting up its database and its
# web page is not there yet. The readiness page answers 200 only once the page can be opened. An n8n without a
# readiness page (404) is waited for on the plain health page.
$base = $Url.TrimEnd('/')
$check = $base + '/healthz/readiness'

# Once the start script that started this one has ended (n8n stopped, or its window was closed), there is
# nothing left to wait for.
$parent = 0
try { $parent = [int](Get-CimInstance Win32_Process -Filter "ProcessId = $PID").ParentProcessId } catch { }

$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri $check -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($r.StatusCode -eq 200) {
            if ($Open) { Start-Process $Url }
            exit 0
        }
    }
    catch {
        $code = 0
        try { $code = [int]$_.Exception.Response.StatusCode } catch { }
        if ($code -eq 404) { $check = $base + '/healthz' }
    }
    if (($parent -gt 0) -and -not (Get-Process -Id $parent -ErrorAction SilentlyContinue)) { exit 1 }
    Start-Sleep -Seconds 2
}
exit 1
