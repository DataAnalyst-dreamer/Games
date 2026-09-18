# 핀 보행 4키포즈 v2 — 원화 시험, 모션 적용 보류

2026-09-13. imagegen `SKILL.md`, `references/prompting.md`, `references/sample-prompts.md`를 전부 읽고 built-in imagegen **1회**로 만든 하나의 네 포즈 설계 시트다. 네 독립 이미지를 조립한 결과가 아니다. 새 외부 API·계정·설치·다운로드·래스터 후처리·리사이즈·절단·압축·배경 제거·아틀라스 조립은 하지 않았다.

원본: `C:/Users/freer/.codex/generated_images/01a09ab2-9de6-7371-b8af-f947d40ab6d9/exec-756773a2-d04b-40ed-a515-f5f7a49b540a.png`.

저장: [fin-walk-keyposes-v2.png](fin-walk-keyposes-v2.png), 원본 byte-copy. 실제 **2048×768, Format24bppRgb, 알파 없음**. 보이는 체크무늬는 불투명 이미지에 그려진 배경이다. transparent 요청은 실패했다. 원본/사본 SHA256 `0E516B01B7F3F64DB82F70CCFF7F366E9959350DDA99C3F3350AB7833672269E`.

## 참조와 변경하지 않은 규격

승인 콘셉트 `../fin-cq-concept-v1.png`, 정면 축소본 `../fin-resolution/front-64.png`, 그 고해상도 원본 `../fin-resolution/front-64-source.png`, 이전 `../parallel-pass/fin/contact-a-v1.png` 및 당시 prompt/review를 직접 읽고 보았다. 이전 contact-a의 false checkerboard/후방 발끝 지지 불명확 문제를 새 합격으로 간주하지 않았다.

생성 입력1은 `front-64-source.png`(정면 정체성/구조), 입력2는 `front-64.png`(작은 크기의 비율/가독성). 승인 콘셉트와 실패 contact-a는 검토만 했으며 이번 도구 입력으로 전달하지 않았다. 입력2의 실제 전체 PNG는 **66×96**이며 검/방패를 포함한 전체 경계다. 승인 **몸체 목표64×96**과 다르다는 사실을 숨기거나 새 규격으로 확정하지 않는다. 이번2048×768도 설계 시트 크기일 뿐 게임 스프라이트/셀 규격이 아니다. FHD1920×1080 기준은 유지한다.

참조 원본 SHA256(생성 전/후 불변):

- 승인 콘셉트: `C686D4E2348D6D5A3D4DDB4C08FC1360E73A5BBA4F037136E696C375171E7BE4`
- 정면66×96: `A7937BC337238B7B9A47D618DED3FE9EA5C5DED5B2E48FF09D269E57CFF4199F`
- 정면 고해상도: `FEACC03859881981562094977DDDA0ACA87BE99D69CBC0435E19101C3E286E21`
- 기존 contact-a: `78DAF5682ACA19DE758291EE863BD9CD441323BD5626DAA194047D1831FA093C`

## 전체 전달 프롬프트

