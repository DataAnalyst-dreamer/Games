# S5 언덕 비석 관찰 — 세 상태의 실제 입력 반응

2026-09-13. 기존 `quest_side_heartland_waypoint`와 `waypoint_stone_01`에 관찰 3줄만 연결했다. **작은 import/표현 검사 267 PASS**, 별도의 **실제 Main·Area·E 입력·HUD 검사 33 PASS**, 각각 자연 종료 native 0이다. 신규 퀘스트/환경 발견 등록, 워프 기능, 보상·세이브 정책은 추가하지 않았다. 독립 DA 완료, 필수 수정 0건이다.

## 채택 범위와 시점

기존 확정 퀘스트의 언덕 비석을 살피는 행동만 표현한다. 미등록 6퀘스트/4발견 원안은 필요한 표지·천·문·걸이 등 소품이 없는 상태여서 문장만 연결하지 않았다. 이번 작업을 그 초안들의 구현으로 집계하지 않는다.

| 퀘스트 상태 | 관찰 문장 |
|---|---|
| locked / available | 언덕 위 비석이다. |
| active (reach / interact 두 단계 모두) | 비석을 살펴보자. |
| complete_ready / completed | 살펴본 비석이다. |

`QuestObject.interact()`는 **퀘스트 신호를 보내기 전** `observation_key()`를 읽는다. 따라서 마지막 interact 목표를 충족하는 E 입력에서는 active 문장이 나오고, 다음 명시적 E 입력부터 after 문장이 나온다. 첫 발견 때 `_used=true`가 되어도 퀘스트를 마쳤다고 간주하지 않는다. 아직 reach 목표인 active 상태도 ‘조사해 보자’는 문장일 뿐 목표 완료/워프 활성화를 주장하지 않는다. complete_ready는 기존처럼 완료 보고를 기다린다.

원본의 변경 범위는 `quest_object.gd`의 observation 분기, `ui_ko.csv` 3행, 실제 Godot importer가 만든 `ui_ko.ko.translation`이다. `test_waypoint_observation.gd`도 추가했지만 GUT으로 실행한 결과는 아니다. 아래 실제 입력 검사는 별도 외부 하네스의 결과다.

## 작은 번역/표현 검사 — 267 PASS

실행: Games에서 `./tools/qa/run-waypoint-import.ps1`.

QA root는 Games 부모 기준 `reviews/games-2026-09-12/runtime/waypoint-observation-20260913-v1`이다. 새 no-autoload `probe`/`import` 프로젝트만 만들었다. 원본 프로젝트의 editor import는 실행하지 않았다.

- 첫 세션 `import-bdd36ab4dee048468f9f67a6a130a366`: exact probe/native0, 실제 CSV reimport/native0 후 QA 하네스의 `key` 변수 타입 추론 오류로 check/native1. 로그와 당시 실패 하네스 byte-copy를 보존했다. 생성 번역을 이 실패에서 원본으로 승격하지 않았다.
- 후속 `import-c97cd4e03625450e89d81fd5a121bbb3`: 같은 실제 import 산출물을 사용하고 QA 변수만 명시 String으로 수정했다. probe/import/check 모두 natural/native0, `WAYPOINT_IMPORT_CHECK_RESULT PASS=267 FAIL=0`.
- 267 구성: compiled 번역239 + 키 개수1 + 실제 폰트 bytes1 + 3줄×11/15px 폭6 + production 관찰 메서드 추출 컴파일1 + S5 상태5×used 여부2=10 + 기존 ward5/cargo3/미지정1 = 267. 상태 부분은 QuestSystem fixture를 붙인 메서드 검사이지 실제 게임 진행이 아니다.
- 원래 236 CSV 키의 값 변경0, 신규 키는 `observe.waypoint.before/active/after` 3개뿐이다. 실제 `.translation`의 239개 문자열 모두 CSV와 일치한다. font는 원본 Galmuri11 bytes로 측정했으며 11px 최대90, 15px 최대123으로 154px보다 작다. production 큰 글씨 전파나 화면 대비를 고쳤다는 뜻이 아니다.
- 기존 원본 번역은 해당 성공 세션 `ui_ko.ko.translation.before`에 보존했고, `promotion.json`은 원본 localization 전후 8파일 중 생성 번역1파일만 변경됐음을 기록한다. 그때 CSV는 이미 3행 추가된 상태이다. `inputs.json`은 선택 입력7개 해시이며 전체 환경 동결 증거가 아니다.

## 실제 Main/E/HUD — 33 PASS

실행: Games에서 `./tools/qa/waypoint-observation/run.ps1`.

새 전체 게임 복사 없이 기존 **가변** `runtime/item-panel-game`을 사용했다. 원본/고정14779·14781·NPC14804 프로젝트를 변경한 것이 아니다. root 승인 후 필요한 아래 5파일만 원본에서 byte-copy했다.

1. `scripts/world/quest_object.gd`
2. `scripts/systems/quest_system.gd` — 기존 가변 copy에 없던 read-only active interact query 의존성.
3. `scripts/ui/hud.gd` — 기존 world observation group/현재 NPC 대사 의존성.
4. `localization/ui_ko.csv`
5. `localization/ui_ko.ko.translation`

