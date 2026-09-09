# 인벤토리·장비 화면 구현 문서 (F7-2/F3-2, M2-2)

> 기준: `docs/ui/wireframes.md` 공통 원칙(§0) + 화면 4(인벤토리 & 장비),
> `docs/brd/03-features/07-UI-접근성.md` F7-2, `03-아이템-파밍.md` F3-2,
> 결정 D-11(40→80칸)·D-12(반지 중복 허용)·D-24(메뉴 오픈 중 일시정지)·D-37(Tab/Select=전체 메뉴, Esc/Start=일시정지 분리).
> 문서 버전: v0.1 (2026-09-08) / 작성: ui-ux-designer / 구현: `game/scenes/ui/InventoryMenu.tscn` + `game/scripts/ui/inventory_menu.gd`

## 0. 화면 구조 개요 — UiRoot

HUD(F7-1)와 이번 메뉴(F7-2)가 각자 `menu` 액션을 따로 처리하며 충돌하지 않도록,
`game/scenes/ui/UiRoot.tscn`(CanvasLayer, `ui_root.gd`) 하나가 `Hud`(기존 Hud.tscn 그대로 자식으로 인스턴싱)와
`InventoryMenu`를 함께 들고 `menu` 액션 하나로 열기/닫기 + `get_tree().paused` 를 중앙에서 관리한다.
`Hud.gd`는 이 태스크에서 `menu` 액션을 건드리지 않는다(기존 그대로) — 충돌 자체가 없지만, 향후 다른 메뉴가
추가돼도 단일 지점에서만 pause/열림상태를 결정하도록 구조를 미리 잡아 둔다.

`UiRoot`와 `InventoryMenu`는 `process_mode = PROCESS_MODE_ALWAYS`로 둬서, `get_tree().paused = true`가 된
동안에도 메뉴 자신은 입력을 계속 받는다(그 외 Player/몬스터/World는 기본 PAUSABLE이라 그대로 멈춘다).

```
Main (Node2D)
├─ World / Player / 몬스터들 / LootSpawner  (PAUSABLE, 메뉴 오픈 중 정지)
└─ UiRoot (CanvasLayer, process_mode=ALWAYS)      ← 이번 태스크가 Hud를 감싸 추가
    ├─ Hud (기존 Hud.tscn 인스턴스, 그대로)
    └─ InventoryMenu (CanvasLayer, process_mode=ALWAYS, layer=10, 평시 hidden)
```

## 1. 레이아웃 개략도 (640×360, 정수 좌표)

```
(0,0)                                                              (640,0)
 +----------------------------------------------------------------+
 | [가방][스킬][도감][퀘스트]   ^LB/RB 탭 순환         골드: 12,340 |
 +----------------------------------------------------------------+
 | +--------------------+  +-----------------------------------+ |
 | |   캐릭터 미리보기    |  | 필터:[전체|일반|고급|희귀|영웅|전설|유물] |
 | |   (플레이스홀더)     |  |  ^LT/RT 등급 필터 순환    [X 정렬]   | |
 | |      [투구]         |  | +--+--+--+--+--+--+--+--+          | |
 | |  [무기][갑옷][보조]  |  | |  |  |  |  |  |  |  |  | (8열 그리드)| |
 | |      [신발]         |  | +--+--+--+--+--+--+--+--+          | |
 | | [반지][반지][부적]   |  | ... 40~80칸(백팩 확장 반영), 스크롤   | |
 | |  -- 치장(준비중) --  |  |                                    | |
 | | [모자][의상][백팩]   |  |  +--비교 툴팁(포커스 시)-----------+ | |
 | |                     |  |  | ◆ 서리 인챈트 검 +4  (장착중과 비교)| |
 | | 공격 152  방어 89    |  |  | 공격 45 (▲12)  강화 +4 재련 2/3   | |
 | | 최대체력+0 이속+0%   |  |  | [옵션] 치명타 +4%(신규)            | |
 | +--------------------+  |  +----------------------------------+ |
 +----------------------------------------------------------------+
 | (A)장착/해제/사용 (X)정렬 (Y 홀드)분해표시 (LB/RB)탭 (LT/RT)필터 (B)닫기 |
 +----------------------------------------------------------------+
(0,360)                                                            (640,360)
```

