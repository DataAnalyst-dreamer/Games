# 《이슬란드 연대기》 Godot 프로젝트

Godot **4.4.1** (gl_compatibility 렌더러) 기준. 기획 문서는 저장소 루트 `docs/` 참조
(`docs/GDD-도트액션RPG-기획안.md`, `docs/brd/`, `docs/specs/`).

## 열기 / 실행

```bash
# 에디터로 열기
godot --path game --editor

# 게임 실행 (메인 씬: scenes/main/Main.tscn)
godot --path game
```

`.godot/`(임포트 캐시)는 커밋하지 않고, `*.import`·`*.uid` 메타 파일은 **커밋한다**.
새로 clone 한 직후에는 아래 임포트 명령을 한 번 돌리거나 에디터를 한 번 열어야 한다.

## 헤드리스 검증 (커밋 전 필수)

```bash
GODOT=godot   # 4.4.1 바이너리 경로

# 1) 임포트 생성 — 에러 없어야 함 (종료 시 "PagedAllocator" 메시지는 엔진 자체 로그, 무시)
$GODOT --headless --path game --import

# 2) GUT 단위 테스트 — 전부 통과해야 함
$GODOT --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
#    설정 파일을 쓰려면: -gconfig=res://tests/.gutconfig.json

# 3) 메인 씬 2초(120프레임) 실행 — 스크립트 에러 없어야 함
$GODOT --headless --path game --quit-after 120
```

새로 clone 한 직후의 **첫** `--import` 에서는 에디터 플러그인(GUT 등)이 아직 임포트되지 않은
자기 폰트를 쓰면서 `Parameter "fd" is null` 이 여러 줄 찍힐 수 있다. 두 번째 실행부터는 사라진다.

## 폴더 규칙

| 경로 | 내용 |
|---|---|
| `scenes/main/` | 부팅·메인 씬 (`Main.tscn`) |
| `scenes/player/` | 플레이어 씬 |
| `scenes/world/` | 월드·청크·맵 씬 |
| `scenes/ui/` | HUD·메뉴 씬 |
| `scripts/core/` | 자동로드(Data, Events) 등 엔진 수준 코어 |
| `scripts/player/` | 플레이어 스크립트 + `states/` 상태머신 상태들 |
| `scripts/entities/` | 몬스터·NPC·오브젝트 (데이터 + 씬 상속으로 추가) |
| `scripts/systems/` | 월드 스트리밍, 전투, 인벤토리 등 시스템 |
| `scripts/tuning.gd` | 테이블화 전 임시 상수 **유일한** 보관처 |
| `data/` | 밸런스 테이블 JSON (`combat.json` …). 기획자 소유 |
| `maps/` | LDtk 프로젝트·맵 파일 |
| `ui/` | 테마(`theme.tres`)·공용 UI 리소스 |
| `assets/` | 아트·사운드. `assets/third_party/`는 CC0 외부 팩 (NOTICE.md 참조) |
| `assets_local/` | 재배포 금지 애셋 — git 제외 |
| `tests/unit/` | GUT 테스트 (`test_*.gd`) |
| `addons/` | GUT, Phantom Camera, Aseprite Wizard, Dialogue Manager, LDtk Importer |

### 밸런스 수치 규칙 (F8-4)
- 코드에 숫자를 직접 쓰지 않는다. `Data.get_value("combat", "roll.iframes_sec")` 로 읽는다.
- 아직 테이블이 없는 값은 `scripts/tuning.gd` 에만 두고 "테이블 이관 예정" 주석을 단다.
- 새 테이블은 `data/<이름>.json` 으로 추가하고 `scripts/core/data.gd` 의 `REQUIRED_SCHEMA` 에 필수 키를 등록한다.
- JSON 안의 `_comment` / `_balance_todo` 키는 문서용이며 코드는 읽지 않는다.

### 텍스트 / 로컬라이징 키 규칙 (아직 텍스트 없음)
- 화면에 나가는 문자열은 코드에 직접 쓰지 않고 `tr("KEY")` 로 참조한다.
- 키 형식: `<영역>.<대상>.<필드>` 소문자 snake_case. 예)
  `ui.hud.stamina`, `item.sword_iron.name`, `item.sword_iron.desc`, `npc.priest.greet_01`, `quest.q001.title`.
- 번역 소스는 `data/locale/<lang>.csv` (Godot CSV 번역 임포트) 로 둘 예정. 대사는 Dialogue Manager `.dialogue` 파일.

### 아트 규칙
- 프로토타입은 Ninja Adventure 16px 팩(`assets/third_party/ninja_adventure/`)을 쓴다. 원작 아트 전환 시
  GDD 9장 기준(타일 32px, 캐릭터 32×48)으로 `Tuning.TILE_SIZE_PROTOTYPE`·카메라 줌·이동 속도를 재조정한다.
