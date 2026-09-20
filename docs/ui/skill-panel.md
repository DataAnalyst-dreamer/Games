# 스탯 분배 · 스킬 패널 (F1-2/F1-3, M3-4)

> 기준: `docs/GDD-도트액션RPG-기획안.md` 5.2(스탯)·4.3(스킬), `docs/ui/wireframes.md` 공통
> 원칙(§0), `docs/specs/skills-m3.md`(액티브 6종 스키마), 결정 D-163~D-166.
> 문서 버전: v0.1 (2026-09-20) / 작성: ui-ux-designer / 구현: `game/scripts/ui/skill_panel_tab.gd`
> + `game/scripts/ui/stats_ui_calc.gd`, InventoryMenu의 기존 "skill" 탭(D-166: 신규 최상위
> 탭이 아니라 이미 있던 placeholder 탭 자리에 좌우 서브탭 2개로 구현 — `quest_log_tab.gd`의
> "메인/사이드/의뢰" 서브탭과 동일한 패턴).

## 0. 진입 경로

- Tab(키보드) / LB·RB 순환(패드) → 전체화면 메뉴 → "스킬" 탭(`TABS`엔 이미 "skill" 존재,
  D-153 이전부터 있던 placeholder 슬롯을 이번에 실제 구현으로 교체).
- 레벨업 배너(`hud_progress.gd`)에 `GameState.stat_points > 0`이면 "포인트 n 남음 — Tab"
  힌트 한 줄이 추가로 붙어 이 화면으로 유도한다.

## 1. 레이아웃 개략도 (ContentArea 632×321, InventoryMenu와 같은 캔버스)

```
+----------------------------------------------------------------+
| [스탯] [스킬]                               <- 좌/우로 전환(패드/키보드) |
+----------------------------------------------------------------+
 스탯 서브탭:
| 잔여 포인트: 3                                                    |
|  STR  12   [+]   공격 ▲+0.2                                      |
|  DEX   4   [+]   (파생치 미리보기 없음)                             |
|  INT   0   [+]   (파생치 미리보기 없음)                             |
|  VIT   8   [+]   HP ▲+5.0  방어 ▲+1.0                             |
|  LUK   0   [+]   크리 ▲+0.1%                                      |
|  공격 32.0 / HP 130 / 방어 8.0 / 크리 5.0%  (현재값, 신호 수신 전 "-") |
+----------------------------------------------------------------+
 스킬 서브탭 (스탯과 좌우 전환으로 이동):
| 강타(blade)  [습득]     |  강타                                    |
| 찌르기(blade)           |  정면 부채꼴 범위를 강하게 베어 넉백을 준다.  |
| 방패 강타(guard)        |  계열 blade · SP 1 · 요구 없음             |
| 철벽(guard)             |  [습득됨] Q/R로 슬롯 장착                  |
| 쇄도(trick)             |                                          |
| 축지(trick)             |                                          |
|  (목록, 상/하로 포커스 이동) | 확인으로 습득 / Q·R로 장착 슬롯 지정      |
+----------------------------------------------------------------+
```

- 스탯 행의 "[+]"는 마우스로도 누를 수 있는 Button이지만 포커스 이동은 상/하 십자키만 쓴다
  (다른 placeholder 탭과 동일 원칙 — 클릭 전용 기능 없음).
- 파생치 미리보기(▲ 화살표)는 `InventoryUiCalc.format_delta()`를 그대로 재사용(신규 색
  토큰 없음, `Inventory/colors/positive`). 공격/HP/방어/크리 4개만 다룬다(DEX/INT는 이
  4개에 영향이 없어 미리보기가 비어 있다 — 공격속도/쿨감은 GDD 5.2에 있지만 이번 범위 밖).
- 스킬 아이콘은 전부 `icon: null`이라 계열 첫 글자(B/G/T)로 대체한다(D-165 방침과 동일하게
  "미완성 데이터는 텍스트로 대체"). 상세 패널의 "요구" 목록은 6종 전부 `requires: []`라
  현재는 항상 "없음"으로 보인다.

