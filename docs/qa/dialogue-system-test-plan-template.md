# 대사 시스템 테스트 계획 템플릿

> 작성: qa-lead / 상태: **템플릿(선행 설계) — 대사 시스템 자체는 미착수(D-145 7단계 중 6번째)**.
> 이 문서는 코드·데이터·씬을 만들지 않는다. `docs/ui/dialogue-balloon.md`(UI 계약, v0.1,
> 구현 미착수 명시)와 기존 `smoke_quest_npc_panel.gd`/`smoke_quest_markers_and_log.gd`/
> `test_quest_system.gd`/GUT 관례를 사실 확인해 실제 착수 시 그대로 복붙 가능한 틀만 둔다.
> 사실은 파일에서 확인한 것만 적었고, 추측은 **(추정)** 표시했다.

## 0. 기준 사실 (코드 근거)

- `docs/brd/04-decisions.md` D-145: 7단계 로드맵 중 6번째가 "대사 시스템". 아직 순서가
  오지 않았다.
- 현재 유일한 "대사형" 팝업은 `game/scripts/ui/quest_npc_panel.gd`(`QuestNpcPanel`)이며
  퀘스트 수락/완료 전용이다. 타이프라이터·초상·선택지 없음(`docs/ui/dialogue-balloon.md`
  §0에 이미 이 사실이 명시돼 있다).
- `game/addons/dialogue_manager`(bramwelt Dialogue Manager)가 플러그인으로 켜져 있지만
  실제 호출부는 `events.gd` 주석 1줄뿐 — 미배선.
- `game/scripts/ui/ui_root.gd:120`: `hud.visible = not any_fullscreen_open` — 전체화면 UI가
  하나라도 열리면 HUD를 끄고, 전부 닫히면 다시 켜는 **단일 지점**. 대사 풍선이 이 집합에
  들어가는지는 `docs/ui/dialogue-balloon.md` §6-A "결정 필요"로 아직 남아 있다(추가 결정 필요
  항목, §5 참조).

## 1. 헤드리스 제약 (확인된 사실)

### 1.1 물리 시간 측정 규칙 — delta 아님, 물리 프레임 수로 센다

`smoke_quest_npc_panel.gd`(`_interact`, L61-64)와 `smoke_iso_actors.gd`(`SETTLE_PHYSICS_FRAMES`,
L20-22)가 공통으로 쓰는 관례:

```gdscript
for i in range(4): await get_tree().physics_frame
```

`--fixed-fps 60`(`smoke_quest_markers_and_log.gd` 헤더 주석의 실행 커맨드)로 고정 프레임을
쓰므로, "N 물리 프레임 대기"가 "N/60초 대기"와 동일하게 재현 가능하다. `await get_tree()
.create_timer(x).timeout`처럼 실제 delta 누적에 기대는 방식은 헤드리스 고정 프레임에서
프레임 드롭 없이도 타이밍이 어긋날 수 있으므로 이 저장소 관례에서 쓰지 않는다(smoke 전체에서
`create_timer` 기반 대기 사용 예 없음 — grep 확인).

대사 시스템에 적용 시: 타이프라이터가 "글자당 N프레임"처럼 프레임 단위로 설계돼야 이
관례로 검증 가능하다. 초당 글자 수(delta 누적) 방식이면 스모크가 실제 재생 속도가 아니라
프레임 수만 흉내 내는 간극이 생긴다 — **결정 필요 항목**(§5-4).

### 1.2 마우스 클릭은 Xvfb 필요 — 이 워크트리엔 파일이 없다(통합 격차, 사실)

