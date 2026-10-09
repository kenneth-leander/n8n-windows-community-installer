# Lists the Linux distributions installed in WSL, one per line as: name|version|state
# (docker-desktop and rancher-desktop are skipped, they are not general-purpose distros).
# wsl.exe writes UTF-16, so its output is decoded here. Prints nothing when WSL has no distro.
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::Unicode
$names = @(wsl.exe -l -q) | ForEach-Object { ($_ -replace [char]0, '').Trim() } |
    Where-Object { $_ -and $_ -notmatch '^(docker-desktop|rancher-desktop)' }
$vlines = @(wsl.exe -l -v) | ForEach-Object { (($_ -replace [char]0, '').Trim()) -replace '^\*\s*', '' }
foreach ($d in $names) {
    $ver = '2'; $st = 'Unknown'
    foreach ($r in $vlines) {
        if ($r.StartsWith($d + ' ')) {
            $p = @($r -split '\s+')
            if ($p.Length -ge 3) { $st = $p[$p.Length - 2]; $ver = $p[$p.Length - 1] }
            break
        }
    }
    '{0}|{1}|{2}' -f $d, $ver, $st
}
