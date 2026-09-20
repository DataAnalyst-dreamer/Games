# 인게임 HUD 구현 문서 (F7-1, M1-5)

> 기준: `docs/ui/wireframes.md` 공통 원칙(§0) + 화면 3, `docs/brd/03-features/07-UI-접근성.md` F7-1,
> 결정 D-07(데미지 숫자)·D-47(퀵슬롯 십자키)·D-63(카메라 셰이크 4단계)·D-64(settings.json 소유).
> 문서 버전: v0.1 (2026-09-08) / 작성: ui-ux-designer / 구현: `game/scenes/ui/Hud.tscn` + `game/scripts/ui/hud.gd`

## 1. 레이아웃 개략도 (640×360 내부 해상도, 정수 좌표)

```
(0,0)                                                              (640,0)
 +----------------------------------------------------------------+
 | [초상20] Lv.1  ██████████████████░░░░ 234/300 (HP, 장식 없음)    +--------+ |
 |         ████████░░░░ (스태미나, 게이지만)                        |미니맵  | |
 |         [버프 아이콘 열 — 빈 컨테이너]                             |(토글)  | |
 |                         ~ 추적 퀘스트 한 줄 (빈 문자열) ~          +--------+ |
 |                                                                          |
 |                        (게임 필드 — UI 없음, 중앙 항상 비움)              |
 |                                                                          |
 |                              [보스 HP바] (평시 숨김)                      |
 |[획득 로그]                                                                |
 |(좌하단,3초)                                                               |
 |            [Q][E]   ▲(1)                                                 |
 |                  ◀(4) ▶(2)   ← 십자키 배치(D-47: 상=1/우=2/하=3/좌=4)     |
 |                     ▼(3)                                                 |
 +----------------------------------------------------------------+
(0,360)                                                            (640,360)
```

- 화면 가장자리 비네트(HP 25% 이하)와 F3 디버그 패널은 오버레이라 위 다이어그램에 없다.
- 중앙은 항상 비운다(GDD 11장 "HUD 최소화") — 위 요소 전부 네 모서리 + 하단 중앙에만 배치.

## 2. 노드 트리 (Hud.tscn)

```
Hud (CanvasLayer)
└─ Root (Control, theme=res://ui/theme.tres, mouse_filter=IGNORE, script=hud.gd)
   ├─ TopLeft (HP·스태미나·버프·초상)
   ├─ TopCenter (QuestLine 라벨, 빈 문자열)
   ├─ TopRight (MinimapFrame — wood_frame 스타일 + placeholder 사각형)
   ├─ BossBar (평시 hidden, wood_frame + ProgressBar + 이름/페이즈)
   ├─ BottomCenter (SkillSlot×2 + QuickCross×4)
   ├─ BottomLeft (LogList — 획득 로그, 런타임에 Label 추가/제거)
   ├─ VignetteOverlay (커스텀 _draw, HP 위험 시에만 표시)
   └─ DebugPanel (평시 hidden, F3 토글 — DebugHud 흡수)
```

- 등급 색·나인패치 스타일은 전부 `game/ui/theme.tres`에서만 정의하고, `hud.gd`가 런타임에
  `theme.get_color(...)`/`theme.get_stylebox(...)`로 읽어 각 노드에 적용한다(코드에 색 하드코딩 금지).
- 텍스트는 `tr(&"ui.hud.*")` 키로 감싼다. 현재 프로젝트에 번역 CSV가 아직 연결되지 않아
  화면에는 키 문자열이 그대로 보일 수 있다 — narrative-writer의 로컬라이징 테이블 연결 대기
  (남은 이슈 참고).

## 3. 입력 흐름 (패드/키마)

| 동작 | 게임패드 | 키보드 | 결과 |
|---|---|---|---|
| 미니맵 토글 | 패드 select(button 8) | M | `map` 액션 → TopRight 컨테이너 visible 토글, 상태는 세션 내 유지 |
| 디버그 패널 토글 | (없음, 개발자 전용) | F3 | `debug_toggle` 액션 → DebugPanel visible 토글 |
| 퀵슬롯 1~4 사용 | 십자키 상/우/하/좌 | 숫자 1~4 | 기존 `quick_1~4` 액션(D-47), 이번 태스크는 표시만 — 실제 소모 로직은 인벤토리 시스템(F7-2) 범위 |
| 스킬 Q/E | L/R 숄더 | Q/E | 기존 `skill_1`/`skill_2` 액션, 표시만 |

