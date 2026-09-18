# 잔디 후보 반복 UI 검사

2026-09-13. [실제640×360 캡처](grass-ground-repeat-v1.png). **DRAFT·본 게임 미적용**. 왼쪽은 4×3 반복, 오른쪽은 같은 반복에 기존 `docs/art/preview/fin-resolution/front-64.png` 정지 시안을 원본 그대로 표시했다. 각 타일64 논리px는 검사 규격이지 생산 TileMap 규격 승인이 아니다. 핀도 실제 플레이어/모션이 아닌 기존 정지 레퍼런스다.

## 재현과 격리

저장소 상위 `reviews/games-2026-09-12/runtime/grass-tile-20260913-classes-v1/`의 신규 project/probe/preview를 사용했다. noautoload, 원본 editor import 없음. 프로세스 APPDATA/LOCALAPPDATA를 이 QA의 userdata/localdata로 지정 후 복원했다. headless probe가 실제 `OS.get_user_data_dir()`와 `<QA>/userdata/GrassTileProbe`의 정확 일치를 먼저 확인했다. 렌더 스크립트도 같은 경로 guard와 결과 파일 미존재 조건을 검사했다.

Godot4.4.1 console 명령:

```text
--headless --path <QA> --script probe.gd --log-file <QA>/probe.log
--path <QA> --audio-driver Dummy --disable-render-loop --script preview.gd --quit-after 120 --log-file <QA>/preview.log
```

두 번째는 headless가 아닌 최소화 창+SubViewport 렌더다. `Image.load_from_file`→ImageTexture→24개 TextureRect(2패널×12타일), nearest/EXPAND_IGNORE_SIZE로 표시했으며 원본 이미지 픽셀을 수정하지 않았다. RenderingServer.force_draw(false) 후 실제 viewport PNG를 저장했다.

`preview.log`: **29 PASS / 0 FAIL** — 최소화1, 원본크기1, 64px 배치24, readback1, 비어 있지 않은 픽셀1, 신규PNG저장1. 이것은 배치/렌더의 기술 검사이지 타일 품질29항목 통과가 아니다. 실제 명령/종료 근거 tool chunk `a471fb`: probe PASS, `GRASS_NATIVE=0`, shell exit_code0. certificate store 오류는 출력됐으며 전체 엔진 무오류라고 하지 않는다.

캡처 SHA256 `6F1B837F084F45E2074404843DBFF123B3C522502430CF2E521AA103863391CA`. 생성 원본/저장 사본 SHA는 [프롬프트·출처 기록](../art/preview/ai-local-pass/grass-ground-tile-v1-prompt.md)과 같고 실행 후에도 불변이다.

## 직접 육안 판정과 남은 조건

- 이 64px 반복에서는 큰 직선 테두리가 두드러지지 않는다. 다만 고해상도 양끝 픽셀 대조/다른 배율/움직이는 카메라는 검사하지 않았으므로 완전 seamless라고 판정하지 않는다.
- 1254px 무늬가64px nearest로 표시되어 세밀한 풀잎보다 촘촘한 입자로 보인다. 명암 덩어리가 반복되는 느낌도 남아 원본 한 장의 미려함만으로 최종 바닥에 채택하지 않는다.
- 정지 핀의 투구·붉은 깃·몸 외곽은 구별된다. 초록 망토와 잔디의 색상은 가까우며, 정지 레퍼런스 한 포즈만으로 모션 가독성 개선을 증명하지 않는다.
- 현재 Main의 노랑초록 바닥과 같은 위치/카메라에서 정량 대비 비교한 것이 아니다. 공격 예고·몬스터·채집물·야간/그림자·접경 타일·전체 HUD는 미검증이다. 새 Map 적용·FHD 플레이·최종 타일 규격 변경은 하지 않았다.
