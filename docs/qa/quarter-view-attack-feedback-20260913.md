# 쿼터뷰 공격 반응 피드백 검수

대상은 독립 `prototypes/quarter-view-lab`의 공격 응답뿐이다. 기존 본편, 세이브, 배경, 이동 속도, 월드 및 플레이 카메라는 수정 대상이 아니다. 핀 최종 디자인/전용 공격 아틀라스 제작 완료를 뜻하지 않는다.

## 사전 이력과 검증 범위

이전 ready를 `reviews/games-2026-09-12/runtime/quarter-attack-audit-4beabd625e9b414e86dc3819a993f772/previous-ready.json`에 보존했다. 같은 폴더의 current-source-observation.json은 관찰 시각/mtime/11파일 SHA를 담는다. 관찰 시 다른 담당자가 편집 중일 가능성을 명시했으며, 이후 이 11개 SHA가 이전 ready 값과 모두 동일함을 확인했다. 전체 본편 해싱은 하지 않았다.

작업 도중 기존 ready는 새 소스와 다르므로 `-VerifyOnly`에서 stale 오류/native 1로 차단되는 것을 확인했다. 완료 후에만 작은 프로젝트 준비를 다시 수행한다.

## 실제 입력·이미지 QA 계약

`tests/attack_capture.gd`는 actual Main에서 플레이어와 슬라임을 정면 62px 간격으로 직접 배치하고 적의 예고 동작을 잠시 고정한 fixture다. physical Space 이벤트 1회를 주입하며 게임의 실제 `_physics_process`를 사용한다. 수동 전투 시계 호출이 아니지만 `--fixed-fps 60`의 시뮬레이션 시계이므로 하드웨어 입력 지연/실시간 성능 측정도 아니다.

첫 피해는 HP 변경 직후 발생하는 combat.status_changed 동기 신호에서 물리 프레임을 기록한다. idle 복귀는 이미지 저장을 포함한 process_frame 루프에서 관찰한 상한이며 첫 피해와 측정 정의가 다르다. 10프레임 피해/45프레임 idle 한도는 통합 기동 안전 기준이다. 구·신 개선 목표의 단독 증거로 쓰지 않고 전투 담당자의 같은 조건 8방향 비교와 분리한다.

준비·접촉·회수는 실제 viewport에서 저장하는 1920×1080 PNG 3장이다. QA 카메라만 3배 확대하며 원본 PNG 후처리나 새 이미지 생성은 하지 않는다. 3장의 키 포즈는 연속 애니메이션 전체의 자연스러움/프레임 보간을 증명하지 않는다.

## 최종 결과

정상 import / 실제 Main 11 / 전투 50 / 기존 GUI 19 / 공격 GUI 10 모두 자연 종료 native 0. 각 단계는 새 exact-userdir probe를 통과했다. stdout/stderr/result는 아래 폴더에 보존했다. `--recovery`와 다운로드/설치/정책 우회를 사용하지 않았고 기존 사용자 게임을 닫지 않았다. 알려진 root certificate store 문구 한 개만 이전과 동일하게 분류하며 다른 SCRIPT/ERROR 및 오디오 종료 잔류 오류는 없었다.

공통 위치: 작업 공간 `reviews/games-2026-09-12/runtime/`.

| 단계 | 최종 폴더 |
|---|---|
| import | quarter-view-import-34280ba6068f48198a4d3beed54024a2 |
| Main 11 | quarter-view-smoke-ae15a4586f154a2b8990c05a7b54e549 |
| 전투 50 | quarter-view-combat-475ccb099eb54f9cb91d3ebdbf32811d |
| GUI 19 | quarter-view-capture-f8044641f23444908b1907a7844ec61e |
| 공격 GUI 10 | quarter-view-attack-motion-3ef020fd9d324f94b5617a6b2197b410 |

### 수치와 의미