`SmokeMenuMouse`(마우스/터치 조작, D-196)는 `stage/m5-int`/`claude/dot-action-rpg-design-cwwlgc`
브랜치에 커밋 `891f873`(도입)·`6d2bd97`(헤드리스 SKIP 가드 추가, 커밋 메시지: "클릭 전달은
Xvfb에서만")로 존재하지만, `git merge-base --is-ancestor 6d2bd97 HEAD` 결과 **NOT ANCESTOR** —
`stage/m6-int`(현재 워크트리)에는 병합되지 않았다. `git ls-files | grep menu_mouse`도 빈 결과.
즉 이 통합 브랜치에서 `SmokeMenuMouse`를 실행할 수 없다(**사실**). 대사 시스템의 마우스
클릭(풍선 선택지 클릭, D-196 패턴 재사용 예정 — `docs/ui/dialogue-balloon.md` §2 마지막 행)
스모크를 쓰려면 이 병합 격차부터 해소해야 한다 — 코드 수정 금지 규칙상 이번 작업에서는
고치지 않고 여기 기록만 한다.

일반 원칙(다른 캡처/마우스 스모크에서 확인): 실제 클릭 전달·렌더 검증은 `DisplayServer
.get_name() != "headless"`일 때만 되고, `xvfb-run -a -s "-screen 0 1920x1080x24" godot
--rendering-driver opengl3 ...`로 실행해야 한다(`smoke_iso_field_capture.gd` 헤더 주석).

### 1.3 Windows 경로 게이트가 있는 스모크 — 이 환경(Linux)에서 `quit(1)`

`OS.get_user_data_dir()`을 하드코딩된 `C:/Users/freer/AppData/Roaming/...` 리터럴과 비교해
불일치하면 `push_error` 후 `get_tree().quit(1)`하는 격리 가드가 있는 스모크 8개(grep
`"C:/Users"` 확인):

| 파일 | 하드코딩 경로(대표) |
|---|---|
| `smoke_quest_npc_panel.gd` | `...Games-QA-npc-greeting-20260913-story` |
| `smoke_quest_npc_late.gd` | 동일 경로 + 캡처 저장 경로도 `C:/Users/freer/...` 절대경로 |
| `smoke_quest_ui_save.gd` | `...Games-QA-quest-ui-save-20260913-story` |
| `smoke_object_observation_capture.gd` | `...Games-QA-object-observation-20260913-story` |
| `smoke_object_observation_save.gd` | 동일 |
| `smoke_ward_waystone.gd` | 2개 값 허용(`...ward-waystone-20260913-story` / `...-fixed-...`) |
| `smoke_quest_fhd_capture.gd` | `...Games-QA-quest-fhd-20260913-classes` |

이 8개는 **이 워크트리(리눅스, 이 사용자 홈)에서 그대로 실행하면 전부 exit(1)로 죽는다**
(추정 아님 — 문자열 비교가 무조건 실패하므로 결정론적). 원래 의도는 "매 스모크마다 전용
user:// 디렉터리로 격리"(`docs/qa/diagnostic-launch-guide.md` "프로세스·세이브 격리" 절과
같은 목적)인데, 그 디렉터리 값이 리터럴로 박혀 있어 다른 머신/CI로 못 옮긴다. 대사 시스템
스모크를 새로 쓸 때 **이 패턴을 그대로 베끼면 안 된다** — 아래 §5-1 결정 필요 항목.

### 1.4 `user://` 공유로 인한 동시 실행 충돌

위 8개가 전용 리터럴 경로를 쓰는 이유 자체가 "기본 `user://`를 공유하면 동시 실행 시 세이브
슬롯이 겹친다"는 문제의 대응이다(`diagnostic-launch-guide.md`: "매 -Play/-SelfTest마다 고유
play-sessions/GUID 아래 appdata... 새로 생성"). 그런데 이 8개 스모크 중 서로 다른 파일이
**같은 리터럴 값**을 쓰는 조합이 있다(`smoke_quest_npc_panel.gd`와 `smoke_quest_npc_late.gd`가
동일한 `Games-QA-npc-greeting-20260913-story`; `smoke_object_observation_capture.gd`와
`smoke_object_observation_save.gd`가 동일한 `Games-QA-object-observation-20260913-story`).
**즉 이 두 쌍은 순차 실행은 몰라도 병렬 실행하면 같은 `user://` 아래 세이브 파일에 동시에
쓸 수 있다(경합 가능, 추정 — 실제로 병렬 실행해 재현하진 않았음).** `SaveManager`가 파일
쓰기 중 락을 걸지 않는 한(코드 미확인, 이번 작업 범위 밖) CI를 여러 워커로 병렬화할 때
주의해야 한다. 대사 시스템 스모크도 같은 함정을 피하려면 파일마다 고유 디렉터리 리터럴을
복붙하지 말고, 스모크 이름 자체(스크립트 파일명)에서 파생한 값을 쓰는 헬퍼가 필요하다
(§5-1).