- 텍스처 필터는 프로젝트 기본이 nearest 이고 2D 트랜스폼/버텍스 픽셀 스냅이 켜져 있다.
- 폰트: Galmuri (`assets/fonts/galmuri/`), `.import` 에서 안티앨리어싱 off·힌팅 none·서브픽셀 off 로 고정.
  `ui/theme.tres` 가 Galmuri11 을 기본 폰트로 지정한다. 프로젝트 전역 테마로는 등록하지 않았으므로
  (첫 임포트 순서 문제 회피) UI 루트 Control 에 `theme = preload("res://ui/theme.tres")` 로 붙인다.

## 자동로드 (project.godot `[autoload]`)

| 이름 | 스크립트 | 역할 |
|---|---|---|
| `Data` | `scripts/core/data.gd` | 부팅 시 `res://data/*.json` 전부 로드 → `Data.tables["combat"]`, `Data.get_value(table, "a.b.c", default)`. 필수 키 누락 시 개발 빌드는 `push_error`+`assert`, 릴리즈는 경고 후 기본값 대체 |
| `Tuning` | `scripts/tuning.gd` | 임시 상수 (스틱 데드존, 애니 FPS, 카메라 줌, 청크 크기 등) |
| `Events` | `scripts/core/events.gd` | 전역 시그널 버스 (`player_damaged`, `enemy_died`, `item_dropped`, `hitstop_requested` …) |
| `GameState` | `scripts/core/game_state.gd` | 세이브/부활 + 인벤토리/장비/골드 전역 상태(M1-2, M2-1). `last_waystone`(D-28 부활 기준점), `death_count`(디버그), `in_boss_encounter`(D-23 자리표시 플래그, M2 훅), `inventory`/`equipment`/`gold`/`mailbox`(F3-1·F3-2, D-10/D-11/D-12) |
| `Metrics` | `scripts/core/metrics.gd` | 플레이테스트 계측 로깅(M1-4). Events 구독만으로 사망·구르기 성공률·저스트 가드 성공률·몬스터별 처치/TTK·플레이어 피격/피해·콤보 3타 완주 횟수를 집계. `Metrics.summary()`가 Dictionary 반환(향후 HUD가 읽음). 순수 계산은 `scripts/systems/metrics_calc.gd`(`MetricsCalc`, GUT 테스트 대상) |
| `AudioManager` | `scripts/core/audio_manager.gd` | BGM/SFX 재생 (M1-3) |
| `PhantomCameraManager` | addons/phantom_camera | Phantom Camera 플러그인이 요구 |
| `DialogueManager` | addons/dialogue_manager | Dialogue Manager 플러그인이 요구 |

## 플레이테스트 계측 로그 (M1-4)

`Metrics` 오토로드가 5분마다 + 세션 종료 시(창 닫기/`--quit-after` 등 엔진 종료) 아래 경로에
JSON을 **덮어쓰기 저장**하고(파일명은 세션 시작 시각 1개로 고정 — 5분마다 새 파일이 쌓이지
않는다), 콘솔에도 요약을 `print()`한다.

- **파일**: `user://playtest/session_<세션 시작 유닉스초>.json`
- **테스터 식별**: 실행 인자 `--tester=<이름>` (예: `godot --path game --tester=hong`) 또는
  이전에 저장된 `user://playtest/tester.txt`. 둘 다 없으면 `"anon"`. `--tester=`로 실행하면
  다음번을 위해 `tester.txt`에도 자동 저장된다.