- 준비/활성/회수 설정: 기존 110/100/230ms → 50/85/140ms. 초반 검 궤적 가속, 접촉 시 가시 궤적/피해 시점 동기화, 회수 후반 기본 자세 복귀를 추가했다. 이동 속도는 230으로 그대로다.
- 동일 고정 거리 62px 전용 fixture에서 60Hz 8방향 모두 구 로직 166.667ms → 신 로직 66.667ms. 30Hz 정면 구 200ms → 신 66.667ms. 구 조건은 byte 보존 v1 controller/config와 현재 actor의 선형 궤적 재생 조합이며 과거 GUI 게임 실행본을 그대로 비교한 것은 아니다. 출력은 `ATTACK_RESPONSE_60HZ` 8행과 `ATTACK_RESPONSE_30HZ` 1행이다. 실제 인간 반응 시간/장치 지연 측정이 아니다.
- 실제 Main의 물리 Space 입력에서는 동기 HP 감소 신호가 **4 물리 프레임** 뒤 발생했다. 60Hz 시뮬레이션 기준 약 66.7ms이다. idle은 21프레임에 관찰했으며 그림 저장을 포함한 관찰 상한이다.
- 단일 입력에서 설정 피해 15를 한 번만 주어 슬라임 HP 45→30. 새 전투 검사는 기존 37개에 응답·표현 관련 13개를 더한 50개다. 11/19/10을 서로 독립 기능 개수로 단순 합산하지 않는다.

### 대표 자세

공격 GUI 폴더의 `appdata/QuarterViewLab/`에 `attack-startup.png`, `attack-contact.png`, `attack-late-recovery.png`, `attack-trace.json`이 있다. 마지막 사진은 회수 비율 60% 이상에서 찍었다. 제작 담당자가 세 장을 직접 확인했으며 접촉에서 검/섬광/HP 감소, 후반에서 몸체의 기본 자세 복귀·검 회수·슬라임 밀림을 확인했다. 가까운 배우의 머리 위 라벨이 겹치는 한계가 남아 있고 QA 3배 확대에서 더 크게 보인다. 일반 플레이에서도 근접 시 발생할 수 있다. 실제 플레이 카메라/라벨 배치는 수정하지 않았다.

앞서 통과한 첫 회수 진입 사진은 `quarter-view-attack-motion-830710667f21405788d736a1aeabec94`에 보존했다. 이를 덮어쓰지 않고 후반 회수 사진을 별도 최종 실행으로 만들었다. 키 포즈 3장만으로 전체 모션 자연스러움이 완성됐다고 판단하지 않는다.

### 준비 및 보호 결과

최종 ready 62파일 및 엔진 console/GUI EXE 2개 SHA 검증. 실제 `-VerifyOnly` native 0, 추가 일반 Play는 자동 실행하지 않았다.

- 런처 SHA: `F5E066AA95C6EF29AADCE0797B802907FF6F8D0482DD5A95DAB65E066A0F2B9B`
- ready SHA: `C3FEC98042E5A658B4BDD35F945AC4D657E39324A777B0A2925AFDC8E552F161`

작은 사전 관찰과 최종 비교는 audit 폴더 `after-source-comparison.json`에 있다. project.godot/main.gd/world.gd/world_layout.json/combat_strings_ko.json/village-gate.png의 6파일 SHA는 동일하다. actor/combat/config/전투 하네스/런처 변경은 이번 요청 범위다. 기존 본편·세이브·이전 본편 실행기에는 변경하지 않았으며 전체 본편을 재해싱한 감사는 아니다.

전투 코드/50개 결과 독립 DA는 art 담당 필수 수정 0. 마지막 공격 GUI 10개 결과/trace 및 세 장의 직접 시각 DA도 완료(필수 수정 0). 동기 피해 4프레임, idle 21 관찰 상한, hitstop 구간의 접촉 자세 유지가 서로 일치했다. 근접 라벨 겹침은 잔존 한계로 기록했다. 최종 보고서 문구는 root 검토 대상이다.
