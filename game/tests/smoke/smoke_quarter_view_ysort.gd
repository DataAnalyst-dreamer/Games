## 헤드리스 스모크: 쿼터뷰 단계 (a)의 그리기 순서 규칙 (D-199/D-204).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeQuarterViewYSort.tscn --quit-after 240
##
## 실제 Main.tscn을 띄워 확인하는 것:
##  1) Y-sort 배선 — Main이 y_sort, World가 z_index=-1(지면은 항상 최하단),
##     HartlandQuestLayer가 y_sort(런타임 스폰물도 Main 정렬에 참여).
##  2) 정렬 참여 여부 — Main의 모든 CanvasItem 자식이 "Y-sort로 정렬될 액터"이거나
##     "명시적 z_index로 층이 고정된 배경"이어야 한다. 새 노드를 Main에 추가하면서
##     이 구분을 빠뜨리면 여기서 걸린다.
##  3) 회귀 표면 — HUD(CanvasLayer)는 y_sort의 영향 밖, 데미지 숫자는 z_index=100으로
##     항상 위, 아이템 드랍은 Main의 자식으로 스폰돼 정렬에 참여.
##  4) 정렬 결과 — 플레이어를 몬스터의 위/아래로 옮겼을 때 Y-sort 기준값(global
##     position.y)의 대소가 실제로 뒤집히는지. 앞/뒤 가림의 육안 증거는
##     docs/art/preview/quarter-view-a-{above,below}.png 캡처가 담당한다.
##
## 좌표·데이터·애셋은 이 단계에서 바꾸지 않았으므로(D-199), 기존 스모크가 전부
## 그대로 통과해야 한다 — 실패하면 Y-sort가 무언가를 가린 것이다.
extends Node

var _ok: bool = true


func _fail(message: String) -> void:
	_ok = false
	print("  [FAIL] %s" % message)


func _ready() -> void:
	print("=== SMOKE: 쿼터뷰 Y-sort 그리기 순서 (D-199/D-204) ===")
	var main: Node2D = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_check_wiring(main)
	_check_layering(main)
	_check_regression_surface(main)
	await _check_sort_flips(main)

	if _ok:
		print("[PASS] Y-sort 배선·층 분리·정렬 뒤집힘 모두 기대대로")
	else:
		print("[FAIL] 쿼터뷰 그리기 순서 규칙 위반")
	print("=== SMOKE 종료 ===")
	get_tree().quit(0 if _ok else 1)


## 1) Y-sort 배선.
func _check_wiring(main: Node2D) -> void:
	print("-- 1. Y-sort 배선 --")
	if not main.is_y_sort_enabled():
		_fail("Main.y_sort_enabled 가 꺼져 있다 - 액터가 트리 순서로 그려진다")
	var world: Node2D = main.get_node_or_null("World") as Node2D
	if world == null:
		_fail("World 노드를 찾지 못했다")
	elif world.z_index > -2:
		# World 서브트리는 통째로 World.position.y(=0) 한 점에 정렬되므로, z_index로
		# 최하단에 고정하지 않으면 y<0 에 선 액터가 지면 뒤로 숨는다.
		# -2 인 이유: z_index -1 은 "지면 위 · 액터 아래" 층으로 비워 둔다. 구르기 잔상
		# (RollGhost.spawn: z_index = 플레이어 스프라이트 - 1 = -1)이 Main 의 자식으로
		# 스폰되므로, World 가 -1 이면 잔상이 지면과 같은 층에서 Y 로 경쟁해 플레이어가
		# y<0 에 있을 때만 지면 뒤로 사라진다.
		_fail("World.z_index=%d - 지면은 -2 이하여야 한다(-1은 잔상 층으로 예약)" % world.z_index)
	var quest_layer: Node2D = main.get_node_or_null("HartlandQuestLayer") as Node2D
	if quest_layer == null:
		_fail("HartlandQuestLayer 를 찾지 못했다")
	elif not quest_layer.is_y_sort_enabled():
		_fail("HartlandQuestLayer.y_sort_enabled 가 꺼져 있다 - 스폰된 비석/NPC가 한 덩어리로 정렬된다")
	else:
		print("  Main y_sort=%s, World z_index=%d, QuestLayer y_sort=%s, 스폰 수=%d" \
			% [main.is_y_sort_enabled(), world.z_index, quest_layer.is_y_sort_enabled(),
				quest_layer.get_children().size()])


