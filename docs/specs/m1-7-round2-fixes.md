# M1-7: 2차 재테스트 회귀 수정 결과 (D-127, D-128)

> 작성: godot-engineer. PR #20(M1-6) 병합 후 재플레이에서 남아있던 두 가지 문제
> (무기 오버레이 잔류 표시, 이동 시 잔여 방향 흔들림)에 대한 실제 원인·수정 내용·
> 정직한 한계를 기록한다.

## D-127. 무기 오버레이(WeaponPivot) 표시 상태 버그 수정

### 실제 원인

`game/scripts/player/player.gd`의 `play_attack_swing()`이 `weapon_pivot.visible = false`를
**tween의 완료 콜백(`tween_callback`)에만** 의존해 껐다. 콤보 2·3타가 이전 타의 tween이
끝나기 전에 재호출되면 같은 `weapon_pivot` 노드에 새 tween이 겹쳐 걸렸고(이전 tween의
콜백은 여전히 예약된 채로 남음), 구르기 캔슬·피격(Hurt 전이)처럼 Attack 상태가 tween 완료
전에 `exit()`되는 경로에서는 그 콜백이 아예 실행되지 못한 채 다음 상태로 넘어가 무기가
계속 보이는 상태로 남을 수 있었다.

### 수정 내용

- `game/scripts/player/player.gd`
  - `_weapon_tween: Tween` 필드를 추가해 `play_attack_swing()`이 만드는 tween을
    보관한다. 매 호출 시작 시 이전 tween이 `is_valid()`면 `kill()`부터 해, 같은
    노드에 tween이 겹쳐 걸리는 상황 자체를 없앤다.
  - 신규 `hide_weapon_overlay()`: `_weapon_tween`을 kill하고 `weapon_pivot.visible`을
    **즉시** false로 만든다. tween 콜백 실행 여부와 무관하게 동작한다.
- `game/scripts/player/states/attack.gd`
  - `exit()`에서 `player.hide_weapon_overlay()`를 호출한다. `PlayerStateMachine.
    transition_to()`는 상태를 벗어나는 모든 경로(피니셔 완주 후 Idle, 구르기 캔슬,
    피격 시 Hurt 전이)에서 반드시 `exit()`를 호출하므로, 이 한 곳만으로 "Attack을
    벗어나는데 무기가 안 숨는" 모든 경우를 커버한다. Idle/Move/Guard 등 개별 상태의
    `enter()`에 방어 코드를 중복으로 넣지 않았다 — 무기가 보일 수 있는 유일한 진입점이
    Attack 상태이고, 그 상태의 `exit()`가 유일한 이탈 경로이기 때문이다.

### 검증

- 신규 `game/tests/unit/test_player_weapon_overlay.gd`(GUT, 5개):
  - 1타 스윙 중 즉시 Hurt 전이 → `weapon_pivot.visible == false` 즉시 확인.
  - 피니셔 후딜 중 구르기 캔슬(Roll 전이) → 즉시 숨김 확인.
  - 3타를 각 `hit_duration_sec`보다 훨씬 짧은 간격으로 연속 진행(매 타마다 새 tween
    생성, 이전 tween과 겹치지 않음 확인) 후 피니셔 종료(Idle 전이) → 최종 숨김 확인.
  - `hide_weapon_overlay()`가 tween이 없는 상태(공격 시작 전)에서도, 연속 호출에도
    안전한지(idempotent) 확인.
- `game/tests/smoke/smoke_player_kills_slime.gd`(기존 스모크 확장): 시나리오 B(3타
  콤보 완주) 종료 직후, Attack 상태를 실제로 벗어날 때까지(최대 1초) 폴링해
  `weapon_pivot.visible == false`를 실측 확인 — 실행 로그: `[D-127][PASS] 공격 종료 후
  t=1.359 시점 weapon_pivot.visible=false`.

## D-128. 방향 판정 시간 기반 디바운스 추가

### 실제 원인

D-121에서 넣은 크기 기반 완충(hysteresis, `FacingCalc.resolve_facing`, bias=1.3)은
"입력 벡터의 수평/수직 성분 크기 비율"만 본다. 그런데 실제 키보드 입력은 대각선
두 키(예: 오른쪽+아래)가 정확히 같은 프레임에 눌리거나 떼어지지 않는다 — 한 프레임은
수평 키만 감지되고, 다음 프레임에 수직 키가 추가로 감지되는 식으로 **입력 자체가 몇
프레임에 걸쳐 순차적으로 들어온다**. 이 경우 crossing 시점 근처에서 매 프레임 다른
축이 "명확히 우세"한 것으로 계산될 수 있어, 크기 조건만으로는 여전히 몇 프레임 안에
축이 토글되는 잔여 흔들림이 남았다.

