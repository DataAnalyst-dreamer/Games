$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$runtime=[IO.Path]::GetFullPath((Join-Path $repo '../reviews/games-2026-09-12/runtime'))
$qa=Join-Path $runtime ('editor-import-differential-'+[guid]::NewGuid().ToString('N'))
$engine=Join-Path $runtime 'godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe'
$source=Join-Path $repo 'game/addons/phantom_camera'
New-Item -ItemType Directory -Path $qa | Out-Null
$inputs=@{}
foreach($file in Get-ChildItem -LiteralPath $source -File -Recurse -Force){$inputs[$file.FullName]=(Get-FileHash $file.FullName).Hash}
foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -File){$inputs[$file.FullName]=(Get-FileHash $file.FullName).Hash}
$inputs[$engine]=(Get-FileHash $engine).Hash
$inputs[(Join-Path $runtime 'godot-4.4.1/Godot_v4.4.1-stable_win64.exe')]=(Get-FileHash (Join-Path $runtime 'godot-4.4.1/Godot_v4.4.1-stable_win64.exe')).Hash
$inputs | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $qa 'inputs.json')
function Run-Child([string]$name,[string[]]$arguments,[string]$caseRoot){
 $info=[Diagnostics.ProcessStartInfo]::new($engine)
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle='Hidden';$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $info.Environment['APPDATA']=Join-Path $caseRoot 'appdata';$info.Environment['LOCALAPPDATA']=Join-Path $caseRoot 'localappdata'
 $expected=(Join-Path $caseRoot 'appdata/EditorImportDifferential').Replace('\','/')
 $info.Environment['EDITOR_DIFF_EXPECTED_USER_DIR']=$expected
 foreach($argument in $arguments){$info.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($info);$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
 $natural=$process.WaitForExit(50000)
 if(-not $natural){$process.Kill($true);$process.WaitForExit()}
 $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$code=$process.ExitCode
 [IO.File]::WriteAllText((Join-Path $caseRoot ($name+'.stdout.log')),$out)
 [IO.File]::WriteAllText((Join-Path $caseRoot ($name+'.stderr.log')),$err)
 $result=@{name=$name;engine=$engine;arguments=$arguments;expected_userdata=$expected;native_exit=$code;natural_exit=$natural;timed_out=(-not $natural);script_errors=([regex]::Matches($out+$err,'SCRIPT ERROR:')).Count}
 $result | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $caseRoot ($name+'.result.json'))
 $process.Dispose()
 if($name -eq 'probe' -and (-not $natural -or $code -ne 0 -or -not $out.Contains('EDITOR_DIFF_PROBE_PASS'))){throw "Probe failed $caseRoot"}
 Write-Host "$name native=$code natural=$natural script_errors=$($result.script_errors)"
 return $result
}
Write-Output "EDITOR_DIFF_ROOT=$qa"
$results=@()
foreach($case in @('import-only','import-plus-quit')){
 $caseRoot=Join-Path $qa $case
 $game=Join-Path $caseRoot 'game';$probe=Join-Path $caseRoot 'probe'
 New-Item -ItemType Directory -Path $game,$probe | Out-Null
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'project.godot') -Destination (Join-Path $game 'project.godot')
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe-project.godot') -Destination (Join-Path $probe 'project.godot')
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'probe.gd') -Destination (Join-Path $probe 'probe.gd')
 foreach($file in Get-ChildItem -LiteralPath $source -File -Recurse -Force){
  $relative=$file.FullName.Substring($source.Length+1);$dest=Join-Path $game ('addons/phantom_camera/'+$relative)
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)) | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $dest
  if((Get-FileHash $dest).Hash -ne $inputs[$file.FullName]){throw 'Copied addon differs'}
 }
 $copyHashes=@{}
 foreach($file in Get-ChildItem $game -Recurse -File -Force){$copyHashes[$file.FullName.Substring($game.Length+1)]=(Get-FileHash $file.FullName).Hash}
 $copyHashes | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $caseRoot 'game-before.json')
 $null=Run-Child 'probe' @('--headless','--path',$probe,'--script',(Join-Path $probe 'probe.gd')) $caseRoot
 $arguments=@('--headless','--path',$game,'--editor','--import')
 if($case -eq 'import-plus-quit'){$arguments+='--quit'}
 $results+=Run-Child 'import' $arguments $caseRoot
 $after=@{}
 foreach($file in Get-ChildItem $game -Recurse -File -Force){$after[$file.FullName.Substring($game.Length+1)]=(Get-FileHash $file.FullName).Hash}
 $after | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $caseRoot 'game-after.json')
}
foreach($path in $inputs.Keys){if((Get-FileHash $path).Hash -ne $inputs[$path]){throw "Original input drift $path"}}
$results | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $qa 'results.json')
Write-Output "EDITOR_DIFF_COMPLETE originals_unchanged=$($inputs.Count) root=$qa"
