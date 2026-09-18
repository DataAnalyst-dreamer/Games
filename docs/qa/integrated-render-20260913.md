# 동일 캐시 복사본의 4개 렌더 단면 — 2026-09-13

작성자 실행 결과: 66 PASS / 0 FAIL, 네 프로세스 모두 native exit 0. story 독립 DA 필수0 완료: 4PNG 직접 시각 검사, 66PASS/native4×0/probe4 exact/하네스7 SHA 대조 및 아래 범위 문구 보완 확인(재실행 없음). **동일 복사본의 서로 독립된 단면 검사이며, 20분 연속 플레이나 정식 빌드 준비 완료가 아니다.**

## 범위와 보존

- 새 복사본은 `reviews/games-2026-09-12/runtime/integrated-render-monsters-v1` 하나다(경로는 Games의 부모 기준). 기존 `autoload-exit-diag-monsters-v1/game`의 작동 캐시 포함 14774파일을 한 번 복사했다. 기존 진단 baseline14779 및 기존 보행 저장 fixture는 실행·수정하지 않았다.
- 원본 재현 하네스는 `Games/tools/qa/integrated-render/`의 run.ps1, ward/late/fhd/icon 스크립트다. 실제 파일명은 `icons.gd`; scene은 ward/late/fhd.tscn이다. 복사본에 테스트 7파일을 배치한 후 `integrated-manifest.json`으로 game14781파일과 engine3파일(exe2개와 `_sc_`)을 동결했다. 기존 manifest가 있으면 run.ps1은 재실행/덮어쓰기를 거부한다.
- editor import, 새 엔진, production 코드·데이터·기본 해상도·readygate 변경은 없다. 기존 하네스의 단면 fixture와 assertions를 유지하고 사용자 경로/캡처 경로를 child 환경변수로 바꿨다. ward에는 캡처1검사를 추가했다.
- 각 모드의 고유 sessions/GUID 아래 APPDATA와 LOCALAPPDATA를 지정하고 no-autoload probe의 실제 user 경로 일치 및 native0를 먼저 확인했다. 기존 사용자 세이브를 읽어 비교하지 않았다. 새 경로만 사용한 코드/probe 증거가 보존 근거이며, 원래 사용자 저장 폴더의 전후 byte 감사를 했다는 뜻은 아니다.
- 각 모드 실행 직전/직후 game14781파일의 수·키·SHA와 engine3 SHA 동일을 확인했다. 동적 engine/editor_data, sessions, PNG, probe 프로젝트 및 외부 실행기 run.ps1은 고정 manifest 대상 밖이다. 전체 실행 환경을 동결했다는 의미는 아니다. 세션/저장/로그는 삭제하지 않는다.

## 실행과 화면

모두 Dummy 오디오, gl_compatibility, minimized, 고유 child 환경으로 실행했다. get_image() PNG와 별도 이미지 크기 판독 모두 1920×1080이다. 물리 모니터에서 창 전체가 보인다는 주장은 하지 않는다.

| 단면 | PASS | 세션 접두사 | 실제 화면 |
|---|---:|---|---|
| D28 비석·관찰·MQ04 같은 E | 7 | ward-60459e1f | `ward.png` |
| MQ06/07 수주·목표·완료·중복 방지 | 32 | late-e6573612 | `late.png` |
| 젤리·뿔·버섯 20px 아이콘과 fallback | 17 | icons-cdc45e01 | `icons.png` |
| 기존 논리 640×360의 FHD 실제 렌더 | 10 | fhd-ecd19dd1 | `fhd.png` |

PNG는 모두 새 복사본 루트에 있다. `run-transcript.log`에 source match14774, baseline14781 및 8회 전후 해시 검사가 남는다. 각 sessions 하위 `probe-native.log`, `render-native.log`에는 실제 probe, assertions, sentinel, NATIVE_EXIT=0가 있으며 engine 로그도 보존한다.

`--quit-after`는 사용하지 않았다. 각 하네스가 마지막 검사 후 실패 수에 따라 quit(0/1)를 호출하여 정상 프로세스 종료를 요청했고, 네 번 모두 120초 강제 종료에 도달하지 않고 실제 native0로 끝났다. 이는 테스트 완료에 의한 정상 종료이며 사용자 GUI 닫기 검증은 아니다. probe에만 headless를 쓰고, 화면 검사는 실제 renderer를 사용했다. 환경 변수는 child ProcessStartInfo에만 APPDATA/LOCALAPPDATA/DIAG_EXPECTED_USER_DIR/INTEGRATED_CAPTURE를 지정하므로 부모 환경 복원 작업이 필요 없다.

| PNG | SHA256 |
|---|---|
| ward.png | 42B2398A8BF400A89C05739263F7502A406FC4456DFEAE2B30FFF56F73F78E20 |
| late.png | BF4DE15336DEF4B461D57F8C2F664413BBBE99ECD9DD833BA5991158F0F5EE72 |
| icons.png | D3F2483193091C6F919C4721DC78268E2AC51226BEF375A1E0DB174A644B40D6 |
| fhd.png | 9C38A9374CEFF7876F99D5BAC7ED71EE7D4AB1BE77B10EF2C219120981A70021 |