- 내부 해상도 640×360, `hud.md`와 동일한 정수 좌표 원칙을 따른다.
- 탭은 인벤토리(가방)만 실구현, 스킬/도감/퀘스트는 "준비 중" placeholder 패널(문서 위임 범위 밖).
- 등급 필터·비교 툴팁 규칙은 `wireframes.md` §0.2/화면4와 1:1.

## 2. 노드 트리

### UiRoot.tscn
```
UiRoot (CanvasLayer, script=ui_root.gd, process_mode=ALWAYS)
├─ Hud (Hud.tscn 인스턴스, 그대로)
└─ InventoryMenu (InventoryMenu.tscn 인스턴스)
```

### InventoryMenu.tscn
```
InventoryMenu (CanvasLayer, layer=10, script=inventory_menu.gd, process_mode=ALWAYS)
└─ Root (Control, full rect, theme=theme.tres, visible=false)
   ├─ Backdrop (ColorRect, 반투명 어둡게)
   ├─ TabBar (HBoxContainer) — TabInventory/TabSkill/TabCodex/TabQuest (Label, 활성=강조색)
   ├─ GoldLabel (Label, 우상단)
   ├─ ContentArea (Control)
   │  ├─ InventoryTab (Control)
   │  │  ├─ LeftPanel
   │  │  │  ├─ PortraitPlaceholder (ColorRect)
   │  │  │  ├─ EquipGrid (Control) — EquipHead/EquipWeapon/EquipArmor/EquipSub/EquipBoots/
   │  │  │  │                        EquipRing1/EquipRing2/EquipAmulet (Panel×8)
   │  │  │  ├─ CostumeRow (Control, "준비중" 캡션) — CostumeHat/CostumeOutfit/CostumeBackpack (Panel×3, disabled)
   │  │  │  └─ StatsSummary (VBoxContainer) — Attack/Defense/MaxHp/Speed (Label×4)
   │  │  └─ RightPanel
   │  │     ├─ FilterRow (HBoxContainer) — FilterChip×7(전체+6등급)
   │  │     ├─ SortButton (Button)
   │  │     ├─ GridScroll (ScrollContainer) → GridContainer(columns=8) — 슬롯 Panel 런타임 생성
   │  │     ├─ EmptyHint (Label, 격자 0칸일 때만)
   │  │     └─ CompareTooltip (Panel, wood_frame) — Header/EnhanceLine/StatRows(VBox)/AffixRows(VBox)
   │  └─ PlaceholderTab (Control, 스킬/도감/퀘스트 공용) — "ui.inv.placeholder_tab" 문구
   └─ GuideBar (HBoxContainer) — 하단 입력 가이드, 패드/키마 자동 전환
```

## 3. 입력 흐름 (패드/키보드)

`project.godot`에 이번 태스크가 추가한 액션(기존 전투 액션과 물리 버튼을 일부러 재사용 —
메뉴가 열리면 Player가 paused라 전투 액션이 동시에 발화돼도 부작용이 없다. `menu`/`pause`처럼
이미 D-37로 분리된 액션은 건드리지 않는다):

| 동작 | 액션 이름 | 게임패드 | 키보드 | 비고 |
|---|---|---|---|---|
| 메뉴 열기/닫기 | `menu` (기존) | Select | Tab | D-37, 토글 |
| 포커스 이동 | `move_up/down/left/right` (기존) | 십자키/좌스틱 | WASD/방향키 | 격자↔장비 슬롯 공용, Player 이동과 물리 버튼 공유(paused라 안전) |
| 결정(장착/해제/사용) | `ui_confirm` (신규) | A | Enter | |
| 닫기 | `ui_close` (신규) + `menu` | B | Backspace | 마우스 우클릭도 닫기 |
| 대분류 탭 전환 | `ui_tab_prev`/`ui_tab_next` (신규) | LB/RB | Q/E | `skill_1`/`skill_2`와 같은 물리 버튼(문맥 재사용) |
| 등급 필터 순환 | `ui_filter_prev`/`ui_filter_next` (신규) | LT/RT | Z/C | `guard`/`heavy_attack`과 같은 물리 트리거(문맥 재사용) |
| 자동 정렬 | `ui_sort` (신규) | X | Space | |
| 분해 표시 토글(홀드 0.5초) | `ui_mark_discard` (신규) | Y | X키 | 장착중 아이템 제외, 그리드 포커스에서만 |
| 비교 툴팁 좌우 고정/전환 | `ui_compare_lock` (신규) | R3 | Alt | 이번 패스는 고정 토글만(좌우 전환은 후속) |
| 마우스 | — | — | 좌클릭=결정, 우클릭=닫기, 휠=격자 스크롤 | 모든 상호작용 마우스로도 동일하게 가능 |