- **`user://`의 실제 OS 경로** (`config/name`="이슬란드 연대기 (Chronicles of Isleland)" 기준):
  - Windows: `%APPDATA%\Godot\app_userdata\이슬란드 연대기 (Chronicles of Isleland)\playtest\`
  - macOS: `~/Library/Application Support/Godot/app_userdata/이슬란드 연대기 (Chronicles of Isleland)/playtest/`
  - Linux: `~/.local/share/godot/app_userdata/이슬란드 연대기 (Chronicles of Isleland)/playtest/`
- **수집 항목**(`docs/qa/m1-gate-playtest.md` §4 스펙): 세션 길이·사망 횟수, 구르기 시도/성공
  (무적 구간 중 피격 없이 넘긴 시도)/성공률, 저스트 가드 시도(가드 상태 피격 총횟수)/성공/성공률,
  일반 가드 횟수, 몬스터 종별 처치 수·평균 TTK(최초 피격→사망), 플레이어 피격 횟수·총 피해,
  콤보 3타(피니셔) 완주 횟수(입력 체이닝 기준, 적중 여부 무관).
- 테스터에게 파일을 요청할 때는 위 폴더의 `session_*.json`을 전달받으면 된다(`tester.txt`는
  개인 식별용이라 공유 불필요).

## 입력 액션 (GDD 4.1, D-37 / 패드는 Xbox 레이아웃)

| 액션 | 키보드·마우스 | 패드 |
|---|---|---|
| `move_left/right/up/down` | WASD, 화살표 | 왼스틱 |
| `attack` | 마우스 좌 | X |
| `heavy_attack` | 마우스 우 | RT |
| `roll` | Space | B |
| `guard` | Shift | LT |
| `skill_1` / `skill_2` | Q / E | LB / RB |
| `quick_1~4` | 1~4 | 십자키 상/우/하/좌 |
| `interact` | F | A |
| `menu` | Tab | Back(Select) |
| `pause` | Esc | Start |
| `map` | M | 우스틱 클릭(R3) |
| `mount_call` | H | 왼스틱 클릭(L3) |

## 플레이어 상태머신

`scenes/player/Player.tscn` → `StateMachine`(`scripts/player/state_machine.gd`) 아래 자식 노드 하나가 상태 하나.
각 상태는 `scripts/player/states/state.gd`(`PlayerState`)를 상속한 별도 스크립트이며 노드 이름이 상태 이름이다.
전환은 상태 안에서 `finished.emit(&"Move", {})`. 현재 `Idle`/`Move`/`Attack`(3타 콤보)/`Hurt`/`Dead`/
`Roll`/`Guard` 일곱 개(M1-2에서 `Roll`/`Guard` 추가). 구르기 발동 공통 로직(`try_enter_roll()`)과
회복 배율 훅(`get_stamina_regen_multiplier()`)은 `state.gd` 베이스에 있어 모든 상태가 공유한다.

## 전투 기초 (M1-1)

- **3타 콤보**: `scripts/player/states/attack.gd` + `scripts/systems/combo_state.gd`(입력 버퍼/유예/피니셔
  후딜 타이밍을 담당하는 순수 로직, GUT 테스트 대상). 공격 프레임이 없는 Knight 시트 대신 무기 스프라이트
  (`WeaponPivot`)를 회전시켜 휘두름을 표현한다 — pixel-artist에게 전용 공격 프레임 요청 필요(완료 보고 참고).
- **히트박스/허트박스**: `scripts/systems/hitbox.gd`·`hurtbox.gd`(Area2D 재사용 컴포넌트, 팀 구분, 중복 타격
  방지). `monitoring` 토글은 반드시 `set_deferred`로 한다 — 물리 신호 콜백 도중 즉시 바꾸면 다음 충돌이
  통째로 씹히는 버그가 난다(직접 겪은 문제, 재발 방지용 메모).
- **타격감 패키지**: `scripts/systems/hit_feel.gd`가 히트스톱(`hitstop.gd`, 개별 노드 `process_mode` 일시
  정지 — `Engine.time_scale` 미사용)·넉백(Tween 기반 위치 보간)·흰 플래시(`hit_flash.gd`)·데미지 숫자
  (`scenes/effects/DamageNumber.tscn`)·카메라 셰이크(`camera_shake.gd`, Phantom Camera Noise Emitter, 강공격/
  크리티컬 한정)를 한 번에 적용한다.
- **몬스터**: `scripts/entities/monster_base.gd`(idle/patrol/chase/telegraph/attack/hurt/dead 상태머신, 데이터
  주도 — `monster_id`로 `monsters.json` 조회). 신규 몬스터는 이 스크립트를 그대로 쓰는 새 씬 + `monsters.json`
  항목 추가만으로 만든다. 현재 씬이 있는 몬스터는 `scenes/entities/monsters/Slime.tscn` 하나뿐(뿔토끼·버섯돌이는
  데이터만 존재, 씬은 이후 태스크).
- **속성 상성**: `data/elements.json`(D-50: 단일 소스) + `scripts/systems/element_calc.gd`(순수 함수, GUT 테스트).
- **HP/스태미나**: `scripts/player/resources.gd`(순수 로직). `tick(delta, regen_multiplier)`이 상태별
  회복 배율(가드 중 0.5배 등)을 받는다. `roll_cost_with_dex(base, dex)`는 DEX 경감식(D-45, 순수 static
  함수) — stats 시스템이 없어 호출부(`Player.get_roll_cost()`)는 전부 dex=0으로 고정한다.

## 구르기·가드·사망/부활 (M1-2)

- **구르기**: `scripts/player/states/roll.gd` + `scripts/systems/roll_calc.gd`(무적/종료 판정 순수 로직,
  GUT 테스트 대상). 거리·시간 모델(D-43: `roll.distance_px / roll.duration_sec`로 속도 역산, 등속 이동).
  무적은 Hurt와 동일한 `Player.start_iframes()`를 재사용해 상태 전환과 무관하게 지속시킨다. 잔상 이펙트는
  전용 아트가 없어 `scripts/systems/roll_ghost.gd`가 현재 스프라이트 프레임을 복제·페이드하는 방식으로
  대체(pixel-artist TODO). 발동 공통 로직은 `PlayerState.try_enter_roll()`(스태미나 부족 시
  `Events.player_stamina_insufficient` 발신) — Idle/Move/Guard(항상)와 Attack(피니셔 후딜 프레임 10 이후,
  `ComboState.can_roll_cancel()`)에서 호출한다.
- **가드/저스트 가드**: `scripts/player/states/guard.gd` + `scripts/systems/guard_calc.gd`(판정 순수 로직).
  가드 버튼을 누른 뒤 `guard.just_guard_window_sec`(0.1s, D-05) 이내에 맞으면 저스트 가드(피해 0·스태미나
  소모 없음·`Hitbox.stagger_requested` 신호로 공격자에게 경직 요청), 그 밖엔 일반 가드(칩데미지
  `guard.chip_damage_ratio`, 히트당 `stamina.costs.guard_hit` 소모 — 스태미나 부족 시 이번 타격은
  무가드로 처리, 제안 규칙). 실제 분기는 `Player._on_hurtbox_hurt()`가 현재 상태를 `GuardState`로 캐스트해
  처리한다(Hurtbox는 "맞았다"는 사실만 전달). 가드 중 이동 배율(`guard.move_speed_multiplier`)·스태미나
  회복 배율(`stamina.guard_regen_multiplier`)은 각 0.5 — docs/specs/combat-tuning-m1-addendum.md §7-1/7-2가
  독립 역산으로 재확인(공식 D-번호 배정 전까지 `_balance_todo` 유지). `Hitbox.unguardable`은 가드 불가
  공격(잡기 등) 플래그 — 현재 M1 몬스터 3종엔 해당 패턴 없어 실제 연출 훅은 미구현.
- **사망·부활(F8-2, D-28)**: `scripts/player/states/dead.gd`가 `Tuning.DEATH_RESPAWN_DELAY_SEC`(1.0초)
  동안 짧은 페이드를 재생한 뒤 `Player.respawn()`을 호출 → `GameState.last_waystone` 위치로 텔레포트하고
  HP/스태미나를 전량 채운다. `scenes/world/Waystone.tscn`(`scripts/world/waystone.gd`)이 Area2D + `interact`
  입력으로 활성화되며 `GameState.set_last_waystone(self)`를 기록한다(Main.tscn에 1개 배치). 골드 페널티
  (D-25)와 보스전 예외(D-23)는 골드/보스 시스템이 없어 각각 `Events.player_respawned` 훅 주석과
  `GameState.in_boss_encounter` 플래그 자리만 남겨 두었다.
- **DebugHud**: (M1-5에서 `Hud`로 대체됨 — 아래 HUD 절 참고) 스태미나 라벨이 잔량 비율에 따라 색이
  바뀌고(`Events.player_stamina_insufficient` 발신 시 빨갛게 깜박임), 상태 줄에 `GUARD`/`JUST-GUARD!`/
  `ROLL`/`IFRAME` 플래그와 사망 횟수(`GameState.death_count`)를 표시하던 텍스트 전용 씬. 이제 이 로직은
  `Hud`의 F3 디버그 패널이 그대로 흡수한다(`scenes/ui/DebugHud.tscn`/`debug_hud.gd`는 더는 Main.tscn이
  참조하지 않지만 참고용으로 남겨 둠).

## 몬스터 3종·사운드 (M1-3)

- **뿔토끼(horn_rabbit)**: Racoon 대역(`scenes/entities/monsters/HornRabbit.tscn`). 예고(0.6s) 후
  `dash_speed_px`(200)로 `dash_duration_sec`(0.3s) 동안 직진 돌진 — 이동 중 정적 콜라이더와 충돌하면
  `STUNNED` 상태로 전이해 `Tuning.DASH_WALL_STUN_SEC`(0.5s, 제안값) 동안 기절한다. HP27/ATK15.
- **버섯돌이(mushroom)**: Mushroom 대역(`scenes/entities/monsters/Mushroom.tscn`). 고정형(`patrol_radius_px`
  =0), 예고(0.7s) 후 접촉 즉시 12 데미지 + `aoe_radius_px`(32) 반경 포자 장판을
  `Tuning.SPORE_PATCH_DURATION_SEC`(2.0s, 제안값) 동안 전개, 1초마다 `atk_tick_per_sec`(4)만큼 지속
  피해 — 이 지속 피해는 `Hitbox.ignores_iframes`로 플레이어 무적(구르기/피격 직후)에도 적용된다(D-61 예정).
  HP45/ATK12.
- 몬스터 AI 공통 5필드(`aggro_range_px`/`melee_range_px`/`attack_recovery_sec`/`patrol_radius_px`/
  `leash_range_px`)가 `monsters.json` 정식 필드로 승격됐다(addendum §4). `monster_base.gd`는 공격 종료 후
  항상 `RECOVER` 상태를 거쳐 `attack_recovery_sec`을 적용한 뒤에야 `CHASE`/`IDLE`로 돌아간다.
- **AudioManager**(`scripts/core/audio_manager.gd`, 오토로드): `play_sfx(id, position, pitch_var)`/
  `play_bgm(id, fade)`. 데이터는 `data/audio_sfx.json`·`data/audio_bgm.json`(sound-map-m1.md 매핑),
  버스 5종은 `default_bus_layout.tres`(Master/BGM/SFX/UI/Ambient). 헤드리스(`--headless`)에서는 실제
  재생 대신 `print()` 로그만 남긴다. 초원 BGM은 부팅 시 자동 재생, 몬스터가 CHASE/TELEGRAPH/ATTACK
  상태이면 0.25초 폴링으로 전투 BGM으로 크로스페이드한다(전투 이탈 후 3.0s 유예).

## 인게임 HUD (F7-1, M1-5)

`scenes/ui/Hud.tscn` + `scripts/ui/hud.gd`가 `DebugHud`를 대체해 Main.tscn에 배치된다. 좌상단
HP·스태미나 바(HP 25% 이하 점멸+화면 비네트, 색약 모드는 대각선 해치 패턴)와 버프 아이콘 빈 컨테이너,
상단 중앙 추적 퀘스트 한 줄(현재 빈 문자열), 우상단 미니맵 토글(`map` 액션, M키/패드 select),
하단 스킬 슬롯 2개+퀵슬롯 4개(십자키 배치 — 상=1/우=2/하=3/좌=4, D-47), 좌하단 획득 로그(`item_picked_up`/
`gold_changed` 이벤트, 3초 페이드, 최대 4줄), 보스 HP바(평시 숨김, `Events.boss_started`/`boss_defeated`
로 표시/숨김 — 지시문의 `boss_encounter_started`는 존재하지 않아 기존 시그널을 재사용, `docs/ui/hud.md`
참고)를 담당한다. `F3`로 여닫는 디버그 패널이 옛 DebugHud의 HP/스태미나/콤보/상태/사망수 텍스트를
그대로 흡수했다. 나무 프레임은 `ninja_adventure` Theme Wood 나인패치, 양피지 배경은 `parchment_gui`
패널 크롭을 사용하며 색·스타일은 전부 `ui/theme.tres` 한 곳에서 정의한다(등급 6색·HUD 색·폰트 2단계
모두 포함). 상세 와이어프레임·상태표는 `docs/ui/hud.md`.

`scripts/core/settings.gd`(오토로드 `Settings`)가 `user://settings.json`에 접근성·오디오 설정(화면
흔들림 4단계 `[0, 0.5, 1.0, 1.5]`, 데미지 숫자 on/off(D-07 기본 켜짐), 색약 모드, 폰트 크기 2단계,
마스터/BGM/SFX 볼륨)을 저장한다(D-64). `camera_shake.gd`는 이제 `Settings.get_shake_scale()`을,
`hit_feel.gd:spawn_damage_number()`는 `Settings.damage_numbers_enabled`를, `audio_manager.gd`는
`Settings.master_volume`/`bgm_volume`/`sfx_volume`을 각각 읽는다 — 값이 바뀌면 `Events.settings_changed`
로 전파된다.

