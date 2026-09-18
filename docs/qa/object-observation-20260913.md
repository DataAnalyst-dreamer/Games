# 화물 선탐험 진행막힘 수정 · 관찰 텍스트

## 실제 적용 범위

- `game/scripts/world/quest_object.gd`: 기존 E 상호작용으로 화물·민들레 결계석 관찰 문구 표시. 첫 발견 신호는 보존하고, `one_shot` 오브젝트의 활성 퀘스트/목표별 진행 신호를 분리했다. 사용했던 화물도 나중에 목표가 활성화되면 **다시 E를 눌러** 진행한다.
- `game/scripts/systems/quest_system.gd`: 상태를 바꾸지 않는 `get_active_interact_objective_keys` 조회만 추가. 기존 reach helper, 보상, 순서, 자동저장 정책은 변경하지 않았다.
- `game/scripts/ui/hud.gd`: 기존 로그 표시를 호출하는 관찰용 그룹 수신점 추가. `game/localization/ui_ko.csv`에 6문장 추가. 기존 NPC 대사/UI 변경은 이전 작업이다.
- 수주·성공한 로드는 목표별 발신 캐시만 갱신하며 자동 상호작용을 하지 않는다. `one_shot=false`의 반복 신호, 다른 오브젝트의 기존 기능/분기/소멸 정책은 유지한다. 관찰 표시 자체는 퀘스트 신호를 보내지 않는다.

새 정본 설정, 퀘스트, 보상, 수치, 키 바인딩은 추가하지 않았다. 화물과 결계석의 보이는 모습에만 반응한다.

| 상황 | 실제 한국어 문장 | 실제 테마 폰트 폭(px) |
|---|---|---:|
| 화물 처음 | 차곡차곡 쌓인 짐. |125|
| 화물 목표 활성 | 묶인 짐을 살펴보자. |141|
| 화물 재방문 | 짐을 살펴본 자리다. |141|
| 결계석 이전 | 홀씨 모양의 돌이다. |141|
| 결계석 목표 활성 | 돌을 가까이 살핀다. |141|
| 결계석 이후 | 다시 돌 앞에 섰다. |129|

154px 로그 영역을 모두 만족한다. CSV 파서 검사에서 `keys,ko` 구조 및 중복 키 0을 확인했다. 화면 전체의 미적 완성도나 FHD 레이아웃 승인과는 별개다.

## 재현 → 수정

`object-observation-before.log`: 수주 전에 화물을 사용하면 `_used`로 영구 차단되어 수주·테오 대화 뒤에도 MQ01이 `active`에 머무는 실패를 재현했다. 이때 최초 문구 2개의 폭 초과도 함께 발견했고 짧은 문장으로 수정했다.

현재 목표키(퀘스트 ID + 목표 인덱스)를 발신 전에 기록하여 재진입/반복 입력 중복을 막는다. 첫 발견과 나중에 활성화된 목표는 서로 다른 사용 기회다. 재수주 알림/로드는 캐시를 비우기만 하며, 그 자체로 진행하지 않는다. 현재 화물 목표는 1회 상호작용이며, 미래의 같은 오브젝트 다회 카운트 설계를 검증했다고 주장하지 않는다.

## 검증 결과와 종료 한계

| 실행 | 결과 | 실제 native 종료 |
|---|---|---|
| GUT 관찰 + 기존 NPC 대사 | 10 tests / 83 assertions PASS (`object-observation-final-v2.log`) | 정상 종료 아님 |
| 관찰 GUT만 verbose 재검사 | 7 tests / 39 assertions PASS, GUT `Exiting with code 0` | **-1073741819** |
| 실제 E + 실제 파일 save/load | 9 PASS / 0 FAIL |0|
| 새 프로세스에서 같은 fixture 읽기 |4 PASS / 0 FAIL |0|
| 기존 MQ01/02 UI 입력 회귀 |22 PASS / 0 FAIL |0|

GUT 실행은 모든 assertion 이후 native access violation 종료가 발생했다. `object-observation-gut-exit.log`에 assertion/GUT 종료 메시지, 실행 도구 출력에 native 코드가 확인된다. 따라서 GUT 전체 프로세스까지 통과했다고 표현하지 않는다. 원인 확정이나 엔진 수정은 하지 않았다. 별도 smoke는 각각 최종 sentinel과 실제 native exit 0을 확인했다.

