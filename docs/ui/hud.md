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

## 4. 상태 목록

| 상태 | 트리거 | 표시 |
|---|---|---|
| 평상시 | — | HP/스태미나 바 정상 색, 보스바·비네트·디버그패널 숨김 |
| HP 25% 이하 | `HudMath.is_hp_critical()` | HP 바 점멸(HUD/colors/hp_warning) + 화면 가장자리 비네트. 색약 모드면 비네트 대신 대각선 해치 패턴(`vignette_overlay.gd`) |
| 스태미나 고갈 | `resources.stamina <= 0` (매 프레임 판정) | 스태미나 바 지속 빨간 점멸 |
| 스태미나 액션 실패 | `Events.player_stamina_insufficient` | 스태미나 바 3회 급속 점멸(플래시) |
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
2. 레벨 표시("Lv.1")는 정적 placeholder — characters.json/경험치 시스템(M1 범위 밖)이 아직 없어 `Events.player_level_up`을 실제로 쏘는 곳이 없다.
3. 퀵슬롯·스킬 슬롯은 표시 전용(아이콘·쿨타임 실데이터 없음) — 인벤토리/스킬 시스템(F7-2) 완성 후 연결.
4. 획득 로그는 `item_picked_up`/`gold_changed` 이벤트를 그대로 문자열화한다 — 아이템명 한글화(아이템 테이블 연동)는 F7-2/데이터 테이블 확정 후.
5. 미니맵 홀드 → 월드맵 열기(와이어프레임 제안)는 이번 범위 밖(월드맵 화면 F7-2에서 구현).
6. 나인패치 마진 수치는 추정값 — pixel-artist 리뷰 대기.
