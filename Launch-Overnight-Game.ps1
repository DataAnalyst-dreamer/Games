param([string]$GodotPath, [switch]$Prepare, [switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
if ($Prepare -and $VerifyOnly) { throw 'Choose either Prepare or VerifyOnly.' }
$buildRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../reviews/games-2026-09-12/runtime/overnight-builds'))
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Generated([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $utf8) }
function Resolve-InSnapshot([string]$Root, [string]$Relative) {
    if (-not $Relative -or [IO.Path]::IsPathRooted($Relative)) { throw 'Manifest paths must be relative.' }
    $resolved = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest path escapes snapshot.' }
    return $resolved
}
function Invoke-Engine([string[]]$Arguments, [string]$Log) {
    Write-Host "Godot check/run log: $Log"
    $info = [Diagnostics.ProcessStartInfo]::new($script:engine)
    $info.UseShellExecute = $false
    $info.CreateNoWindow = [bool]$Prepare
    if ($Prepare) { $info.WindowStyle = 'Hidden' }
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.Environment['APPDATA'] = $script:childAppData
    $info.Environment['LOCALAPPDATA'] = $script:childLocalAppData
    foreach ($key in @('OVERNIGHT_EXPECTED_USER_DIR','NPC_EXPECTED_USER_DIR','DIAGNOSTIC_EXPECTED_USER_DIR','WAYPOINT_EXPECTED_USER_DIR')) { $info.Environment[$key] = $script:expectedUserDir }
    foreach ($argument in @($Arguments) + @('--log-file',$Log)) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($info)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $natural = if ($Prepare -or $Arguments -contains '--headless') { $process.WaitForExit(60000) } else { $process.WaitForExit(); $true }
    if (-not $natural) { $process.Kill($true); $process.WaitForExit() }
    $out = $stdout.GetAwaiter().GetResult()
    $err = $stderr.GetAwaiter().GetResult()
    $code = $process.ExitCode
    Write-Generated ($Log + '.stdout.txt') $out
    Write-Generated ($Log + '.stderr.txt') $err
    Write-Generated ($Log + '.result.json') (@{arguments=$Arguments;engine=$script:engine;expectedUserDir=$script:expectedUserDir;nativeExit=$code;naturalExit=$natural;timedOut=(-not $natural)} | ConvertTo-Json -Depth 5)
    $process.Dispose()
    if (-not $natural -or $code -ne 0 -or ($out+$err) -match 'SCRIPT ERROR:|Failed to import') { throw "Godot failed (native=$code natural=$natural): $Log" }
}
function Assert-NoReparsePath([string]$Path, [switch]$Descendants) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $cursor = $resolved
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse path refused: $cursor" }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        $cursor = if ($parent) { $parent.FullName } else { $null }
    }
    if ($Descendants -and (Test-Path -LiteralPath $resolved -PathType Container)) {
        if (Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Reparse descendant refused: $resolved" }
    }
}
function Tree-Hashes([string]$Root) {
    Assert-NoReparsePath $Root
    $entries = Get-ChildItem -LiteralPath $Root -Recurse -Force
    if ($entries | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Reparse entry refused: $Root" }
    $result = [ordered]@{}
    foreach ($file in ($entries | Where-Object { -not $_.PSIsContainer } | Sort-Object FullName)) { $result[$file.FullName.Substring($Root.Length+1)] = (Get-FileHash -LiteralPath $file.FullName).Hash }
    return $result
}
function Verify-ReadySnapshot([string]$Snapshot, $Manifest) {
    Assert-NoReparsePath $Snapshot
    if ($Manifest.status -ne 'ready' -or $Manifest.schemaVersion -ne 2) { throw 'Invalid ready manifest status/schema.' }
    if ($Manifest.userName -notmatch '^Games-Overnight-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$') { throw 'Invalid isolated user directory name.' }
    $actual = @{}
    foreach ($folder in @('game','probe','qa','engine')) {
        $tree = Tree-Hashes (Join-Path $Snapshot $folder)
        foreach ($key in $tree.Keys) {
            if ($folder -eq 'engine' -and $key -match '^editor_data[\\/]') { continue }
            $actual[("$folder/$key").Replace('\','/').ToLowerInvariant()] = $tree[$key]
        }
    }
    $seen = @{}
    foreach ($entry in $Manifest.verifiedFiles) {
        $null = Resolve-InSnapshot $Snapshot $entry.path
        $normalized = $entry.path.Replace('\','/').ToLowerInvariant()
        if ($normalized -notmatch '^(game|probe|qa|engine)/' -or $seen.ContainsKey($normalized)) { throw 'Invalid or duplicate verified path' }
        $seen[$normalized] = $true
        if (-not $actual.ContainsKey($normalized) -or $entry.sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or $actual[$normalized] -ne $entry.sha256) { throw "Verified snapshot modified or missing: $($entry.path)" }
    }
    if ($actual.Count -ne $seen.Count -or $seen.Count -eq 0) { throw 'Verified snapshot file count changed' }
    $null = Resolve-InSnapshot $Snapshot $Manifest.engine
    if (-not $seen.ContainsKey($Manifest.engine.Replace('\','/').ToLowerInvariant())) { throw 'Engine is not verified' }
    return $actual.Count
}
function Use-Session([string]$Label) {
    $session = if ($Label -eq 'play') { Join-Path $snapshot 'player-session' } else { Join-Path $snapshot ('sessions/' + $Label + '-' + [guid]::NewGuid().ToString('N')) }
    Assert-NoReparsePath $session -Descendants
    $script:childAppData = Join-Path $session 'appdata'
    $script:childLocalAppData = Join-Path $session 'localappdata'
    $script:expectedUserDir = (Join-Path $script:childAppData $userName).Replace('\','/')
    Assert-NoReparsePath $script:expectedUserDir -Descendants
    foreach ($path in @($script:childAppData,$script:childLocalAppData)) {
        if (Test-Path -LiteralPath $path) { if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Userdir reparse point refused' } }
        else { New-Item -ItemType Directory -Path $path | Out-Null }
    }
    $probeLog = Join-Path $session ('probe-' + [guid]::NewGuid().ToString('N') + '.log')
    Invoke-Engine @('--headless','--path',$probe,'--script','probe.gd') $probeLog
    if ((Get-Content ($probeLog+'.stdout.txt') -Raw) -notmatch 'OVERNIGHT_PROBE_PASS') { throw 'Exact userdir probe sentinel absent' }
    return $session
}
try {
    Assert-NoReparsePath $buildRoot
    if ($Prepare) {
        if (-not $GodotPath) {
            $GodotPath = Join-Path $PSScriptRoot '../reviews/games-2026-09-12/runtime/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe'
            if (-not (Test-Path -LiteralPath $GodotPath)) {
                $command = Get-Command godot -ErrorAction SilentlyContinue
                if ($command) { $GodotPath = $command.Source }
            }
        }
        if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) { throw 'Supply -GodotPath pointing to an existing Godot 4.4.1 executable.' }
        Assert-NoReparsePath $GodotPath
        $version = (& $GodotPath --version | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.4\.1\.') { throw "Expected Godot 4.4.1; received $version" }
        $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
        $snapshot = Join-Path $buildRoot $id
        if (Test-Path -LiteralPath $snapshot) { throw 'Snapshot collision; nothing overwritten.' }
        New-Item -ItemType Directory -Path $snapshot | Out-Null
        $game = Join-Path $snapshot 'game'
        $engineDir = Join-Path $snapshot 'engine'
        $probe = Join-Path $snapshot 'probe'
        foreach ($path in @($game,$engineDir,$probe)) { New-Item -ItemType Directory -Path $path | Out-Null }
        $source = Join-Path $PSScriptRoot 'game'
        $sourceBefore = Tree-Hashes $source
        Write-Generated (Join-Path $snapshot 'source-before.json') ($sourceBefore | ConvertTo-Json -Depth 3)
        $hashes = @()
        Write-Host "Copying source into new snapshot: $snapshot"
        foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse -Force) {
            $relative = $file.FullName.Substring($source.Length + 1)
            if ($relative -match '^\.godot[\\/]') { continue }
            $dest = Join-Path $game $relative
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)) | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $dest
            $hash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
            if ($hash -ne (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash) { throw "Source changed during copy: $relative" }
            $hashes += [ordered]@{path=$relative;sha256=$hash}
        }
        foreach ($entry in $hashes) {
            if ($entry.sha256 -ne (Get-FileHash -LiteralPath (Join-Path $source $entry.path) -Algorithm SHA256).Hash) { throw "Source changed during snapshot: $($entry.path). Prepare again after source freeze." }
        }
        $engineName = [IO.Path]::GetFileName($GodotPath)
        Copy-Item -LiteralPath $GodotPath -Destination (Join-Path $engineDir $engineName)
        if ($engineName -match '_console\.exe$') {
            $gui = Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($GodotPath))) ($engineName -replace '_console\.exe$','.exe')
            if (-not (Test-Path -LiteralPath $gui)) { throw 'Console companion executable missing.' }
            Copy-Item -LiteralPath $gui -Destination $engineDir
        }
        Write-Generated (Join-Path $engineDir '_sc_') ''
        $script:engine = Join-Path $engineDir $engineName
        $userName = "Games-Overnight-$id"
        $configPath = Join-Path $game 'project.godot'
        $config = [IO.File]::ReadAllText($configPath)
        if ($config -match 'config/use_custom_user_dir|config/custom_user_dir_name') { throw 'Source already contains custom userdir settings; review isolation before preparing.' }
        $appSettings = "config/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$userName`""
        $config = $config.Replace('[application]', "[application]`n$appSettings")
        # Imported runtime assets remain intact. Disable only editor UI plugins in this copy:
        # existing editor font/plugin teardown crashes do not belong in a play-only snapshot.
        $config = [regex]::Replace($config, '(?s)(\[editor_plugins\]\s*)enabled=PackedStringArray\([^\r\n]*\)', '${1}enabled=PackedStringArray()')
        Write-Generated $configPath $config
        Write-Generated (Join-Path $probe 'project.godot') "config_version=5`n[application]`nconfig/name=`"Overnight probe`"`n$appSettings`n"
        Write-Generated (Join-Path $probe 'probe.gd') @'
extends SceneTree
func _init():
    var expected = OS.get_environment("OVERNIGHT_EXPECTED_USER_DIR")
    var actual = OS.get_user_data_dir().replace("\\", "/")
    print("OVERNIGHT_USER_DIR=" + actual)
    var ok = not expected.is_empty() and actual == expected
    print("OVERNIGHT_PROBE_PASS" if ok else "OVERNIGHT_PROBE_FAIL")
    quit(0 if ok else 1)
'@
        # Only the copied smoke guard changes; production files and original test stay intact.
        $smokePath = Join-Path $game 'tests/smoke/smoke_quest_npc_panel.gd'
        $smoke = [IO.File]::ReadAllText($smokePath)
        $smoke = $smoke.Replace('"C:/Users/freer/AppData/Roaming/Games-QA-npc-greeting-20260913-story"', 'OS.get_environment("OVERNIGHT_EXPECTED_USER_DIR")')
        if ($smoke -notmatch 'OS.get_environment\("OVERNIGHT_EXPECTED_USER_DIR"\)') { throw 'Smoke isolation guard format changed; review required.' }
        $textureChecks = ''
        foreach ($icon in @('slime-jelly','rabbit-horn','mushroom-cap','potion-hp-small')) { $textureChecks += "`n`t" + ('_check(load("res://assets/generated/items/item-{0}-v1.png") is Texture2D, "{0} PNG imported and loadable")' -f $icon) }
        $smoke = $smoke.Replace('print("NPC_PANEL_ISOLATION_PASS")', 'print("NPC_PANEL_ISOLATION_PASS")' + $textureChecks)
        Write-Generated $smokePath $smoke
        $qaDir = Join-Path $snapshot 'qa'
        New-Item -ItemType Directory -Path $qaDir | Out-Null
        $qaInputs = [ordered]@{}
        foreach ($relative in @('tools/qa/reactivity-font/npc-runtime-imported-v3.gd','tools/qa/waypoint-observation/runtime.gd','tools/qa/walk-mq01/smoke_diagnostic_walk.gd','tools/qa/walk-mq01/SmokeDiagnosticWalk.tscn')) { $qaInputs[$relative] = (Get-FileHash (Join-Path $PSScriptRoot $relative)).Hash }
        $npcText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'tools/qa/reactivity-font/npc-runtime-imported-v3.gd'))
        if (-not $npcText.Contains('expected.size() == 236')) { throw 'NPC baseline count guard changed; inspect staging adaptation' }
        $npcText = $npcText.Replace('expected.size() == 236','expected.size() == 239').Replace('exact 236 CSV keys retained','exact 239 CSV keys retained')
        Write-Generated (Join-Path $qaDir 'npc-latest.gd') $npcText
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'tools/qa/waypoint-observation/runtime.gd') -Destination (Join-Path $qaDir 'waypoint.gd')
        foreach ($name in @('smoke_diagnostic_walk.gd','SmokeDiagnosticWalk.tscn')) {
            $dest = Join-Path $game ('tests/smoke/'+$name)
            if (Test-Path -LiteralPath $dest) { throw "Staging test collision: $name" }
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('tools/qa/walk-mq01/'+$name)) -Destination $dest
        }
        Write-Generated (Join-Path $snapshot 'qa-inputs.json') ($qaInputs | ConvertTo-Json -Depth 3)
        # Preserve provenance even if import fails; preparing.json is never launchable.
        Write-Generated (Join-Path $snapshot 'preparing.json') ([ordered]@{
            status='preparing_not_ready';copiedUtc=[DateTime]::UtcNow.ToString('o');
            sourceGame=$source;godotVersion=$version;sourceFiles=$hashes;
            copyOnlyChanges=@('custom user directory','editor plugins disabled','QA panel smoke guard and four Texture checks','two staged WASD smoke files','external NPC harness expected count236 to239','external S5 harness byte-copy','native importer generated metadata/cache')
        } | ConvertTo-Json -Depth 8)
    } else {
        $ready = Get-ChildItem -LiteralPath $buildRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $candidate = Join-Path $_.FullName 'ready.json'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { Get-Item -LiteralPath $candidate }
        } | Sort-Object FullName -Descending | Select-Object -First 1
        if (-not $ready) { throw 'No verified snapshot. Run ./Launch-Overnight-Game.ps1 -Prepare first.' }
        $manifest = Get-Content -LiteralPath $ready.FullName -Raw | ConvertFrom-Json
        $snapshot = $ready.DirectoryName
        $verifiedCount = Verify-ReadySnapshot $snapshot $manifest
        $game = Join-Path $snapshot 'game'
        $probe = Join-Path $snapshot 'probe'
        $script:engine = Resolve-InSnapshot $snapshot $manifest.engine
        $userName = $manifest.userName
        if ($VerifyOnly) { Write-Output "VERIFIED (no game window opened): $snapshot files=$verifiedCount"; return }
    }
    if ($Prepare) {
        $session = Use-Session 'import'
        Invoke-Engine @('--headless','--path',$game,'--editor','--import','res://scenes/ui/InventoryCell.tscn') (Join-Path $snapshot 'import.log')
        if ((Get-Content -LiteralPath (Join-Path $snapshot 'import.log') -Raw) -match 'SCRIPT ERROR:|Failed to import') { throw 'Import contains script/resource failure; not ready.' }
        $session = Use-Session 'panel'
        Invoke-Engine @('--headless','--fixed-fps','60','--path',$game,'res://tests/smoke/SmokeQuestNpcPanel.tscn') (Join-Path $snapshot 'input-smoke.log')
        $smokeLog = Get-Content -LiteralPath (Join-Path $snapshot 'input-smoke.log') -Raw
        if ($smokeLog -notmatch 'NPC_PANEL_TEST_RESULT PASS=\d+ FAIL=0' -or $smokeLog -match 'SCRIPT ERROR:') { throw 'Input smoke did not complete cleanly.' }
        foreach ($icon in @('slime-jelly','rabbit-horn','mushroom-cap','potion-hp-small')) { if (-not (Test-Path -LiteralPath (Join-Path $game ("assets/generated/items/item-$icon-v1.png.import")))) { throw "Icon import metadata absent: $icon" } }
        $session = Use-Session 'walk'
        Invoke-Engine @('--headless','--fixed-fps','60','--path',$game,'res://tests/smoke/SmokeDiagnosticWalk.tscn') (Join-Path $snapshot 'walk-smoke.log')
        if ((Get-Content (Join-Path $snapshot 'walk-smoke.log.stdout.txt') -Raw) -notmatch 'WALK_MQ01_RESULT PASS') { throw 'Actual WASD smoke did not complete' }
        $session = Use-Session 'npc'
        Invoke-Engine @('--headless','--path',$game,'--script',(Join-Path $qaDir 'npc-latest.gd')) (Join-Path $snapshot 'npc-smoke.log')
        if ((Get-Content (Join-Path $snapshot 'npc-smoke.log.stdout.txt') -Raw) -notmatch 'NPC_RUNTIME_IMPORTED_RESULT PASS=289 FAIL=0') { throw 'Latest239 NPC translation/HUD smoke failed' }
        $session = Use-Session 'waypoint'
        Invoke-Engine @('--headless','--fixed-fps','60','--path',$game,'--script',(Join-Path $qaDir 'waypoint.gd')) (Join-Path $snapshot 'waypoint-smoke.log')
        if ((Get-Content (Join-Path $snapshot 'waypoint-smoke.log.stdout.txt') -Raw) -notmatch 'WAYPOINT_RUNTIME_RESULT PASS=33 FAIL=0') { throw 'S5 physical E regression smoke failed' }
        $sourceAfter = Tree-Hashes $source
        Write-Generated (Join-Path $snapshot 'source-after.json') ($sourceAfter | ConvertTo-Json -Depth 3)
        if (($sourceBefore | ConvertTo-Json -Compress) -ne ($sourceAfter | ConvertTo-Json -Compress)) { throw 'Original game source/cache changed during preparation' }
        foreach ($relative in $qaInputs.Keys) { if ((Get-FileHash (Join-Path $PSScriptRoot $relative)).Hash -ne $qaInputs[$relative]) { throw 'External QA input changed during preparation' } }
        $verifiedFiles = @()
        foreach ($folder in @('game','probe','qa','engine')) {
            $tree = Tree-Hashes (Join-Path $snapshot $folder)
            foreach ($key in $tree.Keys) {
                if ($folder -eq 'engine' -and $key -match '^editor_data[\\/]') { continue }
                $verifiedFiles += [ordered]@{path="$folder/$key";sha256=$tree[$key]}
            }
        }
        $manifest = [ordered]@{schemaVersion=2;status='ready';preparedUtc=[DateTime]::UtcNow.ToString('o');sourceGame=$source;godotVersion=$version;engine="engine/$engineName";userName=$userName;sourceFiles=$hashes;sourceAuditedFiles=$sourceBefore.Count;verifiedFiles=$verifiedFiles;checks=@('fresh no-autoload exact isolation probe before every stage','normal full editor import exit0 with explicit InventoryCell edit scene; no recovery','Main panel real input and four Texture2D loads','Main actual WASD MQ01 completion autosave','239 NPC translations plus actual HUD events289PASS','S5 physical E and cargo/D28 regressions33PASS','original source including cache SHA/count unchanged');copyOnlyChanges=@('isolated userdir','editor plugins disabled','staged test adaptations recorded in preparing.json');variableExclusions=@('engine/editor_data','sessions','player-session','logs and preparation reports')}
        Write-Generated (Join-Path $snapshot 'ready.json') ($manifest | ConvertTo-Json -Depth 8)
        Write-Host "READY (no game window opened): $snapshot"
    } else {
        $session = Use-Session 'play'
        Write-Host "Main-game snapshot: $snapshot`nIsolated player saves (separate from QA): $script:expectedUserDir"
        Invoke-Engine @('--path',$game) (Join-Path $snapshot ('play-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log'))
    }
} finally {
    # Parent process environment is never changed. Failed snapshots and logs remain.
    if ($Prepare -and $sourceBefore -and $snapshot) {
        if (-not $sourceAfter) { $sourceAfter = Tree-Hashes $source }
        Write-Generated (Join-Path $snapshot 'source-after-final.json') ($sourceAfter | ConvertTo-Json -Depth 3)
        $unchanged = ($sourceBefore | ConvertTo-Json -Compress) -eq ($sourceAfter | ConvertTo-Json -Compress)
        Write-Generated (Join-Path $snapshot 'source-audit.json') (@{before=$sourceBefore.Count;after=$sourceAfter.Count;unchanged=$unchanged} | ConvertTo-Json)
        if (-not $unchanged) { throw 'Original source changed; snapshot must not be used' }
    }
}
