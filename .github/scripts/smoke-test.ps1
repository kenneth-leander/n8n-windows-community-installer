<#
Installs n8n with npm the way n8n-Installer.bat does, starts it, and checks that it answers.
Called by .github/workflows/windows-npm-smoke-test.yml. Keep the npm commands in sync with the .bat.

  -Mode    folder           npm install n8n@2 inside a folder, with the sqlite3 allowance in a project .npmrc
           global           npm install -g n8n@2 --allow-scripts=sqlite3
           folder-cli-flag  the same folder install but with --allow-scripts on the command line
                            (what 0.2 did; npm 11.19 and newer reject it, so this is expected to fail)
  -Expect  ok    installs and starts the current n8n 2.x
           old   installs and starts, but only n8n 2.35.x, the last release that runs on Node.js 22
           fail  the install or the start fails

The script exits 0 when the outcome matches -Expect, and 1 otherwise.
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet('folder', 'global', 'folder-cli-flag')][string]$Mode,
    [Parameter(Mandatory = $true)][ValidateSet('ok', 'old', 'fail')][string]$Expect,
    [string]$Work
)

$ErrorActionPreference = 'Continue'

function Write-Section([string]$Text) {
    Write-Host ''
    Write-Host "=== $Text ==="
}

if (-not $Work) { $Work = Join-Path ([System.IO.Path]::GetTempPath()) "n8n-smoke-$Mode" }
if (Test-Path $Work) { Remove-Item -Recurse -Force $Work }
New-Item -ItemType Directory -Path $Work | Out-Null

$nodeVersion = (& node --version).Trim()
$npmVersion = (& npm --version).Trim()
Write-Section 'Versions'
Write-Host "node $nodeVersion, npm $npmVersion"

# ---- Install ---------------------------------------------------------------
$log = Join-Path $Work 'install.log'
$installDir = Join-Path $Work 'n8n-folder'
$globalPrefix = Join-Path $Work 'n8n-global'
Write-Section "Install ($Mode)"
$started = Get-Date

if ($Mode -eq 'global') {
    & npm install -g n8n@2 --allow-scripts=sqlite3 --prefix $globalPrefix --loglevel=warn --no-fund --no-audit *>&1 | Tee-Object -FilePath $log
}
elseif ($Mode -eq 'folder') {
    New-Item -ItemType Directory -Path $installDir | Out-Null
    Set-Location $installDir
    Set-Content -Path (Join-Path $installDir '.npmrc') -Value 'allow-scripts=sqlite3' -Encoding ascii
    & npm install n8n@2 --loglevel=warn --no-fund --no-audit *>&1 | Tee-Object -FilePath $log
}
else {
    New-Item -ItemType Directory -Path $installDir | Out-Null
    Set-Location $installDir
    & npm install n8n@2 --allow-scripts=sqlite3 --loglevel=warn --no-fund --no-audit *>&1 | Tee-Object -FilePath $log
}
$installExit = $LASTEXITCODE
$seconds = [int]((Get-Date) - $started).TotalSeconds
Write-Host "npm exit code: $installExit (after $seconds s)"

Write-Section 'Lines that show why a native module or script failed'
$hits = @(Select-String -Path $log -Pattern 'gyp ERR!|find VS|EALLOWSCRIPTS|prebuild-install (warn|ERR)|node-pre-gyp ERR|npm error' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Line.Trim() } | Select-Object -Unique -First 20)
if ($hits.Count -eq 0) { Write-Host '(none)' } else { $hits | ForEach-Object { Write-Host $_ } }

# ---- Find the installed package -------------------------------------------
$n8nDir = $null
if ($installExit -eq 0) {
    if ($Mode -eq 'global') {
        $root = (& npm root -g --prefix $globalPrefix).Trim()
        $n8nDir = Join-Path $root 'n8n'
    }
    else {
        $n8nDir = Join-Path $installDir 'node_modules/n8n'
    }
    if (-not (Test-Path (Join-Path $n8nDir 'package.json'))) { $n8nDir = $null }
}