### 1.5 캡처 씬의 `[SKIP]` 관례

`DisplayServer.get_name() == "headless"`일 때 캡처(PNG 저장) 스모크는 실패시키지 않고
`print("[SKIP] 렌더러 없음 - xvfb-run 으로 실행해야 캡처된다")` 후 `get_tree().quit(0)`로
**정상 종료**한다(`smoke_iso_field_capture.gd`, `smoke_iso_capture.gd`,
`smoke_quarter_view_capture.gd`, `smoke_iso_actors_capture.gd`,
`smoke_quarter_view_b_capture.gd` 확인 — 전부 quit(0)). 반대로 `smoke_quest_rewards_ui.gd`/
`smoke_quest_tracker_arrow.gd`/`smoke_quest_marker_tracked.gd`는 캡처만 `[SKIP]`하고 나머지
로직 검증은 headless에서도 계속 돌려 PASS/FAIL을 낸다(캡처가 전체 스모크의 일부일 뿐인
패턴). 대사 시스템 캡처 스모크(초상·타이프라이터·선택지 강조 화면 확인용)도 이 두 번째
패턴(로직 검증은 headless로, 캡처만 조건부 SKIP)을 따라야 CI에서 유의미하다.

## 2. GUT 단위 테스트 후보 (순수 로직)

`test_quest_system.gd`의 관례(자동로드 대신 새 인스턴스 생성 + `before_each`/`after_each`로
`GameState` 스냅샷/복원, 실제 데이터 테이블 사용)를 그대로 재사용한다고 가정할 때, 대사
시스템 구현 시 다음이 **UI/렌더 없이** 순수 로직으로 뗄 수 있는 후보다(구현 전이므로 대상
클래스/함수명은 전부 **(제안)**):

1. **줄 진행 상태 머신**: `idle → typing → line_complete → (choice_pending | next_line |
   closed)`. 입력 없이 텍스트 하나 넣고 "typing 중 skip 누르면 즉시 line_complete", "이미
   line_complete면 다음 줄로" 두 갈래를 GDScript 값 비교만으로 검증 가능.
2. **선택지 4개 상한 강제**: `docs/ui/dialogue-balloon.md` §1 "4개 초과 콘텐츠는 제작
   단계에서 거부"가 실제 규칙이라면, 대사 리소스 로드 시점에 5번째 선택지가 있는 데이터를
   넣고 에러/거부 결과가 나오는지 — 렌더 없이 데이터만으로 검증 가능.
3. **로컬라이징 key 해석**: 이름표 key 포맷 `npc_<지방>_<이름>.name`(§1 표)이 실제 CSV에
   존재하는지 매핑 함수만 뗀 검사. `test_quest_system.gd`가 `act1_hartland.json`을 정본으로
   쓰듯, 대사 스크립트 리소스도 정본 파일을 그대로 로드해 key 누락을 찾을 수 있다.
4. **분기 선택 → story flag 반영**: `test_quest_system.gd::test_branch_choice_sets_outcome_flag`
   와 동일 패턴(`choose_branch` 후 `has_story_flag` 확인) — 대사 선택지가 퀘스트 분기와
   같은 story flag 저장소를 공유한다면(추정, `docs/ui/dialogue-balloon.md`에 명시 없음 —
   §5-2 결정 필요) 이 테스트를 그대로 복붙할 수 있다.
5. **초상 슬롯 접힘 로직**: 화자 없음(내레이션) → 슬롯 폭 0, 본문 폭 확장(§1 "제안, §6-B") —
   레이아웃 계산 함수만 뗄 수 있으면 픽셀 좌표 비교로 렌더 없이 검증.

## 3. 스모크 시나리오 템플릿 — 대사 시작→줄 넘김→선택지→퀘스트 반영→종료→HUD 복원

