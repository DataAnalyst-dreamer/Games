param(
    [string]$GodotPath,
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
$testProjectPath = Join-Path $PSScriptRoot 'prototypes/fin-front-test'
if (-not $GodotPath) {
    $bundledTestRuntime = Join-Path $PSScriptRoot '../reviews/games-2026-09-12/runtime/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe'
    if (Test-Path -LiteralPath $bundledTestRuntime) {
        $GodotPath = (Resolve-Path -LiteralPath $bundledTestRuntime).Path
    } else {
        $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
        if ($godotCommand) { $GodotPath = $godotCommand.Source }
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot 4.4.1 is required. Run: ./Launch-Fin-Test.ps1 -GodotPath C:/path/to/Godot.exe'
}
# Import only this isolated project. No original game saves, data or scenes used.
& $GodotPath --headless --path $testProjectPath --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed: $LASTEXITCODE" }
if ($SelfTest) {
    & $GodotPath --headless --fixed-fps 60 --path $testProjectPath -- --self-test
} else {
    # Interactive game window is intentional; close it with Esc.
    & $GodotPath --path $testProjectPath
}
if ($LASTEXITCODE -ne 0) { throw "Godot test failed: $LASTEXITCODE" }
