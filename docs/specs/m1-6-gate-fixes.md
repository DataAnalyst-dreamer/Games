# M1-6: M1 게이트 플레이테스트 피드백 대응 구현 결과 (D-119~D-125)

> 작성: godot-engineer. 각 항목의 실제 반영 내용·수치를 기록해 다음 플레이테스트에서
> 재확인할 수 있게 한다. 사전 조사 문서(키맵 리서치, 공격 애니메이션 계획, 이동 애니메이션
> 진단, 몬스터 공격 앵커 검토)는 이미 결론이 났으므로 그대로 반영했고 재조사하지 않았다.

## D-119. 키맵 변경

- `game/project.godot` [input]: `interact` physical_keycode 70(F) → **69(E)**, `skill_2`
  physical_keycode 69(E) → **82(R)**. 게임패드 바인딩(A/RB)은 변경 없음.
- `game/README.md` "입력 액션" 표, `docs/qa/m1-gate-playtest.md` §1-3 조작표 + 시나리오④
  테스터 지시문("F키" → "E키") 갱신.
- `ui_tab_next`(메뉴 탭 이동, physical_keycode 69=E)는 D-119 범위 밖이라 손대지 않음 —
  `skill_2`와는 별개 액션이라 물리 키 값이 우연히 겹쳐도 충돌 아님(서로 다른 컨텍스트에서만
  쓰임).

## D-120. 공격 애니메이션 통합

- `game/scenes/player/Player.tscn`의 `SpriteFrames`에 `attack_down`/`attack_up`/
  `attack_right`/`attack_left` 4개 애니메이션 추가. 소스: `SpriteSheet.png` 행4(y=64),
  region (0,64,16,16)~(48,64,16,16) 4프레임을 4방향 애니메이션 전부에 동일하게 재사용.
  `speed=12.0`, `loop=false`(문서 §2 표 그대로).
- `attack_left`의 `flip_h` 옵션(우선순위 낮음, 문서 §1.3)은 이번엔 적용하지 않음 —
  `AnimatedSprite2D.flip_h`는 노드 전체에 걸리는 단일 값이라 애니메이션별로 다르게 줄 수
  없어(4방향이 한 노드를 공유), 적용하려면 방향 전환 시 코드에서 직접 sprite.flip_h를
  토글해야 한다. 재량 범위(문서 "안 해도 됨")라 이번엔 보류, 후속 폴리시 작업으로 남김.
- `game/scripts/player/states/attack.gd`의 `_start_current_hit()`: `player.play_anim("idle")`
  → `player.play_anim("attack")`으로 교체. 문서 §3이 언급한 추가 반영 지점(§4 무기 오버레이
  방식, 프레임별 키프레임 tween)은 "필수 아님, 현재 단일 tween으로 충분"이라 명시돼 있어
  변경하지 않음.

## D-121. 이동 방향 완충(hysteresis)

- 신규 `game/scripts/systems/facing_calc.gd`(`FacingCalc`, 순수 로직 — `monster_ai_calc.gd`와
  같은 패턴)에 `resolve_facing(current_facing, input_dir, axis_switch_bias)` 구현: 현재 축
  (수평/수직)을 유지하려면 반대 축 성분이 `axis_switch_bias`배를 넘지 않아야 한다.
- `Tuning.FACING_AXIS_SWITCH_BIAS = 1.3`(약 30% 여유, `_balance_todo` — game-designer 확인
  필요) 추가. `game/scripts/player/player.gd`의 `set_facing()`이 이 함수를 호출하도록 교체.
- 검증: `game/tests/unit/test_player_facing.gd` 8개 테스트 신설 — 순수 대각선 흔들림 시퀀스가
  축을 토글하지 않음, 명확한 축 우세 입력은 여전히 전환됨, 게임패드 드리프트 패턴 안정성 등.
  전부 PASS(아래 §검증 결과).

## D-122. 몬스터 공격 이펙트 오프셋 분리

