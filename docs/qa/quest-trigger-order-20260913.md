# 장소 선방문 퀘스트 진행 버그 수정

2026-09-13. 사용자 승인된 기존 게임 개선 범위의 버그 수정이다. 새 수주 UI·정책·퀘스트 데이터·보상 수치는 변경하지 않았다.

## 재현과 원인

기존 `QuestTrigger`는 플레이어의 첫 진입에서 퀘스트 수주 여부와 무관하게 `_fired=true`를 저장했다. `one_shot=true`이면 이후 진입을 모두 무시했다. 반면 `QuestSystem`은 현재 활성 목표만 신호로 진행하므로 수주 전 신호는 버려진다. 두 동작을 결합하면 먼저 탐험한 플레이어가 나중에 MQ02를 수주해도 장소 도달 목표를 완료할 수 없었다. 장소 안에서 수주할 때는 새 `body_entered` 신호 자체가 없어 역시 멈췄다.

수정 전 동일 물리 스모크: **8 PASS / 2 FAIL, exit 1**. 실패는 `early visit does not consume later reach objective`, `inside acceptance awards current reach without leaving` 두 항목이다. 로그: workspace의 `reviews/games-2026-09-12/runtime/quest-trigger-before.log`.

## 최소 수정

- `game/scripts/systems/quest_system.gd`: `get_active_reach_objective_keys(location_id)` 읽기 전용 조회를 추가했다. 현재 reach 목표에 해당하는 `quest_id:index` 문자열의 새 배열만 반환하고 내부 Dictionary를 노출하지 않는다.
- `game/scripts/world/quest_trigger.gd`: 최초 방문 신호와 활성 목표별 소비 기록을 분리했다. 목표 키는 신호 발신 전에 기록하여 동기 이벤트 재진입을 방지한다.
- 수주·목표 갱신·성공 로드 후 물리 갱신을 기다려 현재 겹침을 확인한다. 목표 갱신 이벤트는 목표 인덱스 증가보다 먼저 발신되므로 이벤트 핸들러 안에서 즉시 재귀 발신하지 않는다. 상시 폴링하지 않고 두 물리 프레임의 재확인 구간에만 처리한다.
- `one_shot=false`의 매 재진입 발신은 유지한다. 이미 완료한 reach가 다음 talk/interact를 건너뛰지 않는 것도 확인했다.
- `game/tests/smoke/smoke_quest_layout.gd`의 과거 버그 전제 주석만 현재 동작에 맞게 수정했다.

검사 추가: `game/tests/smoke/SmokeQuestTriggerOrder.tscn`, `smoke_quest_trigger_order.gd`. 현재 데이터의 1회 도달 목표를 대상으로 한다. 새로운 반복 방문 횟수 규칙을 추가하지 않는다.

## 검증 결과

모든 로그는 workspace의 `reviews/games-2026-09-12/runtime` 아래에 있다.

| 검사 | 결과 | 로그 |
|---|---|---|
| 무오토로드 격리 경로 재검증 | 일치 / exit 0 | `quest-trigger-isolation.log` |
| 수정 전 동일 재현 | 8 PASS / 2 FAIL / exit 1 | `quest-trigger-before.log` |
| 수정 후 동일 10개 | 10 PASS / 0 FAIL / exit 0 | `quest-trigger-after.log` |
| 저장·목표 전환까지 확장 최종 | 25 PASS / 0 FAIL / exit 0 | `quest-trigger-final.log` |
| 기존 QuestSystem + 배치 GUT | 22/22 테스트, 142 assertions / exit 0 | `quest-trigger-gut.log` |
| 기존 MQ01~MQ03 실배치 스모크 | 31 PASS / 0 FAIL / exit 0 | `quest-trigger-layout-regression.log` |

최종 25개는 선방문 후 밖에서 수주·재진입, 선방문 후 안에서 수주, 수주만으로 바깥 플레이어에게 목표 미지급, 동일 목표 반복 발신 방지, 조회 배열 변경이 원본에 영향을 주지 않음, pending reach를 장소 안으로 실제 로드했을 때 진행 1회, 완료 저장을 로드했을 때 추가 진행 없음, `one_shot=false` 재진입, MQ06 선행 talk 이후 이미 겹친 다음 reach 진행을 포함한다. MQ06 선행 talk는 기존 NPC 공개 함수로 발신하며 NPC 접근·대화 UI 검사는 아니다.

기존 `stats.luk`·`stats.int` 데이터 경고는 유지했다. 최초 복사본 임포트의 exit 1은 [이전 단면 보고서](mq01-mq02-save-slice-20260913.md)에 남아 있으며 이번에 전체 에디터 임포트 문제가 해결됐다고 보고하지 않는다. 새로운 런타임 스크립트는 Godot가 실제 로드해 위 검사를 실행했다.

## 격리·저장 범위와 재실행

기존 `quest-slice-probe`에서 `OS.get_user_data_dir()`와 의도 경로가 아래처럼 일치하는지 다시 확인한 뒤 `quest-slice-game` 복사본만 사용했다.

```text
C:/Users/freer/AppData/Roaming/Games-QA-quest-slice-20260913-classes
```

실제 사용자 세이브 폴더는 읽거나 수정하지 않았다. `slot2_manual.json`은 도달 전 상태, `slot2_auto.json`은 완료 상태를 담는 **전용 QA fixture**다. 없을 때만 최초 생성하고, 재실행 시 그대로 읽는다. 내용이 예상과 다르면 검사 실패이며 덮어써 숨기지 않는다. 삭제 코드는 없다. 슬롯 정책은 기존 `SaveManager`가 허용하는 0~2/manual·auto를 그대로 사용했다.

기존 GUT·MQ01~MQ03 스모크는 완료 신호로 전용 QA의 `slot0_auto.json`을 갱신할 수 있다. 따라서 이전 MQ 단면 실행 시점의 slot0은 불변 아카이브가 아니며, 그 결과는 당시 로그로 보존한다. 새 트리거 검사는 그 slot0에 의존하지 않고 slot2 fixture로 분리했다. Metrics가 씬보다 먼저 계측을 시작하므로 원본 프로젝트에서 sidecar만 실행하면 안전하지 않다. 반드시 무오토로드 probe와 복사본 custom user-dir 검증을 선행한다.

Godot 실행 파일은 `reviews/games-2026-09-12/runtime/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe`. `Games` 폴더에서 실행한 핵심 명령:

```powershell
& $godotExe --headless --fixed-fps 60 --path ../reviews/games-2026-09-12/runtime/quest-slice-game res://tests/smoke/SmokeQuestTriggerOrder.tscn --quit-after 1200 --log-file ../quest-trigger-final.log -- --expected-user-dir=C:/Users/freer/AppData/Roaming/Games-QA-quest-slice-20260913-classes
& $godotExe --headless --path ../reviews/games-2026-09-12/runtime/quest-slice-game -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_system.gd,res://tests/unit/test_quest_layout_spawner.gd -gexit --log-file ../quest-trigger-gut.log
& $godotExe --headless --fixed-fps 60 --path ../reviews/games-2026-09-12/runtime/quest-slice-game res://tests/smoke/SmokeQuestLayout.tscn --quit-after 1200 --log-file ../quest-trigger-layout-regression.log
```

`--quit-after`는 무한 대기 방지일 뿐 테스트 성공 표시가 아니다. 종료 코드와 각 `PASS/FAIL` 최종행을 함께 확인했다. 저장 관련 명령은 검증된 QA 폴더 접근 범위로 승격 실행했다.