HUD 자체는 비상호작용(포커스 이동 불필요)이라 위 두 토글 외에는 입력 맵 추가가 필요 없다
(작업 지시 5번 확인 완료 — `map`, `debug_toggle` 모두 `project.godot` [input]에 등록됨).

**M5-1(마우스, 선택, 게이트5 피드백)**: 하단 핫바 9칸(`HotbarSlot1~9`)만 예외로 좌클릭=사용을
받는다(`hud.gd:_on_hotbar_slot_gui_input()`). 키보드 1~9와 같은 제약으로 Idle/Move 상태에서만
동작하고, 메뉴가 열려 HUD가 숨겨지는 동안은 `visible` 가드로 자연히 막힌다.

## 3.5 성장 표시 (경험치바·레벨업, M3-2/D-153)

`hud_progress.gd`(별도 파일 — hud.gd가 이미 500줄 상한 D-145에 가까워 분리)가
`Events.exp_changed(current_exp, exp_to_next, level)`/`Events.level_up(new_level, stat_gains)`
두 신호만 구독해 TopLeft의 LevelLabel·(신설) ExpBar와 화면 중앙 LevelUpBanner를 갱신한다.
로직 브랜치(stage/m3-1-exp-level)가 아직 없어 이 신호는 UI 스테이지가 먼저 선언했다
(`core/events.gd`, 합의된 시그니처 그대로 — 병합 시 중복되면 디렉터가 정리). ExpBar는
HP/스태미나와 같은 "장식 없는 색 바"만 쓰고, 640×360 해상도 제약상 숫자 오버레이는
넣지 않았다(레벨 숫자는 LevelLabel이 이미 담당). 레벨업 배너는 3초 노출 + 0.4초
페이드, 스탯 상승은 `stat_gains` 키를 그대로 대문자로 나열한다(스탯 이름 로컬라이징은
game-designer의 stats.json 확정 이후 범위).

## 3.6 SP바 (M4-5, ro-benchmark-progression-v1.md §3)

`hud_sp_bar.gd`(hud_progress.gd와 동일 분리 원칙)가 TopLeft의 StaminaBar와 ExpBar
사이에 새로 넣은 SPBar(4px, 청색 계열 `HUD/colors/sp_fill`)를 담당한다. `Events.sp_changed
(current, max)`는 stage/m4-4(로직)가 신설하는 시그널이라 아직 `core/events.gd`에 없다 —
`Events.has_signal(&"sp_changed")` 가드 뒤에서만 정적 `Events.sp_changed.connect(...)`를
호출한다(가드로 감싼 호출은 신호가 없어도 컴파일·실행이 깨지지 않음을 이 브랜치에서
직접 확인). 병합 전엔 SP바가 항상 0으로 비어 있고, 병합 후 신호가 연결되면 자동으로
채워진다. `hud_skill_slots.gd`도 같은 신호를 구독해 SP가 부족한 스킬 슬롯을 회색으로
표시한다(쿨다운의 검은 오버레이 스윕과는 다른 레이어라 동시에 봐도 구분된다).

## 4. 상태 목록

