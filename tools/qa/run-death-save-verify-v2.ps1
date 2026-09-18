$ErrorActionPreference='Stop'
$work=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../'))
$fixed=Join-Path $work 'reviews/games-2026-09-12/runtime/integrated-render-monsters-v1'
$fixture=Join-Path $work 'reviews/games-2026-09-12/runtime/death-save-boundary-ae1c07a77c30456081427119383e31ee'
$qa=Join-Path $fixture ('verify-v2-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $qa | Out-Null
$script=Join-Path $PSScriptRoot 'death-save-verify-v2.gd'
$manifest=Get-Content (Join-Path $fixed 'integrated-manifest.json') -Raw|ConvertFrom-Json -AsHashtable
$inputs=@{}
foreach($p in @($PSCommandPath,$script,(Join-Path $fixed 'probe/probe.gd'),(Join-Path $fixed 'probe/project.godot'))){$inputs[$p]=(Get-FileHash $p).Hash}
$commands=@{probe=@('--headless','--path',(Join-Path $fixed 'probe'),'--script',(Join-Path $fixed 'probe/probe.gd'));verify=@('--headless','--path',(Join-Path $fixed 'game'),'--script',$script)}
# Reuse the original trusted runner's read-only Verify and child-process Run functions.
$original=Join-Path $PSScriptRoot 'run-death-save-boundary.ps1'
$inputs[$original]=(Get-FileHash $original).Hash
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($original,[ref]$tokens,[ref]$errors)
foreach($name in @('Verify','Run')){
 $f=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
 $definition=$f.Extent.Text
 if($name-eq 'Run'){
  $definition=$definition.Replace("Join-Path `$qa 'appdata'","Join-Path `$fixture 'appdata'").Replace("Join-Path `$qa 'localappdata'","Join-Path `$fixture 'localappdata'").Replace("Join-Path `$qa 'appdata/AutoloadExitDiagMonsters'","Join-Path `$fixture 'appdata/AutoloadExitDiagMonsters'").Replace("Join-Path `$qa 'expected-inventory.json'","Join-Path `$fixture 'expected-inventory.json'")
 }
 Invoke-Expression $definition
}
@{inputs=$inputs;commands=$commands;fixture=$fixture;status='verify_only_external_v2'}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $qa 'inputs.json')
$save=Join-Path $fixture 'appdata/AutoloadExitDiagMonsters/saves/slot1_manual.json'
$before=(Get-FileHash $save).Hash
Write-Output "VERIFY_V2_ROOT=$qa SAVE_BEFORE=$before"
Verify
try {Run 'probe';Run 'verify'} finally {
 Verify
 $after=(Get-FileHash $save).Hash
 Write-Output "SAVE_AFTER=$after UNCHANGED=$($before-eq $after)"
 if($before-ne $after){throw 'Save mutated'}
}
