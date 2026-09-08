## 전역 시그널 버스.
##
## 시스템 간 직접 참조 대신 Events 를 통해 느슨하게 연결한다.
## 예: Events.player_damaged.emit(amount, source)
##     Events.enemy_died.connect(_on_enemy_died)
## 이름만 선언해 두었고, 실제 emit 은 각 시스템 구현 태스크에서 추가한다.
extends Node

# --- 플레이어 ---
signal player_spawned(player: Node2D)
signal player_damaged(amount: int, source: Node)
signal player_healed(amount: int)
signal player_died()
signal player_respawned(at_gravestone: Node)
signal player_stamina_changed(current: float, max_value: float)
## 스태미나 부족으로 액션(구르기 등)이 발동되지 않았을 때(F2-3 예외 규칙). HUD가 스태미나
## 바를 빨간색으로 깜박이는 트리거로 쓴다.
signal player_stamina_insufficient(action: StringName)
signal player_hp_changed(current: int, max_value: int)
signal player_level_up(new_level: int)

# --- 전투 ---
## is_advantage: 원소 상성 적중 여부(ElementCalc.get_multiplier() > 1.0). is_critical:
## LUK 기반 진짜 크리티컬(M2, stats.json 도입 후) — M1은 크리티컬 시스템이 없어 항상
## false로 emit된다. 과거(M1-2까지) 4번째 인자 이름이 is_critical이면서 실제 값은
## is_advantage였던 네이밍 불일치를 바로잡았다(sound-map-m1.md §2/§12 코드 주의 반영,
## D-61 예정 — 시그니처가 바뀌었으므로 구독부는 이 순서(공격자/대상/피해/상성/크리)로 갱신).
signal hit_landed(attacker: Node, target: Node, damage: int, is_advantage: bool, is_critical: bool)
signal just_guard_succeeded(defender: Node, attacker: Node)
signal hitstop_requested(duration_sec: float)
signal screen_shake_requested(strength: float, duration_sec: float)
## 저스트 가드 성공 시 가드 측이 낸 방어 성공량(칩데미지 대비 막아낸 원본 피해량 등,
## 호출부 재량)과 저스트 여부(항상 true — 일반 가드는 이 신호를 쏘지 않는다, 구분용
## 편의 인자). M1-3 신규(D-69 예정) — player.gd:_handle_just_guard()가 emit.
signal player_guarded(amount: int, is_just: bool)
## M1-4 신규(플레이테스트 계측, docs/qa/m1-gate-playtest.md §4). 가드 상태에서 히트박스가
## 도달한 "모든" 경우(저스트 성공/일반 가드/스태미나 고갈로 무가드 전환된 경우 포함)에
## 발신되는 분모용 신호 — player_guarded는 저스트·일반 성공 시에만 나가 가드 붕괴
## 케이스를 놓친다. 발신 지점 1곳: player.gd:_handle_guarded_hit() 최상단.
signal guard_hit_attempted(defender: Node, attacker: Node)
## M1-4 신규(플레이테스트 계측). 구르기가 스태미나 소모에 성공해 실제로 발동한 시점
## (무적 프레임이 걸리기 직전)에 발신 — 스태미나 부족으로 미발동된 시도는 포함하지
## 않는다(그 경우는 이미 player_stamina_insufficient가 있다). 발신 지점 1곳:
## roll.gd:enter() 스태미나 소모 성공 직후.
signal player_roll_started(player: Node)
## M1-4 신규(플레이테스트 계측). 콤보 3타(피니셔)가 실제로 시작된 시점 — 적에게 명중
## 여부와 무관하게 "입력 체이닝으로 3타까지 완주했다"만 센다. 발신 지점 1곳:
## attack.gd:_start_current_hit() hit_index가 combo.max_hits에 도달했을 때.
signal combo_finisher_reached(player: Node)

# --- 몬스터 ---
signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, killer: Node)
signal boss_started(boss_id: StringName)
signal boss_defeated(boss_id: StringName)

# --- 아이템 / 파밍 ---
signal item_dropped(item_id: StringName, world_position: Vector2, rarity: StringName)
signal item_picked_up(item_id: StringName, quantity: int)
## 인벤토리가 가득 차 마을 우편함으로 자동 전송됐을 때(D-10, M2-1). GameState.mailbox에
## 쌓인 뒤 발신 — 우편함 UI/수령 처리는 M2-2 이후.
signal item_mailed(item_id: StringName, quantity: int)
signal inventory_changed()
signal gold_changed(new_amount: int, delta: int)

# --- 월드 ---
signal chunk_loaded(chunk_coord: Vector2i)
signal chunk_unloaded(chunk_coord: Vector2i)
signal region_entered(region_id: StringName)
signal time_of_day_changed(hour: int)

# --- UI / 시스템 ---
signal menu_opened()
signal menu_closed()
signal game_paused(is_paused: bool)
signal save_requested(slot: int)
signal save_completed(slot: int)
signal settings_changed(key: StringName, value: Variant)