## 드랍·인벤토리·장비 (M2-1, F3-1·F3-2)

- **데이터**: `data/{items,affixes,drop_tables,enhance}.json`(57/20/6/1개, game-designer
  소유, `docs/specs/items-and-drops-m2.md`)와 `data/{farming_sources,stats}.json`(8/1개,
  `docs/specs/elite-and-farming-m2.md`). `Data`(`scripts/core/data.gd`)가 부팅 시 필수
  테이블·필수 키(REQUIRED_SCHEMA)뿐 아니라 `_validate_items()`/`_validate_affixes()`/
  `_validate_drop_tables()`/`_validate_enhance()`/`_validate_stats()`/
  `_validate_farming_sources()`로 등급별 옵션 슬롯 규칙·LUK 계수 단조증가·드랍 확률
  합계 1.0·빈 드랍 풀 방지·강화 성공률(D-14)·재련 3회 상한(D-13)·`farming_sources.
  repeat_reward_table_ids[]`↔`drop_tables` 참조까지 개발 빌드에서 즉시 검증한다
  (`tools/qa/validate_tables.py`가 같은 규칙의 오프라인 버전 — 두 곳은 항상 같이
  갱신할 것). `monsters.json.drop_table_id`가 null이 아니면 `drop_tables.json`에
  실존해야 한다(D-67) — `goblin_scout`은 전용 테이블이 아직 없어 `null`(D-80).
