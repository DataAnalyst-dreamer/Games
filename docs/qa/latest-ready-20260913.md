# 최신 소스 실행 준비 — 첫 ready 생성

2026-09-13 저녁, 최신 소스의 **새 복사본1개**에서 정상 editor import와 Main 기반 회귀를 모두 통과해 `ready.json`을 처음 생성했다. 게임 창을 자동으로 열거나 GUI 플레이한 것은 아니다. 핀 모션·전체 리디자인 완성 판정도 아니다.

최신 snapshot(Games 부모 기준): `reviews/games-2026-09-12/runtime/overnight-builds/20260913-215013-3e1dfc92`.

## 원인 분리와 적용한 변경

과거 전체게임 normal import는 native `-1073741819`, recovery는0이었으며 작은 PhantomCamera/GUT 단독에서는 재현하지 못했다. 동일 과거게임에서 편집할 씬을 기존 순수Control `InventoryCell.tscn`으로 명시하자 **recovery 없이 normal import0**을 얻었다. 이 근거와 제한은 [종료 차이 진단](editor-import-differential-20260913.md)에 있다. Main 편집씬 로드/종료와 관련된 후보이지 특정 script의 원인을 확정한 것은 아니다.

준비 실행기는 전체게임 `--editor --import res://scenes/ui/InventoryCell.tscn`을 사용한다. 게임의 `run/main_scene=Main.tscn`, runtime autoload·입력·해상도는 보존한다. editor plugin은 이전 준비 방식과 동일하게 복사본에서만 비활성이다. `--recovery-mode`나 실패 무시는 사용하지 않는다. 이전 실패3개에 ready를 추가하지 않았다.

## 같은 최신 복사본에서 얻은 결과

| 단계 | 결과 | 범위 |
|---|---|---|
| 정상 전체 editor import | natural/native0 | fresh cache, 명시 편집씬 InventoryCell, script/import failure0 |
| Main 패널 입력 | 26 PASS/native0 | 기존22회귀 + 젤리/뿔/버섯/소형물약 Texture2D4개 실제로드 |
| Main 실제 WASD | PASS/native0 | 기본spawn에서419보행frames, MQ01 실제E/Enter완료, EXP5·autosave1 |
| NPC/HUD/번역 | 289 PASS/native0 | 전체239CSV키 일치 포함, 실제Events/HUD. 289개별플레이시나리오 아님 |
| 비석·화물·결계석 | 33 PASS/native0 | S5실제E20 + cargo6 + D28 7, 완료상태주입 fixture 포함 |

단계별 사용자공간은 `sessions/<단계-GUID>/appdata/<snapshot전용이름>`으로 다르다. 각 단계 바로 앞에 no-autoload exact-userdir probe를 별도로 실행했고5개 모두 natural/native0다. 부모 APPDATA/LOCALAPPDATA는 변경하지 않으며 child에만 지정한다. 5개 engine단계도 모두 natural/native0·timeoutfalse였다. 준비 child60초 상한과 출력보존 코드는 있지만 이번에 timeout은 발생하지 않았다. `--quit-after`에 의한 성공 추정은 쓰지 않는다.

root의 `import.log`, `input-smoke.log`, `walk-smoke.log`, `npc-smoke.log`, `waypoint-smoke.log`마다 `.stdout.txt`, `.stderr.txt`, `.result.json`에 실제argv/engine/userdir/native/자연종료를 보존한다. 5probe는 각session에 있다. import에는 기존certificate store 읽기오류, runtime에는 그 오류와 기존stats 경고2개가 남았다. 이번5단계에서는 SCRIPT ERROR나 crash가 없었다.

검사 수를 임의 합산하지 않는다. NPC289 중239는 번역전체, 신규NPC12키는 그 안에 중복검사되며32번만 실제NPC/HUD 이벤트다. S5는 몹제거·teleport 및 완료정보주입을 포함하고 자연보행 완주나 SaveManager.load 시험은 아니다. 패널26은 메인퀘스트 autosave 연결을 끊는 기존시험이며 별도 실제WASD 시험에서 autosave1을 확인했다. 419는 보행 물리frames이며 전체플레이 소요시간이 아니다.

## 복사·소스·캐시 보존 근거

