$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\freer\ClaudeProject\make-passive-income\Games'
$base = 'C:\Users\freer\ClaudeProject\make-passive-income\reviews\games-2026-09-12\runtime\npc-villager-runtime-v1'
$engine = 'C:\Users\freer\ClaudeProject\make-passive-income\reviews\games-2026-09-12\runtime\godot-4.4.1\Godot_v4.4.1-stable_win64_console.exe'
$session = Join-Path $base ('resume-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $session | Out-Null
$qaAppData = Join-Path $session 'appdata'
$expected = (Join-Path $qaAppData 'NpcVillagerRuntime').Replace('\','/')
function Run-NpcChild([string]$name, [string[]]$arguments, [string]$sentinel) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $engine
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['APPDATA'] = $qaAppData
    $psi.Environment['LOCALAPPDATA'] = (Join-Path $session 'localappdata')
    $psi.Environment['NPC_EXPECTED_USER_DIR'] = $expected
    foreach ($arg in $arguments) { $psi.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $natural = $process.WaitForExit(60000)
    if (-not $natural) { $process.Kill($true); $process.WaitForExit() }
    $out = $stdout.GetAwaiter().GetResult()
    $err = $stderr.GetAwaiter().GetResult()
    $out | Set-Content -LiteralPath (Join-Path $session "$name.stdout.log") -Encoding utf8
    $err | Set-Content -LiteralPath (Join-Path $session "$name.stderr.log") -Encoding utf8
    @{engine=$engine;arguments=$arguments;native_exit=$process.ExitCode;natural_exit=$natural;expected_userdata=$expected} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $session "$name.result.json") -Encoding utf8
    Write-Output "$name native=$($process.ExitCode) natural=$natural"
    Write-Output $out
    if (-not $natural -or $process.ExitCode -ne 0 -or ($sentinel -and -not $out.Contains($sentinel))) { throw "$name failed; evidence in $session" }
}
Run-NpcChild 'probe-v2' @('--headless','--audio-driver','Dummy','--path',(Join-Path $base 'probe'),'--script',(Join-Path $repo 'tools/qa/reactivity-font/npc-probe-v2.gd')) 'NPC_PROBE_EXACT'
if ((Get-FileHash (Join-Path $repo 'game/localization/ui_ko.csv')).Hash -ne (Get-FileHash (Join-Path $base 'csv-import/ui_ko.csv')).Hash) { throw 'CSV import fixture source differs' }
Run-NpcChild 'csv-import-v2' @('--headless','--audio-driver','Dummy','--path',(Join-Path $base 'csv-import'),'--editor','--import') ''
$translation = Join-Path $base 'csv-import/ui_ko.ko.translation'
if (-not (Test-Path $translation)) { throw 'Native CSV importer did not produce translation' }
Copy-Item -LiteralPath $translation -Destination (Join-Path $base 'game/localization/ui_ko.ko.translation')
function Snapshot-NpcGame {
    $map = [ordered]@{}
    $game = Join-Path $base 'game'
    foreach ($file in (Get-ChildItem $game -File -Recurse -Force | Sort-Object FullName)) { $map[$file.FullName.Substring($game.Length + 1)] = (Get-FileHash -LiteralPath $file.FullName).Hash }
    return $map
}
$before = Snapshot-NpcGame
$before | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $session 'game-before.json') -Encoding utf8
Run-NpcChild 'runtime-v2' @('--headless','--audio-driver','Dummy','--path',(Join-Path $base 'game'),'--script',(Join-Path $repo 'tools/qa/reactivity-font/npc-runtime-imported-v2.gd')) 'NPC_RUNTIME_IMPORTED_RESULT PASS=49 FAIL=0'
$after = Snapshot-NpcGame
$after | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $session 'game-after.json') -Encoding utf8
if (($before | ConvertTo-Json -Compress) -ne ($after | ConvertTo-Json -Compress)) { throw 'Runtime changed game inputs' }
Get-FileHash -LiteralPath $translation,(Join-Path $repo 'game/scripts/ui/hud.gd'),(Join-Path $repo 'game/localization/ui_ko.csv'),(Join-Path $repo 'tools/qa/reactivity-font/npc-runtime-imported-v2.gd'),$PSCommandPath | Select-Object Path,Hash | ConvertTo-Json | Set-Content (Join-Path $session 'inputs.json') -Encoding utf8
Write-Output "NPC_GAME_IMMUTABLE_COUNT=$($before.Count) SESSION=$session"
