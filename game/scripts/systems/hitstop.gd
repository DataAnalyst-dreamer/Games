## 히트스톱 유틸리티. `Engine.time_scale`(전역)을 건드리지 않고, 타격에 관여한
## 노드만 개별적으로 일시정지한다(F2-2: "양측" 히트스톱).
##
## 구현: 대상 노드의 process_mode를 PROCESS_MODE_DISABLED로 바꾸면 _process/
## _physics_process는 물론 자식(스프라이트 애니메이션 포함)까지 함께 멈춘다.
## 이후 SceneTreeTimer(트리 전체가 아니라 이 노드만 멈췄으므로 정상 진행)로 원래
## process_mode를 복원한다.
##
## D-129(2차 재테스트 "흰색으로 굳은 채 사라지지 않는 적"): 같은 노드에 히트스톱이
## 겹쳐 걸릴 수 있다 — 플레이어의 공격이 몬스터를 때리는 순간 몬스터의 접촉 공격도
## 플레이어를 때리면(트레이드), 몬스터는 "피격자"로 한 번, "공격자"로 또 한 번 정지
## 대상이 된다. 예전 구현은 호출마다 "지금의 process_mode"를 원래 값으로 기억했기
## 때문에, 두 번째 호출이 이미 DISABLED인 상태를 원래 값으로 기억해 복원 시 그대로
## DISABLED로 되돌려 영원히 멈췄다(피격 플래시 tween도 함께 멈춰 흰색으로 굳음).
## 지금은 노드 메타에 "히트스톱 이전의 진짜 process_mode"와 세대 번호를 두어,
## 겹쳐 걸려도 원래 값은 첫 호출 것만 유지하고 가장 마지막 히트스톱이 끝날 때 한 번만
## 복원한다.
class_name Hitstop
extends RefCounted

const META_ORIGINAL_MODE := &"_hitstop_original_mode"
const META_GENERATION := &"_hitstop_generation"


## nodes에 담긴 노드들을 duration_sec 동안 개별 정지시킨다. 접근성 배율(0=off)은
## 호출부에서 duration_sec에 미리 곱해 전달한다(0 이하면 아무 것도 하지 않는다).
static func apply_to(nodes: Array, duration_sec: float) -> void:
	if duration_sec <= 0.0:
		return
	var valid_nodes: Array[Node] = []
	var generations: Array[int] = []
	for n in nodes:
		if n is Node and is_instance_valid(n):
			var node := n as Node
			valid_nodes.append(node)
			# 이미 히트스톱 중이면(메타 존재) 원래 값을 덮어쓰지 않는다 — 그 값은
			# DISABLED(또는 아직 set_deferred가 반영되기 전의 값)일 수 있기 때문이다.
			if not node.has_meta(META_ORIGINAL_MODE):
				node.set_meta(META_ORIGINAL_MODE, node.process_mode)
			var gen: int = int(node.get_meta(META_GENERATION, 0)) + 1
			node.set_meta(META_GENERATION, gen)
			generations.append(gen)
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
			_restore(valid_nodes[i], generations[i])
		return
	var timer := tree.create_timer(duration_sec)
	timer.timeout.connect(func() -> void:
		for i in valid_nodes.size():
			_restore(valid_nodes[i], generations[i])
	)


## 이 호출의 세대가 여전히 최신일 때만 원래 process_mode로 복원한다. 더 늦게 걸린
## 히트스톱이 있으면(세대가 넘어감) 그쪽 타이머가 복원을 책임진다.
static func _restore(node: Node, generation: int) -> void:
	if not is_instance_valid(node):
		return
	if int(node.get_meta(META_GENERATION, 0)) != generation:
		return
	var original: int = int(node.get_meta(META_ORIGINAL_MODE, Node.PROCESS_MODE_INHERIT))
	node.remove_meta(META_ORIGINAL_MODE)
	node.remove_meta(META_GENERATION)
	node.set_deferred("process_mode", original)


## 테스트·디버그용: 노드가 현재 히트스톱으로 정지돼 있는지(메타 기준).
static func is_frozen(node: Node) -> bool:
	return is_instance_valid(node) and node.has_meta(META_ORIGINAL_MODE)
