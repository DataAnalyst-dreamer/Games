# 소형 체력 물약 — 인벤토리 한정 연결 검수

> 후속 이력: 물약 검사가 끝난 뒤 가변 `item-panel-game`의 QuestObject·QuestSystem·HUD·UI CSV/번역 5파일만 [S5 비석 반응 검사](waypoint-observation-20260913.md)를 위해 백업 후 갱신했다. 아래 물약 결과·PNG·로그·manifest는 당시 증거로 그대로 보존하며 최신 전체 게임 통합 결과로 갱신하지 않는다.

2026-09-13 저녁. **새 아이콘은 인벤토리 격자에만 연결했다.** [실제 FHD 캡처](item-potion-inventory-fhd-v1.png)는 Godot의 1920×1080 SubViewport를 직접 저장한 결과다. PNG 확대 편집이 아니다. 본 게임 전체 실행·물약 사용 전투 검증·정상 런처 ready 판정은 아니다. 독립 DA 완료, 필수 수정0건.

독립 검수자 `save_verification`은 보고서/QA4스크립트, menu 변경 전후 한 행 비교, PNG 원본·생산 및 FHD 원본·문서 byte 일치, 원본/복사본 items.json SHA, 선택입력11해시 현재 차이0, 실제 import 로그·3probe·UI/FHD native 자연종료0, 각44 assertions와 경고, 실제 FHD 이미지를 읽기 전용으로 재검토했다. 전체 게임/고정 복사본을 재해싱하거나 Godot를 독립 재실행한 검수는 아니다.

## 변경과 보존

- `game/scripts/ui/inventory_menu.gd`의 기존 `MATERIAL_ICON_PATHS`에 `potion_hp_small` 한 행만 추가했다. 기존 optional ResourceLoader/cache/null fallback과 InventoryCell의 20px·수량·등급·선택·이름/설명 코드는 수정하지 않았다. 상수 이름은 변경 최소화를 위해 유지했다.
- 검수된 `docs/art/preview/ai-local-pass/item-potion-hp-small-v1.png`를 `game/assets/generated/items/`로 byte-copy했다. 1254×1254 RGB 불투명 원본이며 SHA256 `F10EF7D73E47EF312DACEB31CFAD3D129AF880343B4AD62154EE9999AE20D645`가 같다. 출처와 한계는 해당 폴더 README에 기록했다. 새 그림 생성·후처리·알파 수정은 없다.
- `items.json` 전체 SHA256은 변경 전/검사 후 모두 `E39B67289A5991B1E9291DEC3CADA88431992906EE905DD0E0FD853A3C3AFC44`; 검사 복사본도 같다. 기존 heal_hp 40 / sell_price 20 / stack_max 5를 읽어 확인했다. 드롭·효과·경제·전역 `data/item_icons.json`을 수정하지 않았다. 물약을 실제 사용해 치유 효과를 실행한 검사는 아니다.
- 원본 menu와 가변 UI-only copy의 변경 전 SHA `9441FC6B3FDD4D43B5523DDDE310EEFCE1D5AA24BABD7C53D0AFCDAFB6FFF3CD`; 변경 후 `97EF5D5D6ACACD2F6FB3F8338F06DB52E6B078431621DEEE703586B1468254C0`. 줄 비교에서 물약 map 한 행만 추가됐다. README 변경 전 `DD06D8298280B16C0D82FEE81EE9EAF85B4A8CD286D991DFFD9C5B148C72489E`, 후 `3291A6312DDBDADCC3846B030CE965E77EA8603266C455C11A6185794B61FC05`.

## 격리와 실제 import

QA 폴더: 저장소 상위 `reviews/games-2026-09-12/runtime/potion-inventory-20260913-art-v1/`.

기존 가변 `runtime/item-panel-game`의 menu만 갱신하고 새 PNG/.import/.ctex/.md5를 추가했다. 새 경로라 덮어쓴 기존 물약 import/cache는 없다. 변경 전 menu는 `backup/inventory_menu.gd`로 byte-backup했고 위 SHA가 같다. 과거 3재료 검사 로그/PNG는 보존하고 기존 보고서에 후속 변경 이력을 추가했다. **고정14779/14781/NPC14804 복사본과 원본 game editor import는 건드리지 않았다.**