- 원본 game **14806파일**(원래 `.godot` 포함) 전체목록/SHA를 전후 대조했고 변경0이었다. `source-before.json`, `source-after.json`, `source-after-final.json`, `source-audit.json`에 보존했다.
- 원본에서 `.godot`을 제외한7661개 source파일을 새로 복사했다. 별도 cache는 정상import로 생성했다. 팀은 이 동안 원본game 편집을 멈췄다. 원자적파일시스템 snapshot은 아니다.
- 의도적인 copy-only 차이는 `preparing.json`에 명시했다: customuserdir/editorplugin비활성/기존패널시험guard와Texture4추가/WASD시험2파일추가/NPC외부하네스236→239검사2문구변경/S5하네스그대로복사/nativeimport메타데이터.
- `qa-inputs.json`은 원본 외부하네스4파일 SHA를 기록한다. S5 byte가 같고 NPC staging은 키수조건·검사문구 두 곳만236→239로 바뀌었다.
- ready schema2의 `verifiedFiles`는 **14785개**다: game14778(그중 `.godot`7099), probe2, 외부QA2, engine3. `.ctex`/import cache/스크립트 클래스·UID cache를 포함한다. 가변 engine/editor_data, QA·플레이사용자공간, 로그·준비보고서는 제외다. 모든환경이불변이라는뜻은 아니다.
- `ready.json` SHA256: `84B3F8DAEABE884374871724346B105925C584CDE1D25DDDAE0FDA6FD3A242AB`.

## 준비 실행판과 후속 guard판

실제 위 준비를 수행한 실행기는 snapshot의 `preparation-launcher.ps1`에 byte보존했다(SHA256 `2659E10A69E88012AB9C75CBF82EBB45D0F7A5C4B52B83D655790A8400C585A2`). 준비가 끝난 후 독립DA 권고에 따라 현재 `Launch-Overnight-Game.ps1`에 조상·사용자하위reparse 검사 및 pure ready검증함수, **창을 열지 않는 `-VerifyOnly`**를 추가했다. 준비를 다시 실행하거나 새copy를 만들지 않았다.

현재 실행기SHA256 `E0E7F320EDE32593A2736FC62112D17731394FD58F0CB84A4341DDF6100DBB7A`. 이 버전의 실제 `-VerifyOnly`가 같은 ready14785파일을 읽어 검사하고 exit0을 반환했다(`1ed15a`). 엔진·probe·게임창은 실행하지 않았다. source변경검사와 ready파일변조검사는 다른목적이며, 기존source변경이 곧바로 과거preparedcopy를갱신하지 않는다.

기본 실행은 schema2/상대경로/중복경로/누락·추가·해시/검증된engine을 먼저 확인한다. buildRoot/snapshot/각입력tree와 player-session/userdir의 기존조상·하위reparse를 거부한다. 검사와 실행 사이 악의적파일교체까지 막는 보안sandbox나 원자성 보증은 아니다.

QA 저장은 실제 플레이에 재사용하지 않는다. 기본Play는 snapshot의 별도 `player-session`을 사용하고 같은snapshot을다시실행해도그파일을보존한다. 시작메뉴의자동계속하기를구현한것이아니며 기존F5/F9 수동저장규칙은그대로다. 명시적인 기본Play 경로는 아직 실행하지 않아 게임창생성·사용자조작·종료·모니터초기FHD실배율은 미검증이다. 기존640×360논리/1920×1080창요청을보존했을뿐, 앞선FHD샘플을이번최신전체게임의GUI증거로사용하지않는다.

독립 검토: 진단가설/실험문서 DA 필수수정0. 최신5단계/manifest/source/하네스관계 및 이 문서·실행안내 최종DA 필수수정0. NPC 담당은 현재실행기의4개helper를AST추출해 별도 소형경계검사 **17 PASS/native0**도 확인했다(`2ca7e7`). 정상manifest, 구버전/notready/사용자이름/탈출·절대경로/대소문자중복/잘못된·변조SHA/누락·추가/미검증engine/engine탈출/junction직접·조상·하위/추가cache 거부를 포함한다. fixture는 `reviews/games-2026-09-12/runtime/launcher-boundary-da-cd0ca92d32d343e6989de1e7a19bdbe2`에 보존했고 junction 대상도 같은fixture 내부다. 전체game을 변조하거나 최신준비/GUI를 재실행한 검사는 아니다. 대규모 실제14785 `-VerifyOnly`는 작성자가, 소형17경계시험은 별도DA가 실행한 범위로 구분한다.
