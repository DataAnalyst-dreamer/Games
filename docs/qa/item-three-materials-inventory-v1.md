# Three material icons: limited inventory integration

2026-09-13. Existing rabbit_horn and mushroom_cap joined slime_jelly in inventory_menu's local optional texture map. No global item_icons, drops, recipes, stats, text or cell dimensions changed. Original 1254×1254 RGB PNGs copied byte-for-byte to game/assets/generated/items; README records source prompts and SHA256. Main game original editor import not performed.

Existing isolated item-panel-game/probed Games-QA-item-panel-20260913-monsters directory reused for UI-only test, no world or save/load. New PNGs imported only in copy. Editor completed image import then stalled on editor-settings permission errors; own import process interrupted. GUI test ended normally.

Later reuse (2026-09-13 evening): this mutable `item-panel-game` copy is being updated for the small-potion UI test. Its pre-update menu is byte-backed up under `runtime/potion-inventory-20260913-art-v1/backup/` with hashes. This report and its old logs/screenshot remain historical evidence, not a claim that the current mutable copy still matches the original test inputs. Frozen diagnostic/integrated/NPC copies are not modified.

`reviews/games-2026-09-12/runtime/check_material_icons.gd` (workspace-relative) reports **17 PASS, 0 FAIL** in `three-material-icons.log`: three 20px textures, original grade/quantity, translated names/descriptions, each reuse fallback, each missing optional resource, other-item fallback, PNG save.

Actual screenshot `item-three-materials-inventory-v1.png`: **1280×720**, three materials adjacent, rabbit horn selected, white common dots/bars and x3 quantity preserved; gray fourth item unchanged. Directly inspected, no art covers selection border. Horn at20px can resemble a fang; name/description disambiguate. Cap gill details reduce at20px. This is not FHD, complete new icon set, or gameplay completion. Existing shader-cache/certificate/Metrics err7 environment issues remain. Independent final DA pending.