- **LootSystem**(`scripts/systems/loot_system.gd`, 순수 로직·오토로드 아님): LUK
  곱연산 등급 판정(`compute_final_probabilities`/`pick_grade`, D-52 `drop_tables.json.
  _luck_formula` 단일 소스) → 그 등급 안에서 `entries.weight` 가중 추첨(`pick_entry`)
  → 장비면 `affix_slot_count`만큼 중복 없이 옵션 추첨(`roll_affixes`). 실제 게임
  진입점은 `roll_drop(drop_table_id, luck, rng?)`/`roll_gold(...)` — `Data` 오토로드
  테이블을 대신 읽어주는 편의 래퍼이고, 핵심 계산은 전부 static 함수라 GUT에서 직접
  테이블 딕셔너리를 넣어 테스트한다. ItemInstance는 Dictionary(`uid`/`item_id`/`grade`/
  `quantity`/`affixes`/`enhance_level`/`refine_left`).
- **드랍 스폰**: `scripts/systems/loot_spawner.gd`(Main.tscn에 배치된 평범한 Node,
  `Events.enemy_died` 구독) → 골드는 `GameState.add_gold()`로 즉시 지급, 아이템은
  `scenes/world/ItemDrop.tscn`(`scripts/world/item_drop.gd`)으로 스폰. 등급 색 외곽선은
  `Rarity.color_of(Rarity.from_string(grade), theme)`(`ui/theme.tres` 단일 소스),
  카테고리별 placeholder 아이콘은 `ninja_adventure` Items/Ui 팩에서 대표 이미지 1장씩
  매핑(개별 아이템 57종 아이콘은 pixel-artist TODO). 접근 시 자동 획득(Area2D,
  Waystone과 동일한 `collision_mask=2`) → `GameState.pickup_item()`. 등급별 드랍 SFX는
  `drop_common`..`drop_legendary` id 훅만 걸어 두었다(`audio_sfx.json`에 없으면
  `AudioManager.play_sfx()`가 조용히 no-op — sound-designer가 채우면 코드 변경 없이
  소리가 남).
