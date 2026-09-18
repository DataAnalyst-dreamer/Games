# Editor import 종료 차이 재검토 — 2026-09-13 저녁

정식 실행 준비의 editor import 종료 실패를 해소하기 위한 진단이다. 원본 게임·세이브, 고정14779/14781/NPC14804 복사본, ready 조건은 변경하지 않았다. 새 엔진 설치나 외부 다운로드는 없다. 아래 작은 성공은 정식 ready 근거가 아니다.

## 새 가설과 최소 A/B

기존 실패 실행은 `--editor --import --quit`, 최근 작은 CSV/PNG 성공은 `--editor --import`였다. 기존 Godot4.4.1 실행 파일의 실제 `--help`에서 `--import`는 import 완료를 기다린 뒤 종료하고, `--quit`는 첫 iteration 이후 종료함을 확인했다. 옵션 조합의 종료 경계를 가설로 삼되 원인으로 단정하지 않았다. 같은 help에 `--recovery-mode` 지원도 확인했다. recovery는 tool script/plugin 등의 실행을 비활성화하는 **진단 전용**이며 정식 정상 import 조건을 대체할 수 없다.

최소 A/B는 PhantomCamera addon201파일(약1.5MB)을 원본 byte 그대로 복사하고, 필요한 PhantomCameraManager autoload와 viewport640×360 설정을 유지했다. editor plugin은 비활성이다. 원본 게임의 나머지 autoload/씬/다른 addon은 포함하지 않았다. 두 조건 각각 fresh game/cache와 새 APPDATA/LOCALAPPDATA이며 no-autoload probe가 동일한 custom userdir 이름이 각 case 하위에 정확히 해석됨을 먼저 확인했다. 자식프로세스 환경만 설정하며 기존 전역 설정을 바꾸지 않았다.

실행기/템플릿: `tools/qa/editor-import-differential/`의 run.ps1, project.godot, probe-project.godot, probe.gd. run 후 별도 후속 실행기(run-existing-failed.ps1)가 추가되었으므로 최초 inputs207에는 이 후속 파일이 포함되지 않는다.

보존 root(Games 부모 기준): `reviews/games-2026-09-12/runtime/editor-import-differential-9cb48445c46e47ab954b97bab5b5316d`.

| 조건 | probe | 실제 import | script errors |
|---|---|---|---|
| import-only (`--editor --import`) | natural/native0 | natural/native0 | 0 |
| import-plus-quit (`--editor --import --quit`) | natural/native0 | natural/native0 | 0 |

서로 별도 case 경로/사용자 경로인 것 외에 두 프로젝트의 입력 byte가 같고 옵션 차이는 `--quit` 하나다. 각 copy의 사전202파일(201addon+project)과 사후278파일에서 기존파일 변경0, 새생성76개였다. 이는 import cache 등 추가 결과를 포함하므로 copy 전체 불변이라는 뜻이 아니다. 원본 addon201+당시QA파일4+기존engine2=207개 SHA는 실행 전후 불변이었다. engine은 기존 원래 위치의 non-self-contained 실행 파일이며, 과거 실패 snapshot의 `_sc_`/editor_data와 동일 환경이 아니다.

각 case의 probe/import stdout·stderr·result.json, game-before/after.json, root inputs.json/results.json을 보존했다. 기존 인증서 store 읽기 오류는 두 case 모두 있지만 script error나 timeout은 없다. 결과는 자연 종료값이며 강제종료를 성공으로 계산하지 않았다. runner 자체 exit0. 50초 timeout 분기는 이번에 실행되지 않았다.

결론: 이 최소 프로젝트에서 중복 `--quit`나 PhantomCamera 단독이 종료 실패를 재현하지 않았다. 전체게임의 복합 의존성, 기존 editor 상태, 규모와의 상호작용은 배제할 수 없다.

## 기존 실패 snapshot 후속 결과

전체 copy를 다시 만들지 않고 root 승인으로 과거 미준비 snapshot `overnight-builds/20260913-014740-cce9e52e`만 가변 진단 대상으로 재사용한다. 기존 원본로그/preparing/소스와 과거사용자파일은 사전·사후 목록/SHA 비교 대상으로 둔다. `.godot`와 engine/editor_data는 가변 결과를 별도 기록하며 이전 환경을 byte 단위로 재현했다는 주장은 하지 않는다. 새 GUID QA폴더, 새 사용자 경로와 no-autoload exact probe를 사용한다.

후속 실행기 `tools/qa/editor-import-differential/run-existing-failed.ps1`은 `--import` 단독을 한 번만 먼저 실행하고 실패 후 `--recovery-mode` 추가를 한 번 진단했다. 각 자식60초 상한, 자신의 프로세스 트리만 종료하며 stdout/stderr/native/forced 구분을 보존한다. sourceconfig를 편집하지 않았으며 과거 snapshot의 ready.json을 만들지 않았다.

보존 root: `reviews/games-2026-09-12/runtime/editor-existing-differential-96e4d447929f48bba89e35a4a976d063`.

| 조건 | exact probe | import 결과 | 보호파일 전후 |
|---|---|---|---|
| normal `--editor --import` | natural/native0 | natural/native **-1073741819** (access violation), script error0 | 7680개 변경0/추가0 |
| `--editor --import --recovery-mode` | natural/native0 | natural/native0, script error0 | 7680개 변경0/추가0 |