### 수정 내용

- `game/scripts/systems/facing_calc.gd`
  - `resolve_facing()`에 `elapsed_since_last_switch: float`, `min_switch_interval_sec:
    float` 매개변수를 추가(기본값 `1e9`/`0.0` — 생략 시 기존 호출부와 100% 동일하게
    동작해 하위 호환된다). 크기 조건이 축 전환을 요구해도 마지막 축 전환 후
    `min_switch_interval_sec` 이내면 전환을 보류하고 **입력 방향을 재해석하지 않고
    `current_facing`을 그대로 반환**한다(초기 구현에서 "보류 시 부호만 다시 판정"하는
    방식을 시도했으나, 반대 축 성분이 0에 가까운 입력에서 방향이 엉뚱하게 뒤집히는
    버그가 있어 — GUT 테스트로 발견 — 순수하게 이전 facing을 그대로 반환하는 방식으로
    수정했다).
  - 함수는 여전히 노드/타이머에 의존하지 않는 순수 함수로 유지했다.
- `game/scripts/tuning.gd`: `FACING_AXIS_SWITCH_MIN_INTERVAL_SEC = 0.1`(제안값
  0.08~0.12초 중 중간값, `_balance_todo` — game-designer 확인 필요).
- `game/scripts/player/player.gd`
  - `_facing_axis_switch_elapsed: float`(초기값 `1e9` — 최초 입력은 디바운스 없이
    허용)를 `_physics_process(delta)`에서 매 프레임 누적한다.
  - `set_facing()`이 이 값과 `Tuning.FACING_AXIS_SWITCH_MIN_INTERVAL_SEC`을
    `FacingCalc.resolve_facing()`에 전달하고, 실제로 축(수평/수직)이 바뀐 프레임에만
    `_facing_axis_switch_elapsed`를 0으로 리셋한다.

### 검증

- `game/tests/unit/test_player_facing.gd`에 6개 테스트 추가:
  - 기본값(생략)일 때 디바운스가 걸리지 않음(하위 호환).
  - 최근 축 전환 후 최소 유지시간 이내면 크기 조건을 만족해도 축 유지.
  - 최소 유지시간이 지나면 동일 조건에서 축 전환 허용(영구 고정 아님).
  - 같은 축 내 부호 변경(RIGHT→LEFT)은 디바운스와 무관하게 즉시 반영.
  - D-128 요구사항 원문 시나리오: 0.03초 간격으로 축이 살짝 넘어가는 입력을
    연속 투입해도 디바운스 구간(0.1초) 내에는 축이 유지되고, 구간을 넘으면
    전환이 허용됨.
  - `Player.set_facing()` + `_physics_process()` 통합 경로(순수 함수가 아니라
    실제 노드 델타 누적까지 포함)에서도 동일하게 동작함을 확인.
- 기존 `game/tests/smoke/smoke_sprite_axis.gd`가 방향을 바꿀 때마다 `set_facing()`을
  0초 간격으로 연속 호출하고 있어 디바운스에 걸려 실패했다 — 방향 전환 사이에 물리
  프레임 10틱(≈0.167초)을 흘려보내도록 수정(실제 플레이에서도 방향 전환 사이엔 여러
  프레임이 지난다는 점을 반영; 이 테스트의 목적은 디바운스 검증이 아니라 스프라이트
  축 매핑 검증이므로 디바운스를 우회하는 것이 맞는 수정이다).

### 정직한 한계

`docs/qa/walk-animation-diagnosis.md`가 지목했듯, 현재 프로토타입 스프라이트 시트는
**방향별 그림 자체가 거의 동일**하다(down/up 픽셀 유사도 0.935). 이번 수정(D-121의
크기 기반 완충 + D-128의 시간 기반 디바운스)은 **코드 레벨에서 facing 값 자체가
프레임마다 토글되는 현상**을 최대한 줄인 것이지, "그림이 방향을 구분하기 어렵다"는
애셋 자체의 한계를 해결하지는 못한다. 즉:

- facing 값(내부 상태)이 실제로 안정화됐는지는 이번 GUT 테스트로 검증했다.
- 그러나 플레이어가 화면에서 "자연스럽게 걷는다"고 체감하는지는 최종적으로
  스프라이트가 얼마나 방향을 구분해 보여주는지에 달려 있고, 이 부분은 원작 아트
  확보 전까지 남는 한계다. 과장해서 "완전히 해결됨"이라고 보고하지 않는다.
