# 슬라임 v2 — 생성 및 검수 기록

2026-09-13 · builtin imagegen · 정지 컨셉 / 게임 미적용 / 알파 검수 실패

참조: `../parallel-pass/monsters/slime-concept-v1.png` (편집 대상, 사전 육안 확인).
납품 시안: `slime-v2.png`. 래스터 코드 편집·다운샘플 없음.

## 1차 프롬프트

Use case: identity-preserve. Image 1 is the edit target: existing original game slime. Produce one revised stationary character concept on a genuinely transparent PNG background (alpha zero outside the character). Preserve this slime's mint green / teal jelly palette, dark navy stepped pixel outline, two large dark glossy oval eyes with white highlights and small smiling mouth. Revise only its silhouette and camera angle: make the jelly body LOW, WIDE, ROUND, like a small squat soft dome seen from slightly above in top-down three-quarter game view; retain a small soft curl on top but shorten the existing tall elongated crest. Clear visible upper dome, eyes on front-facing lower half. Render polished cute volumetric PIXEL ART with coherent chunky pixel clusters, limited clean shading, sharp stair-step edges, no painterly blur. Single full-body centered slime only, generous transparent margins. Preserve identity, no new limbs, horns, weapons or props. CRITICAL: REMOVE ALL THE GRAY/WHITE CHECKER PATTERN IN THE SOURCE. It is not part of the slime. Do not DRAW a checkerboard, grid, white backdrop, ground plane or drop shadow. Actually encode transparency in the PNG alpha channel. No text, no logo, no watermark, no sprite sheet. This is a concept source, not a request to claim exact runtime pixel dimensions.

생성 원본: `C:/Users/freer/.codex/generated_images/01a09611-3246-75b2-bc58-7a6c02063b4c/exec-065ec900-1836-4b6a-94c7-edc433153d21.png`.
검사: 1254×1254 / Format24bppRgb / 모서리 A=255. 체크무늬가 그림으로 남아 실패.

## 허용된 교정 1회

Use case: background-extraction. Edit this exact image ONLY to remove the entire gray-white checkerboard background. Preserve the green slime exactly: same pixel silhouette, curled top, colors, shading, eyes and smile. Return a PNG with REAL transparency: RGBA alpha channel, alpha=0 outside slime, opaque subject, no painted background pixels. Do NOT illustrate transparency using any checkerboard. Do NOT paint a white or gray background. This is a clean transparent cutout job. No shadow, no other changes.

생성 원본: `C:/Users/freer/.codex/generated_images/01a09611-3246-75b2-bc58-7a6c02063b4c/exec-f03ea049-e1d8-490d-95ee-b3ab68ea6462.png`.
이 파일을 바이트 그대로 `slime-v2.png`로 복사했다.

## 검수

- System.Drawing 읽기 검사: 최종 1254×1254, Format24bppRgb, 모서리 알파 255. RGB이므로 투명 알파 채널 없음. 두 차례 모두 실제 투명 배경 요청 실패.
- 색·큰 눈·미소 유지. v1보다 몸체가 넓고 둥글어졌고 윗면이 보이지만, 윗돌기가 여전히 커서 낮은 실루엣 요구는 부분 충족에 그친다.
- 체크무늬 배경 잔존. 게임 자산으로 통과시키지 않는다. 픽셀 클러스터 가장자리의 균일성·정확한 격자 및 저해상도 가독성 미검증.
- 정지 이미지이므로 보행/공격 개선 없음. 기존 몬스터 데이터·정체성·규칙·런타임 자산 변경 없음.
- 추가 자동 생성은 진행하지 않는다. 실제 알파 확보 및 시점 적합성 검수가 다음 단계의 차단사항이다.
