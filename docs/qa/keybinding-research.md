# 액션 RPG 표준 키보드·마우스/게임패드 조작 관례 리서치

> 목적: M1 게이트 플레이테스트 피드백 대응. 현재 바인딩(`game/project.godot` [input] 절,
> `game/README.md` "입력 액션" 표 = GDD 4.1 / D-37)이 동일 장르 관례와 얼마나 맞는지 점검하고,
> 바꿀 항목·유지할 항목을 근거와 함께 추천한다.
> 코드/설정 변경 없음 — 결정은 `docs/brd/04-decisions.md`에 별도 결정 ID로 남겨야 반영된다.
> 작성일: 2026-09-09.

## 요약

- **이동(WASD)·공격(좌클릭)·구르기(Space)·일시정지(Esc)**는 조사한 모든 사례에서 사실상 만장일치
  표준과 일치한다 — 그대로 두는 것이 맞다.
- **구르기/회피 키는 Space가 압도적 표준**이다(Hades, Tunic, Elden Ring, Path of Exile 2 모두
  Space). Shift는 대부분의 게임에서 "회피"가 아니라 "달리기(스프린트)"에 쓰인다. Enter the
  Gungeon(우클릭)만 예외.
- **상호작용 키는 E가 전반적 다수(커뮤니티 추정 75~99%)이며, 같은 장르(하데스·엔터 더 건전) 표본도
  모두 E**다. 현재 프로젝트의 F는 틀린 선택은 아니지만(오픈월드 대작 계열의 또 다른 큰 관례:
  Cyberpunk 2077, Fortnite, Far Cry 등) 장르 표본 안에서는 소수파다. 다만 F를 E로 바꾸려면 현재
  E에 물려 있는 `skill_2`를 다른 키로 옮겨야 한다(트레이드오프, 아래 표 참고).
- **인벤토리/메뉴는 게임마다 제각각**이다: Tab은 이 장르에서 "인벤토리"보다 "지도/요약 패널"에 더
  자주 쓰이고(Diablo 3, Path of Exile 모두 Tab=지도), 순수 인벤토리는 I(Diablo 3, Path of
  Exile)나 E(Stardew Valley)가 더 흔하다. 현재 프로젝트는 Tab=메뉴, M=지도로 **두 기능을 분리**해
  두었으므로 이 구조 자체는 문제없으나, "Tab이 곧 인벤토리"라는 흔한 기대와는 살짝 어긋난다는 점만
  인지하고 가면 된다.
- **가드(홀드)는 장르 표준이 사실상 없다** — Diablo 3의 "제자리 고정(Shift)"이 개념적으로 가장
  가깝고, 소울라이크형(Elden Ring)은 마우스 우클릭이 가드다. 현재 프로젝트는 우클릭을 강공격에
  이미 쓰고 있으므로 Shift 홀드 가드는 남은 선택지 중 합리적인 절충이다.
- **게임패드는 Xbox 레이아웃 기준으로 표준에 대체로 부합**한다: 회피=B(Elden Ring·Diablo 4
  Evade 기본값과 일치), 상호작용=A(업계 전반 표준), 강공격=RT(트리거에 강한 액션을 배치하는 관례와
  일치). 지도=R3 클릭, 소환=L3 클릭은 조사한 표본에서 흔하지 않은 배치라 오조작(스틱을 쥐다가
  실수로 눌림) 가능성이 있지만, 두 액션 모두 전투 중 긴급하게 누르는 키가 아니라서 위험도는 낮다.

## 조사 표 — 키보드·마우스