작은 `import/project.godot`에는 autoload가 없고 물약 한 장만 있다. 각 단계마다 먼저 noautoload probe로 실제 `OS.get_user_data_dir()`가 `<QA>/userdata/Games-QA-item-panel-20260913-monsters`와 정확히 같음을 확인했다. APPDATA/LOCALAPPDATA는 자식 프로세스 전용 환경이다. PNG 실제 import 후 생성된 remap/ctex/md5를 동일 res:// 경로의 가변 UI-only copy로 byte-copy했다. **작은 import도 자연종료0**을 확인했으며, 이후 UI에서 별도로 실제 ResourceLoader.exists 및 Texture2D 1254×1254 로딩을 검사했다. 작은 import 성공을 전체 게임 import 해결로 확대하지 않는다.

실행기는 `run.ps1 -Mode Import`, `-Mode UI`, `-Mode FHD`. 정확한 argv/엔진/사용자 경로/native exit는 각각의 `*-result.json`에, stdout/stderr와 Godot 로그도 별도 파일로 보존했다. 결과 파일·PNG가 이미 있으면 덮어쓰지 않는다. timeout50초는 자신의 자식 프로세스만 종료하고 출력을 보존한 뒤 실패 처리한다. 이번 실행에 timeout은 없었다. `input-hashes.json`은 실행 후 선택 입력의 해시 기록이지 전체 환경을 동결한 manifest는 아니다.

## 실행 결과

| 단계 | 실제 결과 | 종료 근거 |
|---|---|---|
| noautoload PNG import | 1 PNG 실제 import, 별도 QA assertions 집계 없음 | probe/import 각각 자연종료0, `843570`, `import-result.json` |
| 첫 UI-only 검사 | **44 PASS / 0 FAIL**, 1280×720 실제 readback | 자연종료0, `abb29f`, `ui-result.json` |
| 별도 FHD UI 검사 | **44 PASS / 0 FAIL**, 1920×1080 실제 readback | 자연종료0, `bddf92`, `fhd-result.json` |

두 UI 실행은 같은44검사를 다른 출력 해상도에서 반복했다. 88개의 서로 다른 기능 검사가 아니다. 기본1280 스크립트/PNG/로그를 보존하고 `check-fhd.gd`에서 출력 크기와 결과 라벨만 바꿨다. FHD는 `size_2d_override=640×360`, `size_2d_override_stretch=true`, 실제 viewport1920×1080이므로 논리3배 렌더다. 생산 창·카메라 설정은 변경하지 않았다.

44검사의 범위: 정확 userdata/새 출력 guard, 최소화 창, 물약 정의3항목, fixture5슬롯, optional map4개와 물약 경로, 실제 texture 로딩2항목과 캐시 동일성, 아이콘4종×7(20px/수량·등급 표시/번역명/설명/선택테두리/셀 재사용 fallback/누락 리소스 fallback), 기존 무매핑 무기 fallback, UI 조작 후 fixture/정의 불변, 실제 readback/PNG 저장. 수량 x3은 주입한 UI fixture이며 최대 stack5를 뜻하지 않는다. 슬롯에 무기 x3을 넣은 것도 기존 fallback용 UI fixture이지 실제 획득/스택 허용 판정이 아니다.

UI는 실제 `InventoryMenu.tscn`을 로드해 open/focus/paint API를 사용했다. Main·전투·실제 드롭·소모·게임 저장/불러오기를 실행하지 않았다. Metrics만 격리된 QA user 폴더에 세션 로그를 생성했다. 스크립트 오류는 없었으나 certificate store 오류, 기존 stats2 경고, ObjectDB leak/2 resources 종료 메시지가 있어 전체 엔진 무오류라고 하지 않는다.

## 화면과 남은 한계

FHD 원본/문서 사본 SHA256 `8E685AD31D8E6FADC0AFBF23B8F6A50234C52B545B3F0AD9E01D397B4D2895F1`. 보존한 1280 캡처 SHA256 `C0507B290F00F128E4BBBC283B6B3FCE0A40CFE5C89CE7A540CAC9278CD82900`.

직접 본 FHD 화면에서 붉은 물약과 초록 젤리병이 구별되고, 물약의 선택 테두리·일반 등급 표식·수량 x3·한글 이름/설명이 표시된다. 불투명 어두운 바탕이 슬롯 안에 남으며 세밀한 병 디테일은20논리px에서 제한된다. 프레임/등급/수량을 덮지 않는 후보 연결이지 전 아이템 그림 통일·최종 아트 승인·전체 UI 리디자인 완료가 아니다. 원본 프로젝트가 새 PNG를 실제 import하는 절차와 정상 런처 검증은 별도다.
