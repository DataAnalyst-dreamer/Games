# 외부 애셋 라이선스 대장

저장소에 반입했거나(A등급) 로컬에서만 사용하는(B등급) 외부 애셋의 라이선스 기록. 정책은 `asset-sources.md` 참조. **새 애셋을 쓰기 전에 반드시 여기에 행을 추가한다.**

**등각 8방향 시트 기록 규칙(D-138, `brief-fin-pixellab-8dir.md`/`brief-monsters-iso.md` 대상)**: 방향 수(5방향 원화 또는 2방향 원화인지)와 `normalize_ai_sheet.py --dirs 8`로 반전 생성한 방향(NE/E/SE 또는 N/W)을 프롬프트·파라미터 열에 함께 명시한다 — 반전 프레임은 별도 생성물이 아니라 같은 반입 건의 일부로 기록한다.

## 반입 완료

### 프로젝트 신규 생성물: 핀 CQ 방향 (2026-09-12)

내장 이미지 생성 도구로 신규 콘셉트와 걷기 초안을 생성하고, 사용자 승인하에 `tools/prepare_fin_sprites.py`로 후처리했다. 입력 참조는 이 프로젝트에서 생성한 승인 콘셉트이며 CQ 원작 이미지나 립 스프라이트를 사용하지 않았다. `docs/art/preview/fin-cq-*` 및 `game/assets/sprites/characters/fin/fin-walk-v1.*`에 보관. 프롬프트는 `docs/art/fin-cq-*-prompt.txt`, 처리·검증 이력은 `docs/qa/fin-postprocess-2026-09-12.md` 참고. 외부 CC0 팩으로 분류하지 않으며 독점권/상용 법률 검토 완료를 주장하지 않는다. 게임 런타임 교체 전 후보 에셋이다.

### 외부 팩

정면 실행 시험(2026-09-12): `prototypes/fin-front-test/assets/`는 선택된 신규 생성 정면 B를 사용자 승인된 코드 방식으로 부위 분리·후처리한 시험 에셋이다. `tools/build_fin_front_test.py`, 에셋 `manifest.json`에 재현·출처 기록. 기존 게임이나 외부 팩의 라이선스를 변경하지 않는다.

추가 신규 생성물(2026-09-12): `docs/art/preview/fin-resolution/`의 정면 A/B는 승인 콘셉트를 참조하여 내장 이미지 생성 도구로 제작하고 사용자 승인된 코드 후처리로 비교본을 만들었다. 원작 CQ 이미지는 입력하지 않음. 정확한 프롬프트·사용 범위·한계는 `fin-resolution-review.md` 참조. 최종 게임 에셋 승인 전이다.

| 반입일 | 팩 | 제작자 | 라이선스 (근거) | 출처 | 위치 | 크레딧 문구 |
|---|---|---|---|---|---|---|
| 2026-09-08 | Ninja Adventure – Asset Pack (전체) | Pixel-boy, AAA | **CC0 1.0** — zip 동봉 LICENSE.txt·README.md 원문 | https://pixel-boy.itch.io/ninja-adventure-asset-pack | `game/assets/third_party/ninja_adventure/` | Ninja Adventure asset pack by Pixel-boy & AAA (CC0) |
| 2026-09-08 | Kenney Tiny Dungeon 1.0 | Kenney | **CC0** — 동봉 License.txt | https://kenney.nl/assets/tiny-dungeon | `third_party/kenney/tiny_dungeon/` | Assets by Kenney (CC0) |
| 2026-09-08 | Kenney Tiny Town | Kenney | **CC0** — 동봉 License.txt | https://kenney.nl/assets/tiny-town | `third_party/kenney/tiny_town/` | Assets by Kenney (CC0) |
| 2026-09-08 | Kenney Roguelike/RPG pack | Kenney | **CC0** — 동봉 License.txt | https://kenney.nl/assets/roguelike-rpg-pack | `third_party/kenney/roguelike_rpg/` | Assets by Kenney (CC0) |
| 2026-09-08 | Kenney Impact Sounds / RPG Audio / UI Audio | Kenney | **CC0** — 각 폴더 License.txt | https://kenney.nl/assets/impact-sounds 외 | `third_party/kenney/audio/` | Audio by Kenney (CC0) |
| 2026-09-08 | Tiny Creatures 1.0 | Clint Bellanger | **CC0** — 동봉 License.txt (Kenney 허가 확장팩) | https://clintbellanger.itch.io/tiny-creatures | `third_party/kenney/tiny_creatures/` | Tiny Creatures by Clint Bellanger (CC0) |
| 2026-09-08 | Tiny Swords (Free Pack) | Pixel Frog | **CC0** — itch 페이지 명시 (zip에 라이선스 파일 없음) | https://pixelfrog-assets.itch.io/tiny-swords | `third_party/tiny_swords/` | Tiny Swords by Pixel Frog (CC0) |
| 2026-09-08 | Parchment GUI (buttons/labels/panels/slots) | OpenGameArt 기여자 | CC0/OGA-BY 등록 — **페이지에서 표기 재확인 필요** | https://opengameart.org/content/parchment-gui | `third_party/parchment_gui/` | 페이지 표기에 따라 기재 |
| 2026-09-08 | Galmuri v2.40.4 (7/9/11/11-Bold/11-Condensed/14) | Lee Minseo (quiple) | **SIL OFL 1.1** — 동봉 LICENSE.txt | https://github.com/quiple/galmuri | `game/assets/fonts/galmuri/` | Galmuri font by quiple (OFL) |
| 2026-09-09 | 자체 제작 SFX(sfxr 파라미터 기반, 17종) | 프로젝트 자체(sound-designer 서브에이전트) | **저작권 프로젝트 소유** — `tools/audio/sfxr_synth.py`(자체 작성 순수 파이썬 sfxr 합성기)가 `tools/audio/sfxr/*.json` 파라미터로부터 새로 합성한 파형. 외부 샘플을 자르거나 재생한 것이 아니므로 CC0 팩과 무관한 독립 저작물 | 프로젝트 내부 제작(`tools/audio/README.md` 재생성 명령) | `game/assets/audio/sfx/` (`just_guard_parry_ting.wav`, `stamina_exhausted_deny.wav`, `legendary_drop_sparkle.wav`, `drop_common.wav`~`drop_relic.wav`, `drop_epic_layer.wav`, `goblin_whistle.wav`, `blacksmith_enhance_success.wav`, `blacksmith_enhance_fail.wav`, `blacksmith_refine_roll.wav`, `blacksmith_salvage_complete.wav`, `blacksmith_craft_complete.wav`, `mailbox_claim_chime.wav`) | 크레딧 불필요(자체 저작) |

