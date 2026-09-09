## QA 리뷰 Major-2 회귀 방지 테스트(docs/qa/review-m1-1-m1-2.md).
## HitFeel._collect_freeze_targets()가 Player 노드 자체를 절대 히트스톱 대상에 넣지
## 않는지 확인한다 — Player 전체가 process_mode=DISABLED로 얼면 Player._unhandled_input()
## 이 함께 차단되어 히트스톱 창과 겹치는 콤보 입력이 유실된다(§Major-2 재현 절차 참고).
extends GutTest

const PlayerScene := preload("res://scenes/player/Player.tscn")


func test_player_node_itself_is_never_a_freeze_target() -> void:
	var player: Player = PlayerScene.instantiate()
	add_child_autofree(player)

	var out: Array = []
	HitFeel._collect_freeze_targets(player, out)

	assert_false(out.has(player), "Player 노드 자체는 얼리면 안 된다(입력 차단 방지)")
	assert_true(out.has(player.sprite), "대신 스프라이트는 얼려야 한다(시각적 정지감 유지)")
	assert_true(out.has(player.weapon_pivot), "무기 스프라이트도 얼려야 한다")


func test_non_player_node_is_frozen_whole() -> void:
	var slime_scene: PackedScene = load("res://scenes/entities/monsters/Slime.tscn")
	var slime: MonsterBase = slime_scene.instantiate()
	add_child_autofree(slime)

	var out: Array = []
	HitFeel._collect_freeze_targets(slime, out)

	assert_true(out.has(slime), "몬스터 등 입력이 없는 노드는 기존대로 노드 전체를 얼린다")


func test_null_body_is_ignored() -> void:
	var out: Array = []
	HitFeel._collect_freeze_targets(null, out)
	assert_eq(out.size(), 0)
