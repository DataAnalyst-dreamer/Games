# Editor exit resource isolation — bounded diagnosis

2026-09-13. Same existing Godot 4.4.1 stable console engine, headless editor import/quit. No original game/source/global setting/launcher ready gate changes. No download. This does **not** make the blocked launcher ready.

Environment qualification: these small cases used the original executable with process-local APPDATA, whereas the failed launcher used copied identical binaries plus `_sc_` self-contained editor data. Same binary version is **not** an identical editor-data/mode environment. See the [subsequent controlled-mode comparison](editor-exit-autoload-isolation-20260913.md); baseline outcomes cannot alone eliminate a self-contained-mode interaction.

## Results

| Small isolated condition | Probe native exit | Editor import native exit |
|---|---:|---:|
| Empty project (previous baseline) |0|0|
| Default game font Galmuri11.ttf only |0|0|
| Original theme.tres and its exact four external resources |0|0|
| Same resources plus a minimal Control/Label scene referencing theme |0|0|

Resource presence/import does not reproduce the exit access violation. The minimal theme scene was scanned during editor import; this is not a full editor UI session with the game scenes open. No project autoloads, plugins, tool scripts, game scenes or inherited editor state were included. Therefore this excludes neither interactions with those components nor large resource populations. It does not establish a defective font/theme, and does not prove that all fonts or all theme usages are safe.

All cases retained the certificate-store read error despite exit0, so that message alone does not explain the failure. Original failed launcher copy still had full/cached imports exiting -1073741819 with plugins disabled; its separate runtime23PASS remains a distinct result.

## Isolation / evidence

Workspace-relative base: `reviews/games-2026-09-12/runtime/editor-exit-probe-monsters/`.

- `run-cases.ps1` creates fresh `font-only-v1`, `theme-dependencies-v1`, `theme-scene-v1` folders, refusing existing targets. Copies only project/probe and selected assets. No bulk snapshot.
- Every condition sets process-local APPDATA and LOCALAPPDATA to its own subdirectories; no-autoload `case-probe.gd` compares actual user-data path to exact expected path before import. Separate shell process ends afterward, so caller environment is unchanged.
- Each case's `probe.log` and `import.log` retain engine output. Exact first-two exit codes were captured from `$LASTEXITCODE` in tool execution output (`4e5836` / `588d9f` chunks); not inferred from `All tests passed` or log end.
- `theme-scene-native-transcript.log` is an actual PowerShell transcript containing source hashes and `NATIVE case=theme-scene-v1 probe=0`, `NATIVE case=theme-scene-v1 import=0`.
- Existing failing game copy and original userdata were not accessed for mutation. No native process was killed or error ignored. All these native invocations ended normally.

## Original and copy hashes (SHA256)

Each copied asset matched the current original at copy time; byte copying only, no edits to assets/import metadata.

| Relative game source | SHA256 |
|---|---|
| assets/fonts/galmuri/Galmuri11.ttf | E24256F42E43713D2EA086A1E1669D78B968F5B3CC547E5C157F0606FFA5DEF1 |
| assets/third_party/ninja_adventure/Ui/Theme/Theme Wood/nine_path_panel.png | 5F3BA8EE42700FC366C3EBDF2F9B478CF35D47D6D3E6E8266CA181AA30CEBDA1 |
| assets/third_party/ninja_adventure/Ui/Theme/Theme Wood/inventory_cell.png | 8B0CF04D73B9A2AF8D276746C0A160786110C880074426C1490B549C7520DF17 |
| assets/third_party/parchment_gui/panels.png | B4B2FACB74202D0D7527821E2B69B3AA26AAD969B1BC1CC9625F60F59AC46709 |
| ui/theme.tres | 8F7DE8839FFA95D81A575468B65D5422D2D7A1C476E777873B3BCBF217C9C9F7 |

## Conclusion / next test

The suspect boundary is not narrowed to a single resource. Full-project editor teardown remains the failing condition; game runtime is separately runnable. A useful next bounded test would add one known tool-script/autoload dependency group to a fresh isolated case, or obtain a native crash stack from the existing executable/environment if available. Large project bisection, global settings changes, engine replacement and ready-gate bypass were not performed. Stop here and retain preparation blocked pending an actually normal full import exit.
