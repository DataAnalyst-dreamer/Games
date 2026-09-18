$ErrorActionPreference='Stop'
$work=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../'))
$fixed=Join-Path $work 'reviews/games-2026-09-12/runtime/integrated-render-monsters-v1'
$fixture=Join-Path $work 'reviews/games-2026-09-12/runtime/death-save-boundary-ae1c07a77c30456081427119383e31ee'
$qa=Join-Path $fixture ('verify-v3-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $qa | Out-Null
$script=Join-Path $PSScriptRoot 'death-save-verify-v3.gd'
$fixedManifest=Join-Path $fixed 'integrated-manifest.json'
$originalManifest=Join-Path $fixture 'qa-input-manifest.json'
$manifest=Get-Content $fixedManifest -Raw|ConvertFrom-Json -AsHashtable
$originalInputs=(Get-Content $originalManifest -Raw|ConvertFrom-Json -AsHashtable).inputs
$inputs=@{}
foreach($p in @($PSCommandPath,$script,$fixedManifest,$originalManifest,(Join-Path $fixture 'expected-inventory.json'))){$inputs[$p]=(Get-FileHash $p).Hash}
$commands=@{probe=@('--headless','--path',(Join-Path $fixed 'probe'),'--script',(Join-Path $fixed 'probe/probe.gd'));verify=@('--headless','--path',(Join-Path $fixed 'game'),'--script',$script)}
$save=Join-Path $fixture 'appdata/AutoloadExitDiagMonsters/saves/slot1_manual.json'
$saveFolder=Split-Path $save
$saveHashes=@{}
foreach($file in Get-ChildItem -LiteralPath $saveFolder -File -Recurse -Force){$saveHashes[$file.FullName]=(Get-FileHash $file.FullName).Hash}
if($saveHashes[$save] -ne '3C49EDBB0503198DAA95C6EC479E037E0F6128189CBB2915035AE90EFF3E670D'){throw 'Original manual fixture SHA mismatch'}
@{inputs=$inputs;originalInputs=$originalInputs;commands=$commands;fixture=$fixture;saveHashes=$saveHashes;status='verify_only_external_v3'}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $qa 'inputs.json')
function Verify {
 $files=Get-ChildItem (Join-Path $fixed 'game') -File -Recurse -Force
 if($files.Count -ne $manifest.game.Count){throw 'Fixed game count drift'}
 foreach($file in $files){$rel=$file.FullName.Substring((Join-Path $fixed 'game').Length+1);if((Get-FileHash $file.FullName).Hash -ne $manifest.game[$rel]){throw "Fixed game drift $rel"}}
 foreach($key in $manifest.engine.Keys){if((Get-FileHash (Join-Path $fixed ('engine/'+$key))).Hash -ne $manifest.engine[$key]){throw 'Fixed engine drift'}}
 foreach($key in $originalInputs.Keys){if((Get-FileHash $key).Hash -ne $originalInputs[$key]){throw "Original QA input drift $key"}}
 foreach($key in $inputs.Keys){if((Get-FileHash $key).Hash -ne $inputs[$key]){throw "Current QA input drift $key"}}
 $saveFiles=Get-ChildItem -LiteralPath $saveFolder -File -Recurse -Force
 if($saveFiles.Count -ne $saveHashes.Count){throw 'Save file count drift'}
 foreach($file in $saveFiles){if((Get-FileHash $file.FullName).Hash -ne $saveHashes[$file.FullName]){throw "Save file drift $($file.Name)"}}
 $line="DEATH_QA_HASH_PASS game=$($files.Count) engine=$($manifest.engine.Count) original_external=$($originalInputs.Count) current_inputs=$($inputs.Count) saves=$($saveHashes.Count)"
 Write-Output $line
 Add-Content -LiteralPath (Join-Path $qa 'audit.log') -Value $line
}
function Run([string]$mode){
 $s=[Diagnostics.ProcessStartInfo]::new((Join-Path $fixed 'engine/Godot_v4.4.1-stable_win64_console.exe'))
 $s.UseShellExecute=$false;$s.CreateNoWindow=$true;$s.WindowStyle='Hidden';$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true
 foreach($a in $commands[$mode]){$s.ArgumentList.Add($a)}
 $s.Environment['APPDATA']=Join-Path $fixture 'appdata';$s.Environment['LOCALAPPDATA']=Join-Path $fixture 'localappdata'
 $s.Environment['DIAG_EXPECTED_USER_DIR']=(Join-Path $fixture 'appdata/AutoloadExitDiagMonsters').Replace('\','/')
 $s.Environment['DEATH_QA_MODE']=$mode;$s.Environment['DEATH_EXPECTED']=(Join-Path $fixture 'expected-inventory.json').Replace('\','/')
 $p=[Diagnostics.Process]::Start($s);$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
 $timeout=-not $p.WaitForExit(60000)
 if($timeout){$p.Kill($true);$p.WaitForExit()}
 $body=$o.Result+"`n"+$e.Result+"`nNATIVE_EXIT="+$p.ExitCode+"`ntimed_out="+$timeout+"`nforced="+$timeout
 [IO.File]::WriteAllText((Join-Path $qa ($mode+'.log')),$body)
 $code=$p.ExitCode;$p.Dispose()
 if($timeout -or $code -ne 0 -or $body -match 'SCRIPT ERROR:'){throw "Failed $mode; see $qa"}
 if($mode -eq 'probe'){if($body -notmatch 'match=true'){throw 'Probe mismatch'}}elseif($body -notmatch 'DEATH_SAVE_RESULT mode=verify PASS=\d+ FAIL=0'){throw 'Missing completion sentinel'}
 Write-Output "DEATH_QA_MODE_PASS=$mode"
}
Write-Output "VERIFY_V3_ROOT=$qa SAVE_BEFORE=$($saveHashes[$save])"
Verify
try {Run 'probe';Run 'verify'} finally {
 Verify
 Write-Output "SAVE_AFTER=$((Get-FileHash $save).Hash) ALL_SAVES_UNCHANGED=True"
}
