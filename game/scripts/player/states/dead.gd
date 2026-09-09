## Dead 상태: HP 0 도달 시 진입(F2 관련, 부활/리스폰은 M1-2 범위). 정지 상태를
## 유지할 뿐 별도 전환은 없다 — Player.gd가 is_dead 플래그로 이후 입력/물리 갱신을
## 아예 건너뛰므로 이 상태에서 나가는 로직은 필요 없다.
extends PlayerState


func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	player.velocity = Vector2.ZERO
	player.play_anim("idle")
