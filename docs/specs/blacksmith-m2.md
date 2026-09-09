# M2-4 대장간 로직(강화·재련·분해·제작) + 골드 + 우편함

> 기준: `docs/brd/03-features/03-아이템-파밍.md` F3-3(S3-3a/b/c)·F3-4 / `docs/brd/04-decisions.md`
> D-10·D-12·D-13·D-14·D-31·D-32 / `docs/specs/items-and-drops-m2.md` §5-11 / `docs/specs/data_tables.md`
> §6-8 / `game/data/enhance.json`·`items.json`·`affixes.json`·`blueprints.json`.
>
> 범위: 백엔드 로직만(강화/재련/분해/제작/골드/우편함). UI는 다음 단계 — 대장간/우편함
> NPC는 `Events.blacksmith_opened`/`mailbox_opened`만 발신한다.
>
> **중간 결정 반영(디렉터, D-85 예정)**: 이 문서는 최초 구현 이후 디렉터가 UI 설계 검토
> 중 내려준 6개 결정을 전부 반영한 최종 상태를 기술한다(재련 즉시 차감, 미리보기 API,
> `locked` 필드, 분해 일괄 처리, `Mailbox.claim_all()`, `Equipment.enhance_multiplier()` 통합).

---

## 1. 구현 요약

| 파일 | 내용 |
|---|---|
| `game/scripts/systems/blacksmith.gd` | 강화/재련/분해/제작 순수 로직(`class_name Blacksmith`, RefCounted, static 함수만). RNG 주입 가능. |
| `game/scripts/systems/mailbox.gd` | 우편함 큐 순수 로직(`class_name Mailbox`). push/claim/claim_all. |
| `game/scripts/systems/inventory.gd` | `add_or_mail()`(오버플로 단일 진입점), `consume_item()`(재료 소모), `set_locked()` 추가. |
| `game/scripts/systems/equipment.gd` | `_enhance_multiplier()` → 공개 `enhance_multiplier()`로 전환(중복 정의 제거). |
| `game/scripts/systems/loot_system.gd` | ItemInstance 스키마에 `locked: bool`(기본 false) 추가. |
| `game/scripts/ui/inventory_ui_calc.gd` | 자체 `_enhance_multiplier()` 제거, `Equipment.enhance_multiplier()` 재사용. |
| `game/scripts/core/game_state.gd` | `gold`(기존)+`spend_gold()`, `mailbox`를 `Mailbox` 인스턴스로 전환, `blacksmith_*()` 5종 + 미리보기 4종, `claim_mail()`/`claim_all_mail()`. |
| `game/scripts/core/events.gd` | `blacksmith_opened`, `mailbox_opened`, `blacksmith_result`, `mail_received`, `mail_claimed` 신설(`gold_changed`는 기존). |
| `game/scripts/core/data.gd` | `REQUIRED_SCHEMA.blueprints`(존재만), `_validate_blueprints()` 신설. |
| `game/scripts/world/blacksmith_npc.gd`, `mailbox_npc.gd` | interact 시 open 신호만 발신(Waystone 패턴). |
| `game/scenes/world/BlacksmithNpc.tscn`, `MailboxNpc.tscn` | placeholder 도형. `Main.tscn`에 Waystone1 옆(마을 위치)에 배치 — **주의**: `World.tscn`은 지형(TileMap)만 담당하고 실제 NPC/몬스터/플레이어 인스턴스는 전부 `Main.tscn`에 배치되는 기존 관례(Waystone1도 동일)를 따랐다. |
| `game/tools/qa/validate_tables.py` | `validate_blueprints()` 추가. |
| `game/tests/unit/test_blacksmith.gd`, `test_mailbox.gd` | GUT 유닛 테스트. |
| `game/tests/smoke/SmokeBlacksmith.tscn`/`smoke_blacksmith.gd`, `SmokeMailbox.tscn`/`smoke_mailbox.gd` | 헤드리스 스모크. |

`enhance.json`/`blueprints.json`은 이미 재련 비용표·분해 산출표·도면 6종을 전부 갖추고
있어 데이터 추가가 필요 없었다(`_balance_todo` 없음) — `blueprints.json`은 이전 담당자가
남긴 초안을 검토 후 그대로 채택했다(참조 무결성 검증 통과, §4).

---

## 2. 공개 API

### Blacksmith (순수 로직)
```
Blacksmith.enhance(item_inst, enhance_table, gold, stone_qty, rng=null) -> {ok, reason?|success, level, consumed}
Blacksmith.refine(item_inst, affix_index, item_def, affixes_table, enhance_table, gold, stone_qty, rng=null)
    -> {ok, reason?|old_affix, new_affix, refine_left, cost}
Blacksmith.refine_commit(item_inst, keep_new) -> {ok, reason?|kept, affix}
Blacksmith.auto_resolve_pending(item_inst) -> void   # 미확정 재련을 "구 옵션 유지"로 자동 정리
Blacksmith.salvage(item_insts: Array, enhance_table, equipped_uids: Array) -> {ok, results:[...], yields}
Blacksmith.craft(blueprint_id, blueprints_table, items_table, affixes_table, refine_max_attempts, gold, materials, rng=null)
    -> {ok, reason?|item_inst, consumed}

# 미리보기(부작용 없음)
Blacksmith.get_enhance_preview(item_inst, enhance_table) -> {level_next, success_rate, cost_gold, cost_items, stat_multiplier_next, maxed}
Blacksmith.get_refine_cost(item_inst, enhance_table) -> {cost_gold, attempts_left, cost_material_id, cost_material_qty, refinable}
Blacksmith.get_salvage_preview(item_insts: Array, enhance_table) -> {yields}
Blacksmith.get_craft_preview(blueprint_id, blueprints_table, have_materials, gold) -> {materials:[{id,need,have}], cost_gold, can_craft}
```

