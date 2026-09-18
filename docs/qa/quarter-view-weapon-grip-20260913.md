# 손–검 결합 개선 검수

대상은 독립 `prototypes/quarter-view-lab`의 임시 기사 손–검 부착이다. 기존 본편/세이브/배경/월드/이동과 실제 플레이 카메라는 변경 대상이 아니다. 핀의 신규 도트 아틀라스나 미술 완성을 뜻하지 않는다.

## 이력과 QA 계약

`reviews/games-2026-09-12/runtime/quarter-grip-audit-d5e42e8b7ca24ae5b849e608d4448a30`에 이전 ready와 작은 소스 관찰 11개의 mtime/SHA를 보존했다. 11개 SHA가 이전 ready 값과 모두 동일함을 확인했다. 원본 본편 전체를 다시 해싱하지 않았다.

전투/art 소스 동결 후에만 기존 격리 실행기로 검증한다. 매 단계 새 사용자 폴더·정확한 noautoload probe를 먼저 실행하고 자연 종료/native 상태/stdout/stderr를 보존한다. 준비 및 QA 자식은 최대 60초. 기존 사용자 게임 프로세스를 종료하지 않는다. 알려진 인증서 저장소 문구 한 개 외 SCRIPT/ERROR나 오디오 종료 잔류 오류는 실패다.

### 실제 공격 한 번과 연속 readback

`tests/attack_capture.gd`는 actual Main에 physical Space 한 번을 주입한다. 플레이어와 슬라임을 정면 62px로 직접 배치하고 적의 예고 동작을 고정한 fixture다. 수동 전투 tick을 호출하지 않지만 `--fixed-fps 60`의 엔진 시뮬레이션이며 하드웨어 입력 지연이나 실제 벽시계 성능 측정은 아니다.

동기 HP 감소 신호를 기준으로 기존 정면 4물리프레임 피해를 회귀 검사한다. idle은 관찰 상한이다. 36개 native viewport PNG를 무편집 저장하고 `weapon-motion-preview.html`이 상대 이미지 경로를 재생한다. 로컬 더블클릭용이며 서버/설치가 필요 없다. 프레임 사이 시간은 물리 프레임 차이를 60Hz로 재생하며 루프 사이 650ms 멈춤은 재생기 동작이다. QA 카메라만 3배 확대한다.

각 관찰 프레임에서 get_weapon_attachment의 hand_global/hilt_global 차이를 기록한다. 이는 코드의 부착 좌표 계약 검증이며 손 픽셀을 자동 분할해 쥠의 미술적 자연스러움을 판정하는 검사는 아니다. 실제 이미지/재생 검토와 구분한다.

### 네 방향 × 두 자세 격자

`tests/grip_grid.gd`는 실제 QuarterActor 클래스를 4방향 idle/contact 자세로 직접 배치하고 Godot가 한 FHD 화면을 그린다. PNG를 자르거나 합성한 contact sheet가 아니다. 포즈를 주입한 정적 검수이며 자연 입력으로 8포즈를 실행했다는 주장이 아니다. 각 배우는 3배 확대하고 머리 위 배우 이름은 격자에서만 숨긴다. 손–hilt 좌표/무기 표시 및 실제 readback 크기를 검사한다.

## 최종 결과

정상 import와 Main 11 / 전투 58 / 기존 GUI 19 / 연속 공격 GUI 12 / 격자 18 모두 자연 종료 native 0. 매 단계 probe도 native 0. 36 PNG 저장을 포함해 각 자식은 60초 제한 안에서 정상 종료했고 타임아웃/스크립트 오류/오디오 종료 잔류가 없었다.

공통 위치: 작업 공간 `reviews/games-2026-09-12/runtime/`.

| 단계 | 최종 폴더 |
|---|---|
| import | quarter-view-import-aa6cf90f191c4f56bf60fb05dd96f4b5 |
| Main 11 | quarter-view-smoke-bc09790831254c1891912ecebf2f48d6 |
| 전투 58 | quarter-view-combat-cbc01517a8bf42b6a10b380fa88432a2 |
| 기존 GUI 19 | quarter-view-capture-e69de2ef683b44c3aa5a6ccd0931b13f |
| 연속 공격 GUI 12 | quarter-view-attack-motion-018f31e462d0433e87a72d7931d3d3ce |
| 8포즈 격자 18 | quarter-view-grip-grid-ae528a28074640d3b50322397c05d0dc |

### 실제 변화와 수치 경계

