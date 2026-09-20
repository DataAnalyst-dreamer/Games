# 스탯 분배 · 스킬 트리 패널 (M4-5 v2)

> 기준: `docs/specs/ro-benchmark-progression-v1.md`(§1 6스탯·파생치, §2 포인트 비용 곡선,
> §3 SP, §4 스킬 트리 24노드), `docs/ui/wireframes.md` 공통 원칙(§0), 결정 D-161/D-184/
> D-194/D-195. v0.1(M3-4, 5스탯·플랫 스킬 6종)을 **대체**한다.
> 문서 버전: v0.2 (2026-09-20) / 작성: ui-ux-designer / 구현: `game/scripts/ui/skill_panel_tab.gd`
> + `stats_ui_calc.gd`(순수, 스탯) + `skill_tree_tab.gd` + `skill_tree_calc.gd`(순수, 트리),
> InventoryMenu의 기존 "skill" 탭(D-166 계승: 좌우 서브탭 2개, `quest_log_tab.gd`와 동일 패턴).

## 0. 진입 경로

- `[`/`]`(D-181, 구 Q/E) 또는 LB/RB 순환 → 전체화면 메뉴 → "스킬" 탭.
- 레벨업 배너(`hud_progress.gd`)에 스탯/스킬 포인트 획득 토스트(D-195, `ui.hud.stat_gain_toast`/
  `skill_gain_toast`) + 기존 "포인트 n 남음" 힌트가 이 화면으로 유도한다.

## 1. 레이아웃 개략도 (ContentArea 632×321, InventoryMenu와 같은 캔버스)

```
+----------------------------------------------------------------+
| [스탯] [스킬]                               <- 좌/우로 전환(패드/키보드) |
+----------------------------------------------------------------+
 스탯 서브탭(6행, D-158 AGI 신설):
| 잔여 포인트: 3                                                    |
|  STR 12 [+]  다음 3포인트 · 물리 공격력이 오른다 · 공격 ▲0.20        |
|  AGI  6 [+]  다음 1포인트 · 공격 속도와 회피가 좋아진다              |
|  DEX  4 [+]  다음 1포인트 · 공격이 더 잘 맞고 후딜이 짧아진다        |
|  INT  8 [+]  다음 1포인트 · 마법 공격력과 최대 SP...   MaxSP ▲2.00  |
|  VIT 10 [+]  다음 2포인트 · 최대 체력과 방어력이 오른다  HP▲5 방어▲1 |
|  LUK  2 [+]  다음 1포인트 · 치명타 확률이 오른다  치명 ▲0.1%         |
|  공격 32.4 / 마공 21.2 / HP 150 / SP 36 / 방어 21.0 / 마방 9.0 /   |
|  치명 5.2% / 명중 +0.6% / 회피 +0.01s / 이속 +0.9% / 공속 +1.7% /  |
|  후딜 -0.6% / SP회복 1.24/s   (13개, 값 없으면 행 자체 숨김 — D-195) |
+----------------------------------------------------------------+
 스킬 서브탭(3계열 × tier 3열, LT/RT로 계열 전환):
| [검] [방패] [기교]              <- ui_filter_prev/next(Z/C, LT/RT) |
+---------------+---------------+---------------+------------------+
|  T1(3)        |  T2(3)        |  T3(2)        |  상세 패널        |
| 강타 Lv1/5    | 연격 Lv0/5    | 검의반사 Lv0/5| 강타 Lv.1/5      |
| [습득됨]      | (자물쇠)      | (자물쇠)      | 액티브           |
| 찌르기 Lv0/5  | 예기 Lv0/5    | 종언의일격    | 요구: 없음        |
| [습득]        | (자물쇠)      | Lv0/5(자물쇠) | sp_cost 10 ·     |
| 칼끝집중Lv0/5 | 투기 Lv0/5    |               | cooldown_sec 4.5 |
| [습득]        | (자물쇠)      |               | 확인=습득/레벨업  |
+---------------+---------------+---------------+------------------+
|  (상/하로 노드 순회, tier1→2→3 이어붙인 1차원 목록)                  |
+----------------------------------------------------------------+
```

- 스탯 행의 "다음 N포인트"는 `Progression.next_stat_cost(key)`(있으면) 또는
  `StatsUiCalc.next_point_cost()`(D-184 `floor(n/10)+1`) 폴백. 효과 한 줄 설명(D-195,
  `ui.stat.effect.*`)은 6스탯 전부 항상 보인다 — AGI/DEX처럼 상한 있는 비선형 배율이라
  숫자 미리보기가 없는 스탯도 이 텍스트로 "눈에 보이는 효과"를 전달한다.
- 파생치 미리보기(▲ 화살표, str/vit/int/luk만)는 `InventoryUiCalc.format_delta()` 재사용.
  파생치 절대값 13종(D-195 확정 키)은 `Progression.get_derived()`에 그 키가 있을 때만
  줄에 나타난다(없으면 해당 행 자체를 숨김 — 원시값 덤프 금지, 병합 후 자동 표시).
