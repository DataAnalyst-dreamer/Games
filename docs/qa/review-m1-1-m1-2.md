# QA 코드 리뷰 — PR #5(M1-1) · PR #6(M1-2)

- 대상: `git diff stage/m1-0-project-scaffold..stage/m1-2-roll-guard-death -- game` (커밋 범위만, 작업 트리 변경 무시)
- 기준: `docs/specs/combat-tuning-m1.md`, `docs/specs/combat-tuning-m1-addendum.md`, `docs/brd/03-features/02-전투.md`, `docs/brd/04-decisions.md`(D-42~D-52), GDD 4.2
- 검증 환경: Godot 4.4.1 headless(`--import` → GUT 80/80 → 스모크 씬 4개 실행). 리뷰 중 `game/`는 수정하지 않았고, 엔진 동작 확인용 임시 미니 프로젝트(`/tmp/pm_test`)는 검증 후 삭제했다.
- 작성일: 2026-09-08

## 요약

| 심각도 | 건수 |
|---|---|
| Blocker | 0 |
| Major | 2 |
| Minor | 2 |

**Blocker 요지**: 없음. 리뷰 초기에 "몬스터 사망 시 `hurtbox.monitoring`을 물리 콜백 중 즉시 변경해 런타임 오류가 난다"는 가설을 세웠으나(체크리스트 항목과 정확히 일치하는 패턴이라 유력해 보였음), 실제로 `SmokePlayerKillsSlime.tscn`을 헤드리스로 실행해 확인한 결과 오류 없이 정상 동작해 **기각**했다(과거 스크래치 로그 `smoke_a.log`에는 유사한 "Disabling a CollisionObject node during a physics callback" 오류가 남아 있었지만, 이는 `hitbox.gd`가 `set_deferred`로 고치기 전의 이전 버전 실행 기록으로 보이며 현재 커밋 상태에서는 재현되지 않는다). 코드 리뷰에서 크래시/즉시 실패급 결함은 발견하지 못했고, 대신 손맛(M1 게이트)과 데이터 무결성 파이프라인에 영향을 주는 **Major 2건**을 찾았다.

**M1 게이트 수치(히트스톱 0.05~0.1s / 예고 0.5s / 구르기 무적 0.3s) 자체는 `combat.json`에 정확히 반영되어 있고, 스모크 테스트로 기능도 확인됨(아래 "검증 실행 로그" 참고)** — 이 세 수치는 정상.

---

## Major-1: 몬스터 공격 후딜레이(`attack_recovery_sec`)가 근접 상태에서 사실상 무시됨

- **파일:줄**: `game/scripts/entities/monster_base.gd:158-163` (`_process_attack`)
- **문제**:
  ```gdscript
  func _process_attack() -> void:
      if _state_timer <= 0.0:
          hitbox.deactivate()
          _state_timer = Tuning.MONSTER_ATTACK_RECOVERY_SEC
          state = State.CHASE if _player_valid() else State.IDLE
  ```
  다른 모든 상태 전이는 `_enter_state()`를 거치는데(그 안에서 상태별 `_state_timer`를 설정), 여기만 `state` 필드를 **직접 대입**해 `_enter_state()`를 우회한다. 그 결과:
  1. **CHASE로 갈 때**: `_process_chase()`는 `_state_timer`를 전혀 참조하지 않는다(거리 계산만으로 즉시 TELEGRAPH 재진입 여부를 판정). 따라서 방금 대입한 `MONSTER_ATTACK_RECOVERY_SEC`(슬라임 0.4s)는 **완전히 죽은 값**이 된다 — 플레이어가 넉백으로 근접 사거리(`MONSTER_MELEE_RANGE_PX`=14px) 밖으로 밀려나지 않는 한(벽에 붙어 있는 등), 몬스터는 후딜레이 없이 바로 다음 예고→공격을 시작할 수 있다. `docs/specs/combat-tuning-m1-addendum.md` §4-2가 못박은 불변식 "`attack_recovery_sec > 0`"과 "반격 타이밍 확보" 의도가 코드에서 실질적으로 지켜지지 않는다.
  2. **IDLE로 갈 때**: `_process_idle()`은 `_state_timer <= 0.0`이면 PATROL로 넘어간다. 그런데 `_enter_state(State.IDLE)`을 거치지 않았으므로 원래 그 안에서 설정될 `MONSTER_PATROL_PAUSE_SEC`(1.2s)가 아니라 직전에 대입된 `MONSTER_ATTACK_RECOVERY_SEC`(0.4s)가 그대로 남는다 — 공격 후 아이들 대기 시간이 설계값의 1/3로 단축된다.
