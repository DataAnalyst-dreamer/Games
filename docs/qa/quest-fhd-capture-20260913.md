# 퀘스트 패널 FHD 렌더 진단

2026-09-13. **실제 Godot 렌더 readback 1920×1080 캡처 성공.** 본 게임의 논리 좌표계·시야·UI 배치·아트는 바꾸지 않았다. [실제 FHD PNG](quest-panel-fhd-native.png)는 PNG 확대가 아니라 Godot OpenGL 렌더에서 직접 저장했다.

## 원인과 분리 검사

원본 및 복사본은 모두 논리 640×360, window override 1920×1080, `canvas_items`, 정수 배율이다. 기존 NPC 테스트에는 별도 Window.size/1280×720 강제 코드가 없었다. [앞선 1280×720 기록](quest-npc-panel-2026-09-13.md)의 요청 조건만으로는 결과 해상도를 보장하지 못했다.

| 항목 | CLI 요청만 적용 | QA 런타임 Window.size 재요청 |
|---|---|---|
| 프로젝트/CLI 요청 | 1920×1080 | 1920×1080 |
| 네이티브 클라이언트 실측 | 1920×1061 | 1920×1080 |
| 논리 content/visible rect | 640×360 | 640×360 |
| integer stretch transform | 2배 | 3배 |
| `get_texture().get_image().get_size()` | 1280×720 | 1920×1080 |
| 결과 | 해상도 assertion 실패 | 10 PASS, FAIL=0, exit 0 |

**직접 관찰한 인과 경로:** 시작 시 실제 창 높이가 요청한 1080보다 작은 1061이었다. 1061/360은 3보다 작으므로 정수 배율이 2로 내려가 640×360의 2배인 1280×720 이미지가 나온다. 런타임에서 같은 창에 `Window.size=Vector2i(1920,1080)`을 다시 요청하면 3배와 FHD readback이 된다. 따라서 CLI 옵션이 누락되거나 후속 게임 코드가 720으로 덮어쓴 것이 아니라, 초기 실제 창 크기와 정수 스케일의 결합이 원인이다.

높이 축소가 정확히 어느 엔진/Windows 장식 처리 함수에서 발생하는지는 소스 추적하지 않았다. 디스플레이·작업 영역·창 장식 제약의 초기 맞춤으로 추정하며, 특정 DPI 버그로 단정하지 않는다. 두 모니터 실측은 2560×1080 및 1920×1080, 둘 다 작업 영역 높이 1032, scale 1.0이었다. 모니터 이동 없이 같은 화면에서 재요청만 한 최종 비교로 통과했으므로 화면 이동을 해결책의 필수 조건으로 삼지 않는다.

[Godot 4.4 Window 문서](https://docs.godotengine.org/en/4.4/classes/class_window.html)는 `content_scale_size`가 논리 기준이며 `CANVAS_ITEMS`는 대상 크기로 렌더한다고 구분한다. [DisplayServer 문서](https://docs.godotengine.org/en/4.4/classes/class_displayserver.html)는 `window_get_size()`를 장식 제외 클라이언트 크기로 정의한다. 이 구분대로 창 크기·논리 크기·실제 이미지 크기를 따로 기록했다.

주의: 이 환경에서 `ViewportTexture.get_size()`는 각각 2560×1440/5760×3240으로 보고되어 readback Image 크기와 일치하지 않았다. 로그에는 `viewport_texture_reported_size`라는 별도 진단 값으로 남기고, PNG 해상도 판정에는 사용하지 않는다. 이 차이의 엔진 내부 원인까지 해결했다고 주장하지 않는다.

## 산출물과 검증

- QA 하네스만 추가: `game/tests/smoke/SmokeQuestFhdCapture.tscn`, `smoke_quest_fhd_capture.gd`.
- 사전 무오토로드 probe → 실제 전용 경로 `C:/Users/freer/AppData/Roaming/Games-QA-quest-fhd-20260913-classes`와 의도 경로 일치 확인.
- 독립 복사본 `reviews/games-2026-09-12/runtime/quest-fhd-game` 사용. 다른 에이전트의 `.godot` 캐시와 분리했고 원본 `game/project.godot`은 변경하지 않았다.
- 테스트는 MQ01 완료를 메모리 fixture로 두고 기존 MQ02 패널을 열었다. 수주/턴인 실행은 하지 않으며, 시험용 완료 자동저장 구독도 끊었다. 기존 사용자 세이브를 읽거나 수정하지 않았다. Metrics 계측은 전용 QA 디렉터리만 사용했다.
- 실제 GPU: NVIDIA GeForce RTX 3060 / OpenGL 3.3 Compatibility. headless 경로로 렌더 성공을 주장하지 않는다.
- 10개 PASS: readback FHD, 기존 논리 크기, 기존 canvas_items, 패널 visible, 제목/본문/수주/닫기 4개 control의 논리 경계 포함, 본문 visible line count, PNG 직접 저장.
- 파일을 직접 열어 제목·본문·수주/닫기 버튼이 패널/화면 밖으로 잘리지 않음을 확인했다. .NET Bitmap 독립 실측도 **1920×1080, Format32bppArgb**다.

로그(workspace의 `reviews/games-2026-09-12/runtime`): `quest-fhd-isolation.log`, `quest-fhd-cli-only.log`(1280×720 재현), `quest-fhd-size-only-final.log`(최종 FHD). 중간 `quest-fhd-force.log`는 화면 이동을 포함한 첫 성공 실험이며 최종 해결에 이동은 필요하지 않다.

```powershell
# Games cwd, godotExe는 기존 runtime/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe
& $godotExe --headless --path ../reviews/games-2026-09-12/runtime/quest-fhd-probe --script probe.gd --log-file ../reviews/games-2026-09-12/runtime/quest-fhd-isolation.log
& $godotExe --path ../reviews/games-2026-09-12/runtime/quest-fhd-game --resolution 1920x1080 --audio-driver Dummy --rendering-method gl_compatibility res://tests/smoke/SmokeQuestFhdCapture.tscn --quit-after 600 --log-file ../reviews/games-2026-09-12/runtime/quest-fhd-size-only-final.log -- --force-window-fhd --capture=C:/Users/freer/ClaudeProject/make-passive-income/Games/docs/qa/quest-panel-fhd-native.png
```

## 한계

이는 **기존 논리 게임의 FHD 출력 검수**다. 핀 64×96 새 캐릭터를 본 게임에 이관하거나 본 게임 논리 해상도를 FHD로 바꾼 것이 아니다. 스크린샷의 플레이어·월드·양피지 패널은 현재 기존/임시 아트다. 한 패널·현재 한국어 한 상태만 확인했으며 전체 메뉴/다국어/큰 글꼴 클리핑 검사는 아니다.

작업 영역 높이가 1032이므로 장식 포함 창 전체가 물리 모니터 안에 보인다고 보장하지 않는다. 이 캡처는 정확한 1920×1080 렌더 readback이지 데스크톱 전체 화면 캡처가 아니다. 제품의 창모드/전체화면 기본값을 바꾸지 않았다.

종료 시 기존 데이터 경고와 ObjectDB/resource 2개 잔존 경고가 남았다. 렌더/클리핑 assertions와 PNG 저장은 통과했지만 환경 전체 무경고·전체 에디터 import 성공으로 확대하지 않는다.
