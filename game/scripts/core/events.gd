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
signal player_hp_changed(current: int, max_value: int)
signal player_level_up(new_level: int)

# --- 전투 ---
signal hit_landed(attacker: Node, target: Node, damage: int, is_critical: bool)
signal just_guard_succeeded(defender: Node, attacker: Node)
signal hitstop_requested(duration_sec: float)
signal screen_shake_requested(strength: float, duration_sec: float)

# --- 몬스터 ---
signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, killer: Node)
signal boss_started(boss_id: StringName)
signal boss_defeated(boss_id: StringName)

# --- 아이템 / 파밍 ---
signal item_dropped(item_id: StringName, world_position: Vector2, rarity: StringName)
signal item_picked_up(item_id: StringName, quantity: int)
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
