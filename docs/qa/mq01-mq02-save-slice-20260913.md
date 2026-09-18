# MQ01–MQ02 상호작용·저장 단면 검사

작성: 2026-09-13. **통합 동작 검사 통과, 게임 UI 완성 판정은 아님.** 신규 기획·보상 수치·슬롯 정책·본 게임 런타임을 변경하지 않았다.

## 변경과 실제 확인 범위

- 신규 sidecar: `game/tests/smoke/SmokeQuestSaveSlice.tscn`, `smoke_quest_save_slice.gd`.
- 기존 `QuestNpc`, `QuestObject`, `QuestTrigger`, `Waystone`, `QuestSystem`, `SaveManager`를 그대로 사용했다. 중복 시스템을 구현하지 않았다.
- NPC·화물·비석: 플레이어를 실제 배치로 이동 → 물리 겹침 확인 → `Input.parse_input_event(interact)` → 기존 입력 처리 경로 검증. 위치 트리거도 실제 물리 겹침으로 진행한다. 경로 찾기·키보드 장치·화면 가독성은 검사하지 않는다.
- 수주/턴인은 기존 `accept`/`advance` 공개 API를 호출한다. 현재 NPC는 대화 신호와 인사 토스트만 제공하고 실제 수주·턴인 UI가 없으므로, 사용자가 UI만으로 처음부터 끝까지 플레이할 수 있다는 의미가 아니다.

## 저장 안전장치