`smoke_quest_npc_panel.gd`(입력 시뮬레이션 헬퍼 `_action`/`_key`/`_pad_a`, `_check` 카운터,
`get_tree().quit(0 if failures==0 else 1)`)와 `smoke_quest_markers_and_log.gd`(`Main.tscn`
그대로 인스턴스화 + `QuestSystem.reset()`)의 관례를 그대로 따르는 골격(**의사코드**, 실제
클래스명은 구현 후 채움):

```gdscript
extends Node
# 실행: godot --headless --fixed-fps 60 --path game res://tests/smoke/SmokeDialogueFlow.tscn --quit-after 300
# 격리: §5-1 결정 이후 확정되는 방식으로 user:// 격리(리터럴 Windows 경로 복붙 금지, §1.3)

var _pass := 0
var _fail := 0

func _check(label: String, ok: bool) -> void: ...  # smoke_quest_npc_panel.gd 패턴 그대로

func _ready() -> void:
    QuestSystem.reset()
    var world := load("res://scenes/main/Main.tscn").instantiate()
    add_child(world)
    var ui: UiRoot = world.get_node("UiRoot")
    var hud_visible_before := ui.hud.visible

    # 1) 대사 시작 — NPC interact가 대사를 열고 HUD를 끈다(ui_root.gd:120 규칙 재사용 가정)
    await _interact(player, teo)
    _check("대사 시작 시 전체화면 UI 상호배제(다른 메뉴 못 엶)", ...)
    _check("대사 시작 시 HUD 숨김", not ui.hud.visible)

    # 2) 줄 넘김 — 물리 프레임으로 대기(§1.1), delta 아님
    for i in range(4): await get_tree().physics_frame
    await _action(&"ui_confirm")  # typing 중 skip
    _check("skip이 타이프라이터를 즉시 완료 상태로", ...)
    await _action(&"ui_confirm")  # line_complete -> 다음 줄
    _check("다음 줄로 진행", ...)

    # 3) 선택지 — 상하 이동 + 확정 (마우스 클릭 경로는 §1.2 격차로 headless 대상 아님)
    await _key(KEY_DOWN)
    await _action(&"ui_confirm")
    _check("선택지 확정이 story flag/퀘스트 분기에 반영", ...)

    # 4) 퀘스트 수락 반영 — 대사 중 QuestSystem.accept 경로를 타는 갈래(예: NPC가 대사 끝에 퀘스트 제안)
    _check("대사 종료 후 QuestSystem 상태가 accept로 전이", QuestSystem.get_state(QID) == "active")

    # 5) 종료 — 모달 닫힘 + pause 해제
    _check("대사 종료 시 get_tree().paused == false", not get_tree().paused)

    # 6) HUD 복원 — 시작 전 상태로 정확히 돌아오는가(다른 전체화면 UI가 남아있으면 복원되면 안 됨)
    _check("HUD 가시성이 대사 이전 상태로 복원", ui.hud.visible == hud_visible_before)

    print("=== SMOKE DIALOGUE FLOW: PASS=%d FAIL=%d ===" % [_pass, _fail])
    get_tree().quit(0 if _fail == 0 else 1)
```

핵심은 6번 "HUD 복원"을 **시작 전 값과 비교**로 검증하는 것 — `true`로 하드코딩하면 대사가
다른 전체화면 UI 위에서 열렸을 때(중첩 버그) 거짓 PASS가 난다. `smoke_quest_npc_panel.gd`
L99 "다른 메뉴들이 겹칠 수 없다"는 이미 같은 우려를 검증하고 있으므로, 대사 모달도 동일
상호배제 검사를 넣는다.

## 4. 회귀 대상 스모크 목록

대사 시스템이 `UiRoot`의 전체화면 UI 집합에 들어가거나 `interact` 입력 소비 순서를 바꾸면
아래가 깨질 수 있다(기존 파일이 명시적으로 그 불변식을 검사하고 있어서 회귀 감지용으로
바로 재사용 가능):

- `SmokeQuestNpcPanel`(`smoke_quest_npc_panel.gd`) — 모달 상호배제, interact 재진입 방어,
  중복 수주/보상 방어. 대사 모달이 같은 `interact` 입력을 두고 경쟁할 여지.
