# 외부 애셋 라이선스 대장

저장소에 반입했거나(A등급) 로컬에서만 사용하는(B등급) 외부 애셋의 라이선스 기록. 정책은 `asset-sources.md` 참조. **새 애셋을 쓰기 전에 반드시 여기에 행을 추가한다.**

## 반입 완료

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
