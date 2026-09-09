## Dead 상태: HP 0 도달 시 진입(F8-2). 정지한 채로 가벼운 톤의 사망 연출(짧은 페이드 +
## 대기)을 재생한 뒤 Player.respawn()을 호출해 마지막 비석에서 HP 전량으로 부활한다
## (D-28: 부활 비석 = 워프 비석 동일 오브젝트).
##
## 대기시간은 Tuning.DEATH_RESPAWN_DELAY_SEC(1.0초) — docs/specs/combat-tuning-m1-
## addendum.md §7-3 제안값과 이름/값을 맞췄다. "장엄하지 않은 가벼운 톤"(F8-2 표시 규칙)에
## 맞춘 짧은 지연이다.
##
## Player.gd는 is_dead 플래그가 서있는 동안 physics_process를 건너뛰지만 _process는
## 이 상태의 update(delta)만은 계속 호출한다(대기 타이머를 흘리기 위해) — 자세한 이유는
## player.gd _process() 주석 참고.
extends PlayerState

const FADE_ALPHA := 0.35
const FADE_DURATION_SEC := 0.4

var _elapsed: float = 0.0


func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	player.velocity = Vector2.ZERO
	player.play_anim("idle")
	_elapsed = 0.0
	_play_death_fade()


func update(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= Tuning.DEATH_RESPAWN_DELAY_SEC:
		player.respawn()


func _play_death_fade() -> void:
	if player.sprite == null:
		return
	var tween := player.sprite.create_tween()
	tween.tween_property(player.sprite, "modulate:a", FADE_ALPHA, FADE_DURATION_SEC)
