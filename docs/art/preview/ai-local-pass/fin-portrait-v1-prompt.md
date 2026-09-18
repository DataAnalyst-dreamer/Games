# 핀 초상화 v1 — HUD/대화 후보, 본 게임 미적용

2026-09-13. Built-in imagegen 1회 호출. imagegen SKILL.md와 prompting/sample-prompts 참조를 완독했고, 승인된 `docs/art/preview/fin-cq-concept-v1.png`를 직접 view한 뒤 identity reference로 사용했다. 외부 API/CLI/다운로드/설치/재생성 없음.

원본: `C:/Users/freer/.codex/generated_images/01a09611-0882-7633-8375-805f1bf13f7e/exec-ec356bbb-6b7a-4e66-af87-72f65eec355d.png`

프로젝트 저장: `fin-portrait-v1.png`. 원본 그대로 byte-copy했으며 양쪽 SHA256이 일치한다. **1254×1254 Format24bppRgb, 불투명**. SHA256 `E44618A2C5C49C5D9F15BD25675C50957A0AFCFBC595976F6C69D9D518FE917E`.

## 전달한 전체 프롬프트

```text
Use case: identity-preserve. Asset type: ONE square small-game HUD/dialogue portrait candidate, not a body sprite or animation. Input image 1: approved Fin character identity/style reference sheet; use only the main large Fin on its left as the identity anchor, do not reproduce the sheet. Primary request: create one centered shoulders-up bust portrait of exactly this same friendly SD boy knight Fin. Preserve the reference face design, brown hair tufts and brown eyes, friendly small smile, silver open-face helmet with lifted slotted visor and side hinge, red feather crest, green cloak around neck, ochre tunic and existing simple cloak fastening. Preserve face proportions and helmet silhouette; do not age him up or redesign him. Keep full helmet and red plume within the square with modest margin. The face is the main readable focal point at small HUD sizes. Style: same warm chunky pixel-look illustration as the approved concept, simple readable color clusters, dark stepped outline. Scene/backdrop: plain opaque dark warm brown #0d0a06 background, no checkerboard or transparency. Only one character, shoulders and head, no hands, no sword, no shield, no extra ornaments, no new jewelry, no scenery, no frame, no border, no text, no logo, no watermark, no multiple versions. This is a portrait reference candidate; do not draw a full body, sheet, UI mockup or sprite atlas.
```

## 생성 결과 직접 검수

- 한 명의 머리·어깨 초상, 은색 열린 투구의 세로 슬롯/측면 경첩, 붉은 깃털, 갈색 머리·눈, 친근한 작은 미소, 초록 망토와 황토 튜닉이 보인다. 기존 레퍼런스의 금빛 망토 잠금과 어깨 갑옷은 유지된 요소이며 새 장신구 제안이 아니다.
- 투구·깃털은 화면 안에 있고 무기·손·텍스트·테두리·배경 장면·체커 패턴은 없다. 얼굴이 중심 피사체로 읽힌다. 원본의 픽셀풍 스타일을 따르지만 정확한 저해상도 픽셀 격자나 제한 팔레트를 보장하지 않는다.
- 배경은 어두운 갈색 불투명 카드이며 약한 명암/질감이 있다. 완전 단색 #0d0a06이나 alpha 이미지라고 주장하지 않는다.
- **64×96 몸체 스프라이트가 아니다. 보행·모션 문제가 해결됐다는 뜻도 아니다.** 실제 HUD/대화 슬롯의 축소 표시와 기존 UI 대비는 아직 검사하지 않았고 본 게임 파일을 교체하지 않았다. 독립 DA 후 제한적인 표시 연결 여부를 검토한다.
- AI 생성 원본의 출처 기록이며 제3자 권리 검토 완료나 법적 독점성을 보장하지 않는다.
