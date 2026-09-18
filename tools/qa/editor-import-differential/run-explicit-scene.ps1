$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$runtime=[IO.Path]::GetFullPath((Join-Path $repo '../reviews/games-2026-09-12/runtime'))
$snapshot=Join-Path $runtime 'overnight-builds/20260913-014740-cce9e52e'
$qa=Join-Path $runtime ('editor-explicit-scene-'+[guid]::NewGuid().ToString('N'))
$engine=Join-Path $snapshot 'engine/Godot_v4.4.1-stable_win64_console.exe'
$game=Join-Path $snapshot 'game'
$userName='Games-Overnight-20260913-014740-cce9e52e'
$helper=Join-Path $PSScriptRoot 'run-existing-failed.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($helper,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Helper parse failed'}
foreach($name in @('Get-Map','Run-Child')){
 $fn=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
 Invoke-Expression $fn.Extent.Text
}
New-Item -ItemType Directory -Path $qa | Out-Null
Write-Output "EDITOR_EXPLICIT_ROOT=$qa"
$baseline=Get-Map $false
$baseline | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $qa 'protected-before.json')
$variableBefore=Get-Map $true
$variableBefore | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $qa 'variable-before.json')
$inputs=@{}
foreach($path in @($PSCommandPath,$helper,(Join-Path $PSScriptRoot 'probe.gd'),(Join-Path $snapshot 'probe/project.godot'))){$inputs[$path]=(Get-FileHash $path).Hash}
$inputs | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $qa 'inputs.json')
$probe=Join-Path $qa 'probe'
New-Item -ItemType Directory -Path $probe | Out-Null
Copy-Item -LiteralPath (Join-Path $snapshot 'probe/project.godot') -Destination (Join-Path $probe 'project.godot')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe.gd') -Destination (Join-Path $probe 'probe.gd')
$null=Run-Child 'probe' @('--headless','--path',$probe,'--script',(Join-Path $probe 'probe.gd')) $qa
$result=Run-Child 'import' @('--headless','--path',$game,'--editor','--import','res://scenes/ui/InventoryCell.tscn') $qa
$protectedAfter=Get-Map $false
$protectedAfter | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $qa 'protected-after.json')
$variableAfter=Get-Map $true
$variableAfter | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $qa 'variable-after.json')
$changed=@($baseline.Keys | Where-Object {$baseline[$_] -ne $protectedAfter[$_]})
$added=@($protectedAfter.Keys | Where-Object {-not $baseline.ContainsKey($_)})
$variableChanged=@($variableBefore.Keys | Where-Object {$variableBefore[$_] -ne $variableAfter[$_]})
$variableAdded=@($variableAfter.Keys | Where-Object {-not $variableBefore.ContainsKey($_)})
@{protected_before=$baseline.Count;protected_after=$protectedAfter.Count;protected_changed=$changed;protected_added=$added;variable_before=$variableBefore.Count;variable_after=$variableAfter.Count;variable_changed=$variableChanged;variable_added=$variableAdded} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $qa 'audit.json')
foreach($path in $inputs.Keys){if((Get-FileHash $path).Hash -ne $inputs[$path]){throw 'Current QA input drift'}}
Write-Output "EDITOR_EXPLICIT_AUDIT protected=$($baseline.Count) changed=$($changed.Count) added=$($added.Count) variable_changed=$($variableChanged.Count) variable_added=$($variableAdded.Count)"
if($changed.Count -or $added.Count){throw 'Historical protected inputs changed; preserve and inspect'}
Write-Output "EDITOR_EXPLICIT_COMPLETE native=$($result.native_exit) natural=$($result.natural_exit) errors=$($result.script_errors+$result.import_errors)"
