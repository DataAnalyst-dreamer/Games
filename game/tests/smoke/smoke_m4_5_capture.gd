## M4-5 육안 확인용 스크린샷 캡처(Xvfb, --headless 아님 — 렌더링이 실제로 필요).
## 출력: docs/art/preview/{stats-v2,skill-tree,hud-sp-bar}.png.
##
## 실행: xvfb-run -a godot --path game res://tests/smoke/SmokeM45Capture.tscn --quit-after 600
extends Node

var _out_dir: String
var _ui_root: UiRoot
var _menu: InventoryMenu
var _skill_tab: SkillPanelTab


func _ready() -> void:
	print("=== CAPTURE M4-5: 스탯v2 / 스킬트리 / HUD SP바 ===")
	_out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/art/preview").simplify_path()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)
	_ui_root = main.get_node("UiRoot") as UiRoot

	for i in range(4):
		await get_tree().process_frame

	# --- 스탯v2: 표시용 더미 stats/derived(D-195 13개 파생치 포맷 확인용) ---
	# SkillPanelTab/SkillTreeTab.open()이 GameState.stat_points/skill_points를 그 시점에
	# 캐시하므로(_load_initial_state/_load_state), 둘 다 메뉴를 열기 "전"에 세팅해야 한다
	# (emit 자체는 open() 뒤에 해야 하고 — open()이 stats_changed 리스너 등록 전 상태를
	# 덮어쓴다).
	GameState.stat_points = 3
	GameState.skill_points = 5
	_ui_root.open_menu()
	_menu = _ui_root.inventory_menu
	_menu.select_tab("skill")
	_skill_tab = _menu.skill_panel_tab
	_skill_tab._sub_tab_index = 0
	_skill_tab._refresh_sub_tab_bar()
	Events.stats_changed.emit(
		{"str": 12, "agi": 6, "dex": 4, "int": 8, "vit": 10, "luk": 2},
		{
			"atk": 32.4, "matk": 21.2, "def": 21.0, "mdef": 9.0, "max_hp": 150, "max_sp": 36,
			"sp_regen": 1.24, "crit_chance": 0.052, "hit_scale": 1.006, "flee_iframe_bonus": 0.006,
			"move_speed_mult": 1.009, "combo_frame_mult": 0.9832, "post_recovery_mult": 0.994,
		},
		3)
	await _capture("stats-v2.png")

	# --- 스킬트리: blade 계열, T1 하나 습득 상태로 습득/잠금 대비를 보여준다 ---
	_skill_tab._sub_tab_index = 1
	_skill_tab._refresh_sub_tab_bar()
	_skill_tab._skill_tree_tab._focus_index = 0
	_skill_tab._skill_tree_tab._confirm_learn()
	_skill_tab._skill_tree_tab._refresh_node_states()
	_skill_tab._skill_tree_tab._focus_index = 3 # blade_followup(T2, 아직 잠김) 포커스로 대비 강조.
	_skill_tab._skill_tree_tab._refresh_node_states()
	_skill_tab._skill_tree_tab._refresh_detail()
	await _capture("skill-tree.png")

	# --- HUD SP바: 메뉴 닫고 HP/스태미나/SP 채워서 확인 ---
	_ui_root.close_menu()
	var player: Player = GameState.get_player()
	if player != null and player.resources != null:
		Events.player_hp_changed.emit(player.resources.hp, player.resources.max_hp)
		Events.player_stamina_changed.emit(player.resources.stamina, player.resources.max_stamina)
	if Events.has_signal(&"sp_changed"):
		Events.sp_changed.emit(28.0, 40.0)
	else:
		print("[INFO] Events.sp_changed 아직 없음(m4-4 미병합) — SP바는 0/1(빈 바)로 캡처됨")
	await _capture("hud-sp-bar.png")

	print("=== CAPTURE M4-5 종료 ===")
	get_tree().quit(0)


func _capture(filename: String) -> void:
	for i in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(filename)
	var ok := pixels.save_png(path) == OK
	print("%s SAVE %s -> %s" % ["[PASS]" if ok else "[FAIL]", filename, path])
