## 헤드리스 스모크 테스트: 스탯 분배 패널(v2, 6스탯) + HUD 스킬 쿨타임(M4-5).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeStatsSkillsUi.tscn --quit-after 300
##
## 스킬 트리(계열×tier, 24노드) 자체의 검증은 `smoke_skill_tree_ui.gd`가 전담한다 — 이
## 스모크는 v1 시절부터 있던 스탯 탭 + HUD 슬롯 쿨타임 오버레이 회귀만 계속 지킨다.
## 로직 브랜치(stage/m4-4)의 Progression.allocate_stat 등이 아직 병합 전이라
## Events.stats_changed/hotbar_changed/skill_cast/skill_ready를 이 스모크가 직접 emit해
## UI만 독립적으로 검증한다.
extends Node

var _main: Node
var _ui_root: UiRoot
var _menu: InventoryMenu
var _skill_tab: SkillPanelTab
var _hud_slots: HudSkillSlots

var _failures := 0


func _check(cond: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _ready() -> void:
	print("=== SMOKE STATS/SKILLS UI: 스탯 탭(v2, 6스탯) + HUD 슬롯 쿨타임 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_ui_root = _main.get_node("UiRoot") as UiRoot
	_hud_slots = _main.get_node("UiRoot/Hud/Root/HudSkillSlots") as HudSkillSlots

	_ui_root.open_menu()
	_menu = _ui_root.inventory_menu
	_menu.select_tab("skill")
	_skill_tab = _menu.skill_panel_tab
	_check(_skill_tab.visible, "skill 탭 전환 시 SkillPanelTab visible")
	_check(_skill_tab._stat_rows.size() == 6, "스탯 행 6개(D-158 AGI 신설, actual=%d)" % _skill_tab._stat_rows.size())

	# --- 스탯 탭: Events.stats_changed 직접 emit(v2 6스탯 + D-195 파생치 키) ---
	Events.stats_changed.emit(
		{"str": 5, "agi": 0, "dex": 0, "int": 0, "vit": 3, "luk": 0},
		{"atk": 33.0, "max_hp": 115.0, "def": 11.0, "crit_chance": 0.053},
		2)
	print("Events.stats_changed 발신")
	_skill_tab._refresh_stat_body()
	_check(_skill_tab._points_header.text.contains("2"), "잔여 포인트 헤더에 2 반영: '%s'" % _skill_tab._points_header.text)
	var str_row: Dictionary = _skill_tab._stat_rows[0]
	_check((str_row["value"] as Label).text == "5", "STR 행 값이 5로 갱신")
	var vit_row: Dictionary = _skill_tab._stat_rows[4] # str/agi/dex/int/vit/luk 순서 4번째=vit.
	_check(not (vit_row["preview"] as Label).text.is_empty(), "VIT 행 미리보기(효과 설명+HP/방어)가 비어있지 않음: '%s'" % (vit_row["preview"] as Label).text)
	_check(_skill_tab._derived_footer.text.contains("11.0"), "파생치 푸터에 def=11.0 반영: '%s'" % _skill_tab._derived_footer.text)
	_check(not _skill_tab._derived_footer.text.contains(tr(&"ui.stat.derived.max_sp")),
		"get_derived()에 없는 키(max_sp)는 푸터에서 숨겨짐(원시값 덤프 금지, D-195): '%s'" % _skill_tab._derived_footer.text)

	# --- 핫바 탭: Events.hotbar_changed 직접 emit(M4-1, D-175~D-177) ---
	Events.hotbar_changed.emit([{"kind": "skill", "id": "blade_power_slash"}, {"kind": "", "id": ""}])
	print("Events.hotbar_changed 발신")
	_check(_hud_slots._icon_labels[0].text == "B", "HUD HotbarSlot1 아이콘이 계열 첫 글자 'B'로 대체(icon:null 대체 규칙)")
	_check(_hud_slots._icon_labels[1].text == "", "HUD HotbarSlot2는 미장착이라 빈 아이콘")

	# --- HUD 쿨타임 오버레이: skill_cast -> 진행 중 -> skill_ready로 조기 해제 ---
	Events.skill_cast.emit(0, &"blade_power_slash", 4.0)
	print("Events.skill_cast(0, blade_power_slash, 4.0) 발신")
	_check(is_equal_approx(_hud_slots._overlays[0].anchor_top, 0.0), "시전 직후 오버레이가 슬롯 전체를 덮음(anchor_top=0)")
	for i in range(6): await get_tree().process_frame
	var mid_anchor: float = _hud_slots._overlays[0].anchor_top
	_check(mid_anchor > 0.0 and mid_anchor < 1.0, "몇 프레임 후 쿨타임 진행 중(0<anchor_top<1, actual=%.3f)" % mid_anchor)
	Events.skill_ready.emit(0)
	_check(is_equal_approx(_hud_slots._overlays[0].anchor_top, 1.0), "skill_ready로 즉시 해제(anchor_top=1)")

	print("SMOKE_STATS_SKILLS_UI_RESULT FAIL=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