## 로컬 전용 (B등급 · 커밋 금지 · `game/assets_local/`)

| 반입일 | 팩 | 제작자 | 라이선스 요지 (근거) | 출처 | 위치 |
|---|---|---|---|---|---|
| 2026-09-08 | Pixel Art Top Down – Basic v1.2.3 (32×32) | Cainos | 상용 OK · 수정 OK · 크레딧 불필요 · **재배포·재판매 금지** (itch 페이지, zip에 라이선스 파일 없음) | https://cainos.itch.io/pixel-art-top-down-basic | `assets_local/cainos/basic/` |
| 2026-09-08 | Pixel Crawler – Free Pack 2.11 | Anokolisa | 상용 OK · 수정 OK · 크레딧 불필요 · **애셋 자체 판매·최종 제품으로 유통 금지** (동봉 Terms.txt) — CC0 아님 | https://anokolisa.itch.io/free-pixel-art-asset-pack-topdown-tileset-rpg-16x16-sprites | `assets_local/pixel_crawler/` |

## 미확보 — 2차 확보 목록 (GDD 대조 갭 분석, 2026-09-08)

| 우선 | 갭 | 팩 | 예상 등급 | 링크 | 저장 위치 | 메모 |
|---|---|---|---|---|---|---|
| M2 | 방어구·장신구 아이콘(투구/갑옷/신발/반지/부적) | Kyrise's Free 16x16 RPG Icon Pack | CC-BY 4.0 (크레딧 필수) | https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack | `third_party/kyrise_icons/` | 300+ 아이콘, 반지·목걸이 포함 |
| M2 | 아이콘 보강(32×32 포함) | Shikashi's Fantasy Icons Pack (Free) | 상용 OK, 크레딧 "Matt Firth (shikashipx)" 필수 | https://cheekyinkling.itch.io/shikashis-fantasy-icons-pack | `third_party/shikashi_icons/` | 재배포 조건 페이지 확인 |
| M3 | 설산 프로스트헤임 타일셋 | Winter Forest 16x16 (Seliel the Shaper) | 페이지 확인 필요 | https://seliel-the-shaper.itch.io/winter-forest | `third_party/` 또는 `assets_local/` | 눈 나무·길·바위 |
| M3 | 설산 대체 | Winter Tileset [16x16] (OpenGameArt) | CC0 | https://opengameart.org/content/winter-tileset-16x16 | `third_party/winter_tileset/` | |
| M3 | 화산 이그니스 타일셋 | Cosmo Pixels Top Down Lava Tileset 16x16 / Cute Fantasy Volcano (Kenmi) | 페이지 확인 필요 | https://itch.io/game-assets/tag-lava/tag-tileset | 등급에 따라 | 용암 애니메이션 타일 필요 |
| M2 | 환경 앰비언트(바람·비·모닥불·새) | JC Sounds Nature Ambient Pack Vol 1 / 30 CC0 SFX loops | CC0 (OGA 표기) | https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1 · https://opengameart.org/content/30-cc0-sfx-loops | `third_party/audio_ambient/` | 낮/밤·날씨 시스템용 루프 |
| 필요 시 | Cainos Village 마을 타일 | Cainos | B | https://cainos.itch.io/pixel-art-top-down-village | `assets_local/cainos/village/` | |
| 필요 시 | Neo둥근모 폰트 | Dalgona | A (OFL) | https://github.com/Dalgona/neodgm/releases | `fonts/neodgm/` | Galmuri 대체안 |

