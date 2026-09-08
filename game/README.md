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
| `GameState` | `scripts/core/game_state.gd` | 세이브/부활 전역 상태(M1-2). `last_waystone`(D-28 부활 기준점), `death_count`(디버그), `in_boss_encounter`(D-23 자리표시 플래그, M2 훅) |
| `PhantomCameraManager` | addons/phantom_camera | Phantom Camera 플러그인이 요구 |
| `DialogueManager` | addons/dialogue_manager | Dialogue Manager 플러그인이 요구 |

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
- **DebugHud**: 스태미나 라벨이 잔량 비율에 따라 색이 바뀌고(`Events.player_stamina_insufficient` 발신 시
  빨갛게 깜박임), 상태 줄에 `GUARD`/`JUST-GUARD!`/`ROLL`/`IFRAME` 플래그와 사망 횟수(`GameState.death_count`)를
  표시한다.

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

## 남은 작업 (다음 태스크, M2)
- 전투: 강공격/차지, 스킬 슬롯, 무기별 가드 가능 여부(현재는 항상 가드 가능 — S2-1c 전제 "방패/가드 가능
  무기 장착"은 장비 시스템 없어 미적용).
- 월드: LDtk 맵 임포트 → 64×64 청크 3×3 활성화 스트리밍 (`Tuning.CHUNK_TILES`, `ACTIVE_CHUNK_RADIUS`).
- HUD (`scenes/ui/`) — `ui/theme.tres` 적용 및 정식 게이지 비주얼(현재 `DebugHud`는 텍스트/색상만).

## M1 게이트 플레이테스트 — 실행 방법·조작 요약

`godot --path game`로 실행(또는 에디터에서 F5) — `scenes/main/Main.tscn`이 자동으로 뜬다. 초원 배경음
(`31 - Sunny.ogg`)이 곧바로 흘러나오고, 슬라임 3·뿔토끼 2·버섯돌이 1·비석 1이 겹치지 않게 배치돼 있다.
조작은 **WASD/화살표**로 이동, **마우스 좌클릭**(`attack`)으로 3타 콤보, **Space**(`roll`)로 구르기,
**Shift**(`guard`)를 누르고 있으면 가드(적중 직전 0.1초 안에 누르면 저스트 가드), **F**(`interact`)로
비석 활성화(부활 지점 등록)다. 확인 포인트: 뿔토끼는 근접하면 잠깐 웅크렸다가 빠르게 돌진하니 정면에서
가드/구르기로 받아보고, 버섯돌이는 근접 접촉 후 자리를 벗어나지 않으면 바닥 장판에서 계속 지속 피해를
받는지(무적 중에도 깎이는지) 확인한다. 화면 하단 `DebugHud`가 HP/스태미나·상태 플래그(`GUARD`/
`JUST-GUARD!`/`ROLL`/`IFRAME`)·사망 횟수를 실시간으로 보여준다. 몬스터를 3종 다 만나려면 맵 중앙에서
사방으로 조금씩 이동하며 탐색하면 된다(슬라임은 근처, 뿔토끼는 좌우로 더 멀리, 버섯돌이는 아래쪽).