- `SmokeQuestMarkersAndLog`(`smoke_quest_markers_and_log.gd`) — 머리 위 표식(`!`/`?`/`▼`)이
  대사 시작으로 가려지거나 갱신 타이밍이 밀리는지.
- `SmokeQuestNpcLate`(존재 확인, 내용 미열람 — 파일명상 "늦게 배치된 NPC" 케이스로 추정) —
  대사가 NPC 스폰 타이밍에 영향받는지.
- `SmokeQuestUiSave` — 대사 진행 중 세이브가 걸리면(자동세이브 트리거) 대사 상태가 세이브
  스냅샷에 끼어드는지(`test_quest_system.gd`의 `to_dict`/`from_dict` 라운드트립 패턴과 동일
  우려).
- `SmokeQuarterViewB`(`smoke_quarter_view_b.gd` §8 "상호작용 영역 중복") — 대사를 여는
  NPC/오브젝트가 새 배치와 겹치면 뒤쪽 노드가 영원히 안 열리는 기존 회귀 패턴 그대로 재발
  가능.
- `SmokeMenuMouse` — 병합되면(§1.2) 대사 선택지 클릭이 D-196 패턴을 재사용하므로 반드시
  포함.
- `SmokeHud` — HUD 가시성 토글 지점이 하나(`ui_root.gd:120`)로 모여 있으므로, 대사가 이
  지점을 우회해 자체적으로 HUD를 끄면 여기서 잡힐 가능성.

## 5. 결정 필요 항목 (설계 판단 — 이 문서에서 확정하지 않음)

1. **§1.3/1.4**: 스모크별 `user://` 격리를 리터럴 Windows 경로 대신 무엇으로 파라미터화할지
   (환경변수, `OS.get_cmdline_user_args()`의 `--user-dir=` 같은 커스텀 인자, 스크립트 파일명
   해시 등). 대사 시스템 스모크를 새로 쓰는 시점에 정해야 §1.3 gate를 복붙하지 않는다.
2. **§2-4**: 대사 선택지의 story flag 저장소가 `QuestSystem._completed`/story flag와 같은
   테이블을 공유하는지, 대사 전용 저장소를 따로 두는지 — `docs/ui/dialogue-balloon.md`에
   명시 없음.
3. **`docs/ui/dialogue-balloon.md` §6-A/B/C/D** (이미 그 문서에 결정 필요로 남아있는 항목,
   이 템플릿의 테스트 대상과 직결): dialogue_manager 애드온 채택 여부, 초상 없음일 때 슬롯
   접힘 적용 여부, 선택지 없는 일반 대사의 `ui_cancel` 홀드 종료 허용 여부, `interact` 키를
   대사 중 `ui_confirm`과 동일 취급할지.
4. **§1.1**: 타이프라이터를 프레임 단위(글자당 N프레임)로 설계할지 delta 누적(초당 글자 수)
   으로 설계할지 — 전자만 이 저장소의 기존 스모크 관례로 프레임 카운트 검증이 가능하다.

## 6. 캡처 스크린샷 규칙 (기존 관례 재확인)

- 실행: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 --path game
  res://tests/smoke/<Scene>.tscn --quit-after <N>`.
- headless(`DisplayServer.get_name() == "headless"`)에서는 캡처만 `[SKIP]` 출력 후 나머지
  로직은 계속 검증(§1.5 두 번째 패턴 채택 — 캡처 실패로 전체 스모크를 죽이지 않는다).
- 저장 경로는 프로젝트 상대 경로로 만든다(`smoke_iso_field_capture.gd`의
  `ProjectSettings.globalize_path("res://").path_join("../docs/art/preview")` 패턴). §1.3에서
  지적한 것처럼 `smoke_quest_npc_late.gd`처럼 `C:/Users/...` 절대경로를 저장 대상에 직접
  박아두는 방식은 새 스모크에 반복하지 않는다.
- 파일명은 스모크 목적을 그대로 담아 나중에 diff 리뷰가 가능하게 한다(예:
  `dialogue-flow-choice-v1.png`) — 기존 `docs/qa/*-v1.png`/`*-v2.png` 명명 관례 재사용.
