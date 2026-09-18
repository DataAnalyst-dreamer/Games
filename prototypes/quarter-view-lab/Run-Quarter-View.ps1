[CmdletBinding()]
param([switch]$Prepare,[switch]$ImportOnly,[switch]$VerifyOnly,[switch]$CaptureOnly,[switch]$CombatOnly,[switch]$AttackOnly,[switch]$GripOnly,[switch]$DesignCompare,[switch]$DesignOnly)
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 is required.' }
$project=$PSScriptRoot
$workspace=[IO.Path]::GetFullPath((Join-Path $project '../../..'))
$runtime=Join-Path $workspace 'reviews/games-2026-09-12/runtime'
$engine=Join-Path $runtime 'godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe'
$companion=Join-Path $runtime 'godot-4.4.1/Godot_v4.4.1-stable_win64.exe'
if (!(Test-Path -LiteralPath $engine)) { throw 'Existing Godot 4.4.1 was not found; no download is performed.' }
if (!(Test-Path -LiteralPath $companion)) { throw 'Existing Godot GUI companion is missing.' }
function Reject-Reparse([string]$path) {
  $cursor=[IO.Path]::GetFullPath($path)
  while ($cursor) {
    if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Reparse path rejected: $cursor" }
    $parent=Split-Path -Parent $cursor
    if ($parent -eq $cursor) { break }; $cursor=$parent
  }
}
function Manifest {
  $items=@{}
  Get-ChildItem -LiteralPath $project -File -Recurse -Force | ForEach-Object {
    $rel=[IO.Path]::GetRelativePath($project,$_.FullName).Replace('\','/')
    if ($rel -notmatch '^\.godot/(editor/|editor_layout|scene_groups_cache)' -and $rel -notmatch '(^|/)(README.md|ready.json)$') { $items[$rel]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  }
  return $items
}
function Invoke-Child([string]$label,[string[]]$arguments,[string]$session,[int]$limit=60) {
  $psi=[Diagnostics.ProcessStartInfo]::new(); $psi.FileName=$engine
  $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
  $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
  foreach($arg in $arguments) { [void]$psi.ArgumentList.Add($arg) }
  $psi.Environment['APPDATA']=Join-Path $session 'appdata'
  $psi.Environment['LOCALAPPDATA']=Join-Path $session 'localappdata'
  $psi.Environment['QUARTER_LAB_EXPECTED_USER_DIR']=(Join-Path $session 'appdata/QuarterViewLab').Replace('\','/')
  $p=[Diagnostics.Process]::new(); $p.StartInfo=$psi
  [void]$p.Start(); $out=$p.StandardOutput.ReadToEndAsync(); $err=$p.StandardError.ReadToEndAsync()
  $natural=$true
  if ($limit -eq 0) { $p.WaitForExit() } elseif (!$p.WaitForExit($limit*1000)) { $natural=$false; $p.Kill($true); $p.WaitForExit() }
  $stdout=$out.GetAwaiter().GetResult(); $stderr=$err.GetAwaiter().GetResult()
  [IO.File]::WriteAllText((Join-Path $session "$label.stdout.txt"),$stdout)
  [IO.File]::WriteAllText((Join-Path $session "$label.stderr.txt"),$stderr)
  @{native_exit=$p.ExitCode;natural=$natural;arguments=$arguments;expected_user_dir=$psi.Environment['QUARTER_LAB_EXPECTED_USER_DIR'];engine=$engine} | ConvertTo-Json -Depth 6 | Out-File -LiteralPath (Join-Path $session "$label.result.json") -Encoding utf8
  Write-Host "$label native=$($p.ExitCode) natural=$natural"
  # Existing sandbox certificate-store error is unrelated to this offline sample.
  # Preserve it in stderr; only this exact known message is excluded from the gate.
  $diagnostics="$stdout`n$stderr".Replace('ERROR: Failed to read the root certificate store.','KNOWN_OFFLINE_CERTIFICATE_STORE_WARNING')
  if (!$natural -or $p.ExitCode -ne 0 -or $diagnostics -match 'SCRIPT ERROR:|Parse Error:|ERROR:') { throw "Stage failed; logs preserved: $session" }
  return $stdout
}
function Session([string]$name) {
  $path=Join-Path $runtime ("quarter-view-"+$name+'-'+[guid]::NewGuid().ToString('N'))
  Reject-Reparse $path
  [void](New-Item -ItemType Directory -Path $path)
  foreach($leaf in @('appdata','localappdata','probe')) { [void](New-Item -ItemType Directory -Path (Join-Path $path $leaf)) }
  Copy-Item -LiteralPath (Join-Path $project 'tests/probe-project.godot') -Destination (Join-Path $path 'probe/project.godot')
  Copy-Item -LiteralPath (Join-Path $project 'tests/probe.gd') -Destination (Join-Path $path 'probe/probe.gd')
  $null=Invoke-Child 'probe' @('--headless','--path',(Join-Path $path 'probe'),'--script','res://probe.gd') $path
  return $path
}
function Design-Readiness([string]$session,[string]$stdout) {
  if ($stdout -notmatch 'QUARTER_DESIGN_PARTIAL_APP_RESULT PASS=24 FAIL=0' -or $stdout -notmatch 'QUARTER_DESIGN_ASSET_SET_READY=false') { throw "Partial design app or full-set status missing: $session" }
  $report=Get-Content -LiteralPath (Join-Path $session 'appdata/QuarterViewLab/design-readiness.json') -Raw | ConvertFrom-Json -AsHashtable
  if (!$report.partial_app_passed -or $report.asset_set_ready -or $report.required_candidates -ne 3 -or $report.available_candidates -ne 2 -or $report.missing_candidates.Count -ne 1 -or $report.missing_candidates[0] -ne 'fin' -or $report.app_checks_passed -ne 24 -or $report.app_checks_failed -ne 0) { throw "Unexpected static-design readiness report: $session" }
  return $report
}
Reject-Reparse $project
Reject-Reparse $engine
Reject-Reparse $companion
Get-ChildItem -LiteralPath $project -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | ForEach-Object { throw "Reparse descendant rejected: $($_.FullName)" }
$readyFile=Join-Path $project 'ready.json'
if ($DesignOnly) {
  $stage=Session 'design-check'
  $stdout=Invoke-Child 'design-check' @('--audio-driver','Dummy','--path',$project,'--script','res://tests/design_compare_check.gd') $stage
  $null=Design-Readiness $stage $stdout
  Write-Host "Static design outputs: $stage/appdata/QuarterViewLab"; return
}
if ($GripOnly) {
  $stage=Session 'grip-grid'
  $stdout=Invoke-Child 'grip-grid' @('--audio-driver','Dummy','--path',$project,'--script','res://tests/grip_grid.gd') $stage
  if ($stdout -notmatch 'QUARTER_GRIP_GRID_RESULT PASS=18 FAIL=0') { throw "Grip grid check failed: $stage" }
  Write-Host "Grip grid outputs: $stage/appdata/QuarterViewLab"; return
}
if ($AttackOnly) {
  $stage=Session 'attack-motion'
  $stdout=Invoke-Child 'attack-motion' @('--audio-driver','Dummy','--fixed-fps','60','--path',$project,'--script','res://tests/attack_capture.gd') $stage
  if ($stdout -notmatch 'QUARTER_ATTACK_CAPTURE_RESULT PASS=12 FAIL=0') { throw "Attack motion check failed: $stage" }
  Write-Host "Attack motion outputs: $stage/appdata/QuarterViewLab"; return
}
if ($CombatOnly) {
  $stage=Session 'combat'
  $stdout=Invoke-Child 'combat' @('--headless','--verbose','--audio-driver','Dummy','--fixed-fps','60','--path',$project,'--script','res://tests/combat_check.gd') $stage
  if ($stdout -notmatch 'QUARTER_COMBAT_RESULT PASS=58 FAIL=0') { throw "Combat check failed: $stage" }
  Write-Host "Combat outputs: $stage"; return
}
if ($CaptureOnly) {
  $stage=Session 'capture'
  $stdout=Invoke-Child 'capture' @('--audio-driver','Dummy','--path',$project,'--script','res://tests/capture.gd') $stage
  if ($stdout -notmatch 'QUARTER_CAPTURE_RESULT PASS=\d+ FAIL=0') { throw "Capture check failed: $stage" }
  Write-Host "Capture outputs: $stage/appdata/QuarterViewLab"; return
}
if ($Prepare -or $ImportOnly) {
  $stage=Session 'import'
  $null=Invoke-Child 'import' @('--headless','--audio-driver','Dummy','--path',$project,'--editor','--import','res://Main.tscn') $stage
  if ($ImportOnly) { Write-Host "Import passed: $stage"; return }
  $results=@($stage)
  foreach($test in @(@('smoke','tests/smoke.gd','QUARTER_SMOKE_RESULT PASS=16 FAIL=0'),@('combat','tests/combat_check.gd','QUARTER_COMBAT_RESULT PASS=58 FAIL=0'))) {
    $stage=Session $test[0]; $results += $stage
    $stdout=Invoke-Child $test[0] @('--headless','--verbose','--audio-driver','Dummy','--fixed-fps','60','--path',$project,'--script',('res://'+$test[1])) $stage
    if ($stdout -notmatch $test[2]) { throw "Missing success sentinel: $stage" }
  }
  $stage=Session 'capture'; $results += $stage
  $stdout=Invoke-Child 'capture' @('--audio-driver','Dummy','--path',$project,'--script','res://tests/capture.gd') $stage
  if ($stdout -notmatch 'QUARTER_CAPTURE_RESULT PASS=19 FAIL=0') { throw "Capture check failed: $stage" }
  $stage=Session 'attack-motion'; $results += $stage
  $stdout=Invoke-Child 'attack-motion' @('--audio-driver','Dummy','--fixed-fps','60','--path',$project,'--script','res://tests/attack_capture.gd') $stage
  if ($stdout -notmatch 'QUARTER_ATTACK_CAPTURE_RESULT PASS=12 FAIL=0') { throw "Attack motion check failed: $stage" }
  $stage=Session 'grip-grid'; $results += $stage
  $stdout=Invoke-Child 'grip-grid' @('--audio-driver','Dummy','--path',$project,'--script','res://tests/grip_grid.gd') $stage
  if ($stdout -notmatch 'QUARTER_GRIP_GRID_RESULT PASS=18 FAIL=0') { throw "Grip grid check failed: $stage" }
  $stage=Session 'design-check'; $results += $stage
  $stdout=Invoke-Child 'design-check' @('--audio-driver','Dummy','--path',$project,'--script','res://tests/design_compare_check.gd') $stage
  $designReadiness=Design-Readiness $stage $stdout
  @{schema=1;engine_sha256=(Get-FileHash -LiteralPath $engine).Hash;companion_sha256=(Get-FileHash -LiteralPath $companion).Hash;verified_files=(Manifest);results=$results;design_comparison=$designReadiness;prepared=(Get-Date).ToString('o')} | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $readyFile -Encoding utf8
  Write-Host 'Prototype preparation passed. The short QA window closed naturally; normal play was not started.'; return
}
if (!(Test-Path -LiteralPath $readyFile)) { throw 'Run preparation first: pwsh -File ./Run-Quarter-View.ps1 -Prepare' }
$ready=Get-Content -LiteralPath $readyFile -Raw | ConvertFrom-Json -AsHashtable
$actual=Manifest
if ($ready.schema -ne 1 -or $actual.Count -ne $ready.verified_files.Count -or (Get-FileHash -LiteralPath $engine).Hash -ne $ready.engine_sha256 -or (Get-FileHash -LiteralPath $companion).Hash -ne $ready.companion_sha256) { throw 'Preparation is stale; prepare again.' }
foreach($key in $actual.Keys) { if ($actual[$key] -ne $ready.verified_files[$key]) { throw "Changed file: $key. Prepare again." } }
if ($VerifyOnly) { Write-Host 'Verified. Game not launched.'; return }
if ($DesignCompare) {
  if (!$ready.design_comparison.partial_app_passed) { throw 'Static design comparison has not passed its separate app check.' }
  $stage=Session 'design-compare'
  Write-Host 'Opening opt-in static design comparison; not a new combat animation. Esc closes this window.'
  $null=Invoke-Child 'design-compare' @('--path',$project,'res://DesignCompare.tscn') $stage 0
  return
}
$stage=Session 'play'
Write-Host 'Opening independent prototype. Esc closes only this game; logs are isolated.'
$null=Invoke-Child 'play' @('--path',$project) $stage 0
