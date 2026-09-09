## 히트스톱 유틸리티. `Engine.time_scale`(전역)을 건드리지 않고, 타격에 관여한
## 노드만 개별적으로 일시정지한다(F2-2: "양측" 히트스톱).
##
## 구현: 대상 노드의 process_mode를 PROCESS_MODE_DISABLED로 바꾸면 _process/
## _physics_process는 물론 자식(스프라이트 애니메이션 포함)까지 함께 멈춘다.
## 이후 SceneTreeTimer(트리 전체가 아니라 이 노드만 멈췄으므로 정상 진행)로 원래
## process_mode를 복원한다.
class_name Hitstop
extends RefCounted


## nodes에 담긴 노드들을 duration_sec 동안 개별 정지시킨다. 접근성 배율(0=off)은
## 호출부에서 duration_sec에 미리 곱해 전달한다(0 이하면 아무 것도 하지 않는다).
static func apply_to(nodes: Array, duration_sec: float) -> void:
	if duration_sec <= 0.0:
		return
	var valid_nodes: Array[Node] = []
	var previous_modes: Array[int] = []
	for n in nodes:
		if n is Node and is_instance_valid(n):
			valid_nodes.append(n)
			previous_modes.append((n as Node).process_mode)
	if valid_nodes.is_empty():
		return
	# 히트박스/허트박스의 area_entered는 물리 콜백 도중 발생한다. CollisionObject2D
	# 계열 노드(CharacterBody2D 등)의 process_mode를 그 안에서 즉시 바꾸면 "Disabling a
	# CollisionObject node during a physics callback" 오류와 함께 충돌 형태가 깨질 수
	# 있어(다음 히트가 통째로 무시되는 원인이었다) set_deferred로 프레임 끝에 적용한다.
	for n in valid_nodes:
		n.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	# 정지시킨 노드가 아니라 트리 루트를 기준으로 타이머를 걸어야 타이머 자체가
	# 멈추지 않는다.
	var tree := (valid_nodes[0] as Node).get_tree()
	if tree == null:
		# 트리에 없으면(테스트 등) 즉시 복원.
		for i in valid_nodes.size():
			valid_nodes[i].set_deferred("process_mode", previous_modes[i])
		return
	var timer := tree.create_timer(duration_sec)
	timer.timeout.connect(func() -> void:
		for i in valid_nodes.size():
			if is_instance_valid(valid_nodes[i]):
				valid_nodes[i].set_deferred("process_mode", previous_modes[i])
	)