- **Inventory**(`scripts/systems/inventory.gd`, 순수 로직): 기본 40칸 + 백팩으로 최대
  80칸(D-11, `set_backpack_bonus()`). 재료/소모품은 `stack_max`까지 같은 슬롯에 합치고
  (`AddResult.STACKED`), 장비는 절대 스택하지 않는다. 가득 차면 인벤토리를 바꾸지 않고
  `AddResult.FULL`만 반환 — 호출부(`GameState.pickup_item()`)가 D-10대로 우편함(`
  GameState.mailbox`)에 넣고 `Events.item_mailed`를 쏜다(정상 획득은 `item_picked_up`).
  `sort_slots(items_table)`가 등급→종류→id 순으로 자동 정렬한다.
- **Equipment**(`scripts/systems/equipment.gd`, 순수 로직): 8슬롯(무기/보조/투구/갑옷/
  신발/`ring1`/`ring2`/부적) — 반지 슬롯 2개가 독립적이라 동일 반지 중복 장착(D-12)이
  자연스럽게 허용된다. `compute_stats(equipped, items_table, enhance_table)`이 무기
  `atk_min~max` 평균·방어구 `defense_min~max` 평균에 강화 배율(`enhance.json.
  enhance_levels."+N".stat_multiplier`)을 곱하고, `atk_pct`/`defense_flat`/
  `max_hp_flat`/`move_speed_pct` 옵션을 합산해 `{attack, defense, max_hp, speed_pct}`를
  반환한다. `GameState.equip_item()`/`unequip_item()`이 이 값을
  `Player.apply_equipment_stats()`로 넘겨 `resources.max_hp`·`walk_speed`를 갱신하고,
  `Player.get_attack_power()`(`Tuning.PLAYER_BASE_ATTACK + equip_attack_bonus`)를
  `attack.gd`의 콤보 데미지 계산이 그대로 소비한다. 방어력을 실제 피해 감소로 쓰는
  공식은 아직 결정되지 않아(`items-and-drops-m2.md`/`elite-and-farming-m2.md`
  결정 요청 A, D-74 예정 `_balance_todo`) `equip_defense`는 보관만 한다. STR 요구치
  (`items.json.str_requirement`)는 stats 시스템 확정 전이라 `Equipment.can_equip()`에
  훅 주석만 남겼다.
