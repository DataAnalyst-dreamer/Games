$ErrorActionPreference='Stop'
$base=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../reviews/games-2026-09-12/runtime/integrated-render-monsters-v1'))
$snapshotSource=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../reviews/games-2026-09-12/runtime/autoload-exit-diag-monsters-v1/game'))
$testDest=Join-Path $base 'game/tests/integrated-render'
if(Test-Path (Join-Path $base 'integrated-manifest.json')){throw 'Existing integration manifest: refuse rerun/overwrite'}
New-Item -ItemType Directory -Path $testDest | Out-Null
Copy-Item (Join-Path $PSScriptRoot '*.gd'),(Join-Path $PSScriptRoot '*.tscn') -Destination $testDest
function Hashes([string]$directory){
    $out=@{}
    foreach($file in Get-ChildItem -LiteralPath $directory -File -Recurse -Force){
        if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse file refused'}
        $out[$file.FullName.Substring($directory.Length+1)]=(Get-FileHash -LiteralPath $file.FullName).Hash
    }
    return $out
}
foreach($item in Get-ChildItem -LiteralPath $base -Recurse -Force){if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse entry refused'}}
$sourceHashes=Hashes $snapshotSource
$baseline=Hashes (Join-Path $base 'game')
foreach($key in $sourceHashes.Keys){if($baseline[$key] -ne $sourceHashes[$key]){throw "Copy differs from protected snapshot: $key"}}
$engineHashes=@{}
foreach($name in @('_sc_','Godot_v4.4.1-stable_win64_console.exe','Godot_v4.4.1-stable_win64.exe')){$engineHashes[$name]=(Get-FileHash (Join-Path $base ('engine/'+$name))).Hash}
[IO.File]::WriteAllText((Join-Path $base 'integrated-manifest.json'),(@{status='integrated_qa_only_not_ready';game=$baseline;engine=$engineHashes;sourceGame=$snapshotSource;sourceFiles=$sourceHashes.Count}|ConvertTo-Json -Depth 5))
Write-Output "INTEGRATED_SOURCE_MATCH=$($sourceHashes.Count) BASELINE=$($baseline.Count)"
function Verify {
    $actual=Hashes (Join-Path $base 'game')
    if($actual.Count-ne $baseline.Count){throw 'Post-run file count drift'}
    foreach($key in $baseline.Keys){if($actual[$key]-ne $baseline[$key]){throw "Post-run hash drift: $key"}}
    foreach($key in $engineHashes.Keys){if((Get-FileHash (Join-Path $base ('engine/'+$key))).Hash-ne $engineHashes[$key]){throw 'Engine drift'}}
    Write-Output "INTEGRATED_HASH_PASS=$($actual.Count)"
}
function Execute([string]$Mode,[string[]]$NativeArgs,[string]$Session,[string]$Log){
    $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $base 'engine/Godot_v4.4.1-stable_win64_console.exe'))
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    $start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput=$true
    $start.RedirectStandardError=$true
    foreach($arg in $NativeArgs){$start.ArgumentList.Add($arg)}
    $start.Environment['APPDATA']=Join-Path $Session 'appdata'
    $start.Environment['LOCALAPPDATA']=Join-Path $Session 'localappdata'
    $start.Environment['DIAG_EXPECTED_USER_DIR']=((Join-Path $Session 'appdata/AutoloadExitDiagMonsters').Replace('\','/'))
    $start.Environment['INTEGRATED_CAPTURE']=((Join-Path $base ($Mode+'.png')).Replace('\','/'))
    $p=[Diagnostics.Process]::Start($start)
    $out=$p.StandardOutput.ReadToEndAsync(); $err=$p.StandardError.ReadToEndAsync()
    if(-not $p.WaitForExit(120000)){$p.Kill($true);$p.WaitForExit();throw 'Own renderer timeout; forced not natural'}
    $body=$out.Result+"`n"+$err.Result+"`nNATIVE_EXIT="+$p.ExitCode
    [IO.File]::WriteAllText($Log,$body)
    $code=$p.ExitCode;$p.Dispose()
    if($code-ne 0 -or $body-match 'SCRIPT ERROR:'){throw "Failed mode=$Mode native=$code log=$Log"}
    return $body
}
foreach($mode in @('ward','late','icons','fhd')){
    $session=Join-Path $base ('sessions/'+$mode+'-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $session 'appdata'),(Join-Path $session 'localappdata') -Force | Out-Null
    $probe=Execute $mode @('--headless','--path',(Join-Path $base 'probe'),'--script','probe.gd','--log-file',(Join-Path $session 'probe-engine.log')) $session (Join-Path $session 'probe-native.log')
    if($probe-notmatch 'match=true'){throw 'Probe sentinel missing'}
    Verify
    $args=@('--path',(Join-Path $base 'game'),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--minimized','--fixed-fps','60','--log-file',(Join-Path $session 'render-engine.log'))
    if($mode-eq 'icons'){$args+=@('--script','res://tests/integrated-render/icons.gd')}else{$args+=('res://tests/integrated-render/'+$mode+'.tscn')}
    if($mode-eq 'fhd'){$args+=@('--','--force-window-fhd',('--capture='+((Join-Path $base 'fhd.png').Replace('\','/'))))}
    $body=Execute $mode $args $session (Join-Path $session 'render-native.log')
    $sentinel=@{ward='WARD_WAYSTONE_RESULT PASS=7 FAIL=0';late='LATE_PANEL_RESULT PASS=32 FAIL=0';icons='THREE_MATERIAL_RESULT PASS=17 FAIL=0';fhd='FHD_CAPTURE_RESULT FAIL=0 pixels=(1920, 1080)'}[$mode]
    if(-not $body.Contains($sentinel)){throw "Mode sentinel missing: $mode"}
    Add-Type -AssemblyName System.Drawing
    $png=[System.Drawing.Bitmap]::new((Join-Path $base ($mode+'.png')))
    $size="$($png.Width)x$($png.Height)";$png.Dispose()
    if($size-ne '1920x1080'){throw "Unexpected actual capture $size"}
    Verify
    Write-Output "INTEGRATED_MODE_PASS=$mode PNG=$size SESSION=$session"
}
