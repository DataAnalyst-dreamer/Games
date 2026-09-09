# 몬스터 공격 이펙트 앵커 검토 (M1 게이트 플레이테스트 후속)

> 작성: art-director. 배경: 플레이테스터 피드백 "몬스터 공격 이펙트가 몸에서 떨어진 곳에서 나오는
> 느낌". 코드(`game/scripts/entities/monster_base.gd`)는 이 문서에서 수정하지 않는다 — 아래 권장값을
> godot-engineer가 반영한다.

## 1. 현재 구조 (코드 조사 결과)

`monster_base.gd`는 접촉 히트박스와 투사체 스폰 위치를 전부 같은 공식으로 계산한다.

```gdscript
# _fire_hitbox()  — 접촉 판정(멜리/돌진/포자장판 공통)
hitbox.position = _attack_dir * melee_range_px * 0.6

# _fire_projectile() — 원거리(ranged_dart)
proj.global_position = global_position + _attack_dir * melee_range_px * 0.6

# _activate_spore_patch() — 포자 장판 중심
_spore_hitbox.global_position = global_position + _attack_dir * melee_range_px
```

**핵심 문제**: `melee_range_px`는 game-designer가 정한 **전투 밸런스 값**(플레이어가 "이 거리 안에
들어오면 맞는다"고 인지해야 하는 판정 반경)이지, 스프라이트 몸통 크기에 대응하는 값이 아니다.
그런데 이펙트/히트박스 스폰 오프셋을 여기서 그대로 파생시키다 보니:

1. `goblin_scout`/`elite_goblin_captain`처럼 `melee_range_px=90`(원거리 사거리 스탯)인 종은
   `*0.6=54px` 지점에서 쿠나이가 "공중에서 갑자기 나타나는" 것처럼 보인다 — 몸(반경 8px)에서 6배
   이상 떨어진 허공.
2. `horn_rabbit_big`/`elite_goblin_captain`/`elite_bunchi_spawn`처럼 배치 시 `AnimatedSprite2D.scale`을
   1.3~1.4배로 오버라이드하는 종은, 오프셋 계산이 스케일을 반영하지 않아 **확대된 몸통보다 히트박스가
   더 안쪽에 생긴다**(시각적으로는 몸에 파묻힌 것처럼 보임 — "몸에서 뜬 느낌"의 반대 증상이지만 원인은
   동일: 오프셋이 스프라이트 크기와 무관하게 계산됨).
3. `mushroom`은 접촉 판정(12dmg)이 몸 가장자리보다 4px 더 밖에서 발동해(반경 8px인데 오프셋 12px)
   눈에 띄게 "뜬" 느낌을 준다.

## 2. 스프라이트 기준값 (전종 공통)

Slime/HornRabbit/Mushroom/GoblinScout/Cyclope2 모두 **16×16px 셀**을 쓰고(region 확정,
`docs/art/sprite-layouts-m1.md` 참고), `AnimatedSprite2D.position = Vector2(0, -4)`로 피벗(발밑
기준 원점)에서 4px 위가 스프라이트 중심이다. 즉 미확대 상태의 **시각 반지름은 8px**로 전종 동일.

## 3. 권장 오프셋 (종별)

**원칙**: `melee_range_px`(밸런스 값, 변경 금지)와 "이펙트가 어디서 튀어나오는가"(시각 값)를
분리한다. 시각 오프셋 = `visual_radius_px(8) × AnimatedSprite2D.scale + reach_margin_px`.
`reach_margin_px`는 팔/발/부리가 몸 밖으로 뻗는 여유(2~3px)다.

| 몬스터 | `melee_range_px` | 배치 스케일 | 시각 반지름(8×scale) | 현재 공식 | 현재 오프셋(px) | **권장 오프셋(px)** | 비고 |
|---|---|---|---|---|---|---|---|
| **슬라임**(`slime`, melee_contact) | 14 | 1.0 | 8 | `×0.6` | 8.4 | **8~9 (현행 유지)** | 이미 몸 가장자리와 거의 일치 — 손대지 않아도 됨 |
| **뿔토끼**(`horn_rabbit`, charge) | 16 | 1.0 | 8 | `×0.6` | 9.6 | **9~10 (현행 유지)** | 돌진 리치感을 위해 가장자리보다 살짝 밖인 현재값이 오히려 적절 |
| 뿔토끼(정예, `horn_rabbit_big`, 참고) | 16 | **1.3**(배치 오버라이드) | 10.4 | `×0.6`(스케일 미반영) | 9.6 | **11~12**(스케일 반영) | 확대 배치인데 오프셋이 그대로라 판정이 몸 안쪽에 생김 — 요청 목록엔 없지만 동일 결함이라 참고로 추가 |
| **버섯돌이**(`mushroom`, spore_patch 접촉) | 20 | 1.0 | 8 | `×0.6` | 12 | **8~9** | 가장자리보다 4px 밖 — "몸에서 뜬 느낌"의 가장 유력한 후보. 4px는 이 크기의 스프라이트에서 지각 가능한 차이 |
| 버섯돌이(포자 장판 중심, 참고) | 20 | 1.0 | 8 | `×1.0` | 20 | **14~16**(선택, 우선순위 낮음) | 장판은 AOE 반경 32px로 넓게 퍼지는 연출이라 몸에서 먼 중심도 어느 정도 자연스러움 — 급하지 않음 |
| **고블린 정찰병**(`goblin_scout`, ranged_dart) | 90 | 1.0 | 8 | `×0.6` | 54 | **9~10**(사거리와 분리, 고정값) | 핵심 수정 대상 — 사거리 스탯에서 파생되어 몸에서 6배 이상 떨어진 허공에서 쿠나이가 생성됨 |
| **고블린 정찰대장**(`elite_goblin_captain`, ranged_dart, 정예) | 90 | **1.3** | 10.4 | `×0.6`(스케일 미반영) | 54 | **12~13**(고정값 + 스케일) | 위와 동일 결함 + 확대 스케일 미반영 |
| **뭉치의 새끼**(`elite_bunchi_spawn`, melee_contact, 정예) | 14 | **1.4** | 11.2 | `×0.6`(스케일 미반영) | 8.4 | **11~12**(스케일 반영) | 확대 배치인데 오프셋 불변 — 판정이 몸 안쪽에 생김 |

## 4. 코드 수정 방향 (godot-engineer 참고용 — 이 문서에서는 구현하지 않음)

- `_fire_hitbox()`/`_fire_projectile()`이 쓰는 "스폰 오프셋"을 `melee_range_px`에서 파생시키지 말고
  종별 신규 필드(예: `monsters.json`에 `attack_vfx_offset_px` 추가, 또는 `tuning.gd`에
  `MONSTER_ATTACK_VFX_MARGIN_PX = 2.0` 상수를 두고 `sprite.scale.x`를 곱해 자동 계산)로 분리한다.
  `melee_range_px`(플레이어가 맞는지 판정하는 밸런스 값)는 이번 권장값과 무관하게 그대로 둔다.
  두 값을 분리해 두면 이후 밸런스 조정 시 시각 위치가 같이 흔들리는 일도 없어진다.
- 스케일 반영이 핵심이다: `AnimatedSprite2D.scale`을 배치 시점에 오버라이드하는 종(현재
  `horn_rabbit_big`/`elite_goblin_captain`/`elite_bunchi_spawn` 3종)은 오프셋 계산에
  `sprite.scale.x`(균등 스케일 가정)를 곱해야 한다.
- 표의 값은 "권장 범위"이며, 실제 반영 후 인게임에서 육안 확인 후 ±1~2px 조정은 godot-engineer
  재량으로 둔다.

## 5. 원작 아트 전환 시 참고

32×48 원작 몸체로 교체되면 시각 반지름 자체가 커지므로(대략 16px), 위 계산식(`visual_radius ×
scale + margin`)의 `visual_radius` 상수만 8→16으로 바꾸면 전종 오프셋이 자동으로 갱신된다 — 이번에
"밸런스 값과 시각 오프셋을 분리"해 두는 이유이기도 하다.
