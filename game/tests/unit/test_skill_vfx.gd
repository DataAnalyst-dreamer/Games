## SkillVfx(M4-3 "스킬 이펙트·시전 연출 개선") 단위 테스트: kind별 노드 생성·수명, 색
## 파싱 순수 로직. dash_trail은 RollGhost(tree.current_scene에 스폰)를 재사용해 이 단위
## 테스트 컨텍스트(current_scene 없음)에서는 안전한 no-op이 되는지만 확인한다 — 실제
## 잔상 스폰 검증은 tests/smoke/SmokeSkillVfx.tscn이 맡는다.
##
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const PlayerScene := preload("res://scenes/player/Player.tscn")


func _make_player() -> Player:
	var player: Player = PlayerScene.instantiate()
	add_child_autofree(player)
	player.facing = Vector2.RIGHT
	return player


## parent=player로 스폰해 "노드 1개 생성 → 스스로 free"를 player의 자식 수 변화로 확인한다
## (spawn()의 parent 인자는 이 검증을 Xvfb/Main.tscn 없이 하기 위한 테스트 훅).
func _assert_spawns_and_frees(kind: String, lifetime_sec: float) -> void:
	var player := _make_player()
	var before: int = player.get_child_count()
	SkillVfx.spawn(kind, player, Color.WHITE, 40.0, player)
	assert_eq(player.get_child_count(), before + 1, "%s: 노드 1개가 즉시 생성돼야 한다" % kind)
	await wait_seconds(lifetime_sec + 0.15)
	assert_eq(player.get_child_count(), before, "%s: 수명이 끝나면 스스로 free돼야 한다" % kind)


func test_slash_arc_spawns_and_frees() -> void:
	await _assert_spawns_and_frees("slash_arc", SkillVfx.DEFAULT_LIFETIME_SEC)


func test_thrust_line_spawns_and_frees() -> void:
	await _assert_spawns_and_frees("thrust_line", SkillVfx.DEFAULT_LIFETIME_SEC)


func test_ring_spawns_and_frees() -> void:
	await _assert_spawns_and_frees("ring", SkillVfx.RING_LIFETIME_SEC)


func test_speed_lines_spawns_and_frees() -> void:
	await _assert_spawns_and_frees("speed_lines", SkillVfx.DEFAULT_LIFETIME_SEC * 0.7)


func test_glow_spawns_and_frees() -> void:
	await _assert_spawns_and_frees("glow", SkillVfx.DEFAULT_LIFETIME_SEC)


func test_none_kind_spawns_nothing() -> void:
	var player := _make_player()
	var before: int = player.get_child_count()
	SkillVfx.spawn("none", player, Color.WHITE, 40.0, player)
	assert_eq(player.get_child_count(), before, "none은 이펙트 노드를 만들지 않는다")


func test_unknown_kind_spawns_nothing() -> void:
	var player := _make_player()
	var before: int = player.get_child_count()
	SkillVfx.spawn("갑자기_생긴_kind", player, Color.WHITE, 40.0, player)
	assert_eq(player.get_child_count(), before, "미지정 kind는 데이터 검증 전 더미로 안전 폴백해야 한다")


## dash_trail은 RollGhost.spawn(sprite)이 sprite.get_tree().current_scene에 붙이는데,
## 단위 테스트 트리에는 current_scene이 없어(Main.tscn을 열지 않음) 조용히 no-op된다 —
## 크래시하지 않고 player 자신에게는 아무것도 붙이지 않는지만 확인한다.
func test_dash_trail_kind_does_not_crash_without_current_scene() -> void:
	var player := _make_player()
	var before: int = player.get_child_count()
	SkillVfx.spawn("dash_trail", player, Color.WHITE, 40.0, player)
	assert_eq(player.get_child_count(), before, "current_scene 없이는 player 자식에 아무것도 붙지 않는다")
	# _spawn_dash_trail이 예약한 반복 타이머(최대 0.1s 뒤)가 다 흘러간 뒤 반환해야, GUT의
	# add_child_autofree가 player를 정리한 뒤에 그 타이머가 뒤늦게 콜백을 불러 "freed 캡처"
	# 엔진 오류를 내는 것을 막는다(is_instance_valid 가드 자체는 정상 동작 — 순수 테스트
	# 타이밍 문제).
	await wait_seconds(0.15)


func test_null_player_is_ignored() -> void:
	SkillVfx.spawn("ring", null, Color.WHITE, 40.0)
	pass_test("null player는 조용히 무시되어야 한다(크래시 없음)")


func test_flash_color_from_hex_falls_back_to_default_when_empty() -> void:
	assert_eq(SkillVfx.flash_color_from_hex(""), HitFlash.FLASH_COLOR)


func test_flash_color_from_hex_boosts_given_color() -> void:
	var c: Color = SkillVfx.flash_color_from_hex("#664422")
	assert_almost_eq(c.a, 1.0, 0.001)
	assert_true(c.r > Color("#664422").r, "오버브라이트 부스트가 적용돼야 한다")


func test_base_color_from_hex_falls_back_to_white_when_empty() -> void:
	assert_eq(SkillVfx.base_color_from_hex(""), Color.WHITE)


func test_base_color_from_hex_parses_given_hex() -> void:
	assert_eq(SkillVfx.base_color_from_hex("#ff0000"), Color(1.0, 0.0, 0.0))