- **재현 절차**(정적 분석 기반, 코드 수정 금지 제약으로 자동화 테스트는 추가하지 못함 — 담당 에이전트가 아래 방법으로 직접 확인 권장):
  1. `res://scenes/main/Main.tscn`에서 플레이어를 슬라임 근접범위(14px) 안, 벽 등에 붙여 넉백으로 거리가 벌어지지 않게 고정.
  2. 슬라임이 IDLE→PATROL→CHASE→TELEGRAPH→ATTACK까지 자연 진행하도록 대기(또는 `SmokeSlimeAttacksPlayer.tscn` 패턴 참고).
  3. `ATTACK` 종료 직후 `_slime.state`와 `_state_timer`를 로그로 찍어보면 `state`가 `CHASE`로 바뀌자마자(같은 프레임 또는 그다음 물리 프레임) `to_player.length() <= 14px` 조건이 참이 되어 곧장 `TELEGRAPH`로 재진입하는 것을 확인할 수 있다(중간에 `attack_recovery_sec`만큼의 지연이 없음).
- **권장 수정**(설계 판단 필요 — godot-engineer 구현, 후딜 중 재판정 정책은 game-designer 확인):
  - `_process_attack()`이 `_enter_state()`를 통해서만 전이하도록 고치고, `attack_recovery_sec` 동안 TELEGRAPH 재진입을 막는 별도 게이트(예: `State.RECOVER` 신설, 또는 `_process_chase()`에 `_state_timer > 0`이면 melee 판정을 건너뛰는 조건 추가)를 넣는다.

## Major-2: 히트스톱이 공격자(플레이어 자신)의 `_unhandled_input`까지 차단 — 콤보 입력이 유실될 수 있음

- **파일**: `game/scripts/systems/hitstop.gd`(`apply_to`), `game/scripts/systems/hit_feel.gd:22-26`
- **문제**: `HitFeel.apply()`는 피격자(`defender_body`)뿐 아니라 공격자(`hitbox.source`, 즉 플레이어가 몬스터를 때렸을 때는 플레이어 자기 자신)도 `nodes_to_freeze`에 넣어 `Hitstop.apply_to()`로 넘긴다. `Hitstop.apply_to()`는 대상 노드의 `process_mode`를 `PROCESS_MODE_DISABLED`로 바꾼다(`set_deferred` 사용 — 이 부분 자체는 물리 콜백 규칙을 올바르게 지킴).
  그런데 Godot 4.4.1에서 `process_mode = PROCESS_MODE_DISABLED`는 `_process`/`_physics_process`뿐 아니라 **`_unhandled_input`도 완전히 차단**한다. `Player`의 전투 입력(공격/구르기/가드)은 전부 `Player._unhandled_input() → state_machine.handle_input(event)` 한 경로로만 들어오므로, **플레이어 자신의 타격이 확정되는 순간부터 `hitstop_sec`(일반 0.05s / 강공격·피니셔 0.1s) 동안 플레이어의 입력이 통째로 씹힌다** — 버퍼링되는 게 아니라 이벤트 자체가 그 노드에 전달되지 않는다.
  - 이 사실을 코드가 아니라 **엔진 동작 자체**로 직접 검증했다(별도 미니 Godot 4.4.1 프로젝트, `game/`과 무관): 한 노드의 `process_mode`를 `DISABLED`로 바꾸기 전에는 `Input.parse_input_event()`로 흘린 액션이 정상적으로 그 노드의 `_unhandled_input()`을 호출했고, `DISABLED`로 바꾼 뒤에는 동일한 입력을 흘려도 `_unhandled_input()`이 전혀 호출되지 않았다(로그로 확인, 검증 후 임시 프로젝트는 삭제).
  - **실전 영향 범위**: 콤보 입력 버퍼 구간은 활성 구간(`ATTACK_HIT_DURATION_SEC`≈0.333s)의 **마지막** `combo.input_buffer_sec`(0.2s)이다. 히트박스가 스윙 시작 직후(적이 이미 사거리 안에 있는 일반적인 경우, 활성화 후 약 1물리프레임=0.017s 이내) 판정되면 히트스톱 데드존(0.017~0.067~0.117s)이 버퍼 구간(0.133~0.333s)과 겹치지 않아 실전 영향이 제한적이다. 그러나 **적이 사거리 경계에 있거나 이동 중(뿔토끼 돌진 등)이라 판정이 활성 구간 후반부에 나는 경우**, 히트스톱 데드존이 정확히 콤보 입력 버퍼 구간과 겹쳐 그 프레임의 재입력이 소실된다 — "분명히 버퍼 구간 안에서 눌렀는데 콤보가 안 이어진다"는, 사용자가 재현하기도 원인 파악하기도 어려운 손맛 저하로 나타날 수 있다.
