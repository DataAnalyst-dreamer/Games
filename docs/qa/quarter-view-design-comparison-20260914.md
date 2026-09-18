# 쿼터뷰 정지 디자인 비교 검수 — 2026-09-14

## 결론과 실행

검·슬라임 2개 유효 후보를 실제 마을 배경에서 비교하는 별도 앱을 준비했다. **부분 앱은 24 PASS / 0 FAIL이지만 전체 후보 세트는 2/3, `asset_set_ready=false`다.** 핀은 생성본과 1회 투명 추출 재시도 모두 실제 RGB 체크무늬여서 표시하지 않는다. 정지 후보이지 핀의 최종 64×96 몸체·걷기·공격 모션 완성이 아니다.

`Games/prototypes/quarter-view-lab/Compare-Design.cmd`를 더블클릭한다. Tab은 나란히/기존/후보, Z는 1배/2배, B는 마을/어두운 판/밝은 판, Esc는 종료다. PowerShell 7 및 기존 Godot 4.4.1을 사용한다. 기본 `Play-Quarter-View.cmd`와 실제 전투 배우는 유지했다. 준비가 완료되어 추가 `-Prepare`는 필요 없다.

비교 씬은 실제 엔진 GUI에서 실행했으며 아래 FHD 4장을 GPU readback으로 저장했다. `.cmd`를 더블클릭하는 사용자 동작 자체나 무제한 수동 비교 세션은 대신 실행하지 않았다. 런처의 opt-in 씬 인자/매니페스트 검증은 독립 코드 검토했고 `-VerifyOnly` 실제 native 0을 확인했다.

## 최종 실행 근거

공통 루트: `reviews/games-2026-09-12/runtime/`. 각 폴더에 원본 stdout/stderr/log, 인자·exact 사용자 경로·native/natural 결과 JSON, 별도 noautoload probe 결과를 보존한다.

| 단계 | 세션 폴더 | 결과 |
|---|---|---|
| 정상 import | `quarter-view-import-0869e0e34cf241a8b810bd6a31af387c` | native 0 |
| 실제 Main smoke | `quarter-view-smoke-1c6b7f28152a4e1cbe49ba0314ac11fc` | 11 PASS |
| 전투 fixture | `quarter-view-combat-4c963b4130124a53b9499b8df6499a13` | 58 PASS |
| FHD/입력/가림 회귀 | `quarter-view-capture-d7baa98ab7754a55afee0d8d778ec95f` | 19 PASS |
| 실제 공격 관찰 | `quarter-view-attack-motion-1093b17c024d4c8193861ec2f6b160a2` | 12 PASS |
| 4방향 8포즈 그립 격자 | `quarter-view-grip-grid-d3653cfe99d74f669d9d28a5fd5f3d0c` | 18 PASS |
| 부분 디자인 앱 | `quarter-view-design-check-c61646f4a45e454cbd03ecf2bc8443d7` | 24 PASS, 세트 false |

7단계와 각각의 7개 probe 모두 자연 종료/native 0, FAIL 0이다. 자식별 60초 제한 및 새 GUID APPDATA/LOCALAPPDATA를 사용했다. 알려진 `Failed to read the root certificate store`와 해당 스택 1줄만 허용했고 다른 script/parse/ERROR/종료 잔류 오류는 없었다. 인증서 문제를 수정했다거나 stderr가 비었다는 뜻은 아니다. 기존 사용자 게임 프로세스는 종료하지 않았다.

공격 회귀는 정면 첫 피해 동기 신호 4 physics frames, idle 관측 상한 22 frames였다. 36개 연속 PNG와 HTML은 종전 고정 60Hz/위치 주입 검수이며 실제 하드웨어 입력 지연·새 후보 모션의 증거가 아니다. 전투 fixture의 수동 clock/직접 메서드 범위도 유지한다.

최종 `ready.json`: 검증 파일 **86개**와 console/GUI 엔진 **2개 SHA**를 별도로 기록한다. SHA `222C5A52CFE022685516C55795DF020C91A4DCCA66288C485898B953E98B3174`. 런처 SHA `E91F6B73BA05E43095EBB7456F9216D2C358E616ABFC12491367D371428FBCF9`. 기존 Main 실행 인자는 그대로이고 비교는 명시적 `res://DesignCompare.tscn` 진입만 추가했다. `ready.design_comparison`과 실제 `user://design-readiness.json`에서 partial_app_passed=true, required=3, available=2, missing=[fin], asset_set_ready=false를 교차 확인했다.

## 실제 PNG와 투명도

최종 디자인 세션의 `appdata/QuarterViewLab/`에 다음 실제 1920×1080 파일이 있다.

- `design-compare-native.png`: 나란히 1배
- `design-compare-candidates-2x.png`: 후보만 같은 위치, 2배 정지 검수
- `design-compare-dark-2x.png`: 어두운 판 합성
- `design-compare-light-2x.png`: 밝은 판 합성