# ---- Native modules ---------------------------------------------------------
$version = $null
$modulesOk = $false
if ($n8nDir) {
    $version = (Get-Content (Join-Path $n8nDir 'package.json') -Raw | ConvertFrom-Json).version
    Write-Section "Installed n8n $version, loading its native modules"
    $check = Join-Path $Work 'check-modules.js'
    @'
const dir = process.argv[2];
const required = ['sqlite3', 'isolated-vm', '@confluentinc/kafka-javascript'];
const optional = ['@sentry/node-native-stacktrace', '@sentry/profiling-node'];
let failed = 0;
for (const name of required.concat(optional)) {
  try {
    require(require.resolve(name, { paths: [dir] }));
    console.log('OK    ' + name);
  } catch (e) {
    if (required.includes(name)) failed++;
    console.log('FAIL  ' + name + ' - ' + String(e.message).split('\n')[0].slice(0, 160));
  }
}
process.exit(failed ? 1 : 0);
'@ | Set-Content -Path $check -Encoding utf8
    & node $check $n8nDir
    $modulesOk = ($LASTEXITCODE -eq 0)
}

# ---- Start n8n --------------------------------------------------------------
$ready = $false
if ($n8nDir -and $modulesOk) {
    Write-Section 'Start n8n and wait for it to answer'
    $data = Join-Path $Work 'n8n-data'
    New-Item -ItemType Directory -Path $data | Out-Null
    $settings = @{
        N8N_USER_FOLDER                   = $data
        N8N_PORT                          = '5678'
        N8N_RUNNERS_BROKER_PORT           = '5679'
        N8N_LISTEN_ADDRESS                = '127.0.0.1'
        N8N_DIAGNOSTICS_ENABLED           = 'false'
        N8N_VERSION_NOTIFICATIONS_ENABLED = 'false'
        N8N_TEMPLATES_ENABLED             = 'false'
        N8N_PERSONALIZATION_ENABLED       = 'false'
        N8N_SECURE_COOKIE                 = 'false'
    }
    foreach ($name in $settings.Keys) { Set-Item -Path "Env:$name" -Value $settings[$name] }
    $out = Join-Path $Work 'n8n.out.log'
    $err = Join-Path $Work 'n8n.err.log'
    $proc = Start-Process -FilePath 'node' -ArgumentList @((Join-Path $n8nDir 'bin/n8n'), 'start') -WorkingDirectory $Work `
        -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    for ($i = 1; $i -le 90; $i++) {
        Start-Sleep -Seconds 2
        if ($proc.HasExited) { Write-Host "n8n exited early with code $($proc.ExitCode)"; break }
        try {
            $reply = Invoke-WebRequest -Uri 'http://127.0.0.1:5678/healthz/readiness' -UseBasicParsing -TimeoutSec 5
            if ($reply.StatusCode -eq 200) { $ready = $true; Write-Host "n8n answered /healthz/readiness after $($i * 2) s"; break }
        }
        catch { }
    }
    Write-Host '--- n8n output (last lines) ---'
    foreach ($file in @($out, $err)) { if (Test-Path $file) { Get-Content $file -Tail 12 } }
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
}

# ---- Verdict ----------------------------------------------------------------
$actual = 'fail'
if ($installExit -eq 0 -and $n8nDir -and $modulesOk -and $ready) {
    if ([version]$version -lt [version]'2.36.0') { $actual = 'old' } else { $actual = 'ok' }
}
Write-Section 'Result'
$summary = "Node $nodeVersion / npm $npmVersion / $Mode install: $actual (expected $Expect)"
if ($version) { $summary += ", n8n $version" }
Write-Host $summary
if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value "- $summary" }
if ($actual -eq $Expect) { exit 0 }
Write-Host "Outcome '$actual' does not match the expected '$Expect'."
exit 1
