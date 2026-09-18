# 쿼터뷰 마을 입구 환경 plate v1

## 상태 / 범위

사용자 승인에 따른 **본편과 분리한 작은 실제 쿼터뷰 샘플**의 배경 후보. 생성 1회. root가 원본을 직접 검토하고 샘플 runtime stage 연결 진행을 승인했다. 최종 화풍 확정·전면 맵 교체·완성 게임 품질 판정은 아니다.

따뜻한 석회벽/목재/붉은 기와의 재질 구분과 비스듬한 건물 부피, 중앙 입구 및 넓은 아래쪽 공터를 확인했다. 원본은 엄격하게 통일된 저해상도 도트보다는 **픽셀풍 일러스트**이며, 잔디와 자갈의 작은 질감이 비교적 많다. 도트 밀도와 실제 FHD 표시의 배우 가독성은 별도 실행 검증 대상이다.

## 원본 보존 / 출처

- 방법: 내장 image generation, reference를 사용한 새 이미지 생성 1회. 외부 API/계정/설치 없음.
- 원본: `C:/Users/freer/.codex/generated_images/01a09ab2-9de6-7371-b8af-f947d40ab6d9/exec-07373b6d-bf5b-4109-a8d8-fce5fe96abda.png`
- 실제 원본: **1672×941, Format24bppRgb**. 요청한 1920×1080과 다르다. 불투명 출력 의도이며 실제 alpha 채널이 없다. 투명 sprite 요청이 아니므로 alpha 부재는 결함이 아니다.
- 원본/문서 보존본/샘플 사용본 SHA256 공통: `EF35A5020E1FE965561FC57EAF700ABD3E8FA759ACAF49D12E2E1E861007D77F`
- [문서 보존본](village-gate-v1.png), [샘플 사용본](../../../../prototypes/quarter-view-lab/assets/village-gate.png): 원본 byte 복사. 확대/축소/절단/색 보정/alpha 추출 등의 래스터 후처리 없음.
- 스타일만 참고한 사용자 첨부: `C:/Users/freer/AppData/Local/Temp/codex-clipboard-96d31b45-a0a8-4fdb-b8df-4bb439980373.png`, SHA256 `D9A60FE073FFB07A877AA5E82F614E3EDD82E7113E917C5C05DB4E5713D68B85`. 생성 전 직접 view. 횡시점 구도/캐릭터/건물/물반사/UI를 복제하지 않고 재질 분리·팔레트·SD 상성만 참고하도록 명시했다.
- 사용자 첨부를 프로젝트 assets에 배포 복사하지 않았다. 생성 출처는 권리 법률 검토 완료나 독점권/CC0 보증을 뜻하지 않는다.

## 제작자 시각 검토

- 두 집의 정면/측면/지붕 높이, 열린 중앙 진입로와 하단 넓은 공터가 있어 고정 비스듬한 2D 시점 비교가 가능하다.
- 하늘·수평선·낭떠러지 diorama edge·캐릭터·HUD·글자는 보이지 않는다. 생성된 문장 모양 깃발과 간단한 간판 장식은 존재하며 새 세계관/세력 canon으로 채택한 것이 아니다.
- 왼쪽 큰 나무와 중앙 왼쪽 돌기둥은 가림 동작의 작은 시험 대상으로 사용할 수 있다. 원본이 층별 asset은 아니므로 같은 texture의 실루엣 polygon을 다시 그리는 방식은 샘플용이다.
- 원본 비율 1672:941은 정확한 16:9와 아주 조금 다르다. 1920×1080 rectangle에 표시한다면 축별 비율은 1920/1672,1080/941이다. 이것은 엔진 표시이며 native FHD 원본/수작업 pixel-perfect art 주장과 구분한다.
- 최종 게임 화면, 배우 크기·모션, 충돌/가림은 제작자의 정지 이미지 검토로 통과시킬 수 없다. root/별도 담당의 통합 실행 및 독립 검토가 필요하다.

## 좌표 인계

[실제 이미지 기준 후보 좌표](village-gate-v1-layout-candidates.json). 좌상단 원점, 원본 px와 normalized UV를 함께 제공했다. **육안 근사이며 픽셀 단위 segmentation 정답이나 검증된 충돌 데이터가 아니다.** 런타임 담당자가 직접 이미지와 배우 앞/뒤 이동을 보고 경계를 조정한다.

