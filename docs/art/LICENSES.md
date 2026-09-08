# 외부 애셋 라이선스 대장

저장소에 반입했거나(A등급) 로컬에서만 사용하는(B등급) 외부 애셋의 라이선스 기록. 정책은 `asset-sources.md` 참조. **새 애셋을 쓰기 전에 반드시 여기에 행을 추가한다.**

| 반입일 | 팩 / 파일 | 제작자 | 라이선스 | 출처 URL | 위치 | 크레딧 문구 | 확인자 |
|---|---|---|---|---|---|---|---|
| 2026-09-08 | Ninja Adventure (GitHub 데모 서브셋: 캐릭터 4, 타일셋 5, 파티클, UI 테마, BGM 4) | pixel-boy | CC0 1.0 (itch 페이지 명시, GitHub 저장소에 LICENSE 파일 없음 — 전체 팩 반입 시 동봉 문구 추가) | https://github.com/pixel-boy/NinjaAdventure · https://pixel-boy.itch.io/ninja-adventure-asset-pack | `game/assets/third_party/ninja_adventure/` | Ninja Adventure asset pack by pixel-boy (CC0) | Claude (세션) |

## 확보 예정 (라이선스 확인 후 추가)

| 팩 | 예상 등급 | 반입 방법 | 메모 |
|---|---|---|---|
| Ninja Adventure 전체 팩 | A (CC0) | itch.io 로컬 다운로드 → `third_party/ninja_adventure/` 덮어쓰기 | 몬스터·보스·SFX 대량 포함, 데모 서브셋보다 훨씬 큼 |
| Kenney Tiny Dungeon / Tiny Town / Tiny Creatures / Roguelike RPG / 오디오 | A (CC0) | kenney.nl 로컬 다운로드 | 던전 타일·아이템 아이콘·SFX |
| Tiny Swords | A (CC0) | itch.io 로컬 다운로드 | 중세 건물 레퍼런스 |
| Cainos Pixel Art Top Down – Basic / Village | B (재배포 금지) | 로컬 다운로드 → `game/assets_local/cainos/` (gitignore) | 32×32 규격 일치, 초원 타일 1순위 |
| Galmuri 폰트 | A (SIL OFL) | GitHub 릴리즈 다운로드 → `game/assets/fonts/` | OFL 라이선스 파일 동봉 필수 |
| Parchment GUI (OpenGameArt) | A (CC0/OGA-BY, 확인 필요) | 로컬 다운로드 | 양피지 UI 프레임 |

## 사용 금지 확인
- The Spriters Resource 등 립 스프라이트: 사용하지 않음 (레퍼런스 링크만 아트 바이블에 기재).
