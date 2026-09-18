[CmdletBinding()]
param([switch]$Freeze,[switch]$Play,[switch]$SelfTest)
$ErrorActionPreference='Stop'
if (([int]$Freeze.IsPresent+[int]$Play.IsPresent+[int]$SelfTest.IsPresent) -gt 1) { throw 'Choose only one explicit mode.' }
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../reviews/games-2026-09-12/runtime/autoload-exit-diag-monsters-v1'))
$manifestPath=Join-Path $root 'diagnostic-baseline.json'
function Assert-PlainPath([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    if ($full -ne $root -and -not $full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw "Outside diagnostic root: $full" }
    $cursor=$full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse path refused: $cursor" }
        }
        $parent=Split-Path $cursor
        if ($parent -eq $cursor) { break }
        $cursor=$parent
    }
}
function Read-Tree([string]$Directory) {
    foreach($item in Get-ChildItem -LiteralPath $Directory -Force) {
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Reparse tree entry refused: $($item.FullName)"}
        if($item.PSIsContainer){ Read-Tree $item.FullName } else { $item.FullName }
    }
}
function Inventory {
    Assert-PlainPath (Join-Path $root 'game')
    Assert-PlainPath (Join-Path $root 'probe')
    $files=@(Read-Tree (Join-Path $root 'game'))
    $files+=@(Read-Tree (Join-Path $root 'probe'))
    foreach($name in @('_sc_','Godot_v4.4.1-stable_win64_console.exe','Godot_v4.4.1-stable_win64.exe')) {
        $path=Join-Path $root ('engine/'+$name)
        Assert-PlainPath $path
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing engine input: $name"}
        $files+=$path
    }
    foreach($file in ($files | Sort-Object)) {
        [ordered]@{path=$file.Substring($root.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
    }
}
function Verify {
    Assert-PlainPath $manifestPath
    if(-not(Test-Path -LiteralPath $manifestPath)){throw 'No diagnostic baseline. Explicit -Freeze required after review.'}
    $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if($manifest.status -ne 'diagnostic_only_not_ready' -or $manifest.root -ne $root){throw 'Invalid diagnostic manifest identity.'}
    $expected=@{}
    foreach($entry in $manifest.files){
        if($expected.ContainsKey($entry.path)){throw 'Duplicate baseline entry'}
        if([IO.Path]::IsPathRooted($entry.path) -or $entry.path -match '(^|[\\/])\.\.([\\/]|$)'){throw 'Invalid manifest relative path'}
        $expected[$entry.path]=$entry.sha256
    }
    $current=@(Inventory)
    if($current.Count -ne $expected.Count){throw 'Diagnostic file count changed (added/missing files).'}
    foreach($entry in $current){if(-not $expected.ContainsKey($entry.path) -or $expected[$entry.path] -ne $entry.sha256){throw "Changed/missing baseline file: $($entry.path)"}}
    Write-Host "DIAGNOSTIC_HASH_PASS files=$($current.Count)"
}
function Child([string]$Exe,[string[]]$ChildArgs,[string]$Log,[string]$Session,[switch]$Visible,[int]$TimeoutMs=180000) {
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$Exe
    $start.UseShellExecute=$false
    $start.CreateNoWindow=-not $Visible
    $start.WindowStyle=if($Visible){[Diagnostics.ProcessWindowStyle]::Normal}else{[Diagnostics.ProcessWindowStyle]::Hidden}
    foreach($arg in $ChildArgs){$start.ArgumentList.Add($arg)}
    $start.Environment['APPDATA']=Join-Path $Session 'appdata'
    $start.Environment['LOCALAPPDATA']=Join-Path $Session 'localappdata'
    $expected=((Join-Path $Session 'appdata/AutoloadExitDiagMonsters').Replace('\','/'))
    $start.Environment['DIAG_EXPECTED_USER_DIR']=$expected
    $start.Environment['DIAGNOSTIC_EXPECTED_USER_DIR']=$expected
    $start.RedirectStandardOutput=$true
    $start.RedirectStandardError=$true
    $process=[Diagnostics.Process]::Start($start)
    $stdout=$process.StandardOutput.ReadToEndAsync()
    $stderr=$process.StandardError.ReadToEndAsync()
    if($Visible){$process.WaitForExit()}elseif(-not $process.WaitForExit($TimeoutMs)){
        $process.Kill($true)
        $process.WaitForExit()
        [IO.File]::WriteAllText($Log,($stdout.Result+"`n"+$stderr.Result+"`ntimed_out=true`ntermination=forced_non_natural`nOBSERVED_EXIT="+$process.ExitCode))
        $process.Dispose()
        throw 'Own diagnostic child timed out; not a natural native exit.'
    }
    [IO.File]::WriteAllText($Log,($stdout.Result+"`n"+$stderr.Result+"`nNATIVE_EXIT="+$process.ExitCode))
    $code=$process.ExitCode
    $process.Dispose()
    if($code -ne 0){throw "Diagnostic child failed native=$code log=$Log"}
}
Write-Warning 'DIAGNOSTIC ONLY: editor import shutdown remains unresolved. This is not a ready build.'
Assert-PlainPath $root
if($Freeze){
    if(Test-Path -LiteralPath $manifestPath){throw 'Baseline already exists; overwrite/refreeze refused.'}
    $entries=@(Inventory)
    [IO.File]::WriteAllText($manifestPath,([ordered]@{status='diagnostic_only_not_ready';root=$root;createdUtc=[DateTime]::UtcNow.ToString('o');files=$entries}|ConvertTo-Json -Depth 5))
    Write-Host "Frozen diagnostic baseline files=$($entries.Count); no ready.json created."
    exit 0
}
Verify
if(-not $Play -and -not $SelfTest){Write-Host 'Status checked. No game window opened. Use explicit -Play for a new isolated session.';exit 0}
$session=Join-Path $root ('play-sessions/'+[guid]::NewGuid().ToString('N'))
Assert-PlainPath $session
if(Test-Path -LiteralPath $session){throw 'Existing session refused'}
foreach($folder in @('appdata','localappdata','logs')){New-Item -ItemType Directory -Path (Join-Path $session $folder) -Force | Out-Null}
$engine=Join-Path $root 'engine/Godot_v4.4.1-stable_win64_console.exe'
Child -Exe $engine -ChildArgs @('--headless','--path',(Join-Path $root 'probe'),'--script','probe.gd','--log-file',(Join-Path $session 'logs/probe-engine.log')) -Log (Join-Path $session 'logs/probe-native.log') -Session $session
Verify
try {
    if($SelfTest){
        Child -Exe $engine -ChildArgs @('--headless','--fixed-fps','60','--path',(Join-Path $root 'game'),'res://tests/smoke/SmokeDiagnosticWalk.tscn','--log-file',(Join-Path $session 'logs/selftest-engine.log')) -Log (Join-Path $session 'logs/selftest-native.log') -Session $session
        $result=Get-Content (Join-Path $session 'logs/selftest-native.log') -Raw
        if($result -notmatch 'WALK_MQ01_RESULT PASS' -or $result -notmatch 'DIAGNOSTIC_THREE_TEXTURES_PASS' -or $result -match 'SCRIPT ERROR:'){throw 'Self-test sentinel failure'}
        Write-Host "DIAGNOSTIC_SELFTEST_PASS session=$session"
    }else{
        Write-Warning 'Every -Play starts fresh userdata. Previous sessions are never automatically loaded.'
        Child -Exe (Join-Path $root 'engine/Godot_v4.4.1-stable_win64.exe') -ChildArgs @('--path',(Join-Path $root 'game'),'--log-file',(Join-Path $session 'logs/play-engine.log')) -Log (Join-Path $session 'logs/play-native.log') -Session $session -Visible
    }
} finally { Verify }
