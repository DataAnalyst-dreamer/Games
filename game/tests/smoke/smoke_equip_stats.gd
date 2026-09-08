## 헤드리스 스모크 테스트: "무기 장착 → attack 상승 확인"(M2-1, F3-2).
## GameState.equip_item() → Equipment.compute_stats() → Player.apply_equipment_stats()
## 전체 경로를 실제 Player 노드로 확인한다(단위 테스트는 Equipment.compute_stats()만
## 순수 로직으로 검증 — 이 스모크는 GameState<->Player 배선까지 포함).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeEquipStats.tscn --quit-after 60
extends Node


func _ready() -> void:
	print("=== SMOKE EQUIP STATS: 무기 장착 -> attack 상승 확인 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)

	var player: Player = main.get_node("Player") as Player
	var base_attack: float = player.get_attack_power()
	print("[BEFORE] 미장착 공격력=%.2f (Tuning.PLAYER_BASE_ATTACK=%.2f)" % [base_attack, Tuning.PLAYER_BASE_ATTACK])

	var weapon_def: Dictionary = Data.get_value("items", "weapon_common_1", {})
	if weapon_def.is_empty():
		print("[FAIL] items.json에 weapon_common_1이 없음 — 테이블 확인 필요")
		get_tree().quit()
		return

	var weapon_instance := {
		"uid": "smoke_equip_stats_weapon",
		"item_id": "weapon_common_1",
		"grade": "common",
		"quantity": 1,
		"affixes": [],
		"enhance_level": 0,
		"refine_left": 0,
	}
	var ok: bool = GameState.equip_item("weapon", weapon_instance, weapon_def)
	var after_attack: float = player.get_attack_power()
	print("[AFTER] 장착 성공=%s, 장착 후 공격력=%.2f (weapon_common_1.base_stats=%s)" \
		% [str(ok), after_attack, weapon_def.get("base_stats")])

	var equip_ok: bool = ok and GameState.equipment.is_equipped("weapon")
	var attack_rose: bool = after_attack > base_attack
	print("[CHECK] 장착 확인: %s" % str(equip_ok))
	print("[CHECK] 공격력 상승(%.2f -> %.2f): %s" % [base_attack, after_attack, str(attack_rose)])

	# 해제하면 원래 공격력으로 복귀해야 한다(장착/해제 왕복 확인 — 회귀 방지).
	GameState.unequip_item("weapon")
	var restored_attack: float = player.get_attack_power()
	var restore_ok: bool = is_equal_approx(restored_attack, base_attack)
	print("[CHECK] 해제 후 공격력 원복(%.2f): %s" % [restored_attack, str(restore_ok)])

	if equip_ok and attack_rose and restore_ok:
		print("[PASS] 무기 장착 -> attack 상승 -> 해제 -> 원복 전체 확인")
	else:
		print("[FAIL] equip_ok=%s attack_rose=%s restore_ok=%s" % [str(equip_ok), str(attack_rose), str(restore_ok)])
	print("=== SMOKE EQUIP STATS 종료 ===")
	get_tree().quit()
