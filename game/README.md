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
전환은 상태 안에서 `finished.emit(&"Move", {})`. 현재 `Idle`, `Move` 두 개. `Attack`/`Roll`/`Hurt`/`Dead` 는
같은 방식으로 스크립트 추가 + 노드 추가만 하면 된다.

## 남은 작업 (다음 태스크)
- 전투: 공격/구르기/가드/피격 상태, 히트스톱·넉백·카메라 셰이크(접근성 배율), 스태미나.
- 월드: LDtk 맵 임포트 → 64×64 청크 3×3 활성화 스트리밍 (`Tuning.CHUNK_TILES`, `ACTIVE_CHUNK_RADIUS`).
- HUD (`scenes/ui/`) — `ui/theme.tres` 적용.