직접 시각 검사: 네 PNG를 열어 확인했다. D28 관찰 텍스트, MQ06 본문·현재 목표·버튼, 세 재료 아이콘과 선택 테두리/수량/등급, FHD MQ02 `quest_main_a1_02_firstlook`의 '초원의 첫인사' 패널이 보인다. 아이콘은 20논리px의 축소 표시이므로 원본 세부 표현이 소실된다. 핀64×96이나 새 초상화를 삽입하지 않았다.

## fixture와 남은 한계

- D28은 기존 테스트대로 전투 대상을 제거한 fixture에서 플레이어를 비석 위치에 배치하고 실제 E를 입력한다. 정상 PAUSABLE world, 모달 E 차단, MQ04 완료와 최초 비석 활성 각각 autosave1(합계2), 반복 E 보상/저장 중복0을 검사했다. 자연 보행/전투 통합 검사가 아니다.
- late는 MQ01~05 완료 fixture를 주입하고 기존 목표 이벤트를 발생시킨다. MQ06/07 버튼과 선행 순서·보상·추가 확인 무변화를 검사했지만 앞선 전투나 동굴을 직접 걸어 완주하지 않았다. 캡처는 MQ06 한 상태이며 모든 상태의 스크린샷은 아니다. late와 fhd 모두 Events.main_quest_stage_completed에 연결된 SaveManager 자동저장 구독을 해제하므로 해당 모드의 정상 자동저장까지 검증하지 않는다.
- icons는 재료 스택을 주입해 기존 셀과 상세 설명을 검사한다. 신규 제작/드롭 획득 과정 검사가 아니다. global item_icons는 바꾸지 않았다.
- FHD는 Main 몬스터를 제거하고 MQ01 완료 fixture를 주입한 뒤 MQ02를 표시하는, 기존 논리 좌표계의 렌더 출력 검사다. 새 핀/맵/카메라 전면 FHD 이관 완료가 아니다.
- 모든 모드에 root certificate store 읽기 오류와 기존 stats 경고가 있다. late에는 Act2 등록 태그 미구현 경고가 있고, late/icons/fhd에는 ObjectDB 및 종료 시 2 resources 잔류 메시지가 있다. SCRIPT ERROR는 없고 assertions/native0는 통과했지만 **로그 오류가 전혀 없는 실행**으로 표시하지 않는다. 오디오 청취나 네트워크 기능을 검증하지 않았다.
- 이번 실행은 timeout이 없었다. run.ps1의 timeout 분기는 자체 프로세스를 종료한 뒤 throw하며 stdout/stderr를 보존하기 전에 끝나는 한계가 있다. 정상 실행 로그는 저장되었다.

## 현재 production 핵심 대조

실행 후 원본 `Games/game`과 새 copy의 다음 14개를 직접 SHA 비교하여 모두 일치했다. 전체14774 동일 판정은 현재 production 전체가 아니라 보호된 기존 snapshot에 대한 판정이다.

| game 상대 경로 | SHA256 |
|---|---|
| scripts/world/quest_object.gd | 970AF6E8B795491433B101AC11FEEE8961BA4ED9716D3325F148FE29B5EE47C6 |
| scripts/world/quest_npc.gd | 2EEBF90105FEFB640D42BEEB4BAC666CA7493E638883F572DC51FE156BD5245A |
| scripts/systems/quest_system.gd | D21320E406A5254B848113F6C628C39F2A78DEFF1586154A4243244539274594 |
| scripts/ui/hud.gd | 7BFAACDC586574423D2E883A8B5DCBBEE7D0A09554B3D2F48D209887FB6B9374 |
| scripts/ui/ui_root.gd | 039AA138F031C9F2B4469597BA9C89525E372807D007EF107E973373536BD8D2 |
| scripts/ui/quest_npc_panel.gd | 654937F81F5274297CC7BCD2E51668FC54DCA47C7B8C0700106520A32A5346FD |
| scripts/ui/inventory_menu.gd | 9441FC6B3FDD4D43B5523DDDE310EEFCE1D5AA24BABD7C53D0AFCDAFB6FFF3CD |
| scripts/ui/inventory_cell.gd | 422650962367DE74A15391C4489592EA90FAC1E4D0FC3DA459BAD8E7D007545E |
| localization/ui_ko.csv | 86943F119CE3504B728BC95A734A70AEC7A272856A0AC1561841DF728CB1ADD2 |
| localization/item_descriptions_ko.po | F96956ACE1C3B2F4542F7CBC13495E76FE656707D09AF228977154CF78607ED7 |
| scenes/main/Main.tscn | 2CB13F94E05B73E5146D98B10E15D8309199ED10E73CC624535BFF4E4D477CF3 |
| assets/generated/items/item-slime-jelly-v1.png | 2FCD5BBA74C0E140C7E81F5985184600715E91C5BEAC4AEE76D137A06DD623DB |
| assets/generated/items/item-rabbit-horn-v1.png | 241981FEF302A8CC8B277D65DEC0A954B3719231C2FDC6656D72702DE7BD9F77 |
| assets/generated/items/item-mushroom-cap-v1.png | 827D9522A80C89CC878FC4DCC78380BEF2E905820DB470967999A96DBB776A40 |