## 2) Main 의 CanvasItem 자식 중 z_index 가 0 이 아닌 것은 World(지면, -2) 하나뿐이어야
## 한다. z_index 는 Y-sort 보다 우선하므로, 액터 노드에 z_index 가 붙는 순간 그 액터는
## 거리와 무관하게 항상 앞이나 뒤에 그려진다 - 쿼터뷰 가림이 그 노드에서만 깨진다.
func _check_layering(main: Node2D) -> void:
	print("-- 2. z_index 층 분리 --")
	var layered: Dictionary = {}
	for child: Node in main.get_children():
		if child is CanvasLayer:
			continue # 화면 고정 UI - 월드 Y-sort 영향 밖.
		var item := child as CanvasItem
		if item != null and item.z_index != 0:
			layered[String(item.name)] = item.z_index
	print("  z_index != 0 인 Main 자식: %s" % layered)
	if layered != {"World": -2}:
		_fail("지면(World=-2) 외에 z_index 가 붙은 자식이 있다 - 그 노드는 Y-sort 가림을 무시한다")


## 3) y_sort 도입으로 깨질 수 있는 지점들.
func _check_regression_surface(main: Node2D) -> void:
	print("-- 3. 회귀 표면 (HUD/데미지 숫자/아이템 드랍) --")
	var ui_root: Node = main.get_node_or_null("UiRoot")
	if ui_root == null or not (ui_root is CanvasLayer):
		_fail("UiRoot 가 CanvasLayer 가 아니다 - HUD가 월드 Y-sort에 휘말린다")
	# 데미지 숫자는 어떤 액터보다도 위에 떠야 한다.
	var number: Node2D = load("res://scenes/effects/DamageNumber.tscn").instantiate() as Node2D
	if number == null or number.z_index <= 0:
		_fail("DamageNumber 의 z_index 가 0 이하 - 액터에 가려진다")
	if number != null:
		number.free()
	# 아이템 드랍이 Main의 자식으로 스폰되는지(= 정렬에 참여하는지).
	var spawner: Node = main.get_node_or_null("LootSpawner")
	if spawner == null:
		_fail("LootSpawner 를 찾지 못했다")
	elif spawner.get_parent() != main:
		_fail("LootSpawner 의 부모가 Main 이 아니다 - 드랍이 Y-sort 밖으로 스폰된다")
	else:
		print("  UiRoot=CanvasLayer, DamageNumber z_index>0, 드랍 부모=Main 확인")
	# 구르기 잔상은 Main 의 자식으로 z_index=-1 에 스폰된다 - 지면(World)보다는 위,
	# 액터(z_index=0)보다는 아래여야 한다.
	var world: Node2D = main.get_node_or_null("World") as Node2D
	var player: Player = main.get_node_or_null("Player") as Player
	if world != null and player != null:
		var ghost_z: int = player.sprite.z_index - 1
		if not (world.z_index < ghost_z and ghost_z < player.z_index):
			_fail("잔상 층(z=%d)이 지면(z=%d)과 액터(z=%d) 사이에 있지 않다" \
				% [ghost_z, world.z_index, player.z_index])
		else:
			print("  잔상 층 z=%d: 지면 z=%d < 잔상 < 액터 z=%d 확인" \
				% [ghost_z, world.z_index, player.z_index])


## 4) 플레이어를 몬스터 위/아래로 옮겼을 때 Y-sort 기준값이 실제로 뒤집히는가.
func _check_sort_flips(main: Node2D) -> void:
	print("-- 4. 위/아래 정렬 뒤집힘 --")
	var player: Player = main.get_node_or_null("Player") as Player
	var monster: Node2D = main.get_node_or_null("Slime1") as Node2D
	if player == null or monster == null:
		_fail("Player 또는 Slime1 을 찾지 못했다")
		return
	for case: Dictionary in [
		{"name": "몬스터가 플레이어보다 뒤(위쪽)", "offset": -24.0, "player_in_front": true},
		{"name": "몬스터가 플레이어보다 앞(아래쪽)", "offset": 24.0, "player_in_front": false},
	]:
		player.global_position = monster.global_position + Vector2(0, -float(case.offset))
		await get_tree().process_frame
		var player_in_front: bool = player.global_position.y > monster.global_position.y
		print("  %s: player.y=%.1f, monster.y=%.1f -> 플레이어가 앞=%s" \
			% [case.name, player.global_position.y, monster.global_position.y, player_in_front])
		if player_in_front != bool(case.player_in_front):
			_fail("%s 에서 정렬 기준이 기대와 반대" % case.name)
