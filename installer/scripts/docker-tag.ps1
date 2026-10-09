# Looks up which n8n image tags to offer. Prints up to two lines:
#   v2=<newest stable 2.x.y tag>
#   v3=<newest numbered 3.x.y tag, or v3-nightly while no numbered 3.x exists>
# Prints nothing when Docker Hub cannot be reached; the installer then falls back to a built-in tag.
# Docker has no floating "2.x" tag, and the stable and latest tags move to 3.0 once it ships,
# so the exact 2.x.y release is looked up here.
$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $base = 'https://hub.docker.com/v2/repositories/n8nio/n8n/tags'

    function Get-Tags([string]$prefix) {
        @((Invoke-RestMethod -Uri ($base + '?page_size=100&name=' + $prefix) -TimeoutSec 20).results |
            Where-Object { $_.name -match ('^' + [regex]::Escape($prefix) + '\d+\.\d+$') })
    }

    # 2.x: the tag that "stable" points to, if that is still a 2.x release; else the newest 2.x.y.
    $stableDigest = (Invoke-RestMethod -Uri ($base + '/stable') -TimeoutSec 20).digest
    $t2 = Get-Tags '2.'
    $v2 = ''
    $match = @($t2 | Where-Object { $_.digest -eq $stableDigest })
    if ($match.Count -gt 0) { $v2 = $match[0].name }
    elseif ($t2.Count -gt 0) { $v2 = ($t2 | Sort-Object { [version]$_.name } -Descending | Select-Object -First 1).name }
    if ($v2 -match '^2\.\d+\.\d+$') { "v2=$v2" }

    # 3.x: numbered releases once they exist; before that, the nightly build.
    $t3 = Get-Tags '3.'
    if ($t3.Count -gt 0) {
        $v3 = ($t3 | Sort-Object { [version]$_.name } -Descending | Select-Object -First 1).name
        "v3=$v3"
    }
    else {
        $null = Invoke-RestMethod -Uri ($base + '/v3-nightly') -TimeoutSec 20
        'v3=v3-nightly'
    }
}
catch { }
exit 0
