# 소형 체력 물약 — 실제 UI 크기 비교

후속 변경: 이후 [인벤토리 한정 연결·FHD 검수](item-potion-inventory-20260913.md)를 진행했다. 아래는 연결 전 크기 시험의 당시 기록이다.

2026-09-13. **후보·본 게임 미적용**. 원본 PNG를 편집하지 않고 Godot TextureRect의 nearest 표시로 비교했다. 새 효과나 인벤토리 매핑은 변경하지 않았다.

결과: [640×360 실제 viewport 캡처](item-potion-size-v1.png). 첫 행은 새 물약, 둘째 행은 기존 초록 젤리 참조이며 각각 20/24/32 논리 px이다. 이는 크기 비교용 별도 UI로, 본 게임 인벤토리 화면이나 FHD 결과가 아니다.

## 격리와 실행 근거

별도 프로젝트는 저장소 상위 `reviews/games-2026-09-12/runtime/potion-size-20260913-classes-v1/`에 있다. `project.godot`, `probe.gd`, `preview.gd`만 사용하는 noautoload 프로젝트이다. 원본 게임·저장·에디터 import를 실행하지 않았다. 기존 파일을 덮어쓰지 않는다.

프로세스 실행 동안만 APPDATA/LOCALAPPDATA를 해당 QA 폴더의 userdata/localdata로 지정하고 마지막에 복원했다. noautoload probe에서 실제 `OS.get_user_data_dir()`가 `<QA 폴더>/userdata/PotionSizeProbe`와 일치함을 먼저 확인했다.

Godot 4.4.1 console 실행 순서:

```text
--headless --path <QA 폴더> --script probe.gd --log-file <QA 폴더>/probe.log
--path <QA 폴더> --audio-driver Dummy --disable-render-loop --script preview.gd --quit-after 120 --log-file <QA 폴더>/preview.log
```

두 번째 실행은 headless가 아니다. 최소화된 메인 창의 상태를 검사하고 별도 SubViewport를 `RenderingServer.force_draw(false)`로 렌더했다. 오디오 드라이버는 Dummy이며, 원본 Image를 ImageTexture로 읽어 TextureRect에 전달했다. readback은 실제 640×360이고 PNG 저장 전에 비어 있지 않은 픽셀을 확인했다.

`preview.log`: **10 PASS / 0 FAIL** — 최소화 상태 1, 여섯 TextureRect 크기 6, 실제 readback 크기 1, 렌더 픽셀 1, 새 PNG 저장 1. 도구 실행 기록 chunk `f9df2d`는 위 명령 인수와 `POTION_NATIVE=0`, shell exit_code 0을 보존한다. 엔진 로그의 PASS만으로 native 종료를 추정하지 않았다. root certificate store 오류는 출력됐으나 두 실행의 성공과 구분했다.

캡처 SHA256: `6BDE173CFCE8731DE45CDFF01CEC6F91EE83A1D37185E6FC0588FDB24918D940`.

## 육안 판정

- 20px에서도 붉은 둥근 병과 초록 넓은 병이 색·외곽으로 구별된다. 코르크/유리 세부는 작고 독립적인 설명 수단으로 의존하면 안 된다.
- 24px에서 목과 몸체 구분이 조금 나아지고, 32px에서 액면과 유리 테두리가 더 명확하다. 이는 크기 확대 승인이나 UI 변경 요구가 아니다.
- 어두운 카드 배경이 남는다. 투명 아이콘이나 정확한 20px 픽셀 원화로 보지 않는다. 기존 게임 슬롯에 연결하기 전 독립 DA와 실제 셀의 수량·등급·포커스 공존 검사가 별도로 필요하다.

원본 및 전체 프롬프트: [생성 기록](../art/preview/ai-local-pass/item-potion-hp-small-v1-prompt.md).