Godot 4.4.1 `--help`에서 사용자 데이터 변경 플래그를 확인할 수 없어 추정 플래그를 사용하지 않았다. [공식 사용자 데이터 경로 문서](https://docs.godotengine.org/en/4.4/tutorials/io/data_paths.html)에 따른 복사본 프로젝트 설정을 사용했다.

1. 원본 `game/project.godot`을 바꾸지 않고 `reviews/games-2026-09-12/runtime/quest-slice-game`에 게임을 복사했다.
2. 복사본에만 `application/config/use_custom_user_dir=true`, `custom_user_dir_name="Games-QA-quest-slice-20260913-classes"`를 설정했다.
3. 게임 오토로드가 없는 별도 `quest-slice-probe` 프로젝트로 아래 실제/의도 경로 일치를 먼저 확인했다. probe는 저장·삭제를 호출하지 않았다.
4. 각 sidecar 프로세스도 경로·전용 이름·custom 설정을 다시 검사한 뒤에만 진행한다. prepare는 기존 QA 자동저장이 있으면 덮어쓰지 않고 거부한다. 파일 삭제 코드는 없다.

```text
ISOLATION_ACTUAL=C:/Users/freer/AppData/Roaming/Games-QA-quest-slice-20260913-classes
ISOLATION_EXPECTED=C:/Users/freer/AppData/Roaming/Games-QA-quest-slice-20260913-classes
ISOLATION_PASS
```

주의: 본 게임 `Metrics` 오토로드는 씬보다 먼저 시작해 종료 시 계측 파일을 쓴다. 따라서 sidecar의 경로 가드만 믿고 원본 프로젝트에서 실행하면 안 된다. **무오토로드 사전 probe와 복사본 설정 검증이 선행 조건**이다. 기존 사용자 세이브를 열거나 삭제하지 않았고, QA 저장·백업·계측 결과는 전용 폴더에 보존했다. 재실행 시 기존 QA 자료를 지우지 말고 새 고유 이름을 probe·복사본·sidecar에서 일치시켜야 한다.

## 결과

| 단계 | 결과 | 근거 로그 (workspace의 reviews/games-2026-09-12/runtime 아래) |
|---|---|---|
| 무오토로드 경로 probe | 일치, exit 0 | `quest-slice-isolation.log` |
| 복사본 import | 리소스 처리 완료, exit 1: 완전 성공으로 보지 않음 | `quest-slice-import.log` |
| 기존 배치 GUT | 7/7 테스트, 92 assertions, exit 0 | `quest-slice-gut.log` |
| prepare | 7 PASS / 0 FAIL, exit 0 | `quest-slice-prepare.log` |
| resume (새 프로세스) | 20 PASS / 0 FAIL, exit 0 | `quest-slice-resume.log` |
| verify (다시 새 프로세스) | 최종 7 PASS / 0 FAIL, exit 0 | `quest-slice-verify-final.log` |
| 잘못된 예상 경로 | ISOLATION_FAIL, 저장 검사를 시작하지 않음 | `quest-slice-gate-negative.log` |

최종 관련 단면 합계 **34 assertions 통과**. 첫 verify는 6개였고 EXP 복원 1개를 추가한 최종 verify가 7개다. 기존 import 첫 실행은 에디터 폰트 `Parameter "fd" is null` 오류가 있었다. 재임포트 `quest-slice-import-repeat.log`에서는 그 오류가 다시 출력되지 않았지만 exit 1이므로 원인 해결·깨끗한 전체 임포트라고 보고하지 않는다. GUT/씬 실행은 모두 exit 0이며 기존 `stats.luk`/`stats.int` 데이터 경고는 유지했다.

prepare: 테오 인사로 MQ01 목표 1 진행 → 비석 입력 활성화 → 실제 슬롯 0 자동저장 1회. resume: 새 프로세스에서 MQ01 부분 진행 및 비석 활성 복원, 복원 자체 저장 0회 → 화물 입력 → MQ01 턴인 → MQ02 실제 마을 진입·머루 인사 → 턴인. 각 턴인은 기존 데이터의 EXP/골드를 정확히 1회 지급하고 재호출은 보상 상태를 바꾸지 않는다. verify: 다시 새 프로세스에서 두 완료 상태와 누적 EXP를 복원, 두 턴인 재호출 거부, 골드·인벤토리·우편·퀘스트 직렬화 상태 불변, 추가 자동저장 0회.

이 두 퀘스트의 기존 데이터는 각 골드 0·EXP 5·아이템 없음이다. 따라서 비영(非零) 골드/아이템 보상의 광범위한 중복 방지 검증으로 일반화하지 않는다. 수치는 변경하지 않았다.

부정 경로 검사 전후 전용 QA `slot0_auto.json` SHA256는 동일했다:
`B2F5643679676A440F5CC507A02939A1489A1DA6E0BF60B02F58324AC38A9BC7`.

## 실행 명령 기록

workspace의 `Games`에서 실행했다. `$godotExe`는 `../reviews/games-2026-09-12/runtime/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe`다. sandbox에서는 Godot 로그 접근 문제가 있어 안전 범위 확인 후 승격 실행했다.

```powershell
& $godotExe --headless --path ../reviews/games-2026-09-12/runtime/quest-slice-probe --script probe.gd --log-file ../quest-slice-isolation.log
& $godotExe --headless --path ../reviews/games-2026-09-12/runtime/quest-slice-game --import --log-file ../quest-slice-import.log
& $godotExe --headless --path ../reviews/games-2026-09-12/runtime/quest-slice-game -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_layout_spawner.gd -gexit --log-file ../quest-slice-gut.log
```

아래 명령은 `$stage`를 `prepare`, `resume`, `verify` 순서로 각각 별도 프로세스 실행한 기록이다. 준비 단계가 기존 저장을 발견하면 중단하며, 무조건 성공으로 간주하지 않는다. 기본 씬을 직접 실행하거나 기존 저장 폴더를 삭제하는 대체 절차는 없다.

```powershell
& $godotExe --headless --fixed-fps 60 --path ../reviews/games-2026-09-12/runtime/quest-slice-game res://tests/smoke/SmokeQuestSaveSlice.tscn --quit-after 600 --log-file "../quest-slice-$stage.log" -- --expected-user-dir=C:/Users/freer/AppData/Roaming/Games-QA-quest-slice-20260913-classes --slice-stage=$stage
```

## 다음에 남은 것

게임 로직 오류는 이 정상 순서 단면에서 재현되지 않아 런타임 수정은 하지 않았다. 다음 사용자 실행 단면에는 수주·턴인 UI 연결이 필요하다. 별도 위험인 조기 위치 방문(one-shot 트리거를 수주 전 소모)·비석 재사용 저장·슬롯 선택 UI는 이번 검사 범위 밖이다. 그림·모션 품질·본 게임 FHD 내부 렌더 전환도 검증하지 않았다.