`Games/tools/qa/inspect-design-png.ps1`로 원본 byte를 변경하지 않고 독립 검사했다. 아래 bbox는 `[x,y,width,height]`이며 alpha>=128 영역으로 표시 크기를 맞춘다. 실제로는 전체 텍스처를 그려 낮은 알파 주변 픽셀을 잘라내지 않는다.

| 후보 | 원본 크기/알파 | alpha>0 bbox | alpha>=128 bbox | 실제 1배 core 표시 |
|---|---|---|---|---|
| 검 | 1024×1536 ARGB, min 0/max 254 | 193,39,673,1449 | 342,43,344,1443 | 17.641×74 |
| 슬라임 | 1448×1086 ARGB, min 0/max 255 | 71,21,1226,1022 | 319,276,809,575 | 64×45.488 |
| 핀 추출 v2 | 1024×1536 RGB, 전 픽셀 255 | 전체 | 전체 | 미표시 |

검의 alpha0은 1,396,338개, 1..254는 176,526개, 255는 0개다. alpha255가 없지만 실제 투명도는 있다. 슬라임은 alpha0 1,230,297개, 1..254 341,487개, 255 744개다. 핀 v2는 1,572,864개 모두 불투명이며 sample assets로 반입하지 않았다. 단순 이미지 뷰어에서 alpha0의 RGB 잔여색을 후광으로 오인하지 않도록 실제 합성을 검수했다.

마을/밝음/어두움에서 검에 눈에 띄는 후광이나 체크무늬가 보이지 않고 슬라임 얼굴·질감이 읽힌다. 이는 픽셀 단위 완벽한 매트 판정은 아니다. 새 검의 **전체 실루엣 최대 높이 74px**와 기존 코드 검의 **손→검끝 길이 74px**는 다른 규격이므로 칼날만 동등 크기 비교가 아니다. 후보의 붓질과 기존 임시 도트 배우의 미술 차이도 남아 있다.

## 실패 보존과 범위

최초 3후보 필수 검사 세션 `quarter-view-design-check-92124a9197a7406f82e4a20e9a384827`은 **19 PASS / 3 FAIL / 자연 native 1**로 보존했다. 세 FAIL은 핀 enabled, 실제 불러오기/알파 검증, 유효 표시 크기였다. 원래 3후보 기준을 통과했다고 바꾸지 않았다. 기존 진행 승인 범위 안에서 오케스트레이터가 실패한 핀을 제외한 별도 부분 앱으로 범위를 제한했다. PARTIAL_APP24 검사는 핀 disabled/미로드/빈 슬롯·실패 문구와 전체 세트 false를 명시적으로 검사한다.

해당 실패 세션의 `pre-split-source/`에 당시 코드·설정 5개 byte를 보존했고 `source-hashes-v2.json`이 정확한 5파일 목록이다. 첫 `source-hashes.json`은 생성 중 자기 파일을 열거한 메타데이터 오류가 있어 보존만 하며 근거로 쓰지 않는다.

작은 감사 폴더 `quarter-design-audit-132d53215ffd47a9bd1d24aa4290c14b`에 previous-ready, 원본 관측 SHA/mtime, 후보 alpha, 핀 v2 alpha, `after-source-comparison.json`을 보존했다. 기존 14파일 중 **13개 SHA 불변**, 허용된 런처만 변경됐다. Main/world/배경/actor/combat/전투 수치/rig/임시 배우/Play cmd는 불변이다. 원본 `game/`·과거 세이브 전체를 재해싱한 검수는 아니며 그 경로를 쓰는 코드는 추가하지 않았다. 신규 정지 후보 두 PNG 외의 기존 게임 디자인을 교체하지 않았다.

## 독립 검토

실행 담당은 `lge-da`의 제작자와 검토자 분리 원칙을 적용하여 NPC 담당의 비교 씬/설정/QA를 읽기 검토했다. 알파 bbox·core 배율·Fin 보류·세트 false와 앱 성공의 분리에서 전달 차단사항은 없었다. 런처는 NPC 담당이 전체 코드와 PS AST parse 0을 독립 확인했고 필수 수정 0건이다. 이어서 최종 ready의 7단계 native/natural 결과, 디자인 24/0·SETfalse·JSON 2/3 및 실제 FHD 4장을 읽기/시각 대조하여 필수 수정 0건으로 종결했다. NPC 검수자는 전체 매니페스트 재해싱이나 Godot/VerifyOnly 재실행을 하지 않았다. 아트 담당은 최초 합성 FHD 4장 표시 검수에서 필수 수정 0건을 보고했으며 자신의 원화에 대한 독립 승인으로 계산하지 않는다. 루트도 최종 7단계 원본 로그, VerifyOnly 및 실제 FHD 화면을 직접 확인했다.