- 방향·idle/attack/walk 자세의 원본 도트 셀 좌표를 weapon_rig.json으로 분리하고 손을 기준으로 검의 자루/칼날을 결합했다. 몸체 앞·뒤 무기 레이어 및 원본 장갑 패치의 겹침 순서를 연결했다. 몸체 PNG를 새로 생성하거나 늘리거나 회전하지 않았다.
- 50/85/140ms 준비/활성/회수, 65ms hitstop, 피해 15, 이동 속도 230은 변경하지 않았다. config 전체 SHA도 이전과 같다.
- 정면 실제 Main의 동기 피해는 기존과 같은 **4 물리 프레임**. idle은 **22프레임에 관찰**했으며 관찰 상한이다. 이전 턴의 21프레임 관찰과 동일하다고 주장하지 않는다.
- 같은 62px 고정 거리 전투 fixture의 손 결합 전/후 8방향 비교에서 index 2/5/7(아래/왼쪽 위/오른쪽 위)은 66.667→83.333ms, 나머지는 66.667ms를 유지했다. 새 손 위치와 실제 검 궤적의 기하 차이이며 타이밍 설정을 몰래 바꿔 맞추지 않았다. 공칭 칼날 범위 값이 같아도 월드 좌표상 실제 도달 범위가 같다는 뜻은 아니다.
- 전투 58개는 기존 50개에 v2 baseline SHA 1개와 부착 관련 7개를 추가했다. 수직/수평 벽 fixture는 실제 Right/Down facing 및 active 자세를 명시했다. 구 기준은 별도 BodyCenterActor 인스턴스이며 같은 actor 상태를 오염시키는 방식이 아니다.
- 36개 관찰 프레임에서 손–hilt 계약 좌표 오차는 0.0이었다. 같은 기점 변수라는 사실 때문에 이 숫자만으로 실제 손 픽셀의 쥠을 합격시킨 것은 아니다.

### 볼 수 있는 산출물

연속 공격 폴더의 `appdata/QuarterViewLab/weapon-motion-preview.html`을 로컬에서 열 수 있다. 같은 폴더의 `motion/frame-00.png`부터 `frame-35.png`까지 36개 원본 readback과 `attack-trace.json`을 사용한다. `attack-startup.png`, `attack-contact.png`, `attack-late-recovery.png`도 따로 보존했다. 격자 폴더의 `appdata/QuarterViewLab/weapon-grip-grid.png`는 실제 FHD 한 장이고 `.json`은 8포즈 좌표 기록이다.

제작 담당자는 최종 격자를 직접 확인해 손잡이 위치, 몸체 앞뒤 관계, 검끝/잔상이 FHD와 각 카드에 들어오는 것을 확인했다. 첫 격자 `103510a7a8344d05b3f11c821aab0d3e`는 검끝 잘림/윗 카드 침범이 있어 보존한 채 폐기 판정했고, QA 배우 배치와 카드 여백만 조정했다. 원본 PNG를 자르거나 게임 좌표를 바꾼 수정이 아니다. 중간 `083003ef988f4fa59d6322cb71b20d7f`의 제목/HP바 겹침도 마지막 배치에서 정리했다.

HTML은 모든 이미지 preload가 끝난 다음 재생하고 시간 초과분을 버리지 않는 bounded 누적 재생을 사용한다. `tools/qa/quarter-grip-preview-check.cjs`의 Node mock DOM 검사 8개 논리 그룹이 통과했다(36 PNG의 FHD 헤더, preload 대기, 재생 준비, RAF, 시간 이월, seek/pause, restart, 0.25배 속도). 기록은 사전 audit 폴더 `preview-mock.stdout.txt`/`.result.json`에 있다. **실제 브라우저의 렌더·재생은 별도로 관찰하지 않았다.**

### 보존·준비 상태

audit의 `after-source-comparison.json`에서 project/main/world/layout/config/전투 문구/배경 7파일 SHA 동일. 새 rig와 actor/combat/하네스/런처/QA 변경만 이번 범위에 포함된다. 본편 전체 및 기존 세이브의 SHA 재감사를 수행한 것은 아니며 그 파일들을 편집하거나 읽는 게임 런타임 경로도 추가하지 않았다.

최종 ready는 **70파일 + 엔진 EXE 2개**를 검증한다. `-VerifyOnly` 실제 native 0. 일반 Play는 자동 실행하지 않았다.

- 런처 SHA: `BF20F6062E0F9BB4A0BDC0CB7F7797D4D8D3CD35EBFF203869F989EA3B7D723B`
- ready SHA: `AF133D300D8D30B8D94160D46458EF38B05CAA1970B2D64C404FFD8C3E32DC31`

전투 코드 및 최종 6단계 로그/ready 70개/격자·공격 대표 3장 직접 시각/trace 36행·PNG 36개 독립 DA는 완료(필수 수정 0). 초기 격자의 프레이밍 문제도 해소된 것으로 확인했다. 검토자가 엔진을 다시 실행하거나 실제 브라우저에서 재생한 검토는 아니다. 새 핀 아트, 모든 방향의 연속 모션, 실제 소리 청취까지 완성한 결과로 확대하지 않는다. 최종 문구는 root 검토 대상이다.