두 조건 모두 timeout은 아니었다. normal 실행은 import/scan 및 loading_editor_layout 종료 로그 이후 native AV를 재현했다. 이전의 중단된 shell 결과와 달리 실제 Godot native 값을 기록한 것이다. `--quit`를 제거해도 실패하므로 해당 옵션만의 수정으로 해결되지 않는다. recovery 성공은 제한된 editor 기능 상태이며 **정상 준비 gate에 사용할 수 없다**.

보호7680은 해당 실패 snapshot의 non-cache 게임파일·원래로그/preparing·probe·engine실행파일·기존 userdata 등을 포함한다. 가변7094는 game/.godot 및 engine/editor_data이다. normal에서 `.godot/editor/filesystem_cache10` 한 파일만 바뀌었고 recovery에서는 변경0이며 추가도 두 경우0이다. cache상태가순차진행했으므로 완전동결동일환경 A/B라고 표현하지 않는다. 두 child는 별도 새APPDATA/LOCALAPPDATA였고 기존 userdata파일은 보호목록으로 불변 확인했다. protected-baseline.json, 각 case protected-after/variable-before/variable-after/audit.json을 남겼다. 기존 인증서 오류는 양쪽에 공통이며 이를 AV 원인으로 단정하지 않는다.

## recovery 차이의 해석과 추가 가설

공식4.4.1 [GDScript::can_instantiate 소스](https://raw.githubusercontent.com/godotengine/godot/4.4.1-stable/modules/gdscript/gdscript.cpp)는 recovery에서 script 인스턴스 생성을 막는다. [EditorNode 소스](https://raw.githubusercontent.com/godotengine/godot/4.4.1-stable/editor/editor_node.cpp)는 일반 editor에서 비-tool 스크립트를 기본 비활성으로 둔다. 따라서 차이는 tool/plugin/extension 등의 실행 범위와 연관될 수 있으나 개별 script 원인을 증명한 것은 아니다. 저장소 scripts에는 @tool 선언이 없고 addons 쪽에는135개가 있으며 .gdextension 파일은 이번 파일검색에서 없었다.

GUT의 @tool GutUtils는 여러 정적 load/LazyLoader.new를 포함하고 과거 GUT 시험도 assertion 이후 AV였다는 점에서 작은 GUT-only import를 추가 가설로 검사한다. 이는 GUT을 원인으로 확정한 것이 아니다. native 스택은 확보하지 못했다(최근 Windows Application1000 조회에서 해당 Godot 이벤트 없었고 cdb/windbg/dumpchk 명령도 발견하지 못함). 별도 설치는 하지 않는다.

### GUT-only 결과

`tools/qa/editor-import-differential/run-gut.ps1`로 addon202파일(약2.25MB)을 새 최소 프로젝트에 byte-copy했다. autoload나 editor plugin 활성화는 없고 정상 editor import만 수행했다. exact no-autoload probe와 import 모두 자연/native0, script error0였다. 이 정상 결과 때문에 recovery 반복은 하지 않았다. 보존root `reviews/games-2026-09-12/runtime/editor-gut-differential-1f11ba3688b44eb48b0239313301c62a`, 원본addon202+QA/engine6=208입력 SHA전후불변. 이 모듈단독시험 역시 전체프로젝트의 AV를 재현하지 못했다.

## 명시적인 편집용 씬 선택 결과

공식4.4.1 [main.cpp](https://raw.githubusercontent.com/godotengine/godot/4.4.1-stable/main/main.cpp)의3629–3630행에서는 명시 scene이 없으면 run/main_scene를 선택하고,3966–3967행에서는 recovery가 아닐 때 editor에 scene을 불러온다. 따라서 같은 전체게임 import에서 편집할 scene만 기존 순수 Control인 `InventoryCell.tscn`으로 지정하는 가설을 root가 제안·승인했다. 해당scene의 inventory_cell.gd는 @tool이 아니다. import자체, autoload설정, 게임의 run/main_scene는 유지했다.

`tools/qa/editor-import-differential/run-explicit-scene.ps1` 실행은 과거 같은 미준비 snapshot에 아래 인자만 사용했다.

```text
--headless --path <과거snapshot/game> --editor --import res://scenes/ui/InventoryCell.tscn
```

**recovery 없이 자연/native0, script error0, Failed to import0**. exact no-autoload probe도 natural/native0. 보존root `reviews/games-2026-09-12/runtime/editor-explicit-scene-1af3d006377c4a519a34a3ab1581f6c5`에 argv/result/stdout/stderr/inputs4/보호·가변목록/audit를 남겼다. 과거보호7680파일 변경0/추가0. 가변cache/editor_data는1변경+1추가였고 구체경로는 audit.json에 있다. timeout이나 강제종료는 없었다.

이 결과는 **Main 편집씬을 여는 동작/종료 경계가 관련된다는 후보 근거**이며 특정 게임script 결함이나 모든 editor작업 해결을 증명하지 않는다. 명시Control씬은 정상 import를 진행하며 게임실행 Main을 바꾸지 않는 방식이다. 이 진단 시점에는 최신source 준비완료가 아니었고 과거snapshot은 지금도 ready로 승격하지 않았다.

후속으로 별도의 최신source 새snapshot1개가 동일 normal import + Main 실제검사들을 통과해 첫 ready를 생성했다. 결과/실행안내는 [최신 준비 보고서](latest-ready-20260913.md)로 분리했다. 이 문서의 진단과 실험에 대한 art 담당 독립DA는 필수수정0으로 완료되었으며, source/캐시한계·정상AV/recovery0/명시scene정상0구분을 확인했다. 독립검토자는 실험을재실행하거나보호7680개를현재전부재해싱한것은아니다. 최신snapshot의 실행기·준비결과 검수는 별도보고서에 기록한다.
