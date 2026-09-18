# 핀 걷기 후처리 v1

사용자가 코드 기반 배경 제거·게임용 픽셀 정리를 승인하여 수행했다. 원본 이미지는 보존했다. 생성 모델 재호출이나 유료 API 사용은 없다.

## 산출물

- `game/assets/sprites/characters/fin/fin-walk-v1.png`: 384×256 RGBA, 4방향×8프레임.
- 같은 폴더의 `.tres`: Godot SpriteFrames, walk_down/left/up/right, 8fps. 아직 Player 씬과 연결하지 않음.
- 같은 폴더의 `.json`: 셀·행·발 기준점·원본 경계 등 재현 메타데이터.
- `docs/art/preview/fin-cq-walk-clean-v1.png`: 원본 크기의 배경 제거본.
- `docs/art/preview/fin-cq-walk-pixel-review.png`: 초록 배경의 4배 확대 검토본.
- `docs/art/preview/fin-cq-walk-review.gif`: 4방향 동시 걷기 미리보기.

## 처리

셀 경계와 연결된 밝은 무채색 배경만 flood fill로 제거했다. 은색 장비 내부의 같은 색을 전역 삭제하지 않는다. 공통 배율로 최근접 축소하고 모든 프레임을 48×64 패딩 셀의 발 기준점 (24,56)에 정렬했다. 원본의 최대 실루엣 높이를 48px로 맞춘 것이며 몸만 엄밀히 32×48로 다시 그린 결과는 아니다. 장비 포함 최대 폭은 셀 내부에 수용된다. 전체 시트 공유 32색, 디더링 없음, 알파는 0/255 두 값이다.

## 검증 및 한계

- Python 생성 시 32셀 경계와 크기, 알파 이진값 검사 통과.
- Godot 4.4.1에서 `--headless --path game --script res://tests/smoke/smoke_fin_atlas.gd --quit-after 30`: 종료 코드 0, 32프레임 여백·접지·셀 잘림 검사 통과.
- 격리 환경의 첫 Godot 실행은 엔진 충돌. 승인된 로컬 실행으로 재검증했다. 기존 LUK/INT 데이터 경고는 남아 있다.
- 초록 배경 확대 정지화면에서 방향·망토·투구·검·방패 실루엣을 확인했다. GIF를 생성했으나 실시간 엔진 재생/플레이 검증으로 간주하지 않는다.
- 테두리로 연결되지 않은 작은 배경 조각은 이 보수적 마스크에 남을 수 있다. 축소 시 얼굴·발 모양 흔들림과 이러한 잔여 픽셀은 후속 모션 정제 대상이다.
- 대기·공격·가드·회피·피격·사망은 미제작. 기존 플레이어를 걷기 시트만으로 교체하지 않았다. T04는 게임 반입 후보 제작 단계이며 전 동작 완성은 T06이다.

재현: Pillow가 설치된 Python으로 `python tools/prepare_fin_sprites.py` 실행.