- 중앙 안전 공터 후보: x330–1410, y470–835.
- 연결길 후보: x750–925, y10–440. 입구 돌기둥 사이 통과 및 위쪽 제한은 runtime에서 확인.
- 왼쪽 전경 나무: 발 기준 (91,682), canopy는 충돌로 막지 않고 작은 trunk footprint만 사용. 근처 배우가 뒤로 지나갈 수 있어야 가림 비교가 가능하다.
- 중앙 왼쪽 돌기둥: 발 기준 (704,405), banner/등/상부기둥을 포함한 복잡한 전경 레이어 전체는 이 후보에서 제외.
- FHD 화면좌표: u×1920,v×1080. 원본 PNG와 FHD runtime 캡처의 해상도/품질을 별도로 기록할 것.

## 실행하지 않은 일

본편 game, ready snapshot, 기존 artwork, Fin prototype을 변경하지 않았다. Fin 새 생성·모션 완성·전면 전환·경제·새 canon 채택은 수행하지 않았다. 현재 문서는 배경의 생성/정지 검수와 소유 범위만 기록하며 타 담당의 실행 성공을 대신 주장하지 않는다.

## 독립 검토 기록

NPC 담당의 독립 DA 완료, 필수수정 0건(근거 실행 청크 `57e8fd`). prompt 및 후보 좌표 JSON 전체 읽기, 샘플 원본 직접 보기, 생성 원본/문서 보존본/샘플 사용본 3개 SHA 동일성과 1672×941/24bpp RGB를 확인했다. 불투명 배경·픽셀풍 일러스트·FHD 표시와 native 크기의 구분·근사 좌표 및 실제 충돌/가림 미검증이라는 제한을 검토한 범위다. 독립 담당이 새 통합 게임 실행이나 pixel-exact 실루엣 분할 검사를 완료했다는 뜻은 아니다. 이 항목은 제작자가 전달받은 독립 검토 결과를 기록한 것이며 자체 DA가 아니다.

## 최종 생성 프롬프트

```text
Use case: stylized-concept
Asset type: one opaque background plate for a playable 2D fixed-quarter-view RPG scene, not a mockup or poster.
Primary request: Create an original, polished, warm medieval village entrance that can be used as the entire background of a 1920 x 1080 FHD game viewport. Exact 16:9 landscape composition, edge-to-edge environment.
Camera: fixed orthographic three-quarter overhead view looking diagonally down onto the ground, approximately 40 degree elevation. Show both fronts and side walls of buildings and roof height; all architecture shares one consistent projection. This is neither a side-scrolling landscape nor a straight overhead map. No sky, horizon, or distant panorama; ground continues beyond every image border. No floating island or cutaway diorama edge.
Environment: two charming small timber-and-cream-plaster medieval houses with warm red terracotta roofs occupy the upper-left and upper-right portions. A low, worn stone wall with an open entrance and short fence sections defines the village edge. A coherent path of warm earth and occasional broad flat stones passes through the opening into a generously wide, open central and lower courtyard. Grass smoothly borders dirt and gravel rather than repeated square tiles. Include a leafy tree near an outer edge with a distinct readable canopy and trunk silhouette, and a few restrained grass clumps.
Playable layout: keep roughly the central 50% of the width and lower 50% of the height mostly unobstructed ground, suitable for a small hero walking and fighting a slime. Do not put a central prop, tree, roof, or deep shadow across that test space. Houses must not block the connecting entrance path. Tree and short wall/fence silhouettes at the sides should be cleanly separated from the central clearing so the engine can re-render selected same-image polygons in front of actors. No characters, creatures, silhouettes, item pickups, weapons, circles, arrows, grid, labels, text, UI, logo, or watermark.
Style: exceptionally readable original 2D pixel-art-inspired game environment for appealing super-deformed medieval characters. Refined clustered pixel texture with deliberate broad color shapes, crisp stepped edges, appealing architectural proportions and material distinctions. Restrained texture density: no photographic microtexture, random grain, noisy dither blanket, tiny checker patterns, blurry painterly smears, or oversharpening. The grassy ground is visually quiet enough to keep actors legible. Consistent warm cream, terracotta, earth ochre and muted leafy green palette, cool subdued shadows. Soft clear daylight from upper-left, no dramatic bloom, fog, vignette, or extreme contrast.
Output: a single fully opaque environment image, no transparency and no checkerboard. Intended FHD 1920x1080 canvas; preserve a full 16:9 composition. This is original art, not copied from any existing game's map or screenshot.
Input image 1 is a STYLE REFERENCE ONLY: borrow the readable stepped pixel clusters, warm medieval plaster/timber material separation, harmonious colors, and compatibility with small super-deformed characters. Do not copy its buildings, characters, water, layout, horizontal horizon, side-view perspective, screenshot interface, or any specific design. Generate the wholly new quarter-view ground-plane scene described above.
```