- **재현 절차**:
  1. (엔진 동작 검증) 임의의 최소 Godot 4.4.1 프로젝트에서 노드 A의 `process_mode`를 물리 프레임 중 `PROCESS_MODE_DISABLED`로 바꾼 직후 `Input.parse_input_event()`로 액션 이벤트를 흘리고, A의 `_unhandled_input()`이 호출되는지 로그로 확인 — 호출되지 않음.
  2. (게임 내 영향 확인 방법 제안) `attack.gd::_fire_hitbox()`에 히트 판정 시각(`combo.elapsed`)을 로그로 남기고, 뿔토끼(돌진) 등 이동형 적을 상대로 콤보를 이어가며 히트 판정 시각이 `hit_duration_sec - input_buffer_sec`(≈0.133s) 이후로 밀리는 경우를 찾아 그 직후 눌린 공격 입력이 씹히는지 확인.
- **권장 수정**(설계 판단 필요 — game-designer/godot-engineer 협의):
  - (a) 공격자(=플레이어 자신) 노드는 히트스톱 프리즈 대상에서 제외하고 스프라이트·이펙트만 멈추거나,
  - (b) 전투 입력을 `_unhandled_input` 단발 이벤트 대신 `_physics_process`에서 `Input.is_action_just_pressed()`로 폴링하는 방식으로 바꿔 `process_mode` 차단의 영향을 받지 않게 하거나,
  - (c) 히트스톱 동안의 입력을 별도로 큐에 담아 해제 시 재생하는 소프트 버퍼를 추가한다.

---

## Minor-1: `Data.REQUIRED_SCHEMA`가 M1-1/M1-2에서 추가된 신규 키를 하나도 보호하지 않음

- **파일**: `game/scripts/core/data.gd:15-43`
- **문제**: `REQUIRED_SCHEMA["combat"]`은 m1-0 스캐폴드 시점의 키 11개만 나열하고, 이후 D-46/D-48 및 M1-2에서 `combat.json`에 추가된 아래 키들은 전혀 포함하지 않는다:
  `roll.duration_sec`, `roll.distance_px`, `guard.chip_damage_ratio`, `guard.just_guard_enemy_stagger_sec`, `guard.move_speed_multiplier`, `hitstop.normal_sec`, `hitstop.heavy_crit_sec`, `combo.reset_after_sec`, `combo.finisher_recovery_sec`, `combo.finisher_roll_cancel_after_sec`, `stamina.regen_delay_sec`, `stamina.exhausted_penalty_sec`, `stamina.guard_regen_multiplier`, `stamina.costs.guard_hit`, `stamina.costs.heavy_attack`, `knockback.normal_px`, `knockback.heavy_px`.
  이 키들이 실수로 삭제되거나 오타가 나도 `Data._validate()`(개발 빌드에서 `push_error`+`assert`로 즉시 중단시키는 안전장치)가 전혀 잡아내지 못하고, 코드는 조용히 fallback 기본값으로 넘어간다(그중 일부 fallback은 아래 Minor-2처럼 틀린 값이다). "밸런스 수치는 테이블로만" 원칙을 지키는 최전선 방어막인데, 정작 최근에 확정된 값 대부분이 무방비 상태다.
