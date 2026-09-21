## 단위 전환 ×2(D-206, 단계 b1)가 **단위 전환이었는지** 검사한다.
##
## 절대값을 다시 적는 테스트는 변환 스크립트를 두 번 쓰는 것이라 아무것도 증명하지
## 못한다(같은 실수를 두 번 하면 통과한다). 대신 **비율**을 본다 — 모든 월드 거리가
## 같은 배수로 움직였다면 서로의 비율은 변하지 않고, 하나라도 빠지거나 두 번 곱해지면
## 비율이 깨진다. 기준값은 단계 (a) 커밋 ba544c1 의 값에서 계산했다.
##
## 함께 검사하는 것: 무차원·시간 값은 건드리지 않았는가(잘못 2배 하면 밸런스가 조용히
## 바뀐다), 타일 단위로 환산한 거리가 그대로인가(전환의 목적 자체).
extends GutTest

## 단계 (a) 기준 비율. 좌변/우변 모두 월드 px이라 단위가 약분돼 전환 전후 같아야 한다.
const EPS := 0.0001


func _combat(path: String) -> float:
	return float(Data.get_value("combat", path, -1.0))


func _monster(id: String, field: String) -> float:
	return float(Data.get_value("monsters", id, {}).get(field, -1.0))


# --- 전투: 이동 속도를 분모로 한 비율 ---

func test_roll_distance_over_walk_speed() -> void:
	# 48 / 80 = 0.6 — 구르기가 "0.6초치 걸음"만큼 이동한다는 관계.
	assert_almost_eq(_combat("roll.distance_px") / _combat("movement.walk_speed_px"),
		0.6, EPS, "구르기 거리 : 이동 속도 비율")


func test_knockback_heavy_over_normal() -> void:
	# 20 / 8 = 2.5
	assert_almost_eq(_combat("knockback.heavy_px") / _combat("knockback.normal_px"),
		2.5, EPS, "강넉백 : 일반넉백 비율")


func test_knockback_normal_over_walk_speed() -> void:
	# 8 / 80 = 0.1
	assert_almost_eq(_combat("knockback.normal_px") / _combat("movement.walk_speed_px"),
		0.1, EPS, "넉백 거리 : 이동 속도 비율")


# --- 몬스터: 종별 거리 비율 ---

func test_monster_aggro_over_move_speed() -> void:
	for pair: Array in [["slime", 1.6], ["horn_rabbit", 1.6], ["mushroom", 4.8],
			["goblin_scout", 110.0 / 45.0], ["elite_goblin_captain", 132.0 / 52.0],
			["elite_bunchi_spawn", 77.0 / 46.0]]:
		var id: String = pair[0]
		assert_almost_eq(_monster(id, "aggro_range_px") / _monster(id, "move_speed_px"),
			float(pair[1]), EPS, "%s 인식 범위 : 이동 속도" % id)


## slime·horn_rabbit 은 iso-3(R5/R6)에서 **의도적으로** 재튜닝됐다 - 액터가 등각 시트로
## 커지면서 지면 원 몸 콜리전(R1/R2) 반경 합보다 사거리가 짧아 "닿아 보이는데 안 맞는"
## 구간이 생겼기 때문이다. 단위 전환 불변식이 아니라 승인된 값 변경이므로, 그 둘만
## 새 기준으로 옮기고 나머지 4종은 단계 (a) 기준 비율을 그대로 지킨다(가드 유지).
func test_monster_melee_over_aggro() -> void:
	for pair: Array in [["slime", 32.0 / 128.0], ["horn_rabbit", 36.0 / 160.0],
			["mushroom", 20.0 / 96.0], ["goblin_scout", 90.0 / 110.0],
			["elite_goblin_captain", 90.0 / 132.0], ["elite_bunchi_spawn", 14.0 / 77.0]]:
		var id: String = pair[0]
		assert_almost_eq(_monster(id, "melee_range_px") / _monster(id, "aggro_range_px"),
			float(pair[1]), EPS, "%s 근접 사거리 : 인식 범위" % id)


## horn_rabbit_big(iso-3에서 신규 튜닝된 1막 정예, D-267)은 horn_rabbit 계열 비율표
## 대상이 아니다 — melee_range_px만 32->40으로 재조정된 개체라 위 비율 테스트에 넣으면
## 오히려 잘못된 불변식을 주장하게 된다. 대신 두 값을 리터럴로 고정해 회귀를 막는다.
func test_horn_rabbit_big_range_literals_unchanged() -> void:
	assert_eq(_monster("horn_rabbit_big", "melee_range_px"), 40.0, "horn_rabbit_big 근접 사거리 40px 고정(D-267)")
	assert_eq(_monster("horn_rabbit_big", "aggro_range_px"), 160.0, "horn_rabbit_big 인식 범위 160px 고정(D-267)")


func test_monster_leash_over_aggro() -> void:
	for pair: Array in [["slime", 140.0 / 64.0], ["horn_rabbit", 180.0 / 80.0],
			["mushroom", 120.0 / 96.0], ["goblin_scout", 200.0 / 110.0]]:
		var id: String = pair[0]
		assert_almost_eq(_monster(id, "leash_range_px") / _monster(id, "aggro_range_px"),
			float(pair[1]), EPS, "%s 리쉬 : 인식 범위" % id)


