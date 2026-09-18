# 핀 보행 4키포즈 v3 — 통과 다리 수정 시험, 모션 적용 보류

2026-09-13. [v2](fin-walk-keyposes-v2-prompt.md)를 root가 직접 본 뒤 승인한 **단일 targeted edit 1회**. 같은 턴 합계 built-in2회(v2 생성1 + v3 수정1)이고 이후 추가 생성은 중단했다. imagegen 스킬/두 참조 지침을 완독했으며 v2를 직접 view한 뒤 정확한 파일 하나를 편집 입력으로 전달했다. 이미지 분할·압축·배경 제거·다리 잘라붙이기·래스터 후처리·코드 아틀라스 조립은 하지 않았다.

원본: `C:/Users/freer/.codex/generated_images/01a09ab2-9de6-7371-b8af-f947d40ab6d9/exec-66bce3fa-d05d-4eaa-9868-1ccb2d54a18e.png`.

저장: [fin-walk-keyposes-v3.png](fin-walk-keyposes-v3.png), 원본 byte-copy. 실제 **2048×768, Format24bppRgb, 알파 없음**. 원본/사본 SHA256 `90F369C11A6B81199F1C9D73C80AA7A0121DC30DB61F0700B1BCFA7765BA9C82`. 불투명 체크무늬가 남았으며 실제 transparent 요청은 다시 실패했다.

입력 v2 SHA256은 수정 전/후 모두 `0E516B01B7F3F64DB82F70CCFF7F366E9959350DDA99C3F3350AB7833672269E`이다. 승인 몸체64×96/FHD1920×1080 규격, 기존 정면 전체 PNG66×96, 원본 game/Fin prototype/기사 fallback은 변경하지 않았다.

## 전체 전달 프롬프트

```text
Use case: precise-object-edit.
Asset type: targeted correction to the provided Fin FOUR WALK KEYPOSE design strip.
Input image1 is the edit target. Keep the same one-row four-character composition, order, framing, scale, camera, color palette and pixel illustration style. Keep characters1 and3 (contact poses) unchanged. Preserve ALL four faces, heads, helmet and feather geometry, expressions, upper torsos, tunics except the necessary leg opening, capes, hands, swords and shields. These are the SAME boy, sword on viewer-left in HIS RIGHT hand and shield on viewer-right in HIS LEFT hand; never mirror.
Change only the swinging LEG in characters2 and4 to fix an exaggerated high-knee marching/kicking pose. In character2, lower HIS RIGHT knee (viewer-left leg) so it sits just below the tunic hem rather than rising high into the tunic. Bend it only slightly and let its ankle/boot pass close beside the support ankle under the pelvis. The swinging boot is only slightly above the invisible ground, not thrust toward the viewer; do NOT show a forward-facing sole. HIS LEFT support foot stays grounded directly below the pelvis. In character4 apply the corresponding small low passing step to HIS LEFT leg (viewer-right leg); HIS RIGHT support foot stays grounded. The swing feet must remain visibly lifted by a small amount, rather than becoming two planted identical idle feet. Preserve coherent continuous pelvis-thigh-knee-shin-ankle-boot connections and the existing brown boot design. This is a modest relaxed walk, not marching, kicking, running or standing still.
Preserve characters1/3 contact poses and every upper body as closely as possible; no generalized redraw or new equipment. Keep both corrected passing poses mutually consistent in knee height and low foot clearance.
Background requirement remains genuinely transparent PNG alpha around/between the four figures. The gray-white checkerboard in the input is an unwanted PAINTED opaque background: remove it, do not redraw or fake a checkerboard. No replacement color, floor, cast shadow, text, labels, borders, motion lines or additional figures. Output one corrected strip. Do not crop or enlarge the characters.
```

## 육안 판정 — 포즈/동일성/배경을 분리

- **2번 통과A:** 오른쪽 다리(화면왼쪽)의 무릎과 부츠가 낮아져 v2의 높은 무릎 행진 느낌은 줄었다. 하지만 지지발 옆에서 지나가는 실제 연속 경로와 접지시간은 이 정지 한 장으로 증명하지 않았다.
- **4번 통과B:** 들어 올린 부츠가 여전히 앞을 향해 크게 돌출되고 발바닥이 보인다. 반대쪽 통과A와 보폭/들림 정도가 다르다. 요청한 자연스러운 좌우 통과쌍의 수정 성공으로 보지 않는다.
- **1/3 접지 및 상체 불변:** 접지포즈의 개략적 앞뒤 배치와 핵심 장비/얼굴 표식은 남았지만 얼굴·눈·투구/깃털의 윤곽·채색이 더 매끈한 일러스트처럼 재해석되었다. 2/4 다리만 수정하고 모든 다른 픽셀을 고정했다는 불변 조건은 충족하지 않았다. 픽셀 동일성 검사를 통과한 것으로 취급하지 않는다.
- **배경:** 실제 RGB이므로 보이는 체크무늬는 투명 표시가 아니라 이미지 내용이다. 알파 성공과 다리 수정 성공을 혼동하지 않는다.
- **실행:** 64×96 프레임 재구성·셀 분리·8프레임 보행·루프 재생·실제 Godot 모션·FHD 플레이·발 미끄러짐/몸 흔들림 검사는 미실행이다. 프로그램 검사를 붙여 그림 품질 통과로 대체하지 않았다.

판정: **후속 원화 실험 보존 / 모션 적용 보류**. v2/v3 모두 현재 런타임 교체 자격이 없다. root에 생성 원본 경로와 원본 이미지를 즉시 공유했고, 실패 이유를 전달했다. 독립 DA 완료, 보고서 필수 수정0건: `npc_runtime`이 두 PNG를 직접 보고 prompt/review를 완독했으며 생성 원본/사본 SHA와 실제 크기/RGB 형식을 확인했다. 통과B 발바닥 노출·좌우 비대칭·상체 재해석·불투명 체크무늬가 보류 판정과 일치함을 보고했다. 이미지 편집이나 실제 모션 검사를 수행한 검수는 아니다. root도 두 원본 이미지를 직접 확인했다. 추가 생성은 하지 않는다. 외부 계정·유료서비스·API·설치·게임 적용·원본 덮어쓰기는 없다. 생성 출처 기록은 법적 권리 검토 완료/독점성 보장이 아니다.
