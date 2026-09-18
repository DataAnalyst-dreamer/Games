# MQ06/MQ07 NPC panel extension

Production change: `quest_npc_panel.gd` supports exactly the existing four Teo Act1 main quests (MQ01,02,06,07). Original `act1_hartland.json` confirms MQ03–05 giver system, MQ06/07 giver teo and branch null. No rewards/prerequisites/localization/style/backend changes.

New `SmokeQuestNpcLate.tscn` / `smoke_quest_npc_late.gd` injects MQ01–05 completed fixture using from_dict, then simulates ordered NPC/reach/interact/collect objective events. This is **not prior combat or cave traversal completion**. Acceptance/completion uses actual Enter input on panel buttons. All active objectives and offer/ready text are checked with rendered Label bounds. Duplicate confirmation compares quest snapshot, gold and inventory.

Reused isolated npc-greeting-game copy and no-autoload npc-greeting-probe, actual user directory exact checked before execution and in smoke. No save/load calls; main quest autosave subscription disconnected only inside test. No fixture deletion. Runtime production panel copied from current source; other world code remains previously verified copy, not story's concurrent edits.

- `quest-npc-late-probe.log`: actual Games-QA-npc-greeting-20260913-story directory match.
- `quest-npc-late-headless.log`: 31 PASS / 0 FAIL, exit0.
- `quest-npc-late-render.log`: 32 PASS / 0 FAIL including capture, process ended.
- `quest-npc-late-regression.log`: existing MQ01/02 world/input test 22 PASS / 0 FAIL, exit0.
- `quest-npc-mq06-v1.png`: actual 1280×720 screenshot of MQ06 objective 3; source text/body/buttons visually inspected, no clipping. Not FHD. Remaining MQ06/07 text states have bounds checks rather than individual screenshots.

Known limitations: existing backend warns `register_main_act2_regions` is ignored on MQ07 completion; Act2 transition is not implemented by this UI extension. Existing LUK/INT warnings, certificate/shader cache errors and isolated Metrics err12 remain. No disk persistence or actual world interaction collision test for MQ06/07 in this slice. Full scene pause/world integration is covered only by MQ01/02 regression. Independent DA pending.