- **재현 절차**: `game/data/combat.json`에서 예컨대 `hitstop.heavy_crit_sec` 키를 지우고 `Data.reload()`를 호출 — `validation_errors`가 비어 있음(= 아무 경고도 없음)을 확인할 수 있다. 반면 `game/tests/unit/test_monsters_and_elements.gd::test_combat_json_new_keys_from_d48`은 이 상황에서 실패하므로, "GUT을 안 돌리면 아무도 못 알아챈다"는 뜻이다.
- **권장 수정**: `REQUIRED_SCHEMA["combat"]`(및 대응하는 `RELEASE_FALLBACKS["combat"]`)에 위 키 전부 추가. 소유 에이전트: game-designer(값 확인) → godot-engineer(반영).

## Minor-2: 일부 `Data.get_value` fallback 기본값이 실제 확정값과 불일치

- **파일:줄**:
  - `game/scripts/player/player.gd:40` — `walk_speed = float(Data.get_value("combat", "movement.walk_speed_px", 0.0))`. fallback이 **0.0**이다. 다른 모든 참조(`data.gd:247`의 `RELEASE_FALLBACKS`)는 80.0을 쓰는데 이 자리만 0.0이라, 키가 사라지면 플레이어가 **완전히 움직이지 못하는** 최악의 실패 모드가 조용히 발생한다(에러도 안 남).
  - `game/scripts/player/states/attack.gd:81-84` — 강공격/피니셔 분기(`is_finisher`)에서도 `knockback_px`/`hitstop_sec`의 fallback 기본값이 각각 일반값(8.0 / 0.05)으로 고정되어 있다(`"knockback.heavy_px" if is_finisher else "knockback.normal_px", 8.0` 형태 — 세 번째 인자인 기본값이 분기와 무관하게 하나뿐). 정상 동작 시엔 티가 안 나지만, Minor-1과 겹쳐 해당 키가 빠지면 피니셔 타격이 "강공격"이 아니라 "일반 타격" 수치로 조용히 강등된다.
- **재현 절차**: `combat.json`에서 `movement.walk_speed_px`를 삭제하고 게임을 실행하면(디버그 빌드가 아니라 릴리즈 빌드 가정 시) 플레이어가 이동 입력을 줘도 제자리에 멈춰 있음을 확인할 수 있다.
- **권장 수정**: fallback 값을 실제 확정값(80.0, 20.0/0.1)으로 맞추거나, Minor-1을 먼저 해결해 fallback이 실사용될 일 자체를 없앤다.

---

## 참고: `_balance_todo` 잔존 항목과 결정 ID 공백 (정보성, 별도 심각도 없음)

`docs/brd/04-decisions.md`에는 D-42~D-52까지만 있고, 이는 `docs/specs/combat-tuning-m1.md`(첫 스펙 문서)의 결정 요청 11건에 대응한다. 반면 `docs/specs/combat-tuning-m1-addendum.md`가 제기한 결정 요청 9건(넉백 지속시간, 피격 스턴/무적, 카메라 셰이크 4단계, 몬스터 AI 5필드, 가드 이동속도·회복 배율 등)은 아직 공식 D-번호가 배정되지 않았다. 그런데 `game/data/combat.json`은 이미 `guard.move_speed_multiplier`/`stamina.guard_regen_multiplier`/`knockback.*`/`combo.finisher_recovery_sec`/`guard.just_guard_enemy_stagger_sec`를 `_balance_todo`로 표시해 반영해 두었다(D-46 패턴을 따른 것으로 코드 자체는 문제 없음). 담당 에이전트(game-designer/PM)가 addendum의 결정 요청에 D-번호를 배정해 `_balance_todo`를 해제하는 절차를 놓치지 않도록 트래킹만 남긴다. — **버그 아님, 설계/프로세스 확인 사항**.

---

## 검증 실행 로그 (참고용, 이번 리뷰에서 `game/`는 변경하지 않음)