### Mailbox (순수 로직)
```
Mailbox.push(mail: {id?, item_id|gold, count, expires_day}) -> mail(자동 채번된 id 포함)
Mailbox.claim(mail_id, inventory, items_table) -> {ok, reason?|kind, amount|item_id/count, mail_id}
Mailbox.claim_all(inventory, items_table) -> {claimed: [...], failed: [...]}
```

### GameState (부수효과 담당 — Events 발신 + 실제 골드/인벤토리 반영)
```
GameState.gold: int
GameState.add_gold(amount) / GameState.spend_gold(amount) -> bool
GameState.mailbox: Mailbox
GameState.claim_mail(mail_id) / GameState.claim_all_mail()

GameState.blacksmith_enhance(uid)
GameState.blacksmith_refine(uid, affix_index)          # D-85: 골드·횟수 즉시 차감
GameState.blacksmith_refine_commit(uid, keep_new)       # D-85: 택1은 무료
GameState.blacksmith_salvage(uids: Array)               # D-85: 항상 배열, 부분 성공 허용
GameState.blacksmith_craft(blueprint_id)

GameState.get_enhance_preview(uid) / get_refine_cost(uid) / get_salvage_preview(uids) / get_craft_preview(blueprint_id)

Inventory.add_or_mail(item_instance, item_def, mailbox)  # 오버플로 단일 진입점(D-10)
Inventory.consume_item(item_id, count) -> bool
Inventory.set_locked(uid, locked) -> bool
Equipment.enhance_multiplier(enhance_level, enhance_table) -> float  # 중복 정의 제거, 단일 소스
```

## 3. 시그널
`Events.blacksmith_opened()`, `Events.mailbox_opened()`,
`Events.blacksmith_result(action: StringName, result: Dictionary)`,
`Events.mail_received(mail_id, item_id, count)`, `Events.mail_claimed(mail_id, result)`,
`Events.gold_changed(new_amount, delta)`(기존, `spend_gold`도 음수 delta로 재사용).

## 4. 디렉터 결정 6개 반영 여부
1. 재련 즉시 차감(`refine()`에서 골드+횟수 차감, `refine_commit()`은 택1만/무비용) — **반영**.
2. 미리보기 API 4종(`get_enhance_preview`/`get_refine_cost`/`get_salvage_preview`/`get_craft_preview`) — **반영**.
3. `locked: bool` 필드(`LootSystem.make_item_instance`) + `Inventory.set_locked()` — **반영**. salvage 거부 사유 `"locked"` 추가.
4. `salvage(items: Array)` 배치 시그니처(단일도 길이 1 배열) — **반영**.
5. `Mailbox.claim(mail_id)` + `claim_all()` — **반영**(`GameState.claim_all_mail()` 래퍼 포함).
6. 강화 배율 중복 제거 — `Equipment.enhance_multiplier()`를 공개해 `blacksmith.gd`(미리보기)·`inventory_ui_calc.gd`가 공유 — **반영**.

미확정 재련 자동 처리("다른 액션 전 반드시 commit")는 `Blacksmith.auto_resolve_pending()`으로
구현하고, `GameState.blacksmith_enhance`/`blacksmith_refine`/`blacksmith_salvage` 진입부에서
대상 아이템에 대해 호출한다(구 옵션 유지로 자동 정리).

## 5. 미결정 질문 목록 (디렉터가 D-98+로 기록)

1. **강화 실패 시 골드도 소모되는가?** F3-3 원문 "실패 시 강화석만 소실"은 골드 환불로도
   읽힌다. 이 구현은 `docs/specs/data_tables.md` §6의 "+10까지 기대 비용" 표(예: +7 기대
   1.43회 × 200골드 ≈ 285.7골드 — 시행마다 골드도 소모된다는 전제로 계산된 값)를 정본으로
   채택해 **매 시행마다 골드+강화석 모두 소모**로 구현했다. game-designer 확인 필요.
2. **재련 즉시 차감(디렉터 결정)과 D-13 문서 "확정 시 차감" 문구의 불일치.** 원래
   `docs/brd/04-decisions.md` D-13은 "재련 횟수는 확정 시 차감"이라고 명시하는데, 이번
   디렉터 결정으로 실제 구현은 "굴림 즉시 차감"으로 바뀌었다 — D-13 문서 자체를 이 구현에
   맞춰 갱신할지, 아니면 D-85로 "D-13을 대체"한다고 명시할지 결정 필요.
3. **분해 배치의 부분 성공 UX.** `Blacksmith.salvage()`는 여러 아이템 중 일부만 성공해도
   최상위 `ok=true`를 반환한다(개별 결과는 `results[]`). "영웅 이상 포함 시 확인 다이얼로그"
   (F3-3 예외)는 이번 백엔드 범위 밖이라 UI 단계에서 추가해야 한다.
4. **우편함 만료(`expires_day`).** 스키마에는 존재하지만 D-10("보관 기한 없음")에 따라
   `Mailbox.claim()`은 검사하지 않는다. 이 필드를 완전히 제거할지, 향후 이벤트성 만료
   우편(예: 시즌 보상)을 위해 남겨둘지 결정 필요.
5. **`get_salvage_preview()`가 장착/잠금 여부를 반영하지 않는 것.** 미리보기는 원시 등급별
   산출만 합산하고, 실제 거부(장착/잠금)는 `salvage()` 호출 시점에만 걸러진다 — UI가 선택
   목록 단계에서 이미 걸러준다는 전제인데, 이 전제가 맞는지 UI 설계와 교차 확인 필요.
