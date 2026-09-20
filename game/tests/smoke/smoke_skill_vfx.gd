## 헤드리스 스모크 테스트: M4-3 "스킬 이펙트·시전 연출 개선".
## (1) SkillVfx.spawn() 7종(kind 6개+none)이 실제 Main.tscn(tree.current_scene O)에서
##     노드를 생성/소멸시키는지 — 단위 테스트(test_skill_vfx.gd)는 parent 인자로 우회해
##     current_scene 없이 확인했으므로, 여기서는 실제 배선 그대로(parent 생략) 확인한다.
## (2) 실제 스킬 시전(blade_power_slash) 시 히트박스 activate 프레임과 이펙트 스폰 프레임이
##     같은 콜백에서 함께 도는지(activate 직후 Slime 피해로 간접 확인, smoke_stats_skills.gd
##     의 데미지 체크와 동일 타이밍축).
## (3) 선딜(anticipation) 도중 피격으로 Skill 상태가 캔슬되면(exit() 선발) 늦게 도착하는
##     지연 콜백이 히트박스를 켜지 않는지(D-127류 "상태 나간 뒤 뒤늦은 콜백" 가드, 추가
##     요구사항 (a) 검증) — 몬스터가 전혀 피해를 입지 않아야 한다.
##
## 실행: godot --headless --path game res://tests/smoke/SmokeSkillVfx.tscn --quit-after 900
extends Node

const ALL_KINDS := ["slash_arc", "thrust_line", "ring", "glow", "dash_trail", "speed_lines", "none"]

var _player: Player
var _dummy: MonsterBase
var _fail_count: int = 0


func _ready() -> void:
	print("=== SMOKE SKILL VFX: kind별 노드 생성/소멸 + 히트박스 동기화 + 선딜 캔슬 가드 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)

	_player = main.get_node("Player") as Player
	_dummy = main.get_node("Slime3") as MonsterBase
	_dummy.set_physics_process(false)
	_dummy.hp = 99999
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_dummy.global_position = _player.global_position + Vector2(12, 0)

	await _check_all_kinds_spawn_and_free()
	await _check_real_cast_hitbox_and_vfx_are_synced()
	await _check_anticipation_cancel_skips_hitbox()

	print("=== SMOKE SKILL VFX 종료: %s ===" % ("FAIL(%d)" % _fail_count if _fail_count > 0 else "ALL PASS"))
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_fail_count += 1
		print("[FAIL] %s" % label)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


## 실제 게임 배선(parent 생략 → tree.current_scene)으로 7종을 순차 시전해 노드가
## 생기고 스스로 사라지는지 확인한다. dash_trail은 RollGhost를 재사용하므로 별도로 표시.
func _check_all_kinds_spawn_and_free() -> void:
	var scene_root: Node = get_tree().current_scene
	for kind: String in ALL_KINDS:
		var before: int = scene_root.get_child_count()
		SkillVfx.spawn(kind, _player, Color("#66ccff"), 40.0)
		var after_spawn: int = scene_root.get_child_count()
		if kind == "none":
			_check(after_spawn == before, "kind=none: 이펙트 노드 없음")
		else:
			_check(after_spawn > before, "kind=%s: 발동 프레임에 이펙트 노드 생성" % kind)
		await get_tree().create_timer(SkillVfx.RING_LIFETIME_SEC + 0.15).timeout
		var after_free: int = scene_root.get_child_count()
		_check(after_free == before, "kind=%s: 후딜 종료 후 이펙트 노드 스스로 소멸" % kind)


## 히트박스 activate와 SkillVfx.spawn이 같은 콜백(skill.gd:_fire)에서 함께 실행되므로,
## 실제 스킬 시전 후 "선딜 시간이 지나면 곧바로 피해가 들어간다"만 확인해도 두 이펙트가
## 같은 프레임에서 출발했음을 간접 증명한다(스폰 자체는 위에서 이미 별도 확인).
func _check_real_cast_hitbox_and_vfx_are_synced() -> void:
	const SKILL_ID := "blade_power_slash"
	GameState.skill_points += 1
	Progression.learn_skill(SKILL_ID)
	Progression.assign_hotbar(0, "skill", SKILL_ID)
	var hp_before: int = _dummy.hp

	var evt := InputEventAction.new()
	evt.action = "hotbar_1"
	evt.pressed = true
	_player.state_machine.handle_input(evt)

	# 선딜이 끝나기 직전까지는 아직 피해가 없어야 한다(발동이 지연됐다는 증거).
	await get_tree().create_timer(maxf(Tuning.SKILL_ANTICIPATION_SEC - 0.03, 0.0)).timeout
	_check(_dummy.hp == hp_before, "선딜 중에는 아직 히트박스가 켜지지 않는다")

	await get_tree().create_timer(0.06).timeout
	await _wait_frames(6)
	_check(_dummy.hp < hp_before, "선딜 종료 직후 히트박스 activate + 이펙트가 함께 발동한다")

	await get_tree().create_timer(float(Data.get_value("skills", SKILL_ID + ".cooldown_sec", 4.0)) + 0.2).timeout


## 추가 요구사항 (a): 선딜 지연 중 피격(Hurt 전이)으로 Skill 상태를 캔슬하면, 나중에
## 도착하는 지연 콜백이 히트박스를 켜면 안 된다(D-127류 가드). Slime이 전혀 맞지
## 않아야 한다.
func _check_anticipation_cancel_skips_hitbox() -> void:
	const SKILL_ID := "blade_power_slash"
	if not Progression.can_cast_skill(0):
		await get_tree().create_timer(float(Data.get_value("skills", SKILL_ID + ".cooldown_sec", 4.0)) + 0.2).timeout
	var hp_before: int = _dummy.hp

	var evt := InputEventAction.new()
	evt.action = "hotbar_1"
	evt.pressed = true
	_player.state_machine.handle_input(evt)
	_check(_player.state_machine.current_state.name == &"Skill", "Skill 상태 진입 확인")

	# 선딜이 끝나기 전에 강제로 캔슬(실제로는 Hurtbox.hurt -> Player._apply_full_hit이
	# 같은 경로로 Hurt 전이를 일으킨다 — 여기선 그 결과만 직접 재현).
	_player.state_machine.transition_to(&"Hurt", {})

	# 원래 발동됐어야 할 시점을 넉넉히 지나서도 피해가 없어야 한다.
	await get_tree().create_timer(Tuning.SKILL_ANTICIPATION_SEC + 0.2).timeout
	_check(_dummy.hp == hp_before, "선딜 중 캔슬 시 뒤늦은 콜백이 히트박스를 켜지 않는다")