| 상태 | 트리거 | 표시 |
|---|---|---|
| 평상시 | — | HP/스태미나 바 정상 색, 보스바·비네트·디버그패널 숨김 |
| 경험치 변동 | `Events.exp_changed` | TopLeft ExpBar 값 갱신, LevelLabel 텍스트 갱신 |
| 레벨업 | `Events.level_up` | 화면 중앙 LevelUpBanner 3초 노출 후 페이드(`hud_progress.gd`) |
| HP 25% 이하 | `HudMath.is_hp_critical()` | HP 바 점멸(HUD/colors/hp_warning) + 화면 가장자리 비네트. 색약 모드면 비네트 대신 대각선 해치 패턴(`vignette_overlay.gd`) |
| 스태미나 고갈 | `resources.stamina <= 0` (매 프레임 판정) | 스태미나 바 지속 빨간 점멸 |
| 스태미나 액션 실패 | `Events.player_stamina_insufficient` | 스태미나 바 3회 급속 점멸(플래시) |
| SP 변동(M4-5) | `Events.sp_changed`(has_signal 가드, 병합 전엔 미발신) | TopLeft SPBar 값 갱신, SP 부족한 핫바 스킬 슬롯 회색 |
| 아이템/골드 획득 | `Events.item_picked_up`, `Events.gold_changed`(delta>0) | 좌하단 로그 1줄 추가, 3초 후 페이드, 최대 4줄 스택 |
| 보스전 | `Events.boss_started` / `Events.boss_defeated` | 보스 HP바 표시/숨김. **주의**: 기획 지시문은 `Events.boss_encounter_started`를 언급하지만 실제 이벤트 버스(`core/events.gd`)에는 그 이름이 없고 동등한 `boss_started(boss_id)`/`boss_defeated(boss_id)`가 이미 존재해 그것을 사용했다(신규 시그널 중복 추가 대신 기존 시그널 재사용) |
| 미니맵 토글 | `map` 액션 | TopRight 컨테이너 visible 반전 |
| 디버그 패널 | `debug_toggle`(F3) | DebugPanel visible 반전, DebugHud의 HP/스태미나/콤보/상태/사망수 텍스트를 그대로 흡수 |
| 폰트 크기 변경 | `Settings.font_size_large` / `Events.settings_changed` | Root에 `theme_override_font_sizes/font_size` 적용, 하위 전체에 상속 |
| 색약 모드 변경 | `Settings.colorblind_mode` | 비네트 패턴 전환. 등급 아이콘(●▲◆★✦❖)은 모드 무관 항상 병기(이번 HUD 태스크 범위엔 등급 표시 UI가 없어 `rarity.gd` 헬퍼만 준비, 실사용은 F7-2 인벤토리) |

## 5. 아트 placeholder 현황

- 초상·미니맵 내용물·퀵슬롯 아이콘: 단색 `ColorRect` placeholder (규격만 확정).
- 나무 프레임: `ninja_adventure/Ui/Theme/Theme Wood/nine_path_panel.png` 실제 나인패치 사용(placeholder 아님, 이미 라이선스 확인됨 — `docs/art/LICENSES.md`).
- 퀵슬롯/스킬 슬롯 셀: 동일 팩 `inventory_cell.png` 나인패치.
- 양피지 배경(디버그 패널 등): `parchment_gui/panels.png` 중앙 패널 영역(48,0,48,48) 크롭.
- 나인패치 마진(4px/10px/3px)은 눈대중 추정치 — pixel-artist 확인 후 `theme.tres`에서만 조정.

## 6. 남은 이슈

1. 로컬라이징: `ui.hud.*` 키에 대응하는 실제 한국어 문자열이 아직 어느 CSV/Translation 리소스에도 없다. narrative-writer가 키 테이블을 만들면 자동 반영된다(코드 변경 불필요).
2. (M3-2에서 UI 골격 해소) 레벨/경험치 표시는 `hud_progress.gd`가 `Events.exp_changed`/`level_up`을 구독해 갱신하지만, 두 신호를 실제로 emit하는 경험치 시스템(stage/m3-1-exp-level, godot-engineer)이 아직 병합 전이라 지금은 스모크(`SmokeProgressUi.tscn`)가 신호를 직접 emit해야만 확인 가능하다. 병합 후 실제 전투/퀘스트 보상 경로 재검증 필요.
3. 퀵슬롯·스킬 슬롯은 표시 전용(아이콘·쿨타임 실데이터 없음) — 인벤토리/스킬 시스템(F7-2) 완성 후 연결.
4. 획득 로그는 `item_picked_up`/`gold_changed` 이벤트를 그대로 문자열화한다 — 아이템명 한글화(아이템 테이블 연동)는 F7-2/데이터 테이블 확정 후.
5. 미니맵 홀드 → 월드맵 열기(와이어프레임 제안)는 이번 범위 밖(월드맵 화면 F7-2에서 구현).
6. 나인패치 마진 수치는 추정값 — pixel-artist 리뷰 대기.