- 하단 `GuideBar`는 마지막 입력 장치(키보드 vs 패드, `Input.is_action_just_pressed`가 감지된 이벤트 타입)에 따라
  라벨을 자동 전환한다(`inventory_menu.gd:_note_input_device()`).
- 반지 2슬롯: 그리드에서 반지 아이템에 `ui_confirm` → ring1이 비어 있으면 ring1, 아니면 ring2, 둘 다 차 있으면
  ring1을 교체한다(별도 선택 팝업은 **(제안, 미구현)** — 남은 이슈 참고).
- 치장 3슬롯은 placeholder라 포커스 이동 대상에서 제외한다(시각 표시만, 상호작용 없음).

## 4. 상태 목록

| 상태 | 트리거 | 표시 |
|---|---|---|
| 닫힘(기본) | — | `Root.visible=false`, `get_tree().paused=false` |
| 열림 | `menu` 액션 | `Root.visible=true`, `paused=true`, 마지막 탭·포커스 복원 |
| 탭 전환 | `ui_tab_prev/next` | 인벤토리 탭만 실동작, 나머지는 PlaceholderTab 표시 |
| 등급 필터 | `ui_filter_prev/next` | 그리드에 해당 등급만 표시(없으면 EmptyHint) |
| 격자 0칸(필터 결과 없음) | 필터 적용 후 슬롯 0개 | `ui.inv.filter_empty` 문구 |
| 인벤토리 자체가 비어있음 | `inventory.slot_count()==0` 그리고 필터=전체 | `ui.inv.empty_grid` 문구 |
| 아이템 포커스(장비 카테고리) | 그리드 포커스 이동 | `CompareTooltip` 자동 표시(장착 중인 동일 슬롯과 비교) |
| 아이템 포커스(소모품/재료) | 〃 | 비교 없이 이름·수량·설명만 |
| 분해 표시됨 | `ui_mark_discard` 0.5초 홀드 | 셀에 빨강 틴트+표시 아이콘, 장착중이면 무시 |
| 장착/해제 성공 | `ui_confirm` | 스탯 요약 즉시 갱신(`Equipment.compute_stats` 재계산) |
| 카테고리 불일치 | 장착 시도 실패 | 토스트 없이 무시(로그만) — 남은 이슈 참고 |

## 5. 남은 이슈 (본문 하단 "완료 보고"에도 동일 목록)

1. 스킬/도감/퀘스트 탭은 문구만 있는 placeholder — 각 담당 화면(M2 이후)에서 교체.
2. 치장 3슬롯은 시각 규격만 맞춘 비활성 placeholder — 백팩 장착→인벤토리 용량 확장 배선은 아직 없음
   (`Inventory.set_backpack_bonus()` 훅은 이미 있음, 호출부만 없음).
3. 반지 2슬롯 동시 보유 시 "어느 슬롯에 장착할지" 선택 팝업은 미구현(ring1 우선 자동 배정).
4. 장착 실패(카테고리 불일치, STR 요구치 등) 시 사용자에게 보여줄 실패 토스트 UI 없음(요구치 자체도 아직 미구현).
5. 소모품 "사용"은 `heal_hp`만 실제 효과 적용, `buff_*` 계열은 소모만 되고 버프가 실제로 걸리지 않음(버프 시스템 M2 이후).
6. 분해 표시는 이번 패스에서 순수 UI 토글(`slot["marked_discard"]`)이며 저장(`to_dict`)에는 아직 포함하지 않음 — 실제 분해는 M2-4 대장간.
7. 비교 툴팁 좌우 전환(장착품↔후보 뒤집기)은 미구현, 고정 토글만.
8. 새 아이템 "N" 뱃지, 잠금(자물쇠) 기능은 미구현.
9. 나인패치/필터칩 색상은 placeholder 단색 위주 — pixel-artist 리뷰 대기.