## 코드 리소스 (Godot 애드온 · `game/addons/`)

| 반입일 | 애드온 | 버전 | 제작자 | 라이선스 | 출처 | Godot 호환 |
|---|---|---|---|---|---|---|
| 2026-09-08 | GUT | 9.4.0 | bitwes | MIT (LICENSE.md 동봉) | https://github.com/bitwes/Gut | 4.3–4.4 |
| 2026-09-08 | Phantom Camera | 0.11.0.3 | ramokz | MIT | https://github.com/ramokz/phantom-camera | 4.4+ |
| 2026-09-08 | Aseprite Wizard | 9.8.0 (godot_4) | viniciusgerevini | MIT | https://github.com/viniciusgerevini/godot-aseprite-wizard | 4.x |
| 2026-09-08 | Dialogue Manager | 3.10.5 | nathanhoad | MIT | https://github.com/nathanhoad/godot_dialogue_manager | 4.4–4.5 |
| 2026-09-08 | LDtk Importer | 2.0.1 | heygleeson | MIT | https://github.com/heygleeson/godot-ldtk-importer | 4.1+ |

- 엔진: **Godot 4.4.1-stable** (MIT). 애드온 버전은 4.4.1 호환 기준으로 고정했으며, 엔진 업그레이드 시 위 표의 호환 범위를 먼저 확인한다.
- LimboAI(행동 트리)는 GDExtension 바이너리 배포판이 필요해 M2에서 검토.

## 사용 금지 확인
- The Spriters Resource 등 립 스프라이트: 사용하지 않음 (레퍼런스 링크만 아트 바이블에 기재).

## AI 생성 디자인 시안 — 2026-09-13

### 야간 재료 아이콘3종 — 제한된 인벤토리 적용

`game/assets/generated/items/`의 `item-slime-jelly-v1.png`, `item-rabbit-horn-v1.png`, `item-mushroom-cap-v1.png`는 이 프로젝트용 내장 이미지 생성 출력이다. 원본1254×1254 RGB 불투명 PNG를 바이트 그대로 복사하여 기존 아이템3종의 인벤토리20×20 논리px 영역에만 연결했다. [생성 기록·프롬프트·SHA256 목록](../../game/assets/generated/items/README.md)과 [실제 적용 검사](../qa/item-three-materials-inventory-v1.md)를 보존한다. 외부 게임 추출 이미지나 CC0 팩으로 분류하지 않으며, 독점권·상용 출시 권리 검토 완료를 주장하지 않는다. 이 기록은 아트의 출처·사용 범위 추적이며 법률적 승인서가 아니다.

### 병렬 시안 보관 기록

2026-09-14 통일 디자인 정지 후보: [검·슬라임·핀 생성 기록](preview/quarter-view/unified-v1/README.md)에 내장 생성/참조 입력, 정확한 프롬프트, 원본 경로·SHA, 실제 크기·알파 분포와 실패를 기록한다. 검/슬라임의 원본 bytecopy는 독립 쿼터뷰 정지 비교용 후보이며 기존 본편/배우 텍스처를 교체하지 않았다. 핀 v1과 승인된 배경 추출 v2 모두 실제 RGB 체크가 남아 적용 불가로 별도 보존했다. 총4회 이후 추가 생성을 중단했다. 새 핀 모션이나 동일 무기 세트 완성, CC0 분류 또는 법적 권리 승인으로 해석하지 않는다.

쿼터뷰 마을 입구: [환경 plate v1 생성 기록](preview/quarter-view/village-gate-v1-prompt.md)은 사용자 첨부의 미술 분위기만 참조한 builtin 신규 생성1회다. 1672×941 RGB 원본을 `prototypes/quarter-view-lab/assets/village-gate.png`에 byte-copy했으며 SHA256은 `EF35A5020E1FE965561FC57EAF700ABD3E8FA759ACAF49D12E2E1E861007D77F`다. 본편은 변경하지 않았다. 불투명한 픽셀풍 배경 한 장이며 층별 타일 원본·엄격한 도트·native FHD·완성된 이동/전투를 뜻하지 않는다. 사용자 참고 이미지는 배포 assets로 복사하지 않았다. 생성물에 외부 팩의 CC0 등급을 부여하거나 법적 권리 검토 완료를 주장하지 않는다.

