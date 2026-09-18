# 독립 쿼터뷰 샘플 1차 실행 QA

2026-09-13. 대상은 `prototypes/quarter-view-lab`만이며 기존 게임의 품질 개선 완료 보고가 아니다. 새 AI 마을 배경과 기존 임시 기사/슬라임을 연결한 작은 실제 플레이 토대다. 핀의 최종 64×96 외형/모션, 신규 직업/퀘스트, 정밀 타일맵은 미포함이다.

## 최종 결과

기존 Godot 4.4.1, 새 사용자 폴더별 정확한 no-autoload probe 선행. 다음 4단계 모두 자연 종료 native 0. 각각 최대 60초, stdout/stderr/result 보존. 기존 사용자 게임 프로세스는 닫지 않았다.

| 단계 | 결과 | runtime 폴더 |
|---|---|---|
| 작은 프로젝트 정상 import | native 0, recovery 미사용 | quarter-view-import-ea4a486dc63a479b9f3bb025685f42e3 |
| 실제 Main headless 기동 | 11 PASS | quarter-view-smoke-6ee8912449dc494ba5f45ebaaa97cb6c |
| 전투 격리 fixture | 37 PASS | quarter-view-combat-71a6ece5eef648d3b41b6fc253deb994 |
| 실제 GUI / 물리 키 입력 / readback | 19 PASS | quarter-view-capture-4d63592d5431415aa2fb804413a50267 |

위 폴더들의 공통 위치는 작업 공간의 `reviews/games-2026-09-12/runtime/`. 마지막 폴더 `appdata/QuarterViewLab/quarter-view-fhd.png`가 실제 1920×1080 viewport readback이다. `tree-behind.png`, `tree-mask-off.png`, `tree-front.png`도 보존했다. 물리 모니터 스크린샷/동영상은 아니다.

GUI는 실제 Main에서 Input.parse_input_event로 D 이동, Space 준비 동작, HUD 위 마우스 공격, H 두 번, F11 창↔독점전체화면, R 초기화를 확인했다. 양쪽 끝 2개 픽셀의 배경 채움 검사는 전체 화면의 모든 픽셀/모서리 검사가 아니다. 나무 뒤·앞 위치는 QA에서 직접 배치했다. 앞뒤 가림은 실제 불투명 투구 중심 15×9 픽셀 비교와 발 위치 Y 정렬을 확인했다. 실루엣 정확도는 자동 검증하지 않는다. root가 첫 FHD 및 나무 3장을 직접 보았다.

전투 37개는 전용 fixture의 수동 시계/직접 메서드 호출이 중심이다. 4방향 원본 프레임을 8방향 이동에 사용한다. 공격 준비/활성/회수, 타깃 1회 피해, 빈 공격 회수, hitstop 입력 버퍼, 넉백/벽 양측/리셋 등을 검사했지만 긴 플레이 밸런스나 실제 소리 청취는 검증하지 않았다. 효과음은 실제 기존 WAV 스트림을 연결했다.

## 실패를 숨기지 않은 수정 이력

- 최초 probe는 이 환경의 `ERROR: Failed to read the root certificate store.` 때문에 실패했다. 오프라인 샘플에서 이 **정확한 문구 하나만** 경고로 분류하고 원본 stderr는 보존한다. 나머지 SCRIPT/Parse/ERROR는 실패다.
- 최초 import에서 smoke의 동적 타입 추론 오류를 명시 Node2D 타입으로 수정했다. native 0이어도 parse 오류를 실패로 판정했다.
- 전투 최초 36 PASS/native 0은 WAV 2개 및 playback 잔류로 실패했다. verbose 진단 후 stop/stream 해제와 200ms 실제 mixer 대기를 적용해 37 PASS/종료 잔류 0으로 해결했다. Shapes 원인이라는 초반 추정은 폐기했다.
- GUI 확장판 18 PASS/1 FAIL은 앞쪽 배우 주변의 넓은 사각형에 UV 배경 경계까지 섞여 완전 일치를 요구한 판정 오류였다. 실패 폴더 `quarter-view-capture-8010848c4e5e4704a3d6badd32801b47` 보존. 앞뒤 모두 불투명 투구 중심으로 좁혀 최종 19 PASS. 넓은 영역의 픽셀 차이만으로 배우 가림을 증명하지 않는다.

## 준비·보호 범위

최종 `ready.json`은 정상 import/11/37/19 종료 후 작성했다. 코드/데이터/애셋/런타임 캐시 56파일 목록과 두 엔진 EXE SHA를 검증하며 editor 가변 캐시와 README, ready 자체는 목록에서 제외한다. 경로 조상·프로젝트 하위 reparse를 거부한다. `-VerifyOnly` 실제 native 0으로 실행했고 게임 창은 열지 않았다.

런처 SHA: `B91D69EBF86BD52CE968DD787D30FFE6B9AAD9E5C6D6E5E06852F651DD8D7369`.
ready SHA: `955ED217CCF6CED506E91DB274C7E2DB1A2A008C1EA44422533942D268A27B4A`.

원본 game 설정/전투/player/기존 ready/기존 세이브/기존 런처는 편집하지 않았다. 신규 샘플의 2 PNG/2 WAV/글꼴/라이선스 2개는 원본과 현재 SHA 동일한 bytecopy다. 원본 게임 전체 해시를 다시 계산한 검사는 아니다. 런타임 코드에 기존 game/세이브 접근 경로가 없고 저장 기능도 없다. smoke의 save.json 부재는 지정 파일 1개 검사이지 전체 쓰기 감사가 아니다. Godot 로그/이미지는 새 격리 사용자 폴더에 쓴다.

전투 source/harness 독립 DA는 art 담당 완료(필수 수정 0). 엔진 두 EXE 검증 누락은 DA 지적대로 보완했다. 최종 GUI 코드/19개 결과와 뒤 135픽셀 변화·앞 0픽셀 변화의 일치도 art 담당 독립 DA 완료(필수 수정 0). 이는 독립 검토자의 재실행/직접 PNG 시각 판정은 아니다. root의 실제 이미지 검토와 구분한다. 본 최종 보고서 문구는 root 검토 대상이다.
