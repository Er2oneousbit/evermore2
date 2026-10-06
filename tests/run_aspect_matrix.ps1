<#
.SYNOPSIS
    Runs tests/smoke_aspect at a list of monitor resolutions (Windows).

.DESCRIPTION
    Launches the game once per resolution with --resolution and reports
    PASS/FAIL for each. Windows may shrink windows bigger than your desktop;
    the test validates against the ACTUAL window size it got, so results are
    still meaningful, but sizes larger than your monitor won't be exercised
    exactly. For the full ultrawide matrix use tests/run_aspect_matrix.sh on
    Linux/CI (virtual display, any size).

.PARAMETER Godot
    Path to the Godot CONSOLE executable, e.g.
    C:\Tools\Godot_v4.7.2-stable_win64_console.exe
    (It ships in the same zip as the normal .exe. The normal .exe is a GUI app,
    so its test output and exit codes don't reliably reach PowerShell.)

.PARAMETER ShotDir
    Optional folder to save screenshots into.

.PARAMETER Resolutions
    Optional list overriding the default resolutions. Accepts an array
    (-Resolutions 2560x1080,3440x1440) or one comma-separated string, which is
    what you get when launching via "pwsh script.ps1 ..." from cmd or a shortcut.

.PARAMETER ExtraArgs
    Extra arguments passed straight to Godot, e.g. for older GPUs or VMs:
    -ExtraArgs "--rendering-method gl_compatibility"

.EXAMPLE
    pwsh tests/run_aspect_matrix.ps1 -Godot C:\Tools\Godot_v4.7.2-stable_win64_console.exe

.EXAMPLE
    pwsh tests/run_aspect_matrix.ps1 -Godot .\godot_console.exe -ShotDir C:\temp\shots -Resolutions 2560x1080,3440x1440

.NOTES
    Requires PowerShell 7+.
    Written with help from Claude (Anthropic) via Claude Code.
    Made with ❤️ from your friendly hacker - er2oneousbit
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$ShotDir = "",
    [string[]]$Resolutions = @(
        "1280x800", "1366x768", "1920x1080", "2560x1440", "3840x2160",
        "2560x1080", "3440x1440", "3840x1600",
        "3840x1080", "5120x1440", "7680x2160",
        "5760x1080", "7680x1440"
    ),
    [string[]]$ExtraArgs = @()
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "You're running PowerShell $($PSVersionTable.PSVersion). This script targets PowerShell 7+ (pwsh). It may work, but install PS7: https://aka.ms/powershell"
}

if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Error "Godot executable not found: $Godot"
    exit 1
}
if ((Split-Path -Leaf $Godot) -notmatch 'console') {
    Write-Warning "'$Godot' doesn't look like the *_console.exe build. Output and PASS/FAIL detection may be missing; use the console exe from the same Godot zip."
}

# "a,b" arrives as ONE string when launched via pwsh -File; split it either way.
$Resolutions = @($Resolutions | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$bad = @($Resolutions | Where-Object { $_ -notmatch '^\d+x\d+$' })
if ($bad.Count -gt 0) {
    Write-Error "Bad resolution(s): $($bad -join ', ')  (expected WIDTHxHEIGHT, e.g. 3440x1440)"
    exit 1
}
# Split on whitespace (not commas: Godot args like "--position 10,10" use them).
$ExtraArgs = @($ExtraArgs | ForEach-Object { $_ -split '\s+' } | Where-Object { $_ })

$projectDir = Resolve-Path (Join-Path $PSScriptRoot "..")
if ($ShotDir) {
    New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null
    $env:EVERMORE_SHOT_DIR = $ShotDir
}

$failed = $false
foreach ($res in $Resolutions) {
    Write-Host ("{0,-10} " -f $res) -NoNewline
    # Console build: stdout + exit code come straight back to PowerShell.
    $output = & $Godot --path $projectDir @ExtraArgs --resolution $res --position 0,0 res://tests/smoke_aspect.tscn 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $output -match '\[TEST\] PASS') {
        $summary = ([regex]::Match($output, 'window \([^)]*\) -> scale \d+x, view \([^)]*\)')).Value
        Write-Host "PASS  $summary" -ForegroundColor Green
    }
    elseif ($LASTEXITCODE -eq 0) {
        # Exit 0 but no test output: almost always the GUI exe instead of *_console.exe.
        Write-Host "UNKNOWN (no [TEST] output; are you using the *_console.exe?)" -ForegroundColor Yellow
        $failed = $true
    }
    else {
        Write-Host "FAIL (exit $LASTEXITCODE)" -ForegroundColor Red
        $output -split "`n" | Where-Object { $_ -match '\[TEST\] FAIL|ERROR|SCRIPT' } |
            ForEach-Object { Write-Host "           $_" }
        $failed = $true
    }
}

if ($failed) { Write-Host "SOME RESOLUTIONS FAILED" -ForegroundColor Red; exit 1 }
Write-Host "ALL RESOLUTIONS PASSED" -ForegroundColor Green
exit 0