# --- 타일 단위 거리: 전환의 목적 자체 ---

func test_distances_in_tiles_unchanged() -> void:
	var tile: float = float(Tuning.TILE_SIZE_PROTOTYPE)
	assert_almost_eq(tile, 32.0, EPS, "타일은 32 월드단위여야 한다(D-206)")
	# 단계 (a)에서 타일(16) 기준으로 계산한 타일 수가 그대로여야 한다.
	assert_almost_eq(_combat("movement.walk_speed_px") / tile, 5.0, EPS,
		"초당 이동 = 5타일")
	assert_almost_eq(_combat("roll.distance_px") / tile, 3.0, EPS, "구르기 = 3타일")
	assert_almost_eq(_monster("slime", "aggro_range_px") / tile, 4.0, EPS,
		"슬라임 인식 = 4타일")
	assert_almost_eq(Tuning.MINIMAP_VIEW_RADIUS_PX / tile, 7.5, EPS,
		"미니맵 반경 = 7.5타일")


# --- 건드리면 안 되는 값: 무차원·시간·화면 px ---

func test_dimensionless_values_untouched() -> void:
	assert_eq(Tuning.SCREEN_SHAKE_LEVELS, [0.0, 0.5, 1.0, 1.5] as Array[float],
		"셰이크 배율표는 무차원 — 2배 대상 아님")
	assert_almost_eq(Tuning.FACING_AXIS_SWITCH_BIAS, 1.3, EPS, "축 전환 완충은 무차원")
	assert_almost_eq(_combat("guard.chip_damage_ratio"), 0.2, EPS, "칩데미지 비율은 무차원")


func test_time_values_untouched() -> void:
	assert_almost_eq(_combat("roll.duration_sec"), 0.45, EPS, "구르기 시간 불변")
	assert_almost_eq(_combat("roll.iframes_sec"), 0.3, EPS, "무적 시간 불변")
	assert_almost_eq(_combat("hitstop.normal_sec"), 0.05, EPS, "히트스톱 불변")
	assert_almost_eq(_combat("telegraph.min_sec"), 0.5, EPS, "공격 예고 0.5초 불변")


func test_screen_space_margins_untouched() -> void:
	# 화면 좌표 여백은 월드 거리가 아니다 — 2배 하면 HUD가 어긋난다.
	assert_almost_eq(Tuning.QUEST_ARROW_MARGIN_PX, 24.0, EPS, "퀘스트 화살표 여백은 화면 px")
	assert_almost_eq(Tuning.MINIMAP_EDGE_MARGIN_PX, 3.0, EPS, "미니맵 여백은 화면 px")


func test_non_spatial_stats_untouched() -> void:
	assert_eq(Tuning.PLAYER_MAX_HP, 100, "HP는 거리가 아니다")
	assert_almost_eq(Tuning.PLAYER_BASE_ATTACK, 10.0, EPS, "공격력은 거리가 아니다")
	assert_eq(int(_monster("slime", "hp")), 18, "몬스터 HP 불변")


# --- 세이브 v1 -> v2 마이그레이션 (D-210) ---
#
# 좌표가 2배가 됐으므로 옛 세이브의 위치도 2배여야 같은 지점에 선다. 세이브에 들어 있는
# 좌표는 플레이어 위치 한 쌍뿐이라(비석은 id 문자열) 이 변환이 전부다.

func _v1_payload(x: float, y: float) -> Dictionary:
	return {"version": 1, "state": {"player": {"position": {"x": x, "y": y},
		"resources": {"hp": 50}}, "game_state": {"last_waystone_id": "waystone1"}}}


func test_migration_doubles_player_position() -> void:
	var migrated: Dictionary = SaveManager._migrate_v1_to_v2(_v1_payload(-40.0, -100.0))
	var pos: Dictionary = migrated["state"]["player"]["position"]
	assert_almost_eq(float(pos["x"]), -80.0, EPS, "x가 2배여야 한다")
	assert_almost_eq(float(pos["y"]), -200.0, EPS, "y가 2배여야 한다")
	assert_eq(int(migrated["version"]), 2, "버전이 2로 올라가야 한다")


func test_migration_leaves_everything_else_alone() -> void:
	# 좌표가 아닌 것을 건드리면 세이브가 조용히 망가진다.
	var migrated: Dictionary = SaveManager._migrate_v1_to_v2(_v1_payload(0.0, 0.0))
	assert_eq(int(migrated["state"]["player"]["resources"]["hp"]), 50, "HP 불변")
	assert_eq(String(migrated["state"]["game_state"]["last_waystone_id"]), "waystone1",
		"비석 id 불변(좌표가 아니라 문자열이라 변환 대상이 아니다)")


func test_migration_survives_missing_position() -> void:
	# 손상되거나 옛 필드가 없는 세이브에서도 죽지 않아야 한다.
	var migrated: Dictionary = SaveManager._migrate_v1_to_v2({"version": 1, "state": {}})
	assert_eq(int(migrated["version"]), 2, "위치가 없어도 버전은 올라간다")
