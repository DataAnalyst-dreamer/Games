# 몬스터 정지 시안 병렬 패스 v1

2026-09-13 · built-in image_gen · concept source only / runtime 미적용

## 생성·출처

입력은 프로젝트에서 생성·승인한 `../../fin-cq-concept-v1.png`의 톤 참고만 사용했다. CQ 원본 애셋, 웹 이미지, 외부 스프라이트를 입력·복제하지 않았다. 기존 monster_id `slime`, `horn_rabbit`, `mushroom` 및 `docs/content-drafts/monsters-items-demo-v1.md`의 실루엣을 근거로 각각 별도 호출했다. 원본 게임 애셋과 데이터는 교체하지 않았다.

## 실제 규격과 상태

세 이미지 모두 요청1024×1024와 달리 **1254×1254 / 24-bit RGB**로 반환되었다. System.Drawing.Bitmap으로 모든 픽셀 alpha를 검사: min=max=255, 완전투명0, 반투명0. 따라서 체크무늬는 실제 배경이다. 알파 요청 불충족이며 런타임에 바로 쓰면 안 된다. 후처리·픽셀그리드 정리·축소·애니메이션 미수행.

| 파일 | 기존 ID | 시각 검토 | 상태 |
|---|---|---|---|
| slime-concept-v1.png | slime | 청록 젤리·큰 눈·짙은 윤곽 명확. 꼭지가 길고 높아 낮은 실루엣 목표 재검토 필요 | 정지시안 후보 |
| horn-rabbit-concept-v1.png | horn_rabbit | 단일 뿔·두 귀·큰 뒷발·토끼 식별 가능. 귀가 대기 포즈에서 다소 곧음 | 정지시안 후보 |
| mushroom-concept-v1.png | mushroom | 넓은 갓·보라 주름·짧은 줄기 명확. 갓 아래가 많이 보여 탑다운 카메라에서 확인 필요 | 정지시안 후보 |

모든 시안은 온색 명암과 픽셀풍 윤곽이 핀 컨셉과 가깝지만 동일한 픽셀 격자·64×96 상대크기·인게임 가독성을 보장하지 않는다. 실제 게임 표시 크기·4방향·모션·예고 프레임·충돌 검증 전이다. 세 종의 최종 팔레트·상대크기는 일괄 게임 화면 확인 후 결정한다.

## 재현용 정확한 프롬프트

### Slime

```text
Use case: stylized-concept. Asset type: original game monster static concept source, NOT a sprite sheet. Input image 1 is STYLE REFERENCE ONLY: match the approved Fin knight's warm volumetric pixel-art clusters and dark navy outlines; do not draw the knight or board. One centered full creature, 1024x1024 transparent RGBA PNG, genuine alpha outside creature, no checkerboard pixels, no floor, no ground shadow, no words. Top-down RPG three-quarter view, camera sees top and face, creature facing lower right. Crisp chunky pixel-art shading, limited deliberate color clusters, no smooth gradients, no realism, no extra creatures or props. Designed to eventually read beside a 64x96-body chibi knight; this is a large concept source, not an exact-size production sprite. Subject: a small friendly but alert waterdrop slime of Hartland meadows. Squat rounded emerald-jade gelatinous body, two large dark oval eyes, tiny simple mouth, rounded teardrop crest leaning backward, two broad cream-mint highlights showing jelly volume, darker teal underside. Body is roughly half a knight's height, wider than tall. Idle grounded neutral pose, coherent solid silhouette. No crown, arms, weapons, costume, coins, sparkles, leafy decorations or face copied from existing games.
```

### Horn rabbit

```text
Use case: stylized-concept. Asset type: original game monster static concept source, NOT a sprite sheet. Input image 1 is STYLE REFERENCE ONLY: match the approved Fin knight's warm volumetric pixel-art clusters and dark navy outlines; do not draw the knight or board. One centered full creature, 1024x1024 transparent RGBA PNG, genuine alpha outside creature, no checkerboard pixels, no floor, no ground shadow, no words. Top-down RPG three-quarter view, camera sees top and face, creature facing lower right. Crisp chunky pixel-art shading, limited deliberate color clusters, no smooth gradients, no realism, no extra creatures or props. Designed to eventually read beside a 64x96-body chibi knight; this is a large concept source, not an exact-size production sprite. Subject: original Hartland horn rabbit. Cute squat cream-and-warm-tan rabbit, large haunches and hind paws, tiny forepaws, two long ears swept gently backward, exactly ONE short ivory horn on the forehead, expressive dark eyes and alert neutral face, small round tail. Rabbit anatomy not raccoon. No clothes, armor, plants, saddle or weapons. Idle four-pawed neutral stance, face and horn legible from above. About two thirds of the knight's height including ears, compact broad grounded body. Keep volume through warm ochre shadows and crisp cream highlights, simple fur clusters not fine hair.
```

### Mushroom

```text
Use case: stylized-concept. Asset type: original game monster static concept source, NOT a sprite sheet. Input image 1 is STYLE REFERENCE ONLY: match the approved Fin knight's warm volumetric pixel-art clusters and dark navy outlines; do not draw the knight or board. One centered full creature, 1024x1024 transparent RGBA PNG, genuine alpha outside creature, no checkerboard pixels, no floor, no ground shadow, no words. Top-down RPG three-quarter view, camera sees top and face, creature facing lower right. Crisp chunky pixel-art shading, limited deliberate color clusters, no smooth gradients, no realism, no extra creatures or props. Designed to eventually read beside a 64x96-body chibi knight; this is a large concept source, not an exact-size production sprite. Subject: original Hartland mushroom creature. Broad low warm russet-and-ochre cap with just a few broad cream patches, short pale cream stem body, two stubby rooted feet, two dark oval eyes below cap and a tiny determined mouth. Visible dark plum gill fan beneath cap, readable thick rim. Cute alert idle pose, cap tilts very slightly to show underside at front while top remains visible from above. Overall mushroom height about half to two thirds of a chibi knight, cap wider than body and feet. No arms, clothes, staff, dangling mushrooms, floating spores, ground, grass or accessories. Crisp high-quality pixel cluster shading, warm amber highlights, restrained purple-brown shadows; silhouette must instantly read as mushroom and not as a hat on a human.
```

