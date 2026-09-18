# 슬라임 젤리 아이콘 v1 — 원본 및 작은 크기 검수

- 작성일: 2026-09-13. 상태: 기존 `slime_jelly`의 **그림 시안**, 본게임 미적용. 기존 효과·가격·아이템 정체성 변경 없음.
- imagegen skill에 따라 내장 생성 1회. 참조는 기존 설명의 ‘병 안에서 느릿하게 흐르는 젤리’, art bible의 SD 픽셀 방향과 어두운 외곽선. 기존 상용 게임 그림 복제 없음.
- 생성 원본: `C:/Users/freer/.codex/generated_images/01a09611-3246-75b2-bc58-7a6c02063b4c/exec-e1e31dce-1ef9-477e-99dc-76dbb1600a62.png`
- 보존 파일: `item-slime-jelly-v1.png`. 바이트 복사만 수행. 축소·색 수정·알파 제거·래스터 재저장 없음.
- 양쪽 SHA256 일치: `2FCD5BBA74C0E140C7E81F5985184600715E91C5BEAC4AEE76D137A06DD623DB`.
- .NET Bitmap 실측: **1254×1254, Format24bppRgb**, 알파 채널 없음. 좌상단 RGB=(11,9,6), #0b0906. 불투명 어두운 카드 배경을 이번 요청에서 허용했으므로 알파 실패로 분류하지 않음.

## 프롬프트

```text
Use case: stylized-concept. Asset type: one inventory icon concept for the existing material item slime_jelly in a cute SD pixel-art action RPG. Draw ONE short stout glass jar with a simple cork stopper, filled with a single mint-green/teal mass of thick slime jelly, visibly slowly slumping to one side inside the jar. This is stored crafting material, NOT a living monster: no eyes or mouth, no magical effect. Square composition, jar occupies about 78 percent of the canvas, bold simple silhouette, only 3-4 broad shading clusters per material, thick dark teal outline, very large readable glass highlight and warm brown cork. True chunky crisp pixel-art look designed to remain recognizable when displayed at 24px or32px; no tiny ornament, no smooth painting. Opaque uniform very dark warm charcoal background #0b0906, edge-to-edge flat solid color, no frame, no checkerboard, no transparency simulation. Warm adventurous palette with teal-green jelly and ochre cork. No text, number, label, brand, rune, particle, weapon, extra object, border, multiple variants, or sprite sheet. Original game material icon, not copied from any existing game. Deliver one square raster concept source.
```

## 육안 검수와 제한

- 단일 코르크 유리병과 왼쪽이 높은 민트 젤리 덩어리. 얼굴·글자·마법 효과·체커 없음. 황토 코르크/청록 외곽/밝은 유리 하이라이트가 구분됨.
- 완전 단색 요청과 달리 배경에 미세한 질감/명암이 남음. 정확한 픽셀 격자, 제한 팔레트, 재료당 3~4색을 보장하지 않는 고해상도 픽셀풍 원본임.
- 작은 크기 시안으로는 조건부 통과: 24/32 논리 px 모두 병과 코르크, 초록 내용물이 식별되며 32가 더 명확함. 24에서는 젤리의 느린 흐름이나 유리 세부 표현이 소실됨. 본게임 슬롯에서 기존 아이콘들과 통일되는지는 별도 통합 검수가 필요함.

## 독립 Godot 표시 검사

- 별도 프로젝트: `reviews/games-2026-09-12/runtime/item-icon-preview/` (Games 상위 workspace 기준). game autoload·세이브·아이템 데이터 없음. 원본 PNG를 ImageTexture로 로드해 TextureRect 24×24, 32×32에 nearest 표시. 원본 변경 없음.
- 검수 캡처: `docs/qa/item-slime-jelly-size-preview.png`, **640×360** 실제 뷰포트. FHD 테스트 아님.
- 로그: `reviews/games-2026-09-12/runtime/item-icon-preview.log`. `ICON_PREVIEW source=1254x1254 logical=24,32 capture=(640, 360) save_error=0` 확인. 자체 실행 프로세스 종료 확인.
- shader cache 생성 불가 및 루트 인증서 읽기 오류가 있었으나 PNG 저장은 성공. 원본 게임 import나 기존 Godot 프로세스 조작은 하지 않음.
- 원본 및 캡처를 직접 열어 검수했으며 사용자 승인이나 게임 적용을 뜻하지 않음.