성공 세션 `runtime-447fbbeb2a8f49d09739abfe8fdc31da`의 `copy-before/`에 이전5파일을 보존했다. `copy-before.json`과 `runtime-before.json`으로 갱신 범위를 확인한다. 별도로 보존 대상8파일(menu·QuestTrigger·Waystone·items·item_icons·quests·world_objects·물약PNG)은 갱신 전후 동일하다. runtime 전후 선택13파일 SHA도 동일하다(`runtime-before.json`/`runtime-after.json`). **전체 게임 파일 재해싱이나 최신 전체 통합 검증은 아니다.** 외부 runner/harness/probe/config/console engine5개 해시는 `inputs.json`에 별도 기록했다.

새 GUID 세션의 APPDATA/LOCALAPPDATA를 자식 프로세스에만 설정했다. `runtime-probe`에는 autoload가 없고 실제 user dir가 `<session>/appdata/Games-QA-item-panel-20260913-monsters`와 정확히 일치함을 먼저 확인했다. 그다음 실제 게임 Main/autoload를 headless·Dummy audio·fixed60으로 실행했다. 이전 saves가 있으면 거부하며 timeout60초는 자체 child만 종료·로그보존·실패 처리한다. 이번 probe/runtime은 모두 timeout 없이 native0이다.

33개의 관찰은 다음 범위다.

- S5 20개: 실제 번역, locked/available, 기존 Area2D와 플레이어 물리 overlap, 수락 전 E, reach 단계 active, 범위 밖 E, 실제 reach 목표 진행, 완료를 일으키는 E의 active 표시, 다음 E의 after 표시, complete_ready 유지, active/완료 상태 복원 fixture와 load 알림 후 명시 E, 추가 자동저장/골드/EXP/워프 없음.
- 화물6개: 실제 overlap, 퀘스트 전 E, 수락/테오 신호만으로 자동 진행하지 않음, 후속 명시 E로 진행, one-shot 중복 신호 차단, 재관찰 문구 유지.
- D28 7개: 공유 물체 두 Area overlap, 메뉴 동안 E 차단, 하나의 실제 E로 기존 Waystone 활성화 및 MQ04 처리, 원래 두 자동저장(시스템 퀘스트 완료1+첫 비석 활성화1), 관찰문 유지, 반복 E에서 추가 저장/EXP 없음.

로그 `runtime.stdout.log`의 `WAYPOINT_RUNTIME_RESULT PASS=33 FAIL=0`, `runtime.result.json`의 natural_exit=true/native_exit=0을 보존한다. SCRIPT ERROR는 없었고 기존 certificate store 오류·stats 경고는 남는다. Metrics가 격리 user dir에 세션 로그를 기록하며, D28 검사에서 새 격리 autosave를 만들었다.

## 원본 생산 파일 해시

| 파일 | SHA256 |
|---|---|
| `quest_object.gd` | `616A43B983505B9691936B8DE4E4E18BE5E8B398B070C72A48C12BB74B9AC22F` |
| `ui_ko.csv` | `D32E3E15FA2E1C426A364DA57D02679761E9305A71F2891E2B134544FA82C046` |
| `ui_ko.ko.translation` | `482D20DF1D9205684BF007E374BE0B1F1FDA6A19FB800A9C33B092363B37DC99` |

## 검증하지 않은 것

Main의 몬스터를 제거하고 플레이어를 기존 소품 위치로 teleport한 뒤 실제 physics overlap/E 이벤트를 사용했다. 자연 보행·전투 완주·FHD 렌더는 아니다. 상태 복원은 `QuestSystem.from_dict`+`load_completed.emit` fixture이며 실제 SaveManager.load/프로세스 재시작 시험이 아니다. S5 완료 상태를 주입했으며 실제 보상 수령/워프 개방은 시험하지 않았다. 물약44/FHD 및 NPC286의 과거 결과를 이번 동일 최신 버전의 통합 검사로 합치지 않는다. 원본 전체 import·정식 런처 준비·핀 모션은 이 가변 copy 검사의 범위 밖이다. 이 검사 이후 별도 최신 fullcopy에서 진행한 준비 및 회귀 결과는 [최신 실행 안내](overnight-playtest-guide.md)를 참조한다. 이후 준비 성공을 이 가변 copy의 ready 승격으로 해석하지 않는다.

## 독립 DA

art_review 담당이 생산 관찰 분기·CSV 변경, 작은 importer/267 검사와 최초 QA 실패 보존, 실제 E/HUD 33검사 하네스·로그·자연 종료0, 보고서의 상태/보상/통합 범위를 읽기 검수했다. 기존 236 CSV 값 변경0·신규3을 독립 계산했고, 선택13파일 전후 및 현재 SHA·이전5 backup·보존8파일의 차이0을 직접 확인했다(`60fa2c`). 필수 수정0이다. 독립 담당이 Godot를 재실행하거나 전체 게임 copy를 재검수한 것은 아니다.
