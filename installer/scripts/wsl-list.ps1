# Lists the Linux distributions installed in WSL, one per line as: name|version|state
# (docker-desktop and rancher-desktop are skipped, they are not general-purpose distros).
# When it finds none, it prints one line instead, !<why>, so that the installer can say what WSL said or did.
# wsl.exe writes UTF-16, so its output is decoded here.
# -WslPath is for the tests, which point it at a stand-in for wsl.exe.
param([int]$TimeoutSec = 15, [string]$WslPath = '')
$ErrorActionPreference = 'SilentlyContinue'

# One short line of plain ASCII, with no | in it. The end of a long message is kept.
function Tidy([string]$Text, [int]$Max = 300) {
    $t = ($Text -replace '\s+', ' ').Trim()
    $t = $t -replace '[^\x20-\x7E]', '?'
    $t = $t -replace '\|', '/'
    if ($t.Length -gt $Max) { $t = '...' + $t.Substring($t.Length - ($Max - 3)) }
    return $t
}

# The lines in a file that wsl.exe wrote: UTF-16, or UTF-8 when WSL was asked for that.
function Read-WslFile([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) { return @() }
    if ($bytes -contains 0) { $text = [Text.Encoding]::Unicode.GetString($bytes) } else { $text = [Text.Encoding]::UTF8.GetString($bytes) }
    return @($text -split "`r?`n" | ForEach-Object { ($_ -replace '[\u0000\uFEFF]', '').Trim() } | Where-Object { $_ })
}

# Runs wsl.exe with the arguments. Returns Lines (what it printed, then what it wrote to its error output), its
# exit code, and Note: why it could not be run or did not finish, or '' when it ran and finished.
function Invoke-Wsl([string[]]$WslArgs) {
    $result = [pscustomobject]@{ Lines = @(); Code = -1; Note = '' }
    $out = [IO.Path]::GetTempFileName()
    $err = [IO.Path]::GetTempFileName()
    try {
        $p = $null
        try {
            $p = Start-Process -FilePath $wsl -ArgumentList $WslArgs -NoNewWindow -PassThru -ErrorAction Stop `
                -RedirectStandardOutput $out -RedirectStandardError $err
        } catch {
            $result.Note = 'Windows could not start wsl.exe: ' + (Tidy $_.Exception.Message 200)
        }
        if ($p) {
            if (-not $p.WaitForExit($TimeoutSec * 1000)) {
                try { $p.Kill() } catch { }
                $result.Note = "WSL did not answer within $TimeoutSec seconds."
            } else {
                $p.WaitForExit()
                $result.Code = $p.ExitCode
                $result.Lines = @(Read-WslFile $out) + @(Read-WslFile $err)
            }
        }
    }
    finally {
        Remove-Item -Path $out, $err -Force -ErrorAction SilentlyContinue
    }
    return $result
}

$wsl = $WslPath
if (-not $wsl) {
    $found = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($found) { $wsl = $found.Source }
}
if (-not $wsl) { '!wsl.exe was not found.'; exit 0 }

$names = Invoke-Wsl @('-l', '-q')
if ($names.Note) { '!' + $names.Note; exit 0 }
$table = Invoke-Wsl @('-l', '-v')
$rows = @($table.Lines | ForEach-Object { $_ -replace '^\*\s*', '' })

$listed = 0
$own = @()
if ($names.Code -eq 0) {
    foreach ($d in $names.Lines) {
        if ($d -match '^(docker-desktop|rancher-desktop)') { $own += $d; continue }
        $ver = ''; $state = ''
        foreach ($r in $rows) {
            if ($r.StartsWith($d + ' ') -and $r -match '\s([12])\s*$') {
                $ver = $Matches[1]
                $state = (($r.Substring($d.Length) -replace '\s+[12]\s*$', '')).Trim()
                break
            }
        }
        # Older Windows has no table with versions (wsl -l -v is not understood); everything there is WSL 1.
        if (-not $ver -and ($table.Note -or $table.Code -ne 0) -and $d -match '^[A-Za-z0-9][A-Za-z0-9._-]*$') { $ver = '1' }
        if ($ver) {
            if (-not $state) { $state = 'Unknown' }
            '{0}|{1}|{2}' -f (Tidy $d 60), $ver, (Tidy $state 40)
            $listed++
        }
    }
}

if ($listed -eq 0) {
    if ($own.Count -gt 0 -and $own.Count -eq $names.Lines.Count) {
        '!WSL has only ' + ($own -join ' and ') + ', which Docker Desktop or Rancher Desktop use for themselves, and no Linux distribution of your own.'
    } elseif ($names.Lines.Count -gt 0) {
        '!WSL said: ' + (Tidy ($names.Lines -join ' '))
    } elseif ($table.Lines.Count -gt 0) {
        '!WSL said: ' + (Tidy ($table.Lines -join ' '))
    } else {
        "!wsl.exe ended with code $($names.Code) and printed nothing."
    }
}
exit 0
