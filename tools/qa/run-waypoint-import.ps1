$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\freer\ClaudeProject\make-passive-income\Games'
$qa = 'C:\Users\freer\ClaudeProject\make-passive-income\reviews\games-2026-09-12\runtime\waypoint-observation-20260913-v1'
$engine = 'C:\Users\freer\ClaudeProject\make-passive-income\reviews\games-2026-09-12\runtime\godot-4.4.1\Godot_v4.4.1-stable_win64_console.exe'
$session = Join-Path $qa ('import-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $session | Out-Null
$qaAppData = Join-Path $session 'appdata'
$expectedDir = (Join-Path $qaAppData 'WaypointObservation').Replace('\','/')
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
    if (-not $natural -or $process.ExitCode -ne 0 -or ($out+$err).Contains('SCRIPT ERROR:') -or ($sentinel -and -not $out.Contains($sentinel))) { throw "$name failed; evidence $session" }
}
$priorCsv = 'C:\Users\freer\ClaudeProject\make-passive-income\reviews\games-2026-09-12\runtime\npc-villager-runtime-v1\game\localization\ui_ko.csv'
$beforeCsv = Import-Csv -LiteralPath $priorCsv
$afterCsv = Import-Csv -LiteralPath (Join-Path $repo 'game/localization/ui_ko.csv')
if ($beforeCsv.Count -ne 236 -or $afterCsv.Count -ne 239) { throw 'Unexpected CSV counts' }
foreach ($row in $beforeCsv) {
    $match = @($afterCsv | Where-Object keys -eq $row.keys)
    if ($match.Count -ne 1 -or $match[0].ko -cne $row.ko) { throw "Existing translation changed: $($row.keys)" }
}
$newKeys = @($afterCsv | Where-Object keys -notin $beforeCsv.keys | Select-Object -ExpandProperty keys)
if ((@($newKeys | Sort-Object) -join ',') -ne 'observe.waypoint.active,observe.waypoint.after,observe.waypoint.before') { throw 'Unexpected new keys' }
Copy-Item -LiteralPath (Join-Path $repo 'game/localization/ui_ko.csv') -Destination (Join-Path $qa 'import/ui_ko.csv')
Run-Waypoint 'probe' @('--headless','--audio-driver','Dummy','--path',(Join-Path $qa 'probe'),'--script',(Join-Path $repo 'tools/qa/waypoint-probe.gd')) 'WAYPOINT_PROBE_EXACT'
Run-Waypoint 'csv-import' @('--headless','--audio-driver','Dummy','--path',(Join-Path $qa 'import'),'--editor','--import') ''
Run-Waypoint 'check' @('--headless','--audio-driver','Dummy','--path',(Join-Path $qa 'import'),'--script',(Join-Path $repo 'tools/qa/waypoint-import-check.gd')) 'WAYPOINT_IMPORT_CHECK_RESULT PASS=267 FAIL=0'
$newTranslation = Join-Path $qa 'import/ui_ko.ko.translation'
$target = Join-Path $repo 'game/localization/ui_ko.ko.translation'
$backup = Join-Path $session 'ui_ko.ko.translation.before'
Copy-Item -LiteralPath $target -Destination $backup
$before = [ordered]@{}
foreach ($file in (Get-ChildItem (Join-Path $repo 'game/localization') -File | Sort-Object FullName)) { $before[$file.FullName] = (Get-FileHash $file.FullName).Hash }
Copy-Item -LiteralPath $newTranslation -Destination $target
$after = [ordered]@{}
foreach ($file in (Get-ChildItem (Join-Path $repo 'game/localization') -File | Sort-Object FullName)) { $after[$file.FullName] = (Get-FileHash $file.FullName).Hash }
$changes = @($before.Keys | Where-Object { $before[$_] -ne $after[$_] })
if ($changes.Count -ne 1 -or $changes[0] -ne $target) { throw 'Unexpected translation promotion change' }
@{before=$before;after=$after;new_keys=$newKeys;backup=$backup;previous_csv_sha=(Get-FileHash $priorCsv).Hash} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $session 'promotion.json') -Encoding utf8
Get-FileHash -LiteralPath (Join-Path $repo 'game/scripts/world/quest_object.gd'),(Join-Path $repo 'game/localization/ui_ko.csv'),$target,(Join-Path $repo 'tools/qa/waypoint-import-check.gd'),(Join-Path $repo 'tools/qa/waypoint-probe.gd'),$PSCommandPath,$engine | Select-Object Path,Hash | ConvertTo-Json | Set-Content (Join-Path $session 'inputs.json') -Encoding utf8
"WAYPOINT_SOURCE_READY SESSION=$session"
