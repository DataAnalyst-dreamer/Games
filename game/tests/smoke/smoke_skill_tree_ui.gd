## 헤드리스 스모크 테스트: 스킬 트리 v2(M4-5, D-161/D-194/D-195) — 24노드 실데이터 렌더,
## tier 배치, 잠금 표시, 습득 후 갱신, 핫바 SP 회색 가드까지 확인한다.
##
## 실행: godot --headless --path game res://tests/smoke/SmokeSkillTreeUi.tscn --quit-after 300
##
## `Progression.can_learn_skill/get_skill_level/next_stat_cost`, `Events.sp_changed`
## (stage/m4-4, 병합 전엔 없음)는 has_method/has_signal로 갈라 두 경로 모두 크래시 없이
## 확인한다(D-165 관례) — 병합 전엔 SkillTreeCalc 로컬 계산 경로, 병합 후엔 Progression
## 위임 경로가 그대로 통과해야 한다.
extends Node

var _main: Node
var _ui_root: UiRoot
var _menu: InventoryMenu
var _skill_tab: SkillPanelTab
var _tree_tab: SkillTreeTab
var _hud_slots: HudSkillSlots

var _failures := 0


func _check(cond: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _ready() -> void:
	print("=== SMOKE SKILL TREE UI: 24노드 실데이터 렌더 + 잠금 + 습득 갱신 ===")
	GameState.skill_points = 5 # SkillTreeCalc 로컬 폴백 경로가 "포인트 부족"이 아니게.

	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_ui_root = _main.get_node("UiRoot") as UiRoot
	_hud_slots = _main.get_node("UiRoot/Hud/Root/HudSkillSlots") as HudSkillSlots

	_ui_root.open_menu()
	_menu = _ui_root.inventory_menu
	_menu.select_tab("skill")
	_skill_tab = _menu.skill_panel_tab
	_skill_tab._sub_tab_index = 1 # 스킬 서브탭으로 전환.
	_skill_tab._refresh_sub_tab_bar()
	_tree_tab = _skill_tab._skill_tree_tab
	_check(_tree_tab.visible, "스킬 서브탭 전환 시 SkillTreeTab visible")

	# --- 렌더: blade 계열 8노드(T1 3 / T2 3 / T3 2) ---
	var skills_table: Dictionary = Data.table("skills")
	_check(SkillTreeCalc.skill_ids(skills_table).size() == 24, "skills.json 실데이터 24노드")
	_check(_tree_tab._focus_ids.size() == 8, "blade 계열 8노드 포커스 목록(actual=%d)" % _tree_tab._focus_ids.size())
	var by_tier: Dictionary = SkillTreeCalc.nodes_by_tier("blade", skills_table)
	_check((by_tier[1] as Array).size() == 3 and (by_tier[2] as Array).size() == 3 and (by_tier[3] as Array).size() == 2,
		"tier 배치 3/3/2(actual=%d/%d/%d)" % [(by_tier[1] as Array).size(), (by_tier[2] as Array).size(), (by_tier[3] as Array).size()])
	_check(SkillTreeCalc.node_tier("blade_finishing_strike", skills_table) == 3, "궁극기 tier 계산=3(requires 2개 체인)")

	# --- 계열 전환: ui_filter_next 액션으로 blade -> guard ---
	_check(_tree_tab._current_series() == "blade", "초기 계열 blade")
	_tree_tab._change_series(1)
	_check(_tree_tab._current_series() == "guard", "계열 전환 후 guard")
	_tree_tab._change_series(-1)
	_check(_tree_tab._current_series() == "blade", "계열 되돌리기 blade")

	# --- 잠금 표시: T1(요구 없음) learnable, T2(요구 미충족) locked/requires ---
	_tree_tab._focus_index = 0
	var t1_state: Dictionary = _tree_tab._node_state("blade_power_slash")
	_check(String(t1_state.get("state", "")) == "learnable", "T1 노드 초기 learnable(포인트 5)")
	var t2_state: Dictionary = _tree_tab._node_state("blade_followup")
	_check(String(t2_state.get("state", "")) == "locked" and String(t2_state.get("reason", "")) == "requires",
		"T2 노드 선행 미충족 locked/requires")

	# --- 습득 후 갱신: 확인으로 blade_power_slash 1레벨 습득 ---
	_tree_tab._confirm_learn()
	_tree_tab._refresh_node_states()
	_check(int(_tree_tab._learned.get("blade_power_slash", 0)) >= 1, "확인 입력으로 blade_power_slash 습득(레벨>=1)")
	var label: Button = _tree_tab._node_labels.get("blade_power_slash") # M5-1: Label→Button.
	_check(label != null and label.text.contains("1/5"), "노드 라벨이 Lv.1/5로 갱신: '%s'" % (label.text if label != null else "<null>"))
	var t2_state_after: Dictionary = _tree_tab._node_state("blade_followup")
	_check(String(t2_state_after.get("state", "")) == "locked", "Lv.1로는 아직 T2(요구 Lv.3) 잠김 유지")

	# --- 핫바 SP 회색: sp_changed 신호 유무에 따라 두 경로 모두 크래시 없이 통과 ---
	Progression.assign_hotbar(0, "skill", "blade_power_slash")
	_check(_hud_slots._panels[0].modulate == Color.WHITE, "sp_changed 수신 전엔 회색 판정 보류(흰색 유지)")
	if Events.has_signal(&"sp_changed"):
		Events.sp_changed.emit(0.0, 50.0)
		_check(_hud_slots._panels[0].modulate != Color.WHITE, "sp_changed(0/50) 수신 후 SP 부족 회색")
	else:
		print("[PASS] Events.sp_changed 아직 없음(m4-4 미병합) — has_signal 가드 확인")

	print("SMOKE_SKILL_TREE_UI_RESULT FAIL=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
