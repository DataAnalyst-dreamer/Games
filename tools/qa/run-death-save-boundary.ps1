$ErrorActionPreference='Stop'
$work=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../'))
$fixed=Join-Path $work 'reviews/games-2026-09-12/runtime/integrated-render-monsters-v1'
$qa=Join-Path $work ('reviews/games-2026-09-12/runtime/death-save-boundary-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $qa,(Join-Path $qa 'appdata'),(Join-Path $qa 'localappdata') | Out-Null
$script=Join-Path $PSScriptRoot 'death-save-boundary.gd'
$probe=Join-Path $fixed 'probe/probe.gd'
$manifest=Get-Content (Join-Path $fixed 'integrated-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
$inputs=@{}
foreach($p in @($PSCommandPath,$script,$probe,(Join-Path $fixed 'probe/project.godot'))){$inputs[$p]=(Get-FileHash $p).Hash}
$commands=@{probe=@('--headless','--path',(Join-Path $fixed 'probe'),'--script',$probe);create=@('--headless','--path',(Join-Path $fixed 'game'),'--script',$script);verify=@('--headless','--path',(Join-Path $fixed 'game'),'--script',$script)}
@{inputs=$inputs;commands=$commands;fixedManifest=(Get-FileHash (Join-Path $fixed 'integrated-manifest.json')).Hash;status='external_qa_not_fixed_snapshot_input'}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $qa 'qa-input-manifest.json')
function Verify {
 $files=Get-ChildItem (Join-Path $fixed 'game') -File -Recurse -Force
 if($files.Count-ne $manifest.game.Count){throw 'Fixed game count drift'}
 foreach($file in $files){$rel=$file.FullName.Substring((Join-Path $fixed 'game').Length+1);if((Get-FileHash $file.FullName).Hash-ne $manifest.game[$rel]){throw "Fixed game drift $rel"}}
 foreach($key in $manifest.engine.Keys){if((Get-FileHash (Join-Path $fixed ('engine/'+$key))).Hash-ne $manifest.engine[$key]){throw 'Fixed engine drift'}}
 foreach($key in $inputs.Keys){if((Get-FileHash $key).Hash-ne $inputs[$key]){throw 'External input drift'}}
 Write-Output 'DEATH_QA_HASH_PASS game=14781 engine=3 external=4'
}
function Run([string]$mode){
 $s=[Diagnostics.ProcessStartInfo]::new((Join-Path $fixed 'engine/Godot_v4.4.1-stable_win64_console.exe'))
 $s.UseShellExecute=$false;$s.CreateNoWindow=$true;$s.WindowStyle='Hidden';$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true
 foreach($a in $commands[$mode]){$s.ArgumentList.Add($a)}
 $s.Environment['APPDATA']=Join-Path $qa 'appdata';$s.Environment['LOCALAPPDATA']=Join-Path $qa 'localappdata'
 $s.Environment['DIAG_EXPECTED_USER_DIR']=(Join-Path $qa 'appdata/AutoloadExitDiagMonsters').Replace('\','/')
 $s.Environment['DEATH_QA_MODE']=$mode;$s.Environment['DEATH_EXPECTED']=(Join-Path $qa 'expected-inventory.json').Replace('\','/')
 $p=[Diagnostics.Process]::Start($s);$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
 $timeout=-not $p.WaitForExit(60000)
 if($timeout){$p.Kill($true);$p.WaitForExit()}
 $body=$o.Result+"`n"+$e.Result+"`nNATIVE_EXIT="+$p.ExitCode+"`ntimed_out="+$timeout+"`nforced="+$timeout
 [IO.File]::WriteAllText((Join-Path $qa ($mode+'.log')),$body)
 $code=$p.ExitCode;$p.Dispose()
 if($timeout-or $code-ne 0-or $body-match 'SCRIPT ERROR:'){throw "Failed $mode; see $qa"}
 if($mode-eq 'probe'){if($body-notmatch 'match=true'){throw 'Probe mismatch'}}elseif($body-notmatch "DEATH_SAVE_RESULT mode=$mode PASS=\d+ FAIL=0"){throw 'Missing completion sentinel'}
 Write-Output "DEATH_QA_MODE_PASS=$mode"
}
Write-Output "DEATH_QA_ROOT=$qa"
Verify
Run 'probe'
Run 'create'
Verify
Run 'probe'
Run 'verify'
Verify
