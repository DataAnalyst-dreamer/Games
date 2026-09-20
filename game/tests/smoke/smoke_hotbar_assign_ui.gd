## 헤드리스 스모크 테스트: 핫바 등록 UI(M4-2, D-181~D-183). stage/m4-1(로직)이 아직
## 미병합이라 project.godot에 hotbar_1~9 액션이 없다(D-182) — 그 상태에서 UI가 조용히
## 아무 것도 하지 않는지(has_action 가드) 먼저 확인하고, GameState.hotbar/Progression.
## assign_hotbar가 있다고 가정한 이후의 표시 반응은 Events.hotbar_changed를 직접
## emit해서 검증한다(지시서 "hotbar_changed 직접 emit" 그대로 — exp_changed/skills_changed
## 선례와 동일 패턴).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeHotbarAssignUi.tscn --quit-after 300
extends Node

var _main: Node
var _ui_root: UiRoot
var _skill_tab: SkillPanelTab
var _failures := 0


func _check(cond: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _ready() -> void:
	print("=== SMOKE HOTBAR ASSIGN UI: D-182 가드 + hotbar_changed 반영 ===")
	QuestSystem.reset()
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_ui_root = _main.get_node("UiRoot") as UiRoot

	# --- D-182: 이 브랜치엔 project.godot에 hotbar_1~9 액션이 없다(m4-1 미병합) ---
	for i in range(1, 10):
		_check(not InputMap.has_action("hotbar_%d" % i), "project.godot에 hotbar_%d 액션 없음(m4-1 소유, D-182)" % i)
	_check(HotbarRegisterInput.poll_pressed_slot() == -1, "액션이 없으니 poll_pressed_slot()은 항상 -1(has_action 가드)")
	_check(not HotbarRegisterInput.try_assign("skill", "blade_power_slash"), "액션 없으면 try_assign도 조용히 false")

	# --- Progression.assign_hotbar도 아직 없다(m4-1 미병합) -> has_method 가드 확인 ---
	_check(not Progression.has_method("assign_hotbar"), "Progression.assign_hotbar 아직 없음(m4-1 미병합, has_method 가드 전제)")

	# --- 스킬 패널 미리보기: Events.hotbar_changed 직접 emit -> HudHotbarBar 반응 ---
	_ui_root.open_menu()
	_ui_root.inventory_menu.select_tab("skill")
	_skill_tab = _ui_root.inventory_menu.skill_panel_tab
	Events.skills_changed.emit({"blade_power_slash": 1}, ["blade_power_slash", ""], 0) # M4-4: learned는 id->레벨
	_skill_tab._sub_tab_index = 1
	_skill_tab._skill_focus_index = _skill_tab._skill_ids.find("blade_power_slash")
	_skill_tab._refresh_skill_detail()

	var bar: HudHotbarBar = _skill_tab._hotbar_bar
	_check(bar != null, "SkillPanelTab에 HudHotbarBar 미리보기 부착됨")
	_check(_cell_color(bar, 2) != _focus_color(bar), "hotbar_changed 전에는 3번 칸이 강조색 아님")

	Events.hotbar_changed.emit([
		{"kind": "", "id": ""}, {"kind": "", "id": ""},
		{"kind": "skill", "id": "blade_power_slash"}, {"kind": "", "id": ""},
		{"kind": "", "id": ""}, {"kind": "", "id": ""},
		{"kind": "", "id": ""}, {"kind": "", "id": ""}, {"kind": "", "id": ""},
	])
	_check(bar._hotbar.size() == 9, "HudHotbarBar가 Events.hotbar_changed로 9칸 배열을 받음")
	_skill_tab._refresh_skill_detail() # 포커스 유지 상태로 미리보기 재계산.
	_check(_cell_color(bar, 2) == _focus_color(bar), "3번 칸(blade_power_slash 등록됨)이 강조색으로 표시")
	_check(_cell_color(bar, 0) != _focus_color(bar), "등록 안 된 칸(0번)은 강조색 아님")

	# --- 인벤토리 탭에도 동일 컴포넌트가 붙어 같은 신호에 반응하는지 ---
	_ui_root.inventory_menu.select_tab("inventory")
	var inv_bar: HudHotbarBar = _ui_root.inventory_menu._hotbar_bar
	_check(inv_bar != null and inv_bar != bar, "InventoryMenu에도 별도 HudHotbarBar 인스턴스 부착됨")
	_check(inv_bar._hotbar.size() == 9, "같은 Events.hotbar_changed를 InventoryMenu 쪽도 수신")

	print("SMOKE_HOTBAR_ASSIGN_UI_RESULT FAIL=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _cell_color(bar: HudHotbarBar, index: int) -> Color:
	return bar._cells[index].get_theme_color("font_color")


func _focus_color(bar: HudHotbarBar) -> Color:
	return bar.theme.get_color(&"focus", &"Inventory") if bar.theme != null else Color.YELLOW
