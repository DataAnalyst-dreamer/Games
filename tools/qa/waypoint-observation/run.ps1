$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\freer\ClaudeProject\make-passive-income\Games'
$qa = 'C:\Users\freer\ClaudeProject\make-passive-income\reviews\games-2026-09-12\runtime\waypoint-observation-20260913-v1'
$game = 'C:\Users\freer\ClaudeProject\make-passive-income\reviews\games-2026-09-12\runtime\item-panel-game'
$engine = 'C:\Users\freer\ClaudeProject\make-passive-income\reviews\games-2026-09-12\runtime\godot-4.4.1\Godot_v4.4.1-stable_win64_console.exe'
$session = Join-Path $qa ('runtime-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $session | Out-Null
$qaAppData = Join-Path $session 'appdata'
$expectedDir = (Join-Path $qaAppData 'Games-QA-item-panel-20260913-monsters').Replace('\','/')
$updatePaths = @('scripts/world/quest_object.gd','scripts/systems/quest_system.gd','scripts/ui/hud.gd','localization/ui_ko.csv','localization/ui_ko.ko.translation')
$preservePaths = @('scripts/ui/inventory_menu.gd','scripts/world/quest_trigger.gd','scripts/world/waystone.gd','data/items.json','data/item_icons.json','data/quests/act1_hartland.json','data/world_objects.json','assets/generated/items/item-potion-hp-small-v1.png')
$backup = Join-Path $session 'copy-before'
function SelectedHashes([string[]]$paths) {
    $map = [ordered]@{}
    foreach ($relative in $paths) { $map[$relative] = (Get-FileHash -LiteralPath (Join-Path $game $relative)).Hash }
    return $map
}
$old = SelectedHashes ($updatePaths + $preservePaths)
$old | ConvertTo-Json | Set-Content (Join-Path $session 'copy-before.json') -Encoding utf8
foreach ($relative in $updatePaths) {
    $target = Join-Path $game $relative
    $saved = Join-Path $backup $relative
    New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
    Copy-Item -LiteralPath $target -Destination $saved
    Copy-Item -LiteralPath (Join-Path "$repo/game" $relative) -Destination $target
}
$baseline = SelectedHashes ($updatePaths + $preservePaths)
$baseline | ConvertTo-Json | Set-Content (Join-Path $session 'runtime-before.json') -Encoding utf8
foreach ($relative in $preservePaths) { if ($old[$relative] -ne $baseline[$relative]) { throw "Unexpected preserved file change: $relative" } }
foreach ($relative in $updatePaths) { if ((Get-FileHash (Join-Path "$repo/game" $relative)).Hash -ne $baseline[$relative]) { throw "Copy/source mismatch: $relative" } }
$external = @($PSCommandPath,(Join-Path $PSScriptRoot 'runtime.gd'),(Join-Path $repo 'tools/qa/waypoint-probe.gd'),(Join-Path $qa 'runtime-probe/project.godot'),$engine)
Get-FileHash -LiteralPath $external | Select-Object Path,Hash | ConvertTo-Json | Set-Content (Join-Path $session 'inputs.json') -Encoding utf8
function Run-Waypoint([string]$name, [string[]]$arguments, [string]$sentinel) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $engine
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['APPDATA'] = $qaAppData
    $psi.Environment['LOCALAPPDATA'] = (Join-Path $session 'localappdata')
    $psi.Environment['WAYPOINT_EXPECTED_USER_DIR'] = $expectedDir
    foreach ($arg in $arguments) { $psi.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::Start($psi)
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $natural = $process.WaitForExit(60000)
    if (-not $natural) { $process.Kill($true); $process.WaitForExit() }
    $out = $outTask.GetAwaiter().GetResult()
    $err = $errTask.GetAwaiter().GetResult()
    $out | Set-Content (Join-Path $session "$name.stdout.log") -Encoding utf8
    $err | Set-Content (Join-Path $session "$name.stderr.log") -Encoding utf8
    @{engine=$engine;arguments=$arguments;native_exit=$process.ExitCode;natural_exit=$natural;expected_userdata=$expectedDir} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $session "$name.result.json") -Encoding utf8
    "$name native=$($process.ExitCode) natural=$natural"
    $out
    if (-not $natural -or $process.ExitCode -ne 0 -or ($out+$err).Contains('SCRIPT ERROR:') -or ($sentinel -and $out -notmatch $sentinel)) { throw "$name failed; evidence $session" }
}
$failure = $null
try {
    Run-Waypoint 'probe' @('--headless','--audio-driver','Dummy','--path',(Join-Path $qa 'runtime-probe'),'--script',(Join-Path $repo 'tools/qa/waypoint-probe.gd')) 'WAYPOINT_PROBE_EXACT'
    Run-Waypoint 'runtime' @('--headless','--audio-driver','Dummy','--fixed-fps','60','--path',$game,'--script',(Join-Path $PSScriptRoot 'runtime.gd')) 'WAYPOINT_RUNTIME_RESULT PASS=\d+ FAIL=0'
} catch { $failure = $_ }
finally {
    $after = SelectedHashes ($updatePaths + $preservePaths)
    $after | ConvertTo-Json | Set-Content (Join-Path $session 'runtime-after.json') -Encoding utf8
    if (($baseline | ConvertTo-Json -Compress) -ne ($after | ConvertTo-Json -Compress)) { throw 'Runtime selected-input drift' }
}
if ($failure) { throw $failure }
"WAYPOINT_RUNTIME_IMMUTABLE_SELECTED=$($baseline.Count) SESSION=$session"