- **GameState 확장**: `inventory`/`equipment`/`gold`/`mailbox`를 들고 있고
  `pickup_item()`/`add_gold()`/`equip_item()`/`unequip_item()`/`get_player_luck()`
  (LUK 스탯 미구현이라 0.0 고정, stats.json 확정 시 이 함수만 고치면 됨)을 제공한다.
  `to_dict()`/`from_dict()`로 세이브용 Dictionary 변환까지만 준비했다(디스크 입출력은
  M2-4 세이브 시스템 범위).
- **디버그**: `Hud`의 좌하단 획득 로그가 `item_picked_up`/`gold_changed`를 그대로
  표시한다(기존 M1-5 기능 재사용). `F4`(`debug_inventory_dump` 액션)를 누르면
  `GameState.dump_inventory_debug()`가 인벤토리 슬롯·장비·골드·우편함 요약을 콘솔에
  텍스트로 덤프한다(정식 인벤토리 UI는 M2-2).
- **아이템 아이콘**(소규모 추가): `data/item_icons.json`(asset-wrangler, 58개 배정,
  `docs/art/item-icon-map.md`)을 `scripts/ui/item_icon.gd`(`ItemIcon.resolve(item_id)`)
  로 조회해 `ItemDrop`(필드 드랍)과 `Hud` 획득 로그가 카테고리 placeholder 대신 아이템별
  아이콘(경로+region이 있으면 AtlasTexture, 없으면 원본 그대로)을 우선 쓰도록 연결했다.
  표에 없는 아이템은 기존 카테고리 대표 아이콘으로 자동 폴백한다.
- **드랍 SFX 레이어**(소규모 추가): `item_drop.gd:_play_drop_sfx()`가 등급별
  `drop_<grade>` 기본 재생에 더해 epic은 `drop_epic_layer`, legendary는
  `legendary_drop_sparkle`을 같은 프레임에 추가로 재생해 2레이어로 겹쳐 들리게 한다
  (audio-designer `audio_sfx.json`/`docs/audio/sound-map-m1.md` §4, `goblin_whistle`
  훅은 아래 정예 절 참고).

## 정예 2종 · 고블린 정찰병 · 정예 리스폰 (M2-3, F6-3/D-15)

- **`goblin_scout`(일반, 원거리 경보형)**: `scenes/entities/monsters/GoblinScout.tscn`
  (Ninja Adventure `Actor/Monster/Cyclope` 대역 — 전용 고블린 시트가 팩에 없어 소형
  외눈 인간형으로 대체, 완료 보고 참고). `attack_pattern_id="ranged_dart"` —
  `monster_base.gd`가 접촉 히트박스 대신 `scenes/effects/Projectile.tscn`
  (`scripts/systems/projectile.gd`, CharacterBody2D+Hitbox 재사용, 벽 충돌/대상 명중/
  `Tuning.RANGED_DART_LIFETIME_SEC` 중 먼저 오는 조건에 소멸)을 발사한다. 호루라기
  증원 호출(`whistle_*`, `docs/specs/elite-and-farming-m2.md` §1-1-1)은 상태머신에
  `WHISTLE` 상태를 추가해 구현 — IDLE/PATROL/CHASE 중 플레이어가 `aggro_range_px`
  안이고 쿨다운이 다 찼으면 `whistle_cast_sec` 동안 시전(피격 시 여느 상태처럼 즉시
  HURT로 끊겨 카운터플레이 성립) 후 `whistle_range_px` 안의 `whistle_summon_pool`
  대상을 강제로 CHASE시킨다. SFX 훅은 `goblin_whistle`(audio-designer 제작 완료).
- **정예 공통**(`MonsterBase`, `tier=="elite"`): 이름표(`name_ko`)+등급 테두리 HP바를
  디버그 수준(Label+ColorRect 2장)으로 자동 표시하고, 처치 시 `Events.enemy_died`와
  별도로 `Events.elite_died`를 추가 emit한다(`Metrics`가 구독해 `elite_kills_by_monster`
  로 집계, `Metrics.summary().elite_kills`). `elite_base_monster_id`는 참고용 필드로만
  읽는다(배율은 monsters.json에 이미 계산돼 있음).
- **`elite_goblin_captain`**: `EliteGoblinCaptain.tscn`(Cyclope2 대역, 콜리전은 그대로
  두고 스프라이트만 1.3배 확대 — 판정 크기를 키우면 회피가 불공정해지므로 시각 효과만
  분리). 호루라기 범위/인원이 확대된 값을 그대로 쓰고(데이터 주도), HP
  `wave_trigger_hp_pct`(0.5) 이하 도달 시 1회(`wave_once_per_life`) `WAVE` 상태로
  전이해 `wave_cast_sec` 시전 후 `wave_summon_count`(3)마리를 `whistle_range_px` 반경
  안에 겹치지 않게(`MonsterAiCalc.pick_non_overlapping_offsets`) 스폰하고 즉시
  CHASE시킨다.
