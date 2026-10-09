# Waits until n8n answers on its health URL. Optionally opens it in the default browser.
#   wait-n8n.ps1 -Url http://localhost:5678 [-TimeoutSec 240] [-Open]
# Exit code 0 = n8n is up, 1 = gave up waiting.
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [int]$TimeoutSec = 240,
    [switch]$Open
)
$ErrorActionPreference = 'SilentlyContinue'
$health = $Url.TrimEnd('/') + '/healthz'
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri $health -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) {
            if ($Open) { Start-Process $Url }
            exit 0
        }
    }
    catch { }
    Start-Sleep -Seconds 2
}
exit 1
