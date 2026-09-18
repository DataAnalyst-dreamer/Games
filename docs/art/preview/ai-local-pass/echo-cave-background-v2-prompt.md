# 메아리 굴 배경 v2 — 국소 동선 교정

2026-09-13 · builtin imagegen 편집 1회 · 배경 컨셉 / 게임 미적용

## 입력과 생성

입력 편집 대상: `echo-cave-background-v1.png` (사전 view_image 확인).
생성 원본: `C:/Users/freer/.codex/generated_images/01a09611-3246-75b2-bc58-7a6c02063b4c/exec-1399fa2e-7e2f-4bad-bad0-faad1f7188e4.png`.
워크스페이스 `echo-cave-background-v2.png`로 원본 바이트 복사했다. 코드 래스터 편집·확대·다운샘플 없음.

## 전체 프롬프트

Use case: precise-object-edit. Image 1 is the edit target. Revise only the LEFT landscape area to correct the walking routes in this existing pixel-art game environment concept. Replace ALL the waterfall, flowing water and pond at the left edge with dry grass, low gray rocks and the same mossy ground palette. In the same left area, make the existing left dirt bypass trail visibly and continuously join the central clearing immediately in front of the cave entrance: remove the small blocking strip of vegetation/rock at its upper end and draw a clearly connected dirt junction. Keep the left trail's lower connection and central rock island so a player can read a complete loop around it. Preserve unchanged the cave entrance, camera perspective, composition, central open clearing, right side terrain, original green/ochre/gray palette and pixel-art style. No new waterfall or water elsewhere. No new decorations, characters, enemies, items, signs, labels, UI or text. No change to game lore. Landscape full canvas, request 1920x1080 FHD if supported; do not crop or move existing scene landmarks. This is an environment concept edit, not a tileset.

## 읽기·시각 검사

- System.Drawing 실측: **1672×941, Format24bppRgb**. 불투명 배경 컨셉으로 알파를 요구하지 않았다. **정확한 FHD 1920×1080 아님**.
- 왼쪽 폭포와 못이 잔디·낮은 바위로 대체된 것을 확인했다. 추가 인물·아이템·UI는 보이지 않는다.
- 왼쪽 길의 상단이 중앙 공터와 흙색으로 이어지고 하단 연결도 남아, 바위섬을 도는 고리 형태가 v1보다 읽힌다. 다만 좁은 곳의 실제 캐릭터 통과 폭과 높이 차는 이미지로 검증할 수 없다.
- 동굴·중앙 공터·전체 초록/황토/회색 팔레트·오른쪽 구도는 대체로 유지됐으나 생성 편집이므로 주변 픽셀이 완전히 동일하지는 않다.
- 시점은 v1의 비교적 정면적인 동굴 입구를 유지했다. 탑다운 게임 배경 적합성 최종 승인은 별도다. 타일 격자·충돌·네비게이션·핀 합성·플레이 테스트 미구현.
- 반복 생성은 하지 않았다. 국소 교정 컨셉을 공유하며 런타임 배경 완성으로 보고하지 않는다.
