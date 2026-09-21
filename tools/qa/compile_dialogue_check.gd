# 1막 하틀랜드 giver 잡담 `.dialogue` 원고를 Dialogue Manager 컴파일러(DMCompiler)에
# 직접 통과시켜 문법 오류 0건을 확인한다(⑪-2, D-251/D-253). validate_dialogue.py는
# 정규식 기반 경량 검사라 실제 문법(중첩 조건 등)까지는 못 보므로 이 스크립트가
# 그 역할을 전담한다. waypoint-import-check.gd 관례를 그대로 따른다: extends
# SceneTree, _initialize()에서 call_deferred("run"), 결과에 따라 quit(0|1).
#
# 실행(res:// 밖 경로라 -s 상대경로 대신 --script 절대경로를 쓴다):
#   <godot> --headless --path game --script <repo>/tools/qa/compile_dialogue_check.gd
extends SceneTree

const DIALOGUE_DIR := "res://dialogue/"
const EXCLUDE_FILENAMES := ["_smoke_test.dialogue"]  # 워크스트림 A 소유(런타임 UI 스모크용)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var dir := DirAccess.open(DIALOGUE_DIR)
	if dir == null:
		print("[compile_dialogue_check] cannot open ", DIALOGUE_DIR)
		quit(1)
		return

	var paths: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".dialogue") and name not in EXCLUDE_FILENAMES:
			paths.append(DIALOGUE_DIR + name)
		name = dir.get_next()
	dir.list_dir_end()
	paths.sort()

	if paths.is_empty():
		print("[compile_dialogue_check] no .dialogue files found in ", DIALOGUE_DIR)
		quit(1)
		return

	var total_errors := 0
	for path in paths:
		var text := FileAccess.get_file_as_string(path)
		var result: DMCompilerResult = DMCompiler.compile_string(text, path)
		if result.errors.is_empty():
			print("[PASS] ", path, " (titles=", result.titles.size(), ")")
		else:
			total_errors += result.errors.size()
			for err in result.errors:
				var message: String = DMConstants.get_error_message(err.error)
				print("[FAIL] ", path, ":", int(err.line_number) + 1, " col=", err.column_number,
					" — ", message, " (code=", err.error, ")")

	print("COMPILE_DIALOGUE_CHECK_RESULT files=", paths.size(), " errors=", total_errors)
	quit(0 if total_errors == 0 else 1)
