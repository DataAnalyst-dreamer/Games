## 헤드리스(Xvfb) 스모크 테스트: 메뉴 마우스 입력(M5-1, 게이트5 피드백 "탭 이동에
## 여러 키를 쓰는 게 불편했다"). InputEventMouseButton을 각 컨트롤의
## get_global_rect().get_center() 좌표로 press/release 주입해(Input.parse_input_event)
## 실제 히트박스를 통해 탭 전환·노드 포커스/습득·스탯 분배·핫바 등록·닫기·퀘스트 선택을
## 확인한다.
##
## 순수 --headless로는 GUI 입력이 뷰포트까지 전달되지 않는다(사전 확인 완료) — 반드시
## Xvfb로 실행한다:
##   xvfb-run -a godot --path game res://tests/smoke/SmokeMenuMouse.tscn --quit-after 600
##
## 같은 실행에서 docs/art/preview/menu-mouse.png도 캡처한다(smoke_m4_5_capture.gd와
## 동일한 _capture() 패턴 — 마우스 클릭 자체가 Xvfb를 요구하므로 캡처를 별도 스모크로
## 나눌 필요가 없다).
extends Node

const BLADE_T1 := "blade_power_slash"
const MQ01 := "quest_main_a1_01_arrival"

var _main: Node
var _ui_root: UiRoot
var _menu: InventoryMenu
var _skill_tab: SkillPanelTab
var _tree_tab: SkillTreeTab
var _quest_tab: QuestLogTab
var _out_dir: String
var _failures := 0


