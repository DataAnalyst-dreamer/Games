## M4-3 육안 확인용 스크린샷 캡처 — GUT/스모크 통과 여부와 무관하게 6종 vfx.kind가
## 발동 프레임에 실제로 어떻게 보이는지 PNG로 남긴다(Xvfb, --headless 아님 — 렌더링이
## 실제로 필요). 출력: docs/art/preview/skill-vfx/{kind}.png.
##
## 실행: xvfb-run -a godot --path game res://tests/smoke/SmokeSkillVfxCapture.tscn --quit-after 600
extends Node

const KINDS := ["slash_arc", "thrust_line", "ring", "glow", "dash_trail", "speed_lines"]

var _player: Player
var _out_dir: String


func _ready() -> void:
	print("=== CAPTURE SKILL VFX: kind별 발동 프레임 스크린샷 ===")
	# Xvfb+소프트웨어 렌더러(llvmpipe)는 프레임 하나가 실측 수백ms까지 걸릴 수 있어,
	# 0.1~0.2초짜리 이펙트 수명을 "절반 지점"에서 정확히 잡아내기엔 프레임 해상도가
	# 너무 거칠다(실측: 목표 지점보다 훨씬 앞서 이미 완전히 소멸한 채로 캡처됨).
	# 게임 시간을 10배 늦춰(SceneTreeTimer/Tween 모두 idle 프로세스 delta 기반이라
	# time_scale에 비례해 같이 늘어난다) 같은 비율(lifetime*0.5)을 렌더러가 소화할 수
	# 있는 실제 프레임 수 안에서 잡히게 한다 — 실제 게임 코드/수치는 전혀 건드리지 않음.
	Engine.time_scale = 0.1
	# game/ 프로젝트 루트 기준 상위(docs/art/preview/skill-vfx) — res://../ 상대 경로는
	# 플랫폼별로 신뢰성이 낮아 절대 경로로 직접 계산한다.
	_out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/art/preview/skill-vfx").simplify_path()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)

	_player = main.get_node("Player") as Player
	for child in main.get_children():
		if child is MonsterBase:
			child.set_physics_process(false)
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.play_anim("idle")

	for i in range(4):
		await get_tree().process_frame

	for kind: String in KINDS:
		await _capture(kind)

	print("=== CAPTURE SKILL VFX 종료 ===")
	get_tree().quit(0)


## 각 kind의 성장(grow) tween이 어느 정도 진행된 "발동 중" 프레임에서 캡처한다
## (0=생성 직후, 1=수명 종료). 0.5 지점이 대부분 kind에서 형태+색이 가장 잘 읽힌다.
func _capture(kind: String) -> void:
	SkillVfx.spawn(kind, _player, Color("#66ccff"), 44.0)
	var lifetime: float = SkillVfx.RING_LIFETIME_SEC if kind == "ring" else SkillVfx.DEFAULT_LIFETIME_SEC
	await get_tree().create_timer(lifetime * 0.5).timeout
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("%s.png" % kind)
	var ok := pixels.save_png(path) == OK
	print("%s SAVE %s -> %s" % ["[PASS]" if ok else "[FAIL]", kind, path])
	await get_tree().create_timer(lifetime * 0.6).timeout # 다음 kind 캡처 전에 잔상 정리.
