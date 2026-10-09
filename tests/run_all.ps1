<#
.SYNOPSIS
    Runs every headless smoke test (Windows).

.DESCRIPTION
    smoke_follow at 30, 60 and 120 RENDER fps (physics stays at 60 Hz; this proves
    nothing depends on the render frame rate), smoke_visuals, smoke_faces, smoke_hd, smoke_dialogue, smoke_combat, smoke_party, smoke_settings, smoke_audio, smoke_items, smoke_ring, smoke_rings, smoke_clock, smoke_aspect (math part).
    No display needed. For the live ultrawide checks use run_aspect_matrix.ps1.

.PARAMETER Godot
    Path to the Godot CONSOLE executable, e.g.
    C:\Tools\Godot_v4.7.2-stable_win64_console.exe
    (The normal .exe is a GUI app; its output and exit codes don't reliably
    reach PowerShell.)

.EXAMPLE
    pwsh tests/run_all.ps1 -Godot C:\Tools\Godot_v4.7.2-stable_win64_console.exe

.NOTES
    Requires PowerShell 7+.
    Written with help from Claude (Anthropic) via Claude Code.
    Made with ❤️ from your friendly hacker - er2oneousbit
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Godot
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "You're running PowerShell $($PSVersionTable.PSVersion). This script targets PowerShell 7+ (pwsh). It may work, but install PS7: https://aka.ms/powershell"
}
if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Error "Godot executable not found: $Godot"
    exit 1
}
if ((Split-Path -Leaf $Godot) -notmatch 'console') {
    Write-Warning "'$Godot' doesn't look like the *_console.exe build. Output and PASS/FAIL detection may be missing."
}

$projectDir = Resolve-Path (Join-Path $PSScriptRoot "..")
# Frame cap: a test whose script fails to compile never quits on its own.
# Real runs need a few thousand frames; past this cap the run ends without
# a PASS line and counts as a failure, in seconds instead of hanging.
$maxFrames = 20000
$tests = @(
    @{ Label = "follow @30fps";  Scene = "res://tests/smoke_follow.tscn";  Args = @("--fixed-fps", "30") },
    @{ Label = "follow @60fps";  Scene = "res://tests/smoke_follow.tscn";  Args = @("--fixed-fps", "60") },
    @{ Label = "follow @120fps"; Scene = "res://tests/smoke_follow.tscn";  Args = @("--fixed-fps", "120") },
    @{ Label = "visuals";        Scene = "res://tests/smoke_visuals.tscn"; Args = @("--fixed-fps", "60") },
    @{ Label = "faces";          Scene = "res://tests/smoke_faces.tscn";   Args = @("--fixed-fps", "60") },
    @{ Label = "hd-2d view";     Scene = "res://tests/smoke_hd.tscn";      Args = @("--fixed-fps", "60") },
    @{ Label = "trees off paths"; Scene = "res://tests/smoke_realm_trees.tscn"; Args = @("--fixed-fps", "60") },
    @{ Label = "dialogue";       Scene = "res://tests/smoke_dialogue.tscn"; Args = @("--fixed-fps", "60") },
    @{ Label = "combat";         Scene = "res://tests/smoke_combat.tscn";   Args = @("--fixed-fps", "60") },
    @{ Label = "party";          Scene = "res://tests/smoke_party.tscn";    Args = @("--fixed-fps", "60") },
    @{ Label = "settings";       Scene = "res://tests/smoke_settings.tscn"; Args = @("--fixed-fps", "60") },
    @{ Label = "audio";          Scene = "res://tests/smoke_audio.tscn";    Args = @("--fixed-fps", "60") },
    @{ Label = "items";          Scene = "res://tests/smoke_items.tscn";    Args = @("--fixed-fps", "60") },
    @{ Label = "ring menu";      Scene = "res://tests/smoke_ring.tscn";     Args = @("--fixed-fps", "60") },
    @{ Label = "rings, slots";   Scene = "res://tests/smoke_rings.tscn";    Args = @("--fixed-fps", "60") },
    @{ Label = "clock, shops";   Scene = "res://tests/smoke_clock.tscn";    Args = @("--fixed-fps", "60") },
    @{ Label = "day/night foes"; Scene = "res://tests/smoke_enemy_clock.tscn"; Args = @("--fixed-fps", "60") },
    @{ Label = "map exits";      Scene = "res://tests/smoke_travel.tscn";   Args = @("--fixed-fps", "60") },
    @{ Label = "debug menu";     Scene = "res://tests/smoke_debug_menu.tscn"; Args = @("--fixed-fps", "60") },
    @{ Label = "title screen";   Scene = "res://tests/smoke_title.tscn";  Args = @("--fixed-fps", "60") },
    @{ Label = "boy or girl";    Scene = "res://tests/smoke_gender.tscn";   Args = @("--fixed-fps", "60") },
    @{ Label = "aspect (math)"; Scene = "res://tests/smoke_aspect.tscn";  Args = @() }
)

$failed = $false
foreach ($t in $tests) {
    Write-Host ("{0,-22} " -f $t.Label) -NoNewline
    $godotArgs = @("--headless", "--path", $projectDir, "--audio-driver", "Dummy", "--quit-after", $maxFrames) + $t.Args + @($t.Scene)
    $output = & $Godot @godotArgs 2>&1 | Out-String
    # A script error fails the run even if the test printed PASS: errors in
    # code a test doesn't check (a freed node after a scene change) hide there.
    $scriptErrors = $output -match 'SCRIPT ERROR'
    if ($LASTEXITCODE -eq 0 -and -not $scriptErrors -and $output -match '\[TEST\] PASS(.*)') {
        Write-Host "PASS $($Matches[1].Trim())" -ForegroundColor Green
    }
    elseif ($output -match 'SCRIPT ERROR') {
        # Usually a script that fails to compile: the test hit the frame cap.
        Write-Host "FAIL (script error)" -ForegroundColor Red
        $output -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR' } | Select-Object -First 5 |
            ForEach-Object { Write-Host "      $_" }
        $failed = $true
    }
    elseif ($LASTEXITCODE -eq 0) {
        # Exit 0 but no test output: almost always the GUI exe instead of *_console.exe.
        Write-Host "UNKNOWN (no [TEST] output; are you using the *_console.exe?)" -ForegroundColor Yellow
        $failed = $true
    }
    else {
        Write-Host "FAIL (exit $LASTEXITCODE)" -ForegroundColor Red
        $output -split "`n" | Where-Object { $_ -match '\[TEST\] FAIL|SCRIPT ERROR|^ERROR' } |
            ForEach-Object { Write-Host "      $_" }
        $failed = $true
    }
}

if ($failed) { Write-Host "SOME TESTS FAILED" -ForegroundColor Red; exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
