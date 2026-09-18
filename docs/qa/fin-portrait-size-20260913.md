# 핀 초상화 크기 비교 — 별도 UI 실험

최종 비교 화면: [fin-portrait-size-v2.png](fin-portrait-size-v2.png), 실제 Godot SubViewport **640×360** 렌더. 원본1254×1254 PNG를 ImageTexture로 읽어 16/32/48/64 **논리 픽셀** TextureRect에 nearest 방식으로 표시했다. 원본 픽셀 수정·크롭·파이썬 이미지 처리·합성 이미지 파일 제작은 없으며, 새 PNG는 런타임 UI의 화면 캡처다.

## 결과

- **16px:** 투구·붉은 깃·초록 망토의 색 덩어리 정도는 보이지만 눈과 표정의 안정적 식별은 어렵다. 현재16px HUD 초상화에 그대로 적용해 얼굴 가독성이 충분하다고 판정하지 않는다.
- **32px:** 갈색 얼굴/눈·은색 투구·붉은 깃이 구별되고 핀의 인상을 읽을 수 있으나 작은 명암은 소실된다.
- **48/64px:** 눈·미소·투구 경첩·망토 잠금이 더 명료하다. 이는 비교 결과이지 HUD 크기 확대나 레이아웃 변경 승인이 아니다.
- 전부 동일 원본의 UI 표시이다. 64×96 몸체 또는 모션 완성도와 관계없고 본 게임 HUD/캐릭터 파일을 변경하지 않았다. 작은 실제 HUD의 테두리·자원바와 함께 읽히는지는 별도 통합 검사다.

## 실행 근거

workspace `reviews/games-2026-09-12/runtime/fin-portrait-size-20260913-classes-v1/`에 project/probe/preview.gd와 로그 보존. 기존 프로젝트·세이브·다른 테스트 폴더는 수정하지 않았다. 기존 Godot4.4.1을 사용했고 editor import는 전혀 수행하지 않았다.

실행 프로세스의 APPDATA/LOCALAPPDATA를 위 폴더 내부로 지정하고 원래 값으로 복원했다. no-autoload probe가 실제 `.../userdata/FinPortraitSizeProbe`와 의도 경로 일치를 먼저 확인했다. 렌더 프로세스도 경로를 재확인했다. 메인 Window는 시작 설정부터 **minimized**, 오디오는 Dummy, `--disable-render-loop` 상태에서 별도 UPDATE_ALWAYS SubViewport만 `RenderingServer.force_draw(false)`로 그렸다. 일반 게임 화면을 보여 주는 실행은 아니며 창을 완전히 생성하지 않은 headless라고 주장하지 않는다.

- 첫 `preview.log`: 8PASS/1FAIL, native1. 렌더는 정상이나 비어 있지 않음 검사 좌표를64px 카드(x482~545)가 아닌 x64로 잘못 지정한 테스트 오류였다. 최초 PNG와 로그를 지우거나 덮어쓰지 않았다.
- 수정된 검사는64px 카드 안의 (514,180)을 읽는다. `probe-v2.log` 경로 PASS 후 `preview-v2.log`: **9PASS/0FAIL, native0**. 최종 v2 PNG를 직접 view 확인했다. 실제 화면 내용은 동일하며 픽셀 샘플 검사만 고쳤다.
- native 종료/옵션 증거는 engine 자체 로그가 아니라 실행 도구의 PowerShell 결과 `chunk_id=57141f`에 있다. 해당 결과는 shell `exit_code=0`, 마지막 출력 `PORTRAIT_NATIVE=0`을 기록했다. 명령은 아래와 같고, `$portraitRun`은 위 고유 검토 폴더, `$portraitEngine`은 기존 `runtime/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe`의 Resolve-Path 결과다. 앞서 동일 child 경로 환경에서 headless `probe.gd` native0 검사를 통과했다. engine 로그만으로 명령 옵션/프로세스 종료를 추정하지 않는다.

  ```powershell
  & $portraitEngine --path $portraitRun --audio-driver Dummy --disable-render-loop --script preview.gd --quit-after 120 --log-file (Join-Path $portraitRun 'preview-v2.log')
  "PORTRAIT_NATIVE=$LASTEXITCODE"
  ```

- 원본 SHA256은 계속 `E44618A2C5C49C5D9F15BD25675C50957A0AFCFBC595976F6C69D9D518FE917E`로 유지됐다.
- certificate-store read 오류는 남지만 native0이었다. 깨끗한 전체 엔진 검증이나 import 종료 문제 해결을 의미하지 않는다.

렌더 방식 근거: [Godot4.4 RenderingServer.force_draw](https://docs.godotengine.org/en/4.4/classes/class_renderingserver.html#class-renderingserver-method-force-draw), [SubViewport](https://docs.godotengine.org/en/4.4/classes/class_subviewport.html). 실행한 옵션은 로컬 `--help`로 확인했다. 독립 DA/채택 판단은 별도이며 사용자 결정 없이 HUD 규격을 확대하지 않는다.