- `object-observation-save-create.log`: 사전 E 발견 → 수주/테오 목표(테스트 API) → 목표 활성 상태 실제 slot2 manual 저장 → 명시 E로 준비 → 반복 중복 0 → 실제 load 후 자동 진행 0 → 명시 E 진행.
- `object-observation-save-verify.log`: 새 프로세스에서 위 fixture load → 명시 E까지 active 유지 → 반복 신호/EXP 증가 0. create 9 + verify 4 = 13개 검사. fixture는 한 번만 만들었으며 verify는 덮어쓰지 않는다.
- `object-observation-mqui-regression.log`: E/Enter/Esc, 패드 A, 수주/턴인/중복/모달/인벤토리 겹침 기존 22검사. 이 복사본은 **MQ01/02 전용 패널 버전**이며 다른 담당자의 MQ06/07 확장과 합쳐진 검사는 아니다.
- `test_object_observation.gd`: 범위 밖 입력, 완료 뒤 반복, repeatable 결계석, 미등록 관찰 fallback, 활성/완료 상태 문구, 성공 로드 및 재수주 알림 후 명시 입력을 검사. 재수주 케이스는 합성 상태/알림이며 실제 반복 퀘스트 전 구간은 아니다.

별도 smoke에서도 기존 Data 능력치 경고 2개는 남아 있다. Metrics는 전용 QA 폴더에 저장 성공했다. no-autoload probe에서 OS 인증서 저장소 읽기 오류가 있었으나 사용자 폴더 확인 및 exit 0은 성공했다. 복사본 editor import에는 기존 editor settings 접근 권한 오류/종료 지연이 있었으며 해당 실행만 중단했다. 전역 설정·다른 사용자 프로세스는 건드리지 않았다.

## 저장 격리 및 파일

- 원본 게임을 직접 실행하지 않았다. 기존 격리 `runtime/npc-greeting-game` 전체를 새 `runtime/object-observation-game`으로 복사한 뒤 최신 관찰 코드/테스트를 동기화했다. 링크가 아닌 전체 복사다.
- 복사본 project.godot만 `Games-QA-object-observation-20260913-story` custom user dir로 변경. 원본 project.godot/사용자 세이브는 변경하지 않았다.
- 무오토로드 `runtime/object-observation-probe`가 실제 `C:/Users/freer/AppData/Roaming/Games-QA-object-observation-20260913-story`를 먼저 확인했다 (`object-observation-isolation.log`). 게임 smoke 자체도 같은 절대 경로를 검사한다.
- QA fixture `user://saves/slot2_manual.json`은 기존 파일이 있으면 create를 거절한다. 기존 UI-save fixture와 폴더/슬롯 모두 분리했다.
- `quest_object.gd` 원본/실행 복사본 SHA256 일치: `CECFA18A1B956A4A32FE1E60578FD110B77255C26D4905159F0C71DBE7640DDE`.
- 추가 smoke 원본: `game/tests/smoke/SmokeObjectObservationSave.tscn`, `smoke_object_observation_save.gd`.

관찰/화물 1차 독립 DA 필수 수정 0. 이후 D28 통합 회귀 수정은 아래에 별도 기록한다. 새 아트나 완성 게임 플레이 테스트를 의미하지 않는다.

## D28 복합 비석 입력 회귀 (후속)

Root 검수로 `ward_stone_dandelion`과 Main의 `Waystone1`이 같은 물리적 결계석(D28)인데, QuestObject가 E를 소비하면 Waystone 입력에 도달하지 않는 문제가 발견되었다. `ward-waystone-before-v2.log`에서 실제 `PAUSABLE` 월드, 동일 E 입력으로 **3 PASS / 3 FAIL, native exit 1**을 재현했다. 관찰/MQ04 완료는 되지만 비석 활성화가 안 되고 자동저장이 하나 부족했다.