## 2. 노드 트리 (코드 생성, InventoryMenu.tscn엔 빈 `SkillPanelTab` 컨테이너만 있음)

```
SkillPanelTab (Control, script=skill_panel_tab.gd, InventoryMenu의 ContentArea 형제)
└─ (VBoxContainer, 런타임 생성 — quest_log_tab.gd와 동일 관례)
   ├─ SubTabBar (HBoxContainer) — "스탯"/"스킬" 버튼 2개
   ├─ StatBody (VBoxContainer) — PointsHeader + 5행(StatRow: 이름/값/+버튼/미리보기) + DerivedFooter
   └─ SkillBody (HBoxContainer)
      ├─ ScrollContainer > ListBox (VBoxContainer) — 스킬 이름 + [습득]/[습득됨] 표시
      └─ DetailBox (VBoxContainer) — 이름/설명/계열·SP·요구/상태·조작 힌트
```

## 3. 입력 흐름 (패드/키마)

| 동작 | 게임패드 | 키보드 | 결과 |
|---|---|---|---|
| 서브탭(스탯/스킬) 전환 | 왼쪽 스틱/십자키 좌우 | ←/→ | `_change_sub_tab()`, 포커스 인덱스 0으로 리셋 |
| 행/목록 이동 | 왼쪽 스틱/십자키 상하 | ↑/↓ | 스탯: 5행 순환. 스킬: 목록 순환 |
| 스탯 배분 | A(확인) | Enter/Space(`ui_confirm`) | 포커스 스탯에 `Progression.allocate_stat(key)`(있으면) |
| 스킬 습득 | A(확인) | `ui_confirm` | 포커스 스킬이 습득 가능이면 `Progression.learn_skill(id)`(있으면) |
| 슬롯 장착 | L숄더/R숄더 | Q/R(`skill_1`/`skill_2`, 기존 액션 재사용) | 포커스 스킬이 습득됨이면 `Progression.equip_skill(slot,id)`(있으면), 새 입력맵 추가 없음 |
| 닫기 | B/Start | Esc/Tab | InventoryMenu 공통 처리 |

## 4. 상태 목록

| 상태 | 트리거 | 표시 |
|---|---|---|
| 탭 열림 | `_apply_tab_visibility()`가 "skill"로 전환 | `open()` — 최신 stats/skills 새로고침, 첫 서브탭(스탯)에 포커스 |
| 잔여 포인트 있음 | `GameState.stat_points > 0` | 헤더에 강조 표시 + 레벨업 배너 힌트 |
| 스탯 값 갱신 | `Events.stats_changed(stats, derived, stat_points)` | 5행 값 + 파생치 현재값 갱신(신호 수신 전엔 "-") |
| 스킬 목록 갱신 | `Events.skills_changed(learned, slots, skill_points)` | 습득/장착 상태 갱신 |
| 스킬 상태: 습득됨 | `learned.has(id)` | "[습득됨]" + 슬롯 장착 힌트 |
| 스킬 상태: 습득 가능 | `skill_points >= cost_sp` and 요구 전부 습득 | "[습득]" 확인 가능 |
| 스킬 상태: 잠김 | 그 외 | 회색, 확인 무시 |
| 로직 미병합(M3-3) | `Progression.has_method(...)` == false | 입력해도 무동작(가드, `# ponytail: M3-3 병합 후 제거`) |

## 5. 남은 이슈

1. `Progression.allocate_stat/learn_skill/equip_skill`은 stage/m3-3(로직) 병합 전이라
   `has_method` 가드로 무동작 처리했다 — 병합 후 디렉터가 가드 제거 여부 판단(D-165).
2. 파생치 절대값(공격/HP/방어/크리)은 `Events.stats_changed`가 실제로 발신되기 전까지
   "-"로 표시된다(경험치바가 겪었던 것과 동일한 선례, `docs/ui/hud.md` 3.5절).
3. 계열별 노드 트리 시각화(GDD 4.3 v3, 8계열 124노드)는 이번 범위 밖 — 현재는 flat 목록
   6종만 존재(`docs/specs/skills-m3.md`).
