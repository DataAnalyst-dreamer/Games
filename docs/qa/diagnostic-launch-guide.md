# 별도 진단 실행 경로

`Launch-Game-Diagnostic.ps1`은 정식 `Launch-Overnight-Game.ps1`와 별개다. 편집기 import 종료 실패는 미해결이며 ready.json을 만들거나 정상 준비 판정을 완화하지 않는다. 기존 성공한 보행 단면의 고정 진단 복사본만 대상으로 한다.

Games 폴더 PowerShell 7에서:

```powershell
./Launch-Game-Diagnostic.ps1          # 해시/상태만 검사, 창 열지 않음
./Launch-Game-Diagnostic.ps1 -SelfTest # 새 저장 공간에서 headless 보행/3그림 검사
./Launch-Game-Diagnostic.ps1 -Play    # 명시적으로 진단 게임 창 열기, 종료까지 대기
```

**매번 새 게임 저장 공간을 만든다. 이전 실행의 진행을 자동으로 불러오지 않는다.** 이전 보행 시험 slot0_auto도 사용하지 않는다. 이 제한은 사용자 세이브 보호를 위한 것으로 세션 선택/계속하기 UI를 구현한 것이 아니다. GUI -Play는 현재 작성 단계에서 실행하지 않았다.

## 동결 순서와 범위

먼저 진단용 SmokeDiagnosticWalk.tscn/gd를 복사본에 추가했다. 생산 파일은 바꾸지 않고 원본은 tools/qa/walk-mq01에 보존했다. 고정 userdata guard만 새 child 환경 기대값으로 연결하고 원본Texture2D 3개 로드 검사 추가. 그 뒤 명시적 `-Freeze`로 단 한 번 baseline을 만든다. 기존 baseline 덮어쓰기/자동 갱신은 거부한다.

대상은 workspace `reviews/games-2026-09-12/runtime/autoload-exit-diag-monsters-v1` 하나뿐이다. game 전체(번역·.import·.godot/imported·스크립트 클래스/UID 캐시 포함), probe 전체, console/gui 실행파일과 _sc_를 SHA256 목록으로 동결한다. 추가·누락·변경·reparse 경로는 거부한다. `diagnostic-baseline.json`은 외부 진단 root에 있으며 ready가 아닌 diagnostic_only_not_ready 상태다. 이를 변경해서 검사를 우회하지 않는다.

editor_data와 play-sessions는 가변 영역으로 baseline에 넣지 않는다. _sc_ 모드의 기존 editor_data를 읽을 수 있으므로 모든 설정까지 완전 불변/동일환경이라는 주장은 하지 않는다. 모든 고정 입력은 실행 전후 재검사한다. 런타임이 고정 파일을 바꾸면 실패하고 자동수리하지 않는다.

## 프로세스·세이브 격리

- 매 -Play/-SelfTest마다 고유 play-sessions/GUID 아래 appdata/localappdata/logs를 새로 생성.
- 부모 환경변수는 변경하지 않고 ProcessStartInfo의 자식 환경에만 지정.
- 같은 엔진의 별도 no-autoload probe를 숨김 실행하여 실제 user-data가 새 appdata/AutoloadExitDiagMonsters인지 먼저 확인. native0 필수.
- 본 게임 GUI는 명시 -Play에서만 보이며, 검사는 숨김/headless. GUI가 종료될 때까지 대기한다.
- headless 자식은180초 상한, 초과하면 해당 프로세스 트리만 종료하고 실패. 자연 native 종료와 구분한다.
- 기존 사용자/보행 fixture 경로로 저장하지 않는다. 새 session은 유지하며 자동삭제하지 않는다.

## 검증 상태

classes 독립 코드 DA 필수 수정0 및 기본상태 직접 재실행14779파일PASS(창0) 완료. 실제 GUI 플레이·전체 퀘스트·새 핀·FHD 통합은 이 경로의 성공 판정 대상이 아니다.

2026-09-13 실행 결과:

- 최초 Freeze는 ancestor를 파일마다 반복검사하여 오래 걸려 manifest 생성 전에 자체 shell을 중단했다. 디렉터리 순회에서 각 reparse entry를 한 번씩 검사하도록 최적화한 뒤, 기존manifest없음 확인 후 단 한 번 동결했다.
- baseline **14779파일**, 기본상태 검사 PASS, 창0. 기존manifest 재Freeze 거부 확인. PowerShell parse0, 내부경로허용/상위escape·형제prefix거부 확인.
- -SelfTest 새 session `ec775449711e4346afcafff95ebf9f5c`: 사전probe native0, 3PNG Texture2D 로드 sentinel PASS, 실제WASD/MQ01 UI/autoSave1 보행 sentinel PASS, native0. 전/후 baseline14779 해시PASS. 원래보행fixture 사용하지 않음.
- 세션로그: 진단root/play-sessions/해당GUID/logs/{probe-native,selftest-native}.log. 조건별기존오류는engine로그와함께보존. 새session 저장파일을삭제하지 않았다.
- -Play GUI 경로는 실행하지 않았으므로 실제 창 생성/사용자 조작/종료와 GPU가변캐시 여부는 미검증이다. 성공한 것은 별도진단 headless경로이며 정식readygate는그대로blocked다.

후속 timeout 개선: 자체 자식 Kill/Wait 후 stdout/stderr와 `timed_out=true`, `termination=forced_non_natural`, 관측 종료코드를 저장한 뒤 실패한다. 정상 native 종료로 오인시키지 않는다. 기본180초는 유지한다.

`tools/qa/test_diagnostic_launcher.ps1`는 실제 launcher 함수를 AST로 추출하되 진단 게임/14779manifest를 실행·수정하지 않는다. 고유 작은 fixture의 가짜 입력4개로 baseline/변조/추가/누락 검사를 하고, 별도 PowerShell mock 프로세스를1200ms에 중단해 stdout/stderr/강제종료표식 보존을 확인한다. 작성자 및 classes 독립 실행 모두5검사PASS/native0. 이는 실제14779개를오염시킨변조시험이나Godot자체timeout시험이아니라동일함수의작은격리회귀검사다. 고유 QA fixture/log는보존한다.
