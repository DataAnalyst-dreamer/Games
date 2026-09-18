$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$runtime=[IO.Path]::GetFullPath((Join-Path $repo '../reviews/games-2026-09-12/runtime'))
$snapshot=Join-Path $runtime 'overnight-builds/20260913-014740-cce9e52e'
$qa=Join-Path $runtime ('editor-existing-differential-'+[guid]::NewGuid().ToString('N'))
$engine=Join-Path $snapshot 'engine/Godot_v4.4.1-stable_win64_console.exe'
$game=Join-Path $snapshot 'game'
$userName='Games-Overnight-20260913-014740-cce9e52e'
New-Item -ItemType Directory -Path $qa | Out-Null
function Get-Map([bool]$variable){
 $map=@{}
 foreach($file in Get-ChildItem -LiteralPath $snapshot -Recurse -File -Force){
  $relative=$file.FullName.Substring($snapshot.Length+1)
  $isVariable=$relative -match '^game[\\/]\.godot[\\/]|^engine[\\/]editor_data[\\/]'
  if($isVariable -eq $variable){$map[$relative]=(Get-FileHash -LiteralPath $file.FullName).Hash}
 }
 return $map
}
function Run-Child([string]$name,[string[]]$arguments,[string]$caseRoot){
 $info=[Diagnostics.ProcessStartInfo]::new($engine)
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle='Hidden';$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $info.Environment['APPDATA']=Join-Path $caseRoot 'appdata';$info.Environment['LOCALAPPDATA']=Join-Path $caseRoot 'localappdata'
 $expected=(Join-Path $caseRoot ('appdata/'+$userName)).Replace('\','/')
 $info.Environment['EDITOR_DIFF_EXPECTED_USER_DIR']=$expected
 foreach($argument in $arguments){$info.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($info);$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
 $natural=$process.WaitForExit(60000)
 if(-not $natural){$process.Kill($true);$process.WaitForExit()}
 $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$code=$process.ExitCode
 [IO.File]::WriteAllText((Join-Path $caseRoot ($name+'.stdout.log')),$out)
 [IO.File]::WriteAllText((Join-Path $caseRoot ($name+'.stderr.log')),$err)
 $result=@{name=$name;engine=$engine;arguments=$arguments;expected_userdata=$expected;native_exit=$code;natural_exit=$natural;timed_out=(-not $natural);script_errors=([regex]::Matches($out+$err,'SCRIPT ERROR:')).Count;import_errors=([regex]::Matches($out+$err,'Failed to import')).Count}
 $result | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $caseRoot ($name+'.result.json'))
 $process.Dispose()
 if($name -eq 'probe' -and (-not $natural -or $code -ne 0 -or -not $out.Contains('EDITOR_DIFF_PROBE_PASS'))){throw "Probe failed $caseRoot"}
 Write-Host "$name native=$code natural=$natural script_errors=$($result.script_errors)"
 return $result
}
Write-Output "EDITOR_EXISTING_ROOT=$qa"
$baseline=Get-Map $false
$baseline | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $qa 'protected-baseline.json')
$inputs=@{}
foreach($path in @($PSCommandPath,(Join-Path $PSScriptRoot 'probe.gd'),(Join-Path $snapshot 'probe/project.godot'))){$inputs[$path]=(Get-FileHash $path).Hash}
$inputs | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $qa 'inputs.json')
$results=@()
foreach($case in @('import-only','recovery-diagnostic')){
 $caseRoot=Join-Path $qa $case;$probe=Join-Path $caseRoot 'probe'
 New-Item -ItemType Directory -Path $probe | Out-Null
 Copy-Item -LiteralPath (Join-Path $snapshot 'probe/project.godot') -Destination (Join-Path $probe 'project.godot')
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe.gd') -Destination (Join-Path $probe 'probe.gd')
 $variableBefore=Get-Map $true
 $variableBefore | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $caseRoot 'variable-before.json')
 $null=Run-Child 'probe' @('--headless','--path',$probe,'--script',(Join-Path $probe 'probe.gd')) $caseRoot
 $arguments=@('--headless','--path',$game,'--editor','--import')
 if($case -eq 'recovery-diagnostic'){$arguments+='--recovery-mode'}
 $result=Run-Child 'import' $arguments $caseRoot
 $results+=$result
 $protectedAfter=Get-Map $false
 $protectedAfter | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $caseRoot 'protected-after.json')
 $variableAfter=Get-Map $true
 $variableAfter | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $caseRoot 'variable-after.json')
 $changed=@($baseline.Keys | Where-Object {$baseline[$_] -ne $protectedAfter[$_]})
 $added=@($protectedAfter.Keys | Where-Object {-not $baseline.ContainsKey($_)})
 $variableChanged=@($variableBefore.Keys | Where-Object {$variableBefore[$_] -ne $variableAfter[$_]})
 $variableAdded=@($variableAfter.Keys | Where-Object {-not $variableBefore.ContainsKey($_)})
 @{protected_before=$baseline.Count;protected_after=$protectedAfter.Count;protected_changed=$changed;protected_added=$added;variable_before=$variableBefore.Count;variable_after=$variableAfter.Count;variable_changed=$variableChanged;variable_added=$variableAdded} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $caseRoot 'audit.json')
 Write-Output "EDITOR_EXISTING_AUDIT case=$case protected=$($baseline.Count) changed=$($changed.Count) added=$($added.Count) variable_changed=$($variableChanged.Count) variable_added=$($variableAdded.Count)"
 if($changed.Count -or $added.Count){throw 'Historical protected inputs changed; preserve and inspect before continuing'}
 if($result.natural_exit -and $result.native_exit -eq 0 -and $result.script_errors -eq 0 -and $result.import_errors -eq 0){break}
}
foreach($path in $inputs.Keys){if((Get-FileHash $path).Hash -ne $inputs[$path]){throw 'Current QA input drift'}}
$results | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $qa 'results.json')
Write-Output "EDITOR_EXISTING_COMPLETE root=$qa"
