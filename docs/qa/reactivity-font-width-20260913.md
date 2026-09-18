# 반응 단문 실제 Godot 폰트 폭 — 2026-09-13

신규 반응 초안40개 `hud_short`만 검사했다. 새 그림/대사 등록/생산 변경 없음. **실제 11px Galmuri11 폰트 측정 최대101px, 154px 초과0**. 확장 대사40개는 검사하지 않았다.

## 동일 조건과 실제 값

원본 `Hud.tscn`은 CanvasLayer 아래 Control Root에 `ui/theme.tres`를 붙인다. Root는 Control, BottomLeft도 Control이며 그 아래 LogList만 VBoxContainer(폭154px)이다. `_push_log_line`은 별도 글꼴/크기 override 없는 Label을 넣는다. `_apply_font_size`는 Root에 기본11/큰글씨15 override를 준다.

동일 테마·폰트·부모/자식 Control/VBoxContainer/Label 상속 구조를 **autoload 없는 최소 프로젝트**에 구성했다. HUD 스크립트를 실행하거나 모든 게임 오브젝트를 생성한 검사는 아니다. theme의 모든 외부 참조4개(Font1/PNG3), 원본 .import 및 관련 import cache만 바이트 복사했다. 새 editor import·원본 .godot 변경·전역 설정 변경 없음.

실제 `get_theme_font_size` 결과:

| 설정 | Root override | 실제 자식 Label | 문장 수 | 최대 폭 | 초과 |
|---|---:|---:|---:|---:|---:|
| default |11|11|40|101px|0|
| large |15|11|40|101px|0|

중요: Root override는 이 구조의 자식 Label에 전파되지 않았다. 따라서 80회 측정은 **두 실제 설정 경로의 같은11px** 확인이며, 15px 접근성 글자 크기 통과가 아니다. 생산 큰 글씨 로그 반영 여부는 후속 UI 문제로 남기고 임의 수정하지 않았다.

최대 폭101px 문장: `다시 판이 두드린다.`, `이쪽엔 표시가 있다.`, `귀환길에 잘 보인다.` 나머지 개별 결과는 `measure.log`의 ID·choice·text·width 80행에 보존했다. 줄바꿈/배경 대비/장시간 가독성/실게임 퀘스트 상태 연결 검사는 아니다. 문구 수정은 필요하지 않았다.

## 격리·실행·해시

고유 프로젝트: workspace `reviews/games-2026-09-12/runtime/reactivity-font-story-v1/`. 기존 monsters 진단 복사본이나 세이브를 쓰지 않았다. custom user dir `ReactivityFontStory`, 실행 프로세스 APPDATA만 이 프로젝트 `userdata`로 지정했다. 무오토로드 probe 먼저 실행하여 실제 경로가 `.../reactivity-font-story-v1/userdata/ReactivityFontStory`와 정확 일치함을 확인했다. 같은 실제 경로 guard가 측정 스크립트에도 있다.

재현 코드: `Games/tools/qa/reactivity-font/probe.gd`, `measure.gd`를 이 프로젝트로 복사. 원본 테마/폰트/참조자원과 import remap은 그대로 복사한다. Godot4.4.1 `--headless --path <QA> --script probe.gd --log-file <QA>/probe.log` → 같은 옵션의 `--script measure.gd --log-file <QA>/measure.log`. 실행 셸에서 APPDATA=`<QA>/userdata`, LOCALAPPDATA=`<QA>/localdata`를 설정한다. 환경 변경은 그 자식 셸 수명 안에만 존재한다.

- probe match=true, **native exit0**.
- `REACTIVITY_FONT_RESULT measurements=80 max_width=101.00 overflow=0 expanded=UNTESTED runtime=UNCONNECTED`, **native exit0**.
- 두 실행에 기존 `Failed to read the root certificate store` 경고가 있었으나 측정은 위 sentinel까지 끝났다. 음원·AudioManager·Metrics·SaveManager 등 autoload가 없다.
- theme 원본/복사본 SHA256 일치: `8F7DE8839FFA95D81A575468B65D5422D2D7A1C476E777873B3BCBF217C9C9F7`.
- Galmuri11.ttf 원본/복사본 SHA256 일치: `E24256F42E43713D2EA086A1E1669D78B968F5B3CC547E5C157F0606FFA5DEF1`.
- 측정 입력 JSON SHA256: `753DDB1657BEBB5D02E430730059C4B17FEDE2BDFA3138E547CCC3DBFB049EF0`. 이후 원본 JSON의 측정 상태 메타만 갱신했고40개 텍스트는 불변. 측정 당시 JSON은 QA 폴더에 보존한다.

문자수 검증기 PASS와 이번 실제 폰트 폭 결과를 구분한다. 기존 측정은 monsters 독립 DA 필수 수정0. 게임 미연결/확장 대사 미검증/큰 글씨15px 미검증 상태는 유지한다.

## 후속 검사 가드 (원래 측정과 별도)

최신 `Games/tools/qa/reactivity-font/measure.gd`를 QA 복사본의 `measure-guard.gd`로 복사하여 실행했다. 기존 `measure.gd`는 이전 측정판으로 보존했다. 후속 가드도 monsters 독립 DA 필수 수정0으로 확인했다.

`measure.gd`에 입력 구조, theme/default_font 및 실제 Label font nonnull, 실제11px, 측정 수 정확80 가드를 추가했다. 같은 격리 프로젝트의 `measure-guard.log`는 80회/최대101/초과0 및 `REACTIVITY_GUARD_RESULT expected=80 actual=80 valid=true`, native0이다. 원래 `measure.log`는 보존했다.

`-- --empty-input-regression` 옵션은 별도 `empty-reactivity.json`의 `{"reactions": []}`를 읽는다. `measure-empty-regression.log`는 측정0에서 가드 false 및 **의도한 native1**을 확인했다. 빈 입력이 통과하지 않음을 검사했으며 원래 JSON은 덮어쓰지 않았다. 정상 실행 tool chunk `c111fe`에 `NATIVE_EXIT=0`, 빈 입력 실행 chunk `14e303`에 `EXPECTED_FAILURE_NATIVE_EXIT=1`을 기록했다. 두 실행의 기존 certificate-store 오류는 동일하게 남는다. 후속 가드 추가는 별도 독립 검토 대상이다.
