# Autoload removal/restoration — bounded diagnosis

2026-09-13. Exactly one fresh diagnostic copy under workspace `reviews/games-2026-09-12/runtime/autoload-exit-diag-monsters-v1/`, excluding `.godot` cache. Original source and all previous failed snapshots unchanged. No ready registration, network request, engine replacement, global settings edit or additional bisection.

Copied identical console/gui engine binaries plus `_sc_` flag to this new diagnostic directory. Console SHA256 `239E9D89C02C8E20F3A599DA4B3EFAB2760B240DAA889DD754E2FC2BCD8D0C7D` matches original. APPDATA/LOCALAPPDATA point inside this copy. Before each import, separate no-autoload probe confirms actual `.../autoload-exit-diag-monsters-v1/appdata/AutoloadExitDiagMonsters`, native exit0.

Saved configurations: `original-project.godot`, `no-autoload.godot`, `restored-autoload.godot`. Both test configs preserve original coordinates and other policies, add exact isolated userdata, disable editor plugins. First removes only the autoload block; second restores that block byte-exact to original (comparison True). Current copied QuestObject/QuestSystem/InventoryMenu/QuestNpcPanel SHA256 matches source at inspection. This is not a complete frozen manifest for every source file.

| Condition | Script errors | Observed result |
|---|---:|---|
| No autoload, fresh import |1669|Imports finish, missing singleton parse failures and PhantomCamera2D tool manager-null errors; ObjectDB leak warning, no natural exit observed before own-session interruption|
| Full autoload restored, same cached copy |0|Reaches loading_editor_layout end, no natural exit after bounded observation; own session interrupted, no ready gate pass|

`noauto-import.log` starts script failures with Events not declared, and includes PhantomCamera2D `screen_size` / `noise_2d_emitted` null-manager accesses. This is expected dependency breakage from removing autoloads, not a valid runtime project. The test therefore cannot establish that autoload removal fixes the original native AV.

`native-transcript.log` records first probe0 and the interrupted first command. `restored-native-transcript.log` records second probe0 and second command. Interrupted shell exit1 is **not** a naturally returned Godot native crash code. The prior author's elevated launcher runs returned -1073741819; these sandbox diagnostic runs did not yield that code, so they must not be reported as reproducing the identical AV.

Conclusion: restoring autoloads removes the induced script errors, but this comparison has not obtained a normal full-project editor exit. Ready remains blocked. Runtime23PASS from earlier snapshot remains separate. The next practical decision is a bounded native crash-stack/process diagnosis under an approved execution context, or a separately reviewed preparation workflow; do not skip import errors or invent a ready manifest. No more asset/subsystem bisection was performed in this task.
