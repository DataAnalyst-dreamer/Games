# 퀘스트 로그 화면 (F5-1/F5-2, M3-2)

> 기준: `docs/brd/03-features/05-퀘스트-내러티브.md` F5-1("퀘스트 로그에서 목표 확인, 추적
> 설정") · F5-2(의뢰 탭), `docs/ui/wireframes.md` 공통 원칙(§0), 결정 D-153~D-156.
> 문서 버전: v0.1 (2026-09-18) / 작성: ui-ux-designer / 구현: `game/scripts/ui/quest_log_tab.gd`
> + `game/scripts/ui/quest_log_ui_calc.gd`, InventoryMenu의 기존 "quest" 탭(D-153: 신규
> 화면이 아니라 이미 있던 placeholder 탭을 실제 구현으로 교체).

## 0. 진입 경로

- 기존: Tab(키보드) / LB·RB 순환(패드) → 전체화면 메뉴 → "quest" 탭으로 이동.
- 신규(D-153): **J 키**(키보드 전용, 패드 미배정 — 장르 관례상 인벤토리/스킬은
  I/E 계열, 퀘스트 로그는 J가 흔해 채택) → 메뉴가 닫혀 있으면 열면서 즉시 quest
  탭으로, 이미 열려 있으면(다른 탭이었어도) quest 탭으로만 전환한다(`ui_root.gd`).

## 1. 레이아웃 개략도 (ContentArea 632×321, InventoryMenu와 같은 캔버스)

```
+----------------------------------------------------------------+
| [메인] [사이드] [의뢰]                     <- 좌/우로 전환(패드/키보드) |
+----------------------------------------------------------------+
| [추적] 항구에 도착하다      |  항구에 도착하다                       |
|  다섯 갈래 길              |  진행 중                              |
|                            |  [x] talk npc:teo                    |
|                            |  > interact object:cargo_pile (0/1)  |
|                            |  [ ] obj_03                          |
|                            |                                      |
|  (목록, 상/하로 포커스 이동) |  확인 버튼으로 이 퀘스트를 추적합니다   |
+----------------------------------------------------------------+
```

- 목록이 비어 있으면(그 탭에 수주한 퀘스트가 없으면) 오른쪽에 `ui.quest_log.empty` 한 줄만
  보여준다("수주 가능"/"완료 보고 가능"만 있고 아직 손대지 않은 퀘스트는 로그에 없다 —
  §3 진단 참고).
- `[추적]` 표식이 붙은 항목이 HUD 상단 추적 줄에 나오는 퀘스트다.

## 2. 노드 트리 (코드 생성, InventoryMenu.tscn엔 빈 `QuestLogTab` 컨테이너만 있음)

```
QuestLogTab (Control, script=quest_log_tab.gd, InventoryMenu의 ContentArea 형제)
└─ (VBoxContainer, 런타임 생성)
   ├─ SubTabBar (HBoxContainer) — 메인/사이드/의뢰 버튼 3개(클릭 가능, M5-1)
   └─ Body (HBoxContainer)
      ├─ ScrollContainer > ListBox (VBoxContainer) — 현재 탭의 퀘스트 제목 목록(Button, M5-1: Label→Button, 클릭=선택)
      ├─ EmptyHint (Label, 목록 비었을 때만)
      └─ DetailBox (VBoxContainer)
         ├─ DetailTitle / DetailState (Label)
         ├─ DetailObjectives (VBoxContainer) — 완료/진행/잠김 3단 표시
         └─ DetailTrackHint (Label)
```

- `quest_npc_panel.gd`와 같은 관례로 씬 파일에 노드를 미리 그리지 않고 `_ready()`에서
  코드로 구성한다(inventory_menu.gd가 이미 500줄 상한을 넘어 있어, tscn에 상세 트리를
  더 얹기보다 로직·레이아웃 모두 이 파일 하나로 격리).
- 색은 `game/ui/theme.tres`의 기존 `Inventory/colors/*`(tab_active/tab_inactive/focus/
  neutral)를 그대로 재사용한다 — 퀘스트 로그 전용 색 토큰 신설 없음(중복 정의 금지 원칙).

## 3. 입력 흐름 (패드/키마)

| 동작 | 게임패드 | 키보드 | 마우스(M5-1) | 결과 |
|---|---|---|---|---|
| 진입 | LB/RB로 quest 탭 이동 | Tab 후 방향키, 또는 **J**(바로가기) | — | quest 탭 표시 + 목록/상세 새로고침 |
| 탭(메인/사이드/의뢰) 전환 | 왼쪽 스틱/십자키 좌우 | ←/→ | 탭 버튼 클릭 | `_change_sub_tab()`/`_on_sub_tab_pressed()`, 포커스 인덱스 0으로 리셋 |
| 목록 이동 | 왼쪽 스틱/십자키 상하 | ↑/↓ | 목록 항목 클릭(=선택) | `_move_focus()`/`_on_list_item_pressed()`, 순환(wrap) |
| 추적 설정 토글 | A(확인) | Enter/Space(`ui_confirm`) | — (클릭은 선택만, 토글은 확인 전용 — 실수 방지) | 포커스 항목이 이미 추적 대상이면 해제, 아니면 그 항목으로 설정(`QuestSystem.set_tracked`) |
| 닫기 | B/Start(`ui_close`/`menu`) | Esc/Tab | 우클릭 또는 `CloseButton` 클릭(InventoryMenu 공통) | InventoryMenu 공통 처리(UiRoot가 paused 해제) — 이 탭에서 추가로 처리하는 것 없음 |

## 4. 상태 목록

| 상태 | 트리거 | 표시 |
|---|---|---|
| 탭 열림 | `_apply_tab_visibility()`가 "quest"로 전환 | `open()` 호출 — 목록 재계산, 첫 비어있지 않은 탭으로 포커스 |
| 목록 비어있음 | 그 탭에 active/complete_ready/completed 퀘스트가 하나도 없음 | `ui.quest_log.empty` |
| 목표 완료 | `objective_index`가 그 인덱스를 지나감 | `[x]` 접두 |
| 목표 진행 중 | 현재 objective_index와 일치 | `>` 접두, count형(kill/collect)이면 `(n/m)` |
| 목표 미도달 | 아직 이전 목표 미완료 | `[ ]` 접두 |
| 추적 중 항목 | `QuestSystem.get_tracked() == quest_id` | 목록에 `[추적]` 접두, 상세에 `ui.quest_log.tracking_on` |
| 실시간 갱신 | `Events.quest_accepted/objective_updated/completed/quest_tracked_changed` | 탭이 열려 있는 동안만 구독 → 자동 새로고침, 닫히면 구독 해제(`close()`) |

## 5. 왜 지금까지 목표가 안 보였는가 (진단, M3-2 지시서 인용)

NPC에게 말을 걸어야 퀘스트가 시작된다는 사실을 알려주는 신호가 전혀 없었다(머리 위
표식 없음 D-155로 해소, 자동 온보딩 없음 D-154로 해소) + 퀘스트를 수주해도 확인할
화면이 없어(이 문서가 다루는 부분) HUD 한 줄 외에는 진행 상황을 볼 방법이 없었다.

## 6. 남은 이슈

1. 마우스 클릭으로 목록 항목을 직접 선택하는 기능은 없다(패드/키보드 완주 우선 —
   다른 placeholder 탭과 동일 원칙). 필요시 후속 단계에서 추가.
2. 사이드/의뢰 탭은 현재 act1_hartland.json의 실제 side/daily_template 퀘스트로만
   검증했다 — 2막 이후 데이터가 늘어나면 스크롤 동작(현재 ScrollContainer 기본값)
   재점검 필요.
3. `QuestLogUiCalc.format_objective_line()`의 목표 라벨은 목표 id 문자열 그대로다
   (narrative-writer의 objective별 title_key가 아직 없음 — 생기면 `tr()`로 교체).