func _check(cond: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


## 좌표 기반 클릭 — 실제 히트박스를 통과해야 하므로 press/release를
## Input.parse_input_event()로 각각 흘리고 프레임을 기다린다(사전 확인: 이 경로는
## Xvfb에서만 뷰포트까지 전달된다). 직전 동작(탭 전환 등)이 트리를 다시 그렸을 수
## 있어, 좌표를 읽기 전에 먼저 프레임을 흘려보내 레이아웃이 자리 잡을 시간을 준다.
##
## `Input.parse_input_event()`가 받는 좌표는 OS 창(window/size/window_width_override=
## 1920×1080) 픽셀 기준이지만 `Control.get_global_rect()`는 캔버스(내부 해상도
## 640×360, window/stretch/mode=canvas_items) 기준이라 그대로 넣으면 엉뚱한 곳을
## 클릭한 것으로 처리된다(사전 확인 — 별도 최소 재현 프로젝트로 검증) — 실제 창 픽셀
## 크기 / 캔버스 크기 비율을 곱해 변환한다.
func _click(control: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var canvas_center: Vector2 = control.get_global_rect().get_center()
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	var window_pos: Vector2 = canvas_center * scale
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = window_pos
	down.global_position = window_pos
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = window_pos
	up.global_position = window_pos
	Input.parse_input_event(up)
	await get_tree().process_frame


func _ready() -> void:
	print("=== SMOKE MENU MOUSE: 탭 전환/노드 포커스·습득/스탯 분배/핫바 등록/닫기(좌표 클릭) ===")
	_out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/art/preview").simplify_path()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	QuestSystem.reset()
	QuestSystem.accept(MQ01)

	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_ui_root = _main.get_node("UiRoot") as UiRoot

	GameState.stat_points = 3
	GameState.skill_points = 5
	var potion_def: Dictionary = Data.get_value("items", "potion_hp_small", {})
	GameState.pickup_item({
		"uid": "smoke_mouse_potion", "item_id": "potion_hp_small", "grade": "common",
		"quantity": 3, "affixes": [], "enhance_level": 0, "refine_left": 0,
	}, potion_def)

	for i in range(3):
		await get_tree().process_frame

	_ui_root.open_menu()
	_menu = _ui_root.inventory_menu
	_skill_tab = _menu.skill_panel_tab
	_tree_tab = _skill_tab._skill_tree_tab

	# --- 1) 상단 탭 클릭: inventory -> skill ---
	await _click(_menu._tab_buttons["skill"])
	_check(InventoryMenu.TABS[_menu._tab_index] == "skill", "상단 탭 클릭으로 skill 탭 전환")

	# --- 2) 스킬 패널 서브탭 클릭: 스탯 -> 스킬 ---
	await _click(_skill_tab._sub_tab_buttons["skill"])
	_check(_skill_tab._sub_tab_index == 1, "스킬 서브탭 클릭으로 전환")

	# --- 3) 계열 탭 클릭: blade -> guard -> blade(핫바/노드 확인은 blade 기준) ---
	await _click(_tree_tab._series_buttons["guard"])
	_check(_tree_tab._current_series() == "guard", "계열 탭 클릭으로 guard 전환")
	await _click(_tree_tab._series_buttons["blade"])
	_check(_tree_tab._current_series() == "blade", "계열 탭 클릭으로 blade 복귀")

	# --- 4) 노드 클릭 = 포커스 이동(확정 아님) ---
	# blade_power_slash(T1)는 계열 리셋 직후 기본 포커스(_focus_index=0)라 그걸 바로
	# 클릭하면 "이미 포커스된 노드 클릭"이 돼버려 확정까지 함께 검증되므로, 먼저 다른
	# 노드를 클릭해 포커스를 옮겨둔 뒤 blade_power_slash를 클릭해야 "포커스만 이동"을
	# 제대로 확인할 수 있다.
	var other_id: String = _tree_tab._focus_ids[1]
	await _click(_tree_tab._node_labels.get(other_id))
	_check(_tree_tab._focused_id() == other_id, "다른 노드 클릭으로 포커스를 옮겨둠(사전 준비)")

	var node_btn: Button = _tree_tab._node_labels.get(BLADE_T1)
	await _click(node_btn)
	_check(_tree_tab._focused_id() == BLADE_T1, "노드 클릭으로 포커스 이동(아직 미습득)")
	_check(int(_tree_tab._learned.get(BLADE_T1, 0)) == 0, "포커스만 이동 — 클릭 한 번으로는 습득되지 않음")

	# --- 5) 포커스된 노드를 다시 클릭 = 확정(습득) ---
	await _click(node_btn)
	_check(int(_tree_tab._learned.get(BLADE_T1, 0)) >= 1, "포커스된 노드 재클릭으로 습득 확정")

	await _capture("menu-mouse.png") # 스킬트리(노드 Button) + 핫바 미리보기 + 닫기 버튼이 보이는 상태.

	# --- 6) 핫바 미리보기 칸 클릭(스킬) — 3번 슬롯 ---
	var skill_hotbar: HudHotbarBar = _tree_tab._hotbar_bar
	await _click(skill_hotbar._cells[2])
	_check(String(GameState.hotbar[2].get("id", "")) == BLADE_T1, "스킬 핫바 미리보기 칸 클릭으로 3번 슬롯 등록")

	# --- 7) 스탯 서브탭 복귀, "+" 버튼 클릭 = 배분 ---
	await _click(_skill_tab._sub_tab_buttons["stat"])
	_check(_skill_tab._sub_tab_index == 0, "스탯 서브탭 클릭으로 복귀")
	var points_before: int = GameState.stat_points
	var plus_button: Button = (_skill_tab._stat_rows[0]["row"] as HBoxContainer).get_child(2) as Button
	await _click(plus_button)
	_check(GameState.stat_points == points_before - 1, "스탯 \"+\" 버튼 클릭으로 배분(포인트 1 소모)")

	# --- 8) 상단 탭 클릭으로 inventory 복귀, 격자 칸 클릭 = 포커스 ---
	await _click(_menu._tab_buttons["inventory"])
	_check(InventoryMenu.TABS[_menu._tab_index] == "inventory", "상단 탭 클릭으로 inventory 탭 복귀")
	await _click(_menu._grid_cells[0])
	_check(_menu._focus_area == "grid" and _menu._focus_grid_index == 0, "격자 칸 클릭으로 포커스 이동")

	# --- 9) 인벤토리 핫바 미리보기 칸 클릭(아이템) — 5번 슬롯 ---
	var item_hotbar: HudHotbarBar = _menu._hotbar_bar
	await _click(item_hotbar._cells[4])
	_check(String(GameState.hotbar[4].get("id", "")) == "potion_hp_small", "아이템 핫바 미리보기 칸 클릭으로 5번 슬롯 등록")

	# --- 10) 퀘스트 탭: 상단 탭 클릭 -> 서브탭 클릭 -> 목록 항목 클릭(선택) ---
	await _click(_menu._tab_buttons["quest"])
	_check(InventoryMenu.TABS[_menu._tab_index] == "quest", "상단 탭 클릭으로 quest 탭 전환")
	_quest_tab = _menu.quest_log_tab
	await _click(_quest_tab._sub_tab_buttons["main"])
	_check(QuestLogUiCalc.TABS[_quest_tab._tab_index] == "main", "퀘스트 서브탭 클릭으로 main 탭 유지/전환")
	_check(_quest_tab._list_labels.size() > 0, "메인 탭에 목록 항목 있음(MQ01 accept 완료)")
	if _quest_tab._list_labels.size() > 0:
		await _click(_quest_tab._list_labels[0])
		_check(_quest_tab._focus_index == 0, "목록 항목 클릭으로 선택(포커스 이동)")

	# --- 11) 닫기 버튼 클릭 ---
	await _click(_menu.close_button)
	_check(not _ui_root.is_menu_open(), "닫기 버튼 클릭으로 메뉴 닫힘")

	print("SMOKE_MENU_MOUSE_RESULT FAIL=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _capture(filename: String) -> void:
	for i in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(filename)
	var ok := pixels.save_png(path) == OK
	print("%s SAVE %s -> %s" % ["[PASS]" if ok else "[FAIL]", filename, path])
	if not ok:
		_failures += 1
