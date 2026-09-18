# 큰 글씨 로그 — 별도 UI 단면

본게임/전역 theme 변경 없음. [v2 실제640×360 캡처](hud-large-sample-v2.png)는 이미지 후처리가 아니라 Godot SubViewport 렌더다. 원본 HUD의 Root(Control)→BottomLeft(Control,154×64)→LogList(VBox,END 정렬), 최대4메시지, 16px 아이콘 행을 복제했다. 테스트 배경 색과 비교 가로배치는 QA용이며 실제 HUD 전체를 띄운 것은 아니다.

## 결과와 제안

아이콘에는 생산 코드와 차이가 있다. 생산 `hud.gd`는 `custom_minimum_size=16`만 지정하지만 이 QA는 `EXPAND_IGNORE_SIZE`도 명시해1254px 원본을16px로 표시했다. 따라서 이번 결과는 **의도한16px 아이콘 행의 시험**이지 현재 생산 HUD의 아이콘16px 보장 또는 동일 이미지의 생산 연결 검증이 아니다. 실제 통합 때 기존 TextureRect 최소 크기·expand_mode도 별도 확인해야 한다.

| 조건 | 실제 VBox 크기 | 남은 메시지 | 판정 |
|---|---|---:|---|
| 기존 방식11px |169×67|4|폭과 하단 넘침 재현|
| Label 직접15px, 기존 배치 |229×84|4|폭과 하단 넘침 재현|
| 15px+WORD_SMART+가시 높이에 맞춰 오래된 행 제거 |154×64|3|현재 사례 경계 안, 최신 아이콘 행 유지|

직계 Label과 HBox 안 Label 모두 11→15→11→15 설정을 갱신해 실제 크기를 확인했다. 입력은 기존 머루 인사 `왔으면 밥부터 먹어. 국 데워줄게.`, 화물 관찰 `묶인 짐을 살펴보자.`, 결계석 관찰 `홀씨 모양의 돌이다.`, 실제 아이템 이름/수량 형식 `슬라임 젤리 x1`이다. 기존 generated 젤리 PNG를 UI Texture로 표시했다. 새 대사나 게임 보상을 만들지 않았다.

권고는 새 로그 생성 시 현재 설정을 Label에 직접 지정하고, 설정 변경 시 기존 직계/아이콘 내 Label도 갱신하는 최소 수정이다. 가로 자동 줄바꿈과 **최대4행이 아니라 최대4메시지 안에서 실제 높이에 맞춰 가장 오래된 메시지를 제거**하는 처리를 함께 검토한다. 과거 메시지가 빨리 사라지는 절충이 있으므로 root 통합 승인 전까지 시험안이다. 단일 메시지만으로64px를 넘는 극단적 입력·보스/다른HUD 겹침·동시 타이머 삭제·연속 보상 폭주는 미검증이며 생산 적용 전 보완해야 한다. 현재 기존 긴 NPC 문장은 대안에서 오래된 행으로 제거되므로 모든4문장 동시 가시성을 보장하지 않는다.

## 실행/격리

재현 코드 `Games/tools/qa/reactivity-font/large-preview.gd`; 별도 `reviews/games-2026-09-12/runtime/hud-large-story-v1/`에 project, raw theme/font/참조PNG 및 import cache 바이트 복사. 원본 editor import 없음. custom user `HudLargeStory`, 프로세스 APPDATA/LOCALAPPDATA를 이 복사본 userdata/localdata로 지정했다. noautoload `--headless --script large-preview.gd -- --probe`가 실제 workspace 경로를 확인하고 native0(tool chunk237772). 렌더도 같은 정확 경로 guard를 재확인했다.

실행은 Godot4.4.1 `--path <QA> --audio-driver Dummy --disable-render-loop --script large-preview-v2.gd --quit-after 120 --log-file <QA>/preview-v2.log`, minimized Window + UPDATE_ALWAYS SubViewport + force_draw(false). v2 로그는28 PASS/실패0 및 `HUD_LARGE_RESULT failures=0`; tool chunk191f00에 `PREVIEW_NATIVE=0` 보존. 기존 certificate-store 오류는 남는다. 일반 GUI 플레이/음향/전체엔진 무오류 검사가 아니다.

v1은 아이콘을 첫행에 두어 대안에서 오래된 아이콘 행이 제거되는 사례(2행 유지), v2는 최신 아이콘을 남겨 3행을 확인한 추가 사례다. v1 로그와 PNG도 보존했다. 원본 theme와 복사본 SHA256은 `8F7DE8839FFA95D81A575468B65D5422D2D7A1C476E777873B3BCBF217C9C9F7`로 동일. 독립 DA 및 본게임 통합 승인 대기.

## 후속 경계 사례 — 시험만, 정책 미채택

`tools/qa/reactivity-font/large-edge-cases.gd`를 동일 격리 QA의 `large-edge-cases-v2.gd`로 실행했다. 기존 noautoload probe와 같은 실제 userdir guard, minimized 프로젝트/Dummy/별도 SubViewport를 사용한다. 첫 `edge.log`는 SceneTree에 없는 `get_tree()` 호출 구문 오류로 native1이었다. 해당 QA 호출을 `create_timer()`로 고친 `edge-v2.log`는 **15PASS/0FAIL, native0**(tool chunk191356의 `EDGE_NATIVE=0`). 첫 실패 로그·스크립트는 보존했으며 생산 코드 오류가 아니다.

- 기존 머루 문장을8회 반복한 스트레스 입력(새 게임 대사 아님)을15px Label에 유지했다. 두154×64 ScrollContainer의 실제 내용은64px보다 길고 clip이 켜져 있으며 원문 문자열이 그대로임을 검사했다. 하나는 시작, 하나는 프로그램으로 끝까지 이동해 마지막 영역 도달을 확인했다. **마우스/패드/키보드 스크롤 조작이나 게임 내 조작정책을 검증·승인한 것은 아니다.**
- burst10개는 시험용 메모리 배열에서 순서/원문을 유지하고 가시행2개만 남기는 후보를 검사했다. 새 기록시스템·세이브·생산 HUD 연결은 없다. 시간 경과 후 재열람 UI도 없으므로 플레이어가10개 모두 읽을 수 있다는 주장이 아니다.
- 제거된8행의 예약 콜백과 살아 있는2행의 타이머/페이드가 끝난 뒤 새 행을 추가해 옛 콜백이 그 새 행을 지우지 않음을 검사했다. QA시간은0.02초/0.01초로 단축했다. 생산 타이머 전체 통합이나 이미 진행 중인 tween을 외부 삭제하는 모든 순열을 검증한 것은 아니다.

[실제 경계 사례 캡처](hud-large-edge-v1.png): 왼쪽 시작/가운데 끝/오른쪽 새 행 유지. UI그림 편집은 없다. 일반 로그에 스크롤을 넣는 결정, 긴 문장 표시시간, 유저가 놓친 burst 재열람 방법은 미확정이다. 따라서 **단일 긴 문장 원문 보존과 경계 제한의 기술적 후보**까지만 확인했으며, 이대로 생산 자동삭제를 채택해 텍스트 손실이 해결됐다고 판정하지 않는다. 독립 DA 대기.