최소 수정은 QuestObject의 물리 E 경로에서 기존 진행 처리 후, `ward_stone_dandelion`인 경우에만 `waystones` 그룹의 `waystone1`을 찾고 **그 비석의 플레이어 겹침 범위까지 확인한 뒤** `activate()`를 호출하는 것이다. 일반 이벤트 소비는 유지하여 다른 오브젝트를 무차별 동시 작동시키지 않는다. 직접 `interact()` API나 관찰 표시만으로 비석을 켜지 않는다. Waystone/SaveManager 및 데이터는 변경하지 않았다.

- `ward-waystone-fixed.log`: **6 PASS / 0 FAIL, native exit 0**. 실제 E 한 번으로 관찰, MQ04 완료, `Waystone.is_active`, `GameState.last_waystone` 확인. 모달 E는 양쪽 동작/저장 0. 반복 E는 반복형 관찰만 유지하고 추가 저장/EXP 0.
- 첫 E의 자동저장은 **2회가 정상**: 기존 MQ04는 giver=system이므로 완료 트리거 1회, 비석 최초 활성화 트리거 1회. 별도 기존 사건이며 저장 정책을 합치거나 변경하지 않았다. 비석만 최초 활성화되는 상황의 기대값 1회와 구분한다.
- `ward-waystone-mqui-regression.log`: 기존 MQ01/02 패널 스냅샷 회귀 22 PASS, native exit 0.
- 최초 `ward-waystone-before.log`는 smoke root의 ALWAYS를 월드가 상속한 잘못된 조건이므로 유효 재현 근거로 사용하지 않는다. 보존만 한다. 이후 양쪽 모두 월드를 명시 PAUSABLE로 맞췄다.
- before/fixed는 동일 테스트 시나리오지만 새 독립 custom user dir `Games-QA-ward-waystone-20260913-story` / `Games-QA-ward-waystone-fixed-20260913-story`를 사용했다. 양쪽 no-autoload probe 통과. 기존 fixture는 덮어쓰거나 삭제하지 않았다. 두 경로 외에는 smoke가 실행을 거절한다.
- 최종 QuestObject SHA256: `970AF6E8B795491433B101AC11FEEE8961BA4ED9716D3325F148FE29B5EE47C6`. 이전 CECF 해시는 D28 수정 전 관찰 단계 기록이다. classes 담당자에게 이 최종 해시로 재freeze 전달했다.

## 실제 HUD 렌더 확인

`SmokeObjectObservationCapture.tscn`은 실제 Main을 띄우고 물리 E를 주입하여 네 상태를 캡처한다. 초기 퀘스트 상태는 테스트용 API로 구성하며 플레이 전 구간 증명은 아니다. 그림을 새로 만들거나 편집하지 않았다.

- `object-observation-capture-v2.log`: 최종 D28 소스 기준 **16 PASS / 0 FAIL, native exit 0**. 번역 문구, 로그 영역 내 위치, 모달 비표시 및 PNG 저장 확인.
- `observation-cargo-before.png`, `observation-cargo-active.png`, `observation-cargo-after.png`, `observation-ward-active.png` 네 장 모두 실제 renderer PNG **1280×720**. 직접 view_image로 확인했다. FHD 캡처나 논리 좌표 이관 완료가 아니다.
- 네 문구는 화면 왼쪽 아래에 잘림 없이 나타나며 중앙 월드/퀘스트 패널을 덮지 않는다. 기존 흰 글씨가 밝은 잔디에 놓이면 대비는 낮은 편이며 배경 대비 개선은 별도 UI 미관 후속이다. 기존 임시 아트·도형, 맵 가장자리의 회색 영역이 그대로 보인다. 최종 핀/배경 디자인이 아니다.
- 캡처 테스트에서만 main-stage와 waystone 자동저장 구독을 해제하여 기존 QA fixture를 보존했다. 생산 코드의 자동저장은 정상이며 위 별도 저장 smoke는 구독을 유지한 검사다.
- 최신 MQ06/07 패널·인벤토리 아이콘까지 합친 동일 소스 snapshot은 classes의 portable 준비가 끝난 뒤 별도 통합 검사 예정이다. 이 캡처만으로 해당 통합을 통과했다고 주장하지 않는다.
