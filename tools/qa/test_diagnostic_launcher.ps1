# Extract functions only: never invoke real launcher/manifest/game or GUI.
$ErrorActionPreference='Stop'
$scriptPath=Join-Path $PSScriptRoot '../../Launch-Game-Diagnostic.ps1'
$tokens=$null
$errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Launcher parse errors'}
foreach($name in @('Assert-PlainPath','Read-Tree','Inventory','Verify','Child')){
    $node=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
    Invoke-Expression $node.Extent.Text
}
$root=Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../reviews/games-2026-09-12/runtime'))) ('launcher-unit-'+[guid]::NewGuid().ToString('N'))
foreach($dir in @('game','probe','engine','appdata','localappdata')){New-Item -ItemType Directory -Path (Join-Path $root $dir) -Force | Out-Null}
foreach($name in @('_sc_','Godot_v4.4.1-stable_win64_console.exe','Godot_v4.4.1-stable_win64.exe')){[IO.File]::WriteAllText((Join-Path $root ('engine/'+$name)),'mock data, never executed')}
$fixture=Join-Path $root 'game/input.txt'
[IO.File]::WriteAllText($fixture,'original')
$manifestPath=Join-Path $root 'diagnostic-baseline.json'
[IO.File]::WriteAllText($manifestPath,([ordered]@{status='diagnostic_only_not_ready';root=$root;files=@(Inventory)}|ConvertTo-Json -Depth 4))
Verify
Write-Output 'UNIT_PASS baseline'
function Expect-Rejected([string]$Label){
    $rejected=$false
    try { Verify } catch { $rejected=$true }
    if(-not $rejected){throw "Expected rejection: $Label"}
    Write-Output "UNIT_PASS $Label"
}
[IO.File]::WriteAllText($fixture,'modified')
Expect-Rejected 'modified file'
[IO.File]::WriteAllText($fixture,'original')
[IO.File]::WriteAllText((Join-Path $root 'game/added.txt'),'added')
Expect-Rejected 'added file'
Move-Item -LiteralPath (Join-Path $root 'game/added.txt') -Destination (Join-Path $root 'added-preserved.txt')
Move-Item -LiteralPath $fixture -Destination (Join-Path $root 'input-preserved.txt')
Expect-Rejected 'missing file'
Move-Item -LiteralPath (Join-Path $root 'input-preserved.txt') -Destination $fixture
Verify
$log=Join-Path $root 'timeout.log'
$caught=$false
try {
    Child -Exe (Get-Process -Id $PID).Path -ChildArgs @('-NoProfile','-Command','[Console]::WriteLine("mock-start"); [Console]::Error.WriteLine("mock-error"); Start-Sleep -Seconds 10') -Log $log -Session $root -TimeoutMs 1200
} catch {
    if($_.Exception.Message -notmatch 'timed out'){throw}
    $caught=$true
}
$body=Get-Content -LiteralPath $log -Raw
if(-not $caught -or $body -notmatch 'timed_out=true' -or $body -notmatch 'forced_non_natural' -or $body -notmatch 'mock-start' -or $body -notmatch 'mock-error'){throw 'Timeout output not preserved'}
Write-Output "UNIT_PASS timeout stdout stderr forced marker; retained fixture=$root"