- `monsters.json`에 종별 `attack_vfx_offset_px` 필드 추가(문서 §4 두 방식 중 "구현하기 쉬운
  쪽"으로 데이터 필드 방식 채택 — 종별 정확한 권장값을 그대로 반영할 수 있어서). 적용값:

  | 몬스터 | 신규 `attack_vfx_offset_px` | 문서 권장 범위 | 비고 |
  |---|---|---|---|
  | slime | 8.5 | 8~9(현행 유지) | 기존 8.4에서 소폭 조정 |
  | horn_rabbit | 9.5 | 9~10(현행 유지) | |
  | horn_rabbit_big(정예) | 11.5 | 11~12 | 스케일(1.3) 반영값 |
  | mushroom | 8.5 | 8~9(수정) | 기존 12 → 8.5로 수정(핵심 대상) |
  | goblin_scout | 9.5 | 9~10(고정값) | 사거리(90px)와 분리 |
  | elite_goblin_captain | 12.5 | 12~13 | 스케일(1.3) 반영값 |
  | elite_bunchi_spawn | 11.5 | 11~12 | 스케일(1.4) 반영값 |

- `game/scripts/entities/monster_base.gd`: `_fire_hitbox()`/`_fire_projectile()`이
  `melee_range_px * 0.6` 대신 신규 `_attack_vfx_offset_px()` 헬퍼를 쓴다. 이 헬퍼는
  `attack_vfx_offset_px`가 배정돼 있으면(>0) 그 값을, 없으면
  `8.0 * sprite.scale.x + Tuning.MONSTER_ATTACK_VFX_MARGIN_PX(2.0)` 폴백 공식을 쓴다(신규
  몬스터가 이 필드를 아직 못 받아도 완전히 깨지지 않게 하는 안전망).
- `melee_range_px`(밸런스 값)는 어느 몬스터도 값을 바꾸지 않았다.
- `_activate_spore_patch()`(포자 장판 중심)는 문서 §3에서 "선택, 우선순위 낮음, 급하지 않음"
  으로 명시된 항목이라 이번엔 그대로 둠(`melee_range_px * 1.0` 유지).

## D-123. 일반 몬스터 체력바

- 기존 정예 전용 `_elite_hp_bar_bg`/`_elite_hp_bar_fill`을 전 티어 공용 `_hp_bar_bg`/
  `_hp_bar_fill`로 일반화(`_setup_hp_bar()`). 정예 이름표(`_elite_nameplate`)는 여전히
  `tier=="elite"`일 때만 생성.
- 크기: 정예 24×3px(기존 유지), 일반 14×2px(더 작게). 색상은 정예 골드 테두리 스타일을
  그대로 참고(배경=테두리색, 채움=빨강).
- 상태 전이: 생성 시 `visible=false`(숨김) → `_on_hurtbox_hurt()`에서 피격마다
  `_show_hp_bar()`(노출 + `modulate.a=1.0` + 페이드 타이머 리셋) → `Tuning.
  MONSTER_HP_BAR_FADE_DELAY_SEC(2.5초)` 경과 시 `_start_hp_bar_fade_out()`이
  `Tuning.MONSTER_HP_BAR_FADE_DURATION_SEC(0.4초)` 동안 알파를 0으로 트윈 후 `visible=false`.
  재피격 시 진행 중이던 트윈은 즉시 kill()되고 다시 완전 노출.
- 검증: `game/tests/unit/test_monster_hp_bar.gd` 8개 테스트(숨김 기본값/피격 시 노출/HP
  비율/정예-일반 크기 차이/지연 전 유지/지연 후 페이드 시작/페이드 완료 후 숨김/재피격 시
  리셋) 전부 PASS.

## D-124. 공격 중 이동 입력 블렌딩

- `game/scripts/player/states/attack.gd`의 `physics_update()`: 기존
  `velocity.move_toward(Vector2.ZERO, 900*delta)`를
  `velocity.move_toward(move_input * walk_speed * Tuning.ATTACK_MOVE_INPUT_BLEND_RATIO,
  900*delta)`로 교체. `Tuning.ATTACK_MOVE_INPUT_BLEND_RATIO = 0.35`(정상 속도의 35%,
  요청 범위 30~40% 중간값) 추가.
- 감쇠 목표점 자체를 "0"에서 "저속 이동 속도"로 바꾼 것이라 lunge와 입력이 단순 합산되지
  않고, lunge 감쇠가 끝나면 자연스럽게 그 저속 이동으로 수렴한다. 콤보 판정(`combo.update()`)
  · 히트박스 타이밍(`_fire_hitbox()`, `_start_current_hit()`)은 전혀 건드리지 않음.

## D-125. 데스크탑 해상도

- `game/project.godot`: `window_width_override` 1920→**2560**,
  `window_height_override` 1080→**1440**(4배, 640×360×4). `window/stretch/scale_mode`는
  "integer" 유지.
- `window/size/resizable`: 명시적으로 `true`를 추가해 봤으나, Godot는 기본값과 같은 설정을
  프로젝트 파일에서 자동으로 생략한다(`--import` 재저장 시 사라짐) — 즉 Godot 4의 기본값
  자체가 이미 `true`임을 확인했다. 별도 조치 불필요.

## 검증 결과 (실제 수치)

Godot 4.4.1 headless, `GODOT=.../Godot_v4.4.1-stable_linux.x86_64` (세션 스크래치패드):

1. `--headless --path game --import`: 정상 완료(엔진 셧다운 시 `Pages in use exist at exit`
   경고 1줄은 기존에도 나오는 벤치성 메시지, 신규 아님).
2. GUT 전체: **Scripts 36, Tests 361, Passing 361**(기존 345 + 신규 16 — facing 8 + hp bar
   8), Asserts 3803, Time 1.549s. 전부 PASS.
3. 스모크 전체(`tests/smoke/*.tscn`, 총 23개 씬): **전부 PASS**, FAIL 0. 지정 5종
   (`SmokePlayerKillsSlime`/`SmokeRabbitDash`/`SmokeMushroomAoE`/`SmokeSlimeAttacksPlayer`/
   `SmokeGoblinWhistle`) 포함 회귀 없음.
4. 메인 씬(`Main.tscn`) `--quit-after 300`: **SCRIPT ERROR 0건**, `validate_tables.py`
   경고 2건(기존에도 있던 stats.luk/stats.int 상한 관련, 이번 작업과 무관)만 출력.
5. `python3 tools/qa/validate_tables.py`: **PASS** —
   `items=64 affixes=20 drop_tables=7 monsters=7 farming_sources=8 blueprints=6 pools=2
   world_objects=17 quests=15`.

## 남은 이슈 / game-designer·후속 확인 필요

- `Tuning.FACING_AXIS_SWITCH_BIAS(1.3)`, `Tuning.ATTACK_MOVE_INPUT_BLEND_RATIO(0.35)`,
  `Tuning.MONSTER_HP_BAR_FADE_DELAY_SEC(2.5)`, `Tuning.MONSTER_ATTACK_VFX_MARGIN_PX(2.0)`
  모두 `_balance_todo` 취급 — 실측 없이 문서 제안 범위 중간값을 채택했다. 다음 플레이테스트
  결과를 보고 game-designer가 확정하거나 조정해야 한다.
- `attack_left`의 flip_h 좌우 비대칭 표현(문서 §1.3, 우선순위 낮음)은 이번엔 미적용 —
  적용하려면 `AnimatedSprite2D.flip_h`를 코드에서 방향별로 직접 토글하는 작업이 필요하다.
- `elite_goblin_captain`의 `attack_vfx_offset_px=12.5`는 문서 권장 범위(12~13)의 하단에
  가깝고, `elite_bunchi_spawn`의 11.5는 권장 범위(11~12) 상단에 가깝다 — 둘 다 범위 안이지만
  인게임 육안 확인 후 ±1px 조정 여지는 남아 있다(문서 §4가 이미 허용한 재량 범위).
