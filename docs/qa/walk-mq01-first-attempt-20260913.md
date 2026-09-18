# MQ01 actual keyboard walking — first failed attempt

2026-09-13. This is a failed play-input slice, not first-play completion or launcher readiness.

Test source preserved in `tools/qa/walk-mq01/`; these files are diagnostic only and not referenced by production. Executed in `reviews/games-2026-09-12/runtime/autoload-exit-diag-monsters-v1/game/tests/smoke/` after restoring original autoload block. Original Main/player/monster parameters unchanged. No player position assignment, quest accept/advance/objective API or monster removal; only key events and state/position reads. Main process mode explicitly PAUSABLE to avoid inheriting test ALWAYS; game itself normally pauses this way.

No-autoload probe verified exact diagnostic user-data path before play. Test refuses existing slot0_auto fixture, keeps normal autosave subscriptions, and fails on player death or 7200 walking physics frames (120 simulated seconds at60fps). This cap covers walking frames, not all UI waits or real-time wall clock.

First attempt: spawn(0,0) → waypoint(-300,0) → Teo target(-350,135) → E/Enter accepted MQ01 → E/Escape → cargo target(-399,190). Cargo arrival actual(-396.8806,186.2141), cumulative396 walking frames (6.6 simulated seconds); E did not produce complete_ready. Test stopped with `WALK_MQ01_RESULT FAIL reason=cargo explicit E did not ready frames=396`, native exit1. No completion/autosave success claim. No retry or save cleanup performed.

Monster combat remained enabled: slime telegraph/attack and goblin whistle logged. Metrics show zero hits/deaths during this attempt. Initial `monsters=0` diagnostic is erroneous because the selected group does not enumerate actual monster instances; it is **not** evidence of disabled/absent monsters. The script's next revision should count actual MonsterBase instances instead.

Cargo's RectangleShape2D center offset(0,-4) and size20×20 suggest the chosen lower approach may be outside overlap, but first run did not log overlaps or objective index, so this remains a hypothesis. Next diagnostic should log exact overlap/current objective and use a natural walking approach within actual bounds, not teleport or alter collision rules.

Logs: diagnostic-root `probe-before-walk.log`, `walk-mq01.log`, `walk-native-transcript.log` (records probe native0/play native1). Editor-import failure still blocks ready.json. Readiness gate unchanged, no production edits. Full snapshot source manifest not collected in this attempt; four key production hashes were checked before execution, so avoid an all-source freeze guarantee.
