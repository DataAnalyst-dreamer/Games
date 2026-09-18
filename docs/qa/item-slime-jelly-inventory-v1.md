# Jelly inventory icon — limited integration

2026-09-13. Existing `slime_jelly` inventory grid only. InventoryCell gains an optional 20×20 nearest TextureRect below all grade/quantity/lock/focus overlays. Existing four-argument `set_item` resets the texture; `clear` removes it. Other items and blacksmith call compatibility retain the gray placeholder. No global item_icons mapping or game data changes.

Source PNG is byte-preserved in `game/assets/generated/items/`; source/prompt record is `docs/art/preview/ai-local-pass/item-slime-jelly-v1-prompt.md`.

Actual capture: `item-slime-jelly-inventory-v1.png`, 1280×720. Selected jelly, adjacent fallback ring and equipped fallback weapon are visible. Yellow focus border and white rarity dot remain above/beyond art. At 20 logical px the jar/cork/green fill remain identifiable but flowing jelly detail is reduced. Opaque card fits within the slot; no FHD or complete inventory redesign claim.

Validation used existing isolated `reviews/games-2026-09-12/runtime/item-panel-game` and no-autoload `item-panel-probe` (workspace-relative). Actual user directory checked as `C:/Users/freer/AppData/Roaming/Games-QA-item-panel-20260913-monsters`; no save/load calls or world scene. Existing QA fixtures were not deleted. Only relevant UI scripts/scene and the new PNG copied to the validation project.

- `check_item_icon.gd`: 14 PASS, 0 FAIL including texture→fallback→empty reuse, 20px bounds, nearest/input passthrough, grade/quantity/focus/lock order, equip fallback, filter empty/restoration, tooltip and real capture. Four-argument cell invocation exercises the blacksmith-compatible API; full blacksmith scene navigation was not tested.
- `check_item_descriptions.gd`: existing 10 description checks PASS, exit0.
- Logs in workspace `reviews/games-2026-09-12/runtime/item-icon-{probe,render,descriptions,import}.log`.
- Import completed PNG and script import but editor shutdown stalled after editor-settings permission errors; its own terminal process was interrupted. Renderer/test process ended normally. Shader cache, root-certificate and isolated Metrics err7 errors remain; no claim of error-free full game.
- Independent final DA pending. Original game editor import was not run; its new PNG will require normal Godot import before running.

## Optional-resource hardening

After initial DA, preload was replaced with guarded ResourceLoader.exists + lazy load and texture/null cache. Missing optional PNG now leaves the existing gray fallback rather than a script preload dependency. Added missing-path test; `item-icon-optional.log` reports 15 PASS / 0 FAIL and real capture regenerated. Source PNG bytes unchanged. Final delta DA pending.