- 스킬 노드는 전부 `icon: null`이라 이름 텍스트 + Lv.n/5 + 상태 마크로만 표시한다.
  선행 관계는 Line2D 대신 상세 패널 텍스트(`ui.skill.requires_fmt`, "X Lv.3 이상")로만
  보여준다(스펙이 명시한 대안 — 24노드 규모에 커스텀 `_draw()`는 과함).
- 계열 표시명(검/방패/기교, `ui.skill_tree.series.*`)은 D-195로 placeholder 승인된
  값 — 최종 네이밍은 narrative-writer 후속 작업.

## 2. 노드 트리 (코드 생성, InventoryMenu.tscn엔 빈 `SkillPanelTab` 컨테이너만 있음)

```
SkillPanelTab (Control, script=skill_panel_tab.gd)
└─ (VBoxContainer, 런타임 생성)
   ├─ SubTabBar (HBoxContainer) — "스탯"/"스킬" 버튼 2개
   ├─ StatBody (VBoxContainer) — PointsHeader + 6행(이름/값/+/미리보기줄) + DerivedFooter
   └─ SkillTreeTab (Control, script=skill_tree_tab.gd)
      ├─ SeriesBar (HBoxContainer) — "검"/"방패"/"기교" 버튼 3개
      └─ Body (HBoxContainer)
         ├─ 3× VBoxContainer(tier 열, T1/T2/T3) — 노드 Label(이름+Lv.n/5+상태 마크)
         └─ DetailBox (VBoxContainer) — 이름+레벨/타입/요구/레벨별 수치/힌트 + HudHotbarBar
```

## 3. 입력 흐름 (패드/키마)

| 동작 | 게임패드 | 키보드 | 결과 |
|---|---|---|---|
| 서브탭(스탯/스킬) 전환 | 왼쪽 스틱/십자키 좌우 | ←/→ | `SkillPanelTab._change_sub_tab()` |
| 계열(검/방패/기교) 전환 | LT/RT | Z/C(`ui_filter_prev/next`) | `SkillTreeTab._change_series()`(스킬 서브탭 안에서만) |
| 행/노드 이동 | 왼쪽 스틱/십자키 상하 | ↑/↓ | 스탯: 6행 순환. 스킬: tier1→2→3 이어붙인 목록 순환 |
| 스탯 배분 | A(확인) | `ui_confirm` | 포커스 스탯에 `Progression.allocate_stat(key)` |
| 스킬 습득/레벨업 | A(확인) | `ui_confirm` | `Progression.can_learn_skill(id).ok`(있으면, 없으면 `SkillTreeCalc.node_state` 폴백)면 `Progression.learn_skill(id)` |
| 핫바 등록 | 숫자 패드 대응 | 1~9(`hotbar_N`) | 습득된 active/buff 노드만 `HotbarRegisterInput.try_assign` |
| 닫기 | B/Start | Esc/Tab | InventoryMenu 공통 처리 |

## 4. 상태 목록

| 상태 | 트리거 | 표시 |
|---|---|---|
| 탭 열림 | `_apply_tab_visibility()`가 "skill"로 전환 | `open()` — 스탯 서브탭·blade 계열·첫 노드에 포커스 |
| 스탯 값 갱신 | `Events.stats_changed(stats, derived, stat_points)` | 6행 값 + 파생치 13종(있는 것만) 갱신 |
| 노드 상태: locked/no_points | `skill_points < cost` | 회색, `ui.skill.reason_no_points` |
| 노드 상태: locked/requires | 선행 레벨 미충족 | 회색, `ui.skill.reason_requires` |
| 노드 상태: learnable | 선행 충족 + 포인트 충분 | 확인으로 습득/레벨업, `ui.skill.learn_hint` |
| 노드 상태: maxed | `level >= max_level(5)` | `ui.skill.state.maxed`, `ui.skill.reason_maxed` |
| 스킬 목록 갱신 | `Events.skills_changed(learned, slots, skill_points)` | learned가 Array(구)/Dictionary(신) 어느 쪽이든 `SkillTreeCalc.normalize_learned()`로 통일 |
| 로직 미병합(M4-4) | `Progression.has_method(...)` == false | `SkillTreeCalc`/`StatsUiCalc` 로컬 계산으로 폴백(무동작 아님 — 같은 모양의 결과) |

## 5. 남은 이슈

1. 파생치 13종 중 `hit_scale`/`flee_iframe_bonus`/`move_speed_mult`/`combo_frame_mult`/
   `post_recovery_mult`의 정확한 반환 단위는 stage/m4-4 병합 후 실측으로 재확인 필요
   (현재는 D-195 지시 공식대로 서식화, `docs/specs/ro-benchmark-progression-v1.md` §1
   worked examples와 대조해 맞춰 두었다).
2. 레벨별 수치(상세 패널 하단)는 `levels[]` 필드를 이름 그대로 나열하는 일반화 텍스트다
   (예: "sp_cost 18 · cooldown_sec 25 · atk_buff_pct 6 duration_sec 5") — 필드별 로컬라이징은
   이번 범위 밖(placeholder 단계, D-167 아이콘 placeholder 관례와 동일 정신).
3. 선행 관계 시각화(Line2D)는 텍스트로 대체했다 — 나중에 아트가 확정되면 재검토.
