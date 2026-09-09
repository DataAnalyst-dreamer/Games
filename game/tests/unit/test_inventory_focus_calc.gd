## InventoryFocusCalc(scripts/ui/inventory_focus_calc.gd) 테스트 — 장비 패널 방향 이동,
## 가방 격자 8열 이동, 장비↔격자 경계 전환 판정(F7-2, M2-2). 순수 RefCounted라 Node
## 없이 직접 테스트한다.
extends GutTest

const FocusCalcScript := preload("res://scripts/ui/inventory_focus_calc.gd")


func test_equip_neighbor_right_from_weapon_goes_to_armor() -> void:
	# weapon(0,1) -> 오른쪽으로 armor(1,1)이 가장 가깝다(같은 행, 거리 1).
	assert_eq(FocusCalcScript.equip_neighbor("weapon", Vector2i(1, 0)), "armor")


func test_equip_neighbor_right_twice_reaches_sub() -> void:
	var mid: String = FocusCalcScript.equip_neighbor("weapon", Vector2i(1, 0))
	assert_eq(FocusCalcScript.equip_neighbor(mid, Vector2i(1, 0)), "sub")


func test_equip_neighbor_down_from_head_goes_to_armor_row() -> void:
	# head(1,0) -> 아래로 armor(1,1)이 같은 열이라 가장 가깝다.
	assert_eq(FocusCalcScript.equip_neighbor("head", Vector2i(0, 1)), "armor")


func test_equip_neighbor_no_candidate_stays_put() -> void:
	# amulet(2,3)은 이미 맨 오른쪽/맨 아래 — 더 오른쪽/아래로 갈 슬롯이 없다.
	assert_eq(FocusCalcScript.equip_neighbor("amulet", Vector2i(1, 0)), "amulet")
	assert_eq(FocusCalcScript.equip_neighbor("amulet", Vector2i(0, 1)), "amulet")


func test_equip_neighbor_unknown_slot_returns_itself() -> void:
	assert_eq(FocusCalcScript.equip_neighbor("nope", Vector2i(1, 0)), "nope")


func test_is_equip_rightmost_and_leftmost() -> void:
	assert_true(FocusCalcScript.is_equip_rightmost("sub"))
	assert_true(FocusCalcScript.is_equip_rightmost("amulet"))
	assert_false(FocusCalcScript.is_equip_rightmost("weapon"))
	assert_true(FocusCalcScript.is_equip_leftmost("weapon"))
	assert_true(FocusCalcScript.is_equip_leftmost("ring1"))
	assert_false(FocusCalcScript.is_equip_leftmost("armor"))


func test_grid_neighbor_moves_right_within_row() -> void:
	assert_eq(FocusCalcScript.grid_neighbor(0, 8, 40, Vector2i(1, 0)), 1)


func test_grid_neighbor_moves_down_a_row() -> void:
	assert_eq(FocusCalcScript.grid_neighbor(0, 8, 40, Vector2i(0, 1)), 8)


func test_grid_neighbor_clamps_at_right_edge() -> void:
	assert_eq(FocusCalcScript.grid_neighbor(7, 8, 40, Vector2i(1, 0)), 7)


func test_grid_neighbor_clamps_at_left_edge() -> void:
	assert_eq(FocusCalcScript.grid_neighbor(0, 8, 40, Vector2i(-1, 0)), 0)


func test_grid_neighbor_clamps_on_partial_last_row() -> void:
	# 40칸, 8열 -> 마지막 행(4행)은 정확히 8칸 꽉 참(인덱스 32~39) — 33에서 아래로 이동은
	# 더 갈 행이 없어 그대로(마지막 행 유지, 같은 열).
	assert_eq(FocusCalcScript.grid_neighbor(33, 8, 40, Vector2i(0, 1)), 33)
	# 5칸만 채워진 마지막 행(41칸, 8열=6행에서 마지막 행이 1칸)이라면 열이 없는 칸으로
	# 넘어가지 않고 존재하는 마지막 인덱스로 clamp된다.
	assert_eq(FocusCalcScript.grid_neighbor(32, 8, 33, Vector2i(0, 1)), 32)


func test_grid_neighbor_empty_grid_returns_zero() -> void:
	assert_eq(FocusCalcScript.grid_neighbor(5, 8, 0, Vector2i(1, 0)), 0)


func test_grid_is_leftmost_col() -> void:
	assert_true(FocusCalcScript.grid_is_leftmost_col(0, 8))
	assert_true(FocusCalcScript.grid_is_leftmost_col(8, 8))
	assert_false(FocusCalcScript.grid_is_leftmost_col(1, 8))


func test_enter_indices_are_stable() -> void:
	assert_eq(FocusCalcScript.grid_enter_index_from_equip(), 0)
	assert_eq(FocusCalcScript.equip_enter_slot_from_grid(), "weapon")