**중요한 방법론 메모**: 리뷰 도중 다른 에이전트가 같은 작업 트리(`game/`)를 실시간으로 수정하고 있다는 사실을 `git status`로 뒤늦게 확인했다(`monster_base.gd`, `data.gd`, `hit_feel.gd`, `hitbox.gd`, `hurtbox.gd`, `hurt.gd`, `player.gd`, `tuning.gd`, `combat.json`, `monsters.json` 등 이번 리뷰 대상과 겹치는 파일 다수가 M1-3 작업으로 이미 변경되어 있었음). 이 세션은 해당 파일들을 `Read` 도구로 먼저 읽었기 때문에 코드 분석 자체는(비교 확인 결과) 오염 이전 시점이라 m1-2 범위와 일치했지만, **첫 번째 스모크/GUT 테스트 실행은 이미 M1-3 코드가 섞인 작업 트리에서 수행된 것**이었다. 이를 바로잡기 위해 `git archive stage/m1-2-roll-guard-death`로 작업 트리를 건드리지 않고 `/tmp/m12_pure`에 순수 m1-2 스냅샷을 별도로 뽑아, 그 위에서 아래 검증을 **다시** 수행했다(`game/`에는 어떤 쓰기도 없었음 — `git archive`/`git show`/`git diff`/`git log` 등 읽기 전용 명령만 사용).

순수 m1-2 스냅샷(`/tmp/m12_pure/game`)에서 헤드리스 Godot 4.4.1로 `--import` 후 실행한 결과:

- GUT 전체: **80/80 통과** (`test_combo_state`, `test_element_calc`, `test_guard_calc`, `test_hitbox`, `test_monsters_and_elements`, `test_player_resources`, `test_roll_calc`, `test_game_state` 등).
- `SmokePlayerKillsSlime.tscn`: 2타 슬라임 사망(A), 3타 콤보 배율 정확(B) — 오류 없이 PASS. (초기 가설이었던 "사망 시 물리 콜백 중 monitoring 변경 오류"는 **재현되지 않아 기각**. 참고: 세션 스크래치의 과거 로그 `smoke_a.log`에는 유사한 "Disabling a CollisionObject node during a physics callback" 오류가 남아 있었는데, 이는 `hitbox.gd`가 `set_deferred`로 고쳐지기 전 더 이른 초안 실행 기록으로 보이며 m1-2 스냅샷에서는 재현되지 않았다.)
- `SmokeDeathRespawn.tscn`: 즉사 → Dead 전이 → 1.0s 후 비석 위치·HP/스태미나 전량 부활 — PASS.
- `SmokeRollIframes.tscn`: 슬라임 공격 판정 활성 구간 전체를 구르기 무적(0.3s)이 덮어 피해 0 — PASS.
- `SmokeSlimeAttacksPlayer.tscn`: 예고 실측 0.518s(설정 0.5s) → 피격 → Hurt 전이 — PASS.

(오염된 작업 트리에서 먼저 돌렸던 최초 실행도 결과는 동일했지만, 위 결과가 실제 리뷰 대상 범위와 정확히 일치하는 유효한 근거다.)

이 로그들은 Major-1(공격 후딜레이 무시)·Major-2(히트스톱 중 입력 차단)를 직접 노출하지는 않는다 — 두 문제 모두 기존 스모크 테스트가 다루지 않는 시나리오(연속 공격 사이클, 사거리 경계에서의 히트 타이밍)에서 발생하기 때문이다. 두 findings은 코드 정적 분석(Major-1) 및 별도의 격리된 미니 프로젝트를 이용한 엔진 동작 실측(Major-2)으로 뒷받침했으며, `monster_base.gd`/`hit_feel.gd`의 관련 코드가 m1-2 순수 스냅샷과 동일함을 `diff`로 재확인했다. `game/`가 잠겨 있어 이번 세션에서 재현 자동화 테스트를 추가하지 못했으니, 담당 에이전트가 GUT/스모크 테스트로 후속 검증할 것을 권장한다.

**작업 트리 공유 관련 권고(프로세스 이슈, 버그 아님)**: 여러 에이전트가 커밋 없이 같은 `game/` 작업 트리를 동시에 수정하면, 이번처럼 리뷰/테스트 대상이 의도치 않게 섞일 위험이 있다. 가능하면 단계별 작업은 `git worktree` 등으로 물리적으로 분리하거나, 리뷰어는 항상 `git archive <브랜치>`로 격리 스냅샷을 떠서 검증하는 절차를 `.claude/agents/README.md` 운영 규칙에 명시할 것을 제안한다.