- **`elite_bunchi_spawn`**: `EliteBunchiSpawn.tscn`(슬라임 스프라이트 재사용, 1.4배
  확대+보라 틴트로만 구분 — 신규 애셋 없이 골격 재사용). 사망 시
  `on_death_split_monster_id`("slime")를 `on_death_split_count`(2)마리
  `on_death_split_spawn_radius_px` 반경에 겹치지 않게 스폰한다. 분열체는
  `suppress_loot_drop=true`로 스폰되어 `loot_spawner.gd`가 드랍을 굴리지 않는다(부모만
  드랍) — 스폰된 개체는 일반 `slime` 데이터를 그대로 쓰므로(`on_death_split_*` 필드
  없음) 재귀 분열이 데이터 상 불가능하다.
- **정예 리스폰**(D-15): `scripts/systems/elite_spawner.gd`가 `farming_sources.json`의
  정예 2종을 `hartland.md` §5 좌표(임시 상수, `SPAWN_POS_GLOBAL_TILE`)에 고정 스폰하고,
  처치 시 `respawn_seconds`(1800초=30분)를 `GameState.elite_respawn_remaining_sec`에
  채운다. `GameState`에 신설된 `play_time_sec`(실제 플레이 시간 누적, `_process(delta)`
  가 매 프레임 더함 — 일시정지 중엔 엔진이 이 콜백 자체를 스킵해 자동으로 오프라인/
  일시정지 시간이 제외된다)가 같은 `_process()`에서 리스폰 카운트다운을 함께 깎는다.
  두 필드 모두 `to_dict()`/`from_dict()`로 세이브에 포함된다. `EliteSpawner`는
  `Main.tscn`(정예 2종을 이미 고정 배치해 둠, 아래 참고)에는 배치하지 않는다 — 같이
  쓰면 중복 스폰된다. 실제 오픈월드가 들어오면 레벨 루트에 이 노드 하나만 배치하면 된다.
- **Main.tscn 배치**: 기존 슬라임 3·뿔토끼 2·버섯돌이 1에 더해 `GoblinScout` 2마리
  (220,-80)/(-220,-60)와 정예 2종 각 1(`EliteGoblinCaptain1` (250,140),
  `EliteBunchiSpawn1` (-250,-140))을 아레나 가장자리에 배치했다.

## 남은 작업 (다음 태스크, M2)
- 전투: 강공격/차지, 스킬 슬롯, 무기별 가드 가능 여부(현재는 항상 가드 가능 — S2-1c 전제 "방패/가드 가능
  무기 장착"은 장비 시스템 없어 미적용).
- 월드: LDtk 맵 임포트 → 64×64 청크 3×3 활성화 스트리밍 (`Tuning.CHUNK_TILES`, `ACTIVE_CHUNK_RADIUS`).
- HUD (`scenes/ui/`) — 퀵슬롯·스킬 슬롯 실데이터 연동(F7-2 인벤토리/스킬 시스템 완성 후), 아이템명
  한글화, 미니맵 실제 지형 렌더(현재 placeholder 사각형).

## M1 게이트 플레이테스트 — 실행 방법·조작 요약

`godot --path game`로 실행(또는 에디터에서 F5) — `scenes/main/Main.tscn`이 자동으로 뜬다. 초원 배경음
(`31 - Sunny.ogg`)이 곧바로 흘러나오고, 슬라임 3·뿔토끼 2·버섯돌이 1·비석 1이 겹치지 않게 배치돼 있다.
조작은 **WASD/화살표**로 이동, **마우스 좌클릭**(`attack`)으로 3타 콤보, **Space**(`roll`)로 구르기,
**Shift**(`guard`)를 누르고 있으면 가드(적중 직전 0.1초 안에 누르면 저스트 가드), **F**(`interact`)로
비석 활성화(부활 지점 등록)다. 확인 포인트: 뿔토끼는 근접하면 잠깐 웅크렸다가 빠르게 돌진하니 정면에서
가드/구르기로 받아보고, 버섯돌이는 근접 접촉 후 자리를 벗어나지 않으면 바닥 장판에서 계속 지속 피해를
받는지(무적 중에도 깎이는지) 확인한다. 좌상단 `Hud` HP/스태미나 바로 상태를 확인하고, **F3**을 누르면
옛 DebugHud와 같은 HP/스태미나·상태 플래그(`GUARD`/`JUST-GUARD!`/`ROLL`/`IFRAME`)·사망 횟수 패널이
열린다. 몬스터를 3종 다 만나려면 맵 중앙에서
사방으로 조금씩 이동하며 탐색하면 된다(슬라임은 근처, 뿔토끼는 좌우로 더 멀리, 버섯돌이는 아래쪽).