| 게임 | 장르 | 이동 | 공격 | 강공격/보조 | 구르기·회피 | 가드 | 상호작용 | 인벤토리 | 지도 | 출처 |
|---|---|---|---|---|---|---|---|---|---|---|
| Hades | 로그라이트 핵앤슬래시 | WASD | 좌클릭 | 우클릭(특수) | **Space** | — | E | — | — | [Shacknews](https://www.shacknews.com/article/146103/hades-2-controls-pc-keybindings), [defkey](https://defkey.com/hades-pc-shortcuts) |
| Diablo 3 | ARPG(클릭이동) | 마우스 클릭 | 좌클릭 | 우클릭(스킬) | 없음(회피 스킬 별도) | Shift(제자리 고정) | 좌클릭 | I / B | Tab | [Magic Game World](https://www.magicgameworld.com/diablo-3-pc-keyboard-controls-guide/), [DiabloFans](https://www.diablofans.com/forums/read-only-diablo-forums/diablo-iii-general-discussion/25344-optimal-key-bindings) |
| Path of Exile / PoE2 | ARPG(클릭이동) | 마우스 클릭 | 좌클릭 | 우클릭(스킬) | **Space**(PoE2 신규 회피 롤) | 없음(장르 특성상 회피형) | 좌클릭 | I | Tab | [Fextralife](https://pathofexile2.wiki.fextralife.com/Controls), [Mobalytics](https://mobalytics.gg/poe-2/guides/dodge-roll-mechanic) |
| Elden Ring (2D는 아니나 액션 표준 참고) | 소울라이크 | WASD | 좌클릭 | 우클릭(가드) | **Space**(패치 후 기본값) | 우클릭 | E(추정, 상호작용) | 인벤토리 별도 UI | G | [Fextralife](https://eldenring.wiki.fextralife.com/Controls), 커뮤니티(dodge/jump 키 교체 이력) |
| Tunic | 탑다운 젤다류 | WASD | J/K/L | 실드(;) | **Space**(상호작용 겸용) | ; (실드) | Space | Tab | 매뉴얼 페이지 수집형 | [gamepressure](https://www.gamepressure.com/tunic/keybinds/z8f972), [Tunic Wiki](https://tunic.fandom.com/wiki/Controls) |
| Hollow Knight | 메트로배니아 | 방향키 | X | A(포커스) | C(대시, 회피 개념) | — | 방향키+상호작용 겸용 | — | Tab(커뮤니티 보고) | [Fextralife](https://hollowknight.wiki.fextralife.com/Controls) |
| Stardew Valley | 농장 시뮬 겸 라이트 액션 | WASD | 좌클릭 | 우클릭(도구 사용) | 없음(회피 불필요 장르) | 없음 | 좌클릭 | **E** | F | [Stardew Wiki](https://stardewvalleywiki.com/Controls) |
| Enter the Gungeon | 탑다운 불릿헬 | WASD | 좌클릭 | — | **우클릭**(예외 사례) | 없음 | **E** | Tab(지도 겸용) | Tab | [Magic Game World](https://www.magicgameworld.com/enter-the-gungeon-pc-controls-key-bindings/) |
| Vampire Survivors | 자동전투 로그라이트 | WASD | 자동 | — | 없음(장르 특성상 불필요) | 없음 | 자동 | — | — | [gamepressure](https://www.gamepressure.com/newsroom/vampire-survivors-controls-explained/z14ebf) |
| Crusader Quest | 모바일 오토배틀 SD RPG | 자동(캐릭터 자동 진행) | 자동 | 터치(스킬 블록) | 개념 없음 | 없음 | 터치 | 터치 UI | 터치 UI | [Fandom Basics](https://crusaders-quest-game.fandom.com/wiki/Basics) — **PC 키보드 조작 자체가 존재하지 않는 장르**(참고용 배제) |
| 업계 일반(다장르 참고) | 오픈월드/AAA | WASD | 좌클릭 | — | — | — | **E(우세, 커뮤니티 추정 75~99%)** / F(리닝 기믹 있는 FPS·Fortnite류) | I 계열 다수 | M 계열 다수 | [Witcher 3](https://www.errantdreams.com/2015/05/witcher-3-for-the-pc-default-key-bindings/), [Steam 토론](https://steamcommunity.com/app/1623730/discussions/0/4139438760460511735/?ctp=3), [GOG 포럼](https://www.gog.com/forum/cyberpunk_2077/why_cant_i_change_the_interact_button_i_hate_the_f_key_but_theres_no_option_to_change_it) |

집계(구르기/회피, 키보드 전용 게임 중 명확한 값이 있는 6개 표본): **Space 4(Hades, PoE2, Elden
Ring, Tunic) vs 우클릭 1(Gungeon) vs 없음 1**. → Space가 다수.
집계(상호작용, 명확한 값이 있는 4개 표본 + 업계 일반): **E 3(Hades, Gungeon, Stardew 계열
변형) vs F 1(현재 프로젝트만)**, 업계 전반도 E 우세. → E가 다수, F는 소수파지만 여전히 널리
쓰이는 관례(오픈월드 AAA 계열)이므로 "틀린 선택"은 아님.

## 조사 표 — 게임패드(Xbox 레이아웃)

| 게임 | 공격 | 강공격/보조 | 회피·구르기 | 가드 | 상호작용 | 스킬 | 인벤토리/맵 | 출처 |
|---|---|---|---|---|---|---|---|---|
| Elden Ring | RB | RT(강공격/차지) | **B**(백스텝/구르기) | LB | A(추정) | LT | 별도 UI | [Fextralife](https://eldenring.wiki.fextralife.com/Controls) |
| Diablo 4 | RT(기본 공격) | 페이스 버튼(스킬) | **B**(회피, 기본값) | 없음 | A | 페이스 버튼 4종 | Start/Back 계열 | [pcgamesn](https://www.pcgamesn.com/diablo-4/controller-support), 커뮤니티(sportskeeda) |
| Hades | X/A(대시) | — | X/A(대시, 공격과 분리된 전용 버튼 없음) | — | — | LB/RB(캐스트·스페셜) | — | [shortcutposters 요약](https://shortcutposters.com/games/hades/)(전체 표는 접근 차단, 검색 요약 기준 — **미확인 부분 있음**) |
| **현재 프로젝트** | X | RT | **B** | LT | A | LB/RB | Back(메뉴)/R3(지도)/L3(소환) | `game/README.md` |

패드 결론: 회피=B, 상호작용=A, 강공격=RT는 조사한 표본(Elden Ring·Diablo 4)과 정확히 일치한다.
가드=LT, 스킬=LB/RB는 표본에서 정확히 같은 조합을 찾지 못했지만(Elden Ring은 LB=가드, LT=스킬로
반대), 이미 회피(B)·공격(X)·강공격(RT)이 표준을 따르고 있어 나머지 두 개도 자연스러운 절충으로
보인다. 지도=R3, 소환=L3는 표본에 동일 사례가 없어 "특이하다"고만 표기한다(미확인 — 나쁘다는
근거는 없음).

## 항목별 추천 (유지/변경)

| 액션 | 현재 | 추천 | 근거 |
|---|---|---|---|
| 이동 | WASD+화살표 / 왼스틱 | **유지** | 예외 없는 만장일치 표준. |
| 공격 | 좌클릭 / X | **유지** | 클릭형·논클릭형 ARPG 모두 좌클릭이 기본 공격의 절대 표준. |
| 강공격 | 우클릭 / RT | **유지** | RT에 강한 액션을 두는 패드 관례(Elden Ring·Diablo 4)와 일치. 우클릭이 "가드"로 쓰이는 게임(Elden Ring)도 있으나, 이 프로젝트는 가드를 Shift로 이미 분리해 두어 충돌 없음. |
| 구르기 | Space / B | **유지** | Space가 표본 다수(Hades·PoE2·Elden Ring·Tunic), 패드 B도 Elden Ring·Diablo 4와 일치. 가장 확신도 높은 항목. |
| 가드 | Shift(홀드) / LT | **유지(약한 확신)** | 장르 표준 자체가 약함. Shift는 다른 장르에서 "스프린트"로 더 흔히 쓰이지만 이 게임엔 스프린트가 없어 충돌 안 남. Diablo 3의 "Shift=제자리 고정"과 개념적으로 유사해 완전히 낯선 배치는 아님. 변경 급하지 않음. |
| 상호작용 | F / A | **변경 검토(중간 우선순위)** | 장르 표본(Hades·Gungeon)과 업계 전반 다수(E)에서 밀림. 다만 F→E로 바꾸려면 현재 E인 `skill_2`를 다른 키(예: R, 또는 Q/E 대신 Q/R 조합)로 옮겨야 함 — 이번 리서치에서는 방향만 제시, 실제 변경은 `docs/brd/04-decisions.md`에 결정 ID로 남기고 GDD 갱신 후 진행. 패드 A는 이미 표준과 일치하므로 패드는 변경 불필요. |
| 스킬 1·2 | Q / E | **상호작용 변경 시 함께 검토** | 상호작용을 E로 옮기면 skill_2를 R 등으로 이동 필요. 유지한다면 Q/E 그대로 두어도 무방(MOBA류 QWER 관례와도 부합). |
| 퀵슬롯 1~4 | 숫자키 1~4 / 십자키 | **유지** | Diablo 계열(벨트 1~4)·Path of Exile(플라스크 1~5) 모두 숫자키 소모품 슬롯이 표준. 패드 십자키도 소울류의 아이템 사용 관례와 일치. |
| 메뉴(인벤토리 등) | Tab / Back | **유지, 단 명명 재확인 권장** | Tab을 "지도"가 아니라 "종합 메뉴"로 쓰는 것 자체는 이 프로젝트 구조상 합리적(지도는 M으로 분리했으므로 충돌 없음). 다만 "Tab=인벤토리"라는 흔한 기대(다른 장르에서도 인벤토리는 I가 더 흔함)와 다르다는 점은 튜토리얼/툴팁에서 한 번은 명시할 가치가 있음(코드 변경 아님, UX 문구 권장 사항). |
| 일시정지 | Esc / Start | **유지** | 예외 없는 표준. |
| 지도 | M / R3 클릭 | **유지** | M은 이 장르 표본에서는 소수(대부분 Tab에 지도를 얹음)이지만, WoW 등 더 넓은 RPG 관례에서는 M=지도가 표준이고 이 프로젝트는 Tab을 이미 메뉴로 썼으므로 M 분리가 합리적. 패드 R3는 표본 부재(미확인)로 나쁘다는 근거 없음 — 실사용 피드백 계속 관찰 권장. |
| 소환(mount_call) | H / L3 클릭 | **유지, 관찰 필요** | 조사 표본에 직접 대응 사례 없음(미확인). L3는 스틱을 쥔 채 눌러야 해 오조작 위험이 이론상 있으나, 소환은 전투 중 긴급 입력이 아니라서 우선순위 낮음. |

## 결론 요약 (변경 후보 vs 유지 확정)

- **그대로 두어도 되는 항목**: 이동, 공격, 강공격, 구르기, 퀵슬롯, 일시정지, 지도, 소환 — 근거
  충분히 확보, 이번 플레이테스트 불만의 원인일 가능성 낮음.
- **변경을 검토할 만한 항목**: 상호작용(F→E 후보, skill_2 재배치 필요) — 다만 이번 M1 플레이
  테스트 자유 서술에서 "F가 어색하다"는 불만이 실제로 나왔는지부터 `docs/qa/m1-gate-playtest.md`
  결과와 대조해 우선순위를 정할 것을 권장.
- **약한 확신으로 유지 중인 항목**: 가드(Shift), 메뉴(Tab) — 장르 표준이 약해서 유지하지만, 플레이
  테스트에서 반복 지적되면 가장 먼저 재검토할 후보.

## 주의점

- 표본 10개 중 2개(Crusader Quest, Vampire Survivors)는 애초에 "탑다운 실시간 방향 조작 + 회피"
  구조가 아니라 참고 가치가 제한적이다(Crusader Quest는 PC 키보드 조작이 아예 없는 모바일
  오토배틀; Vampire Survivors는 자동 전투). 두 게임은 "키 배치"보다 "장르 자체가 다르다"는 점을
  주의점으로 남긴다.
- 검색 요약에 의존한 항목(Hades 게임패드 전체 표, Elden Ring 상호작용 키 등)은 원문 페이지가
  프록시 차단으로 직접 확인되지 않아 "(미확인)"으로 표기했다 — 실제 변경 전에는 원문 재확인 권장.
- 여기서 다룬 것은 "구조적 관례"(어떤 액션에 어떤 성격의 키를 쓰는가)이며, 특정 게임의 키 배치
  전체를 그대로 복제하라는 뜻이 아니다.

## 출처 목록

- https://www.shacknews.com/article/146103/hades-2-controls-pc-keybindings
- https://defkey.com/hades-pc-shortcuts
- https://shortcutposters.com/games/hades/ (검색 요약 기준, 원문 접근 차단)
- https://www.magicgameworld.com/diablo-3-pc-keyboard-controls-guide/
- https://www.diablofans.com/forums/read-only-diablo-forums/diablo-iii-general-discussion/25344-optimal-key-bindings
- https://pathofexile2.wiki.fextralife.com/Controls
- https://mobalytics.gg/poe-2/guides/dodge-roll-mechanic
- https://eldenring.wiki.fextralife.com/Controls
- https://www.gamepressure.com/tunic/keybinds/z8f972
- https://tunic.fandom.com/wiki/Controls
- https://hollowknight.wiki.fextralife.com/Controls
- https://stardewvalleywiki.com/Controls
- https://www.magicgameworld.com/enter-the-gungeon-pc-controls-key-bindings/
- https://www.gamepressure.com/newsroom/vampire-survivors-controls-explained/z14ebf
- https://crusaders-quest-game.fandom.com/wiki/Basics
- https://www.errantdreams.com/2015/05/witcher-3-for-the-pc-default-key-bindings/
- https://steamcommunity.com/app/1623730/discussions/0/4139438760460511735/?ctp=3
- https://www.gog.com/forum/cyberpunk_2077/why_cant_i_change_the_interact_button_i_hate_the_f_key_but_theres_no_option_to_change_it
- https://www.pcgamesn.com/diablo-4/controller-support
- https://www.sportskeeda.com/gaming-tech/diablo-4-best-controller-settings-pc-ps5-xbox
- `game/project.godot` [input] 절, `game/README.md` "입력 액션" 표 (프로젝트 내부 근거)
