## Hurt 상태: 피격 경직 + 무적 프레임(F2-2). 넉백·플래시·히트스톱은 이미
## Player._on_hurtbox_hurt()에서 HitFeel.apply()로 처리된 뒤 이 상태로 진입하므로,
## 여기서는 경직 시간 동안 조작을 막는 역할만 한다. 무적 프레임 자체는 상태 전환과
## 무관하게 지속돼야 해서 Player.start_iframes()/Player._process가 관리한다.
## 수치(hurt.stun_sec/hurt.iframes_sec)는 addendum §2 확정(D-61 예정) —
## combat.json에서 조회한다(stun_sec ≤ iframes_sec 불변식은 data.gd가 검증).
extends PlayerState

var _stun_remaining: float = 0.0


func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	_stun_remaining = float(Data.get_value("combat", "hurt.stun_sec", 0.25))
	player.start_iframes(float(Data.get_value("combat", "hurt.iframes_sec", 0.5)))
	player.play_anim("idle")


func physics_update(delta: float) -> void:
	_stun_remaining -= delta
	# 피격 넉백(HitFeel의 Tween)이 진행 중일 수 있으므로 남은 velocity는 그대로 소화한다.
	if player.velocity != Vector2.ZERO:
		player.move_and_slide()
	if _stun_remaining <= 0.0:
		if player.get_move_input() != Vector2.ZERO:
			finished.emit(&"Move", {})
		else:
			finished.emit(&"Idle", {})