```text
Use case: identity-preserve.
Asset type: ONE coherent four-key-pose WALK DESIGN STRIP for the SAME pixel-style game character Fin. A high-resolution design reference for eventual 64x96 body art, NOT a finished sprite animation or separate unrelated character illustrations.
Input images: Image1 is the exact frontal character identity and design anchor; preserve its face, head-to-body proportions, silver open helmet shape, red feather, brown hair and brown eyes, ochre tunic, brown belt/boots, green cape, sword in HIS RIGHT hand (viewer LEFT), round wooden shield in HIS LEFT hand (viewer RIGHT). Ignore and completely remove its magenta background. Image2 is the compact approved frontal proportion/readability reference, not a new character. Do not mirror any character or equipment.
Primary request: draw the same Fin four times across ONE horizontal landscape strip, four evenly spaced equal cells, left to right CONTACT A, PASSING A, CONTACT B, PASSING B (do NOT print those labels). All four face directly toward the viewer, full body and complete gear visible, same camera, same scale, same head and helmet geometry, same expression and palette. Generous transparent margins and no overlap between figures. Share the same invisible ground level for grounded boots across the strip.
Pose mechanics: 1 CONTACT A: HIS LEFT leg (viewer-right) advances toward the viewer with heel touching ground; HIS RIGHT leg trails behind on its toes with visibly raised heel. 2 PASSING A: weight supported by HIS LEFT foot flat under his pelvis, while HIS RIGHT knee bends and swings forward, that boot visibly lifted off ground and passing close to the support leg. 3 CONTACT B: HIS RIGHT leg (viewer-left) advances with heel touching ground; HIS LEFT leg trails on its toes with raised heel. 4 PASSING B: weight supported by HIS RIGHT foot flat under his pelvis, while HIS LEFT knee bends and swings forward with that boot visibly lifted and passing close to the support leg. A relaxed purposeful walk toward camera, not a sideways wide stance, jump, kick, run or march with high knees. The two contact silhouettes must differ from the two passing silhouettes. Every leg is coherently drawn from pelvis through thigh, bent knee, shin and ankle to boot; both legs stay anatomically connected beneath the tunic, not pasted or compressed. Keep the two boot designs identical through their rotations and depth shortening. Small natural arm counter-swing only; no torso wobble or head redesign.
Style: closely match the anchor's charming detailed SD pixel illustration with crisp dark stepped outlines and broad stable color clusters. Treat the four figures as one animator's internally consistent model sheet, not four independently restyled images. No new armor, no face changes, no massive weapon swings.
Background: truly transparent PNG alpha around and between figures, no visible floor, no shadow, no opaque color, absolutely NO drawn checkerboard. Transparency means alpha, never a gray-white grid pattern.
Avoid: text, labels, numbers, borders, cell lines, UI, multiple rows, extra figures, duplicated static poses, floating disconnected legs, rectangular hip patches, cut-and-paste joints, missing boots, cropped sword/feather/shield, mirrors, perspective changes, motion streaks. Keep all original inputs unchanged.
```

## 육안 검사 — 실행 애니메이션 단계로 넘어가지 않음

원본 시트를 직접 보았다. 아래는 그림 판단이며 해상도/파일 숫자에 의한 품질 합격이 아니다.

- 네 그림 모두 은 투구·붉은 깃·갈색 머리/눈·황토 튜닉·초록 망토, 검 화면왼쪽/방패 화면오른쪽이라는 핵심 표식과 정면 방향이 유지된다. 눈·투구/깃털 외곽·방패 각도에 재해석이 있으며 프레임 간 픽셀 동일성/고정 기준점은 검증되지 않았다.
- 1/3에서 앞으로 나온 발이 좌우로 바뀌고 2/4는 들린 발이 보여 접지/통과의 개략적 차이는 생겼다. 하지만 **2번 통과A의 무릎·부츠가 높고 앞으로 돌출되어 차기/높은 무릎 행진처럼 보인다.** 4번 통과B와의 들림 정도/발 방향도 대칭적인 자연 보행이라고 확정하기 어렵다.
- 튜닉 아래 허벅지/무릎/정강이/부츠의 연결이 이어져 보이며 기존 직사각형 hip patch나 잘린 부츠를 그대로 재사용한 것은 아니다. 이것만으로 보행 품질 문제가 해결됐다고 하지 않는다.
- 1/3의 후방 발은 작게/높게 보이지만 발끝 지지와 뒤꿈치 들림을 명확히 읽기 어렵다. 체중 중심/지지발 고정/발 미끄러짐도 정지 시트만으로 통과시킬 수 없다.
- **진짜 알파 실패**로 즉시 게임용 투명 스프라이트로 사용할 수 없다. 배경 제거를 후처리로 몰래 수행하지 않았다.
- 연속8프레임, 프레임 셀 분리, 64×96 축소, Godot 재생, FHD 플레이, 8fps loop, 머리 흔들림/발 미끄러짐 검사는 **미실행**이다. 기존 Main의 기사 fallback 및 Fin prototype/애셋은 교체하지 않았다.

판정: **원화 실험 보존 / 모션 적용 보류**. 자동 재생성하지 않고 root에 위 실패를 보고했다. 이후 root가 승인한 단일 targeted edit를 [v3 별도 기록](fin-walk-keyposes-v3-prompt.md)에 보존했다. v2는 덮어쓰지 않았다. 독립 DA 완료, 보고서 필수 수정0건: `npc_runtime`이 두 PNG를 직접 보고 prompt/review를 완독했으며 생성 원본/사본 SHA와 실제 크기/RGB 형식을 확인했다. 이미지 편집이나 실제 모션 검사를 수행한 검수는 아니다. root도 두 원본 이미지를 직접 확인했다. AI 생성 출처 기록이지 권리 검토 완료나 법적 독점성을 뜻하지 않는다.
