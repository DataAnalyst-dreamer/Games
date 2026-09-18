# 소형 체력 물약 v1 — 아이콘 후보, 본 게임 미적용

후속 변경: 이후 [인벤토리 한정 연결·FHD 검수](../../../qa/item-potion-inventory-20260913.md)를 진행했다. 아래는 생성 당시의 미연결 기록이다.

2026-09-13. imagegen SKILL.md와 prompting/sample-prompts를 완독한 후 built-in imagegen 1회로 생성했다. 외부 API·설치·재생성은 없다. 기존 `item-slime-jelly-v1.png`를 직접 확인하고 스타일 참조로 전달했다.

대상은 기존 `game/data/items.json`의 `potion_hp_small`, 한국어 이름은 **소형 체력 물약**이다. 기존 설명은 “체력을 회복하는 작은 물약. 남은 수량을 확인하고 필요한 순간에 쓰자.”이며 아이템 효과·가격·중첩 수량·런타임 매핑을 변경하지 않았다.

생성 원본: `C:/Users/freer/.codex/generated_images/01a09611-0882-7633-8375-805f1bf13f7e/exec-b7a0ed84-3f2a-4141-ba9e-e4b8c22c1806.png`

저장 파일: `item-potion-hp-small-v1.png`. 원본 그대로 byte-copy, 양쪽 SHA256 일치: `F10EF7D73E47EF312DACEB31CFAD3D129AF880343B4AD62154EE9999AE20D645`. 실제 크기는 **1254×1254, Format24bppRgb, 불투명**이다. 자르기·배경 제거·리사이즈·픽셀 재작성은 하지 않았다.

## 전달한 전체 프롬프트

```text
Use case: stylized-concept. Asset type: ONE game inventory icon candidate for the existing item potion_hp_small, named Small Health Potion. Input image1 is only a style reference for dark opaque card background, warm chunky pixel-look shading and clear glass; do not copy its green jelly subject or wide jar shape. Draw one small compact round-bottom glass potion bottle with a short narrow neck, simple brown cork, and bright RED healing liquid with a clear horizontal liquid level. It is a humble common consumable, not a magic relic. Strong simple silhouette, thick dark stepped outline and broad color clusters readable at20px. Match the reference warm SD pixel illustration style, on an opaque plain dark brown #0d0a06 background. Center the single bottle, generous readable body, no extra objects. Distinguish the bottle from the green jelly jar through red liquid and a narrow neck. No label, letters, numbers, health cross, hearts, rune, magic glow, particles, gilding, added powers, frame, border, watermark, checkerboard or transparent background. Not a sheet or multiple variants. No UI screenshot, only one square icon.
```

## 직접 검수와 한계

- 한 개의 둥근 유리병, 좁은 병목과 갈색 코르크, 붉은 액체와 수평 액면이 보인다. 문자·숫자·회복 십자가·하트·룬·별도 소품은 없다.
- 짙은 갈색 불투명 배경에는 약한 명암/질감이 있다. 완전 단색이나 투명 alpha라고 주장하지 않는다. 픽셀풍 이미지이며 정확한 저해상도 픽셀 격자·제한 팔레트는 보장하지 않는다.
- [실제 UI 크기 검사](../../../qa/item-potion-size-20260913.md)에서 원본을 그대로 TextureRect 20/24/32px로 표시했다. 기존 초록 젤리와 색·목 부분 실루엣이 구별되지만 20px 세부 디테일은 제한적이다.
- 본 게임에는 미적용이다. 새 기능·효과 또는 핀 몸체/모션 개선과 관계없다. AI 생성 출처 기록이며 권리 검토 완료나 법적 독점성을 보장하지 않는다.