핀 보행 설계 시트 [v2](preview/ai-local-pass/fin-walk-keyposes-v2-prompt.md)와 [v3](preview/ai-local-pass/fin-walk-keyposes-v3-prompt.md)는 프로젝트 정면 참조 기반 builtin생성1회 및 해당시트 부분편집1회 결과다. 두2048×768 RGB 원본·입력/출력경로·프롬프트·해시를 보존했다. 불투명 체크 배경과 포즈/동일성 문제가 남아 본게임에 적용하지 않았다. 외부 게임 추출·완성 스프라이트·권리 승인 자산으로 분류하지 않는다.

잔디 바닥: [잔디v1 생성 기록](preview/ai-local-pass/grass-ground-tile-v1-prompt.md)은 참조 입력 없이 builtin1회 생성한1254×1254 RGB 불투명 후보다. 생성 원본과 사본 SHA를 확인했고 [4×3 반복 배치](../qa/grass-ground-repeat-20260913.md)는 별도 Godot UI 시험이다. 명암 반복·촘촘한 무늬가 남아 본게임 맵에는 적용하지 않았다. 완전한 seamless·최종 타일 규격·출시 권리승인을 보증하지 않는다.

야간 소형 체력 물약: [물약v1 생성 기록](preview/ai-local-pass/item-potion-hp-small-v1-prompt.md)은 기존 젤리 그림을 스타일 참조로 사용한 builtin 생성1회 결과다.1254×1254 RGB 불투명 원본을 바이트 그대로 보존했고, [20/24/32px 표시 검사](../qa/item-potion-size-20260913.md) 및 독립뷰 검수를 했다. 저녁 재개 후 같은 PNG를 `game/assets/generated/items/`로 바이트 복사해 기존 `potion_hp_small`의 인벤토리20px optional map에만 연결했다([44검사·실제FHD화면](../qa/item-potion-inventory-20260913.md), 독립검수). 전역매핑·효과·가격·드롭은 불변이며 원본전체import/정식배포 준비는 별도다. 새 생성·리사이즈·알파수정은 없었다. 다른 생성물과 마찬가지로 출처 기록이며 출시 권리 검토 완료를 보증하지 않는다.

야간 추가 초상화: [핀 초상화v1 기록](preview/ai-local-pass/fin-portrait-v1-prompt.md)은 프로젝트의 승인 `fin-cq-concept-v1.png`를 참조한 builtin 생성1회 결과다.1254×1254 RGB 불투명 원본을 검토 폴더에 바이트 그대로 보관했다. 핵심 외형에 대한 독립뷰 검수를 했으나 작은 HUD 표시·본게임 적용·모션 완성이나 사용자 최종승인을 뜻하지 않는다. 외부 팩 라이선스/독점권/출시 권리승인 주장을 추가하지 않는다.

`docs/art/preview/parallel-pass/`의 핀 접지1·몬스터3·소품2는 builtin imagegen 신규 생성/참조 편집 출력이다. 외부 게임에서 추출한 이미지가 아니다. [목록·규격·프롬프트·원본 경로](preview/parallel-pass/README.md)를 보존한다. 새 시안은 검토 단계이며 `game/assets`에 반입하지 않았다. **v1 묶음 기준** 천조각만 실제 알파를 확인했고 나머지5장은 체크무늬 배경이 포함되어 있다. 외부 팩의 CC0/MIT 등급을 이 생성물에 임의 부여하지 않는다. 출시 사용 시 필요한 권리 검토 완료를 이 기록이 보증하지 않는다.

후속 [뿔토끼 배경 추출 v2](preview/parallel-pass/monsters/horn-rabbit-alpha-v2.png)는 프로젝트의 [v1 원본](preview/parallel-pass/monsters/horn-rabbit-concept-v1.png)을 입력한 builtin imagegen background-extraction 편집1회 결과다. v1은 삭제·교체하지 않았고 v2는 검토 폴더에만 보관한다. 실제 RGBA 알파를 확인했지만 정확한 픽셀 격자·런타임 적합성·권리 검토 완료를 의미하지 않는다. [정확한 프롬프트](preview/parallel-pass/monsters/horn-rabbit-alpha-v2-prompt.txt)와 [검수·생성 원본 경로](preview/parallel-pass/monsters/horn-rabbit-alpha-v2-review.md)를 함께 기록한다. 코드로 래스터를 재가공하거나 게임/프로토타입 에셋을 교체하지 않았다.
