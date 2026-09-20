# M3-3: 스탯 분배 규칙 + 스킬 테이블 명세

> **[v2로 대체됨, M4-0]** 이 문서의 5스탯/6종 액티브 전용 스키마는 `docs/specs/ro-benchmark-progression-v1.md`(AGI 추가 6스탯, 3계열×8노드=24개, SP 자원, 핫바)로 대체됐다. 이력 보존용으로 남겨두며, 새 작업은 v2 문서를 참조할 것.

> 기준: GDD 4.3(D-141)·5.2, `docs/brd/03-features/01-캐릭터-성장.md` F1-2·F1-3, `docs/GDD-도트액션RPG-기획안.md` v1.1
> 결정: D-158(초기 스탯/상한), D-159(레벨 게이트 없음), D-160(슬롯 교체 자유), D-161(3계열 id `trick` 차용)
> 소유: game-designer(수치) / godot-engineer(로더·구현, 수치 소유 아님)
> 이 문서는 `docs/specs/data_tables.md`의 combat.json/stats.json 항목에 추가되는 확장이며, 형식은 그 문서 §0~§1 관례를 따른다.

---

## 1. `stats.json.allocation` — 스탯 분배 규칙

| 키 | 타입 | 값 | 근거 |
|---|---|---|---|
| `allocation.initial.{str,dex,int,vit,luk}` | int | 전부 0 | GDD 5.2 / F1-2 어디에도 시작 스탯 지급 언급 없음. 캐릭터 기본 전투치는 `characters.json`이 별도 계층으로 관리하므로 여기서는 "레벨업으로 버는 자원"만 다룬다 (D-158). |
| `allocation.max_per_stat` | int\|null | `null`(무제한) | F1-2 "사제 전체 리셋, 레벨×100G"가 이미 몰빵 재분배를 정상 플레이로 취급 — 스탯당 캡을 둘 근거가 없다 (D-158). |

**분배 흐름(로직 담당 구현 대상)**: 레벨업 시 `stat_points_per_levelup`(3)만큼 포인트 지급 → 캐릭터 메뉴에서 스탯 1개당 포인트 1 소모로 즉시 반영 → 리셋은 F1-2 그대로(사제, 전체 환불, 레벨×100G) — 이번 범위 밖.

**검증(`validate_tables.py::validate_stats`)**: `allocation.initial`이 정확히 `{str,dex,int,vit,luk}` 5키와 일치하고 각각 0 이상, `max_per_stat`이 `null` 또는 양의 정수인지 확인.

---

## 2. `skills.json` — 스키마

```
"<skill_id>": {
  "name_key": str,          // ui_ko.csv 키, "skill.<id>.name"
  "desc_key": str,          // "skill.<id>.desc"
  "series": str,            // class-progression-v3.md 8계열 id와 호환(blade/guard/bow/trick/element/life/faith/forge).
                             // M3-3은 blade·guard·trick 3종만 사용(D-161: trick은 v3 호환 목적의 임시 차용, 기교 정체성 전체를 구현하는 것이 아님)
  "tier": int,              // M3-3은 전부 1(선행 트리 없음, D-159)
  "node_type": "active",    // M3-3 범위는 active만. passive/keystone 등 v3 값은 미구현
  "cost_sp": int,           // 습득 비용(스킬 포인트)
  "cooldown_sec": float,    // > 0
  "stamina_cost": float,    // >= 0
  "damage_mult": float,     // 기본 공격 대비 배율. combat.json.combo.damage_multipliers와 동일 계층
                             // (최종 데미지 = base_attack * skill.damage_mult, 콤보 배율과 별개 — 스킬은 콤보 중첩 없음)
  "hitbox": {"shape": "arc|line|circle", "range_px": number, "width_px": number|null} | null,
                             // damage_mult가 0보다 크면 필수, 0이면(순수 자기 버프) null.
                             // circle은 range_px=반지름, width_px는 의미 없어 null 고정
  "knockback_px": number,   // combat.json.knockback과 동일 단위(px)
  "self_effect": {...} | null,  // §3 참고, 없으면 필드 생략 가능
  "requires": [skill_id...],    // 선행 스킬 id 목록. M3-3은 전부 빈 배열
  "icon": null               // M3-3은 전부 null(후속 작업, UI는 계열 첫 글자로 대체 — D-161 (b))
}
```

**적용 공식(godot-engineer 구현 대상)**: 스킬 사용 시 `Hitbox.damage = effective_base_attack * skill.damage_mult`(effective_base_attack은 stats.json 공식 그대로), `Hitbox.knockback_px = skill.knockback_px`, `Hitbox.hitstop_sec`은 combat.json.hitstop.normal_sec 재사용(스킬 전용 히트스톱 값은 이번 범위 밖). `hitbox`가 `null`이면 Hitbox를 활성화하지 않는다(자기 버프 전용 스킬).

---

## 3. `self_effect` 고정 스키마 (3종만 허용, 로직 담당은 이 3키만 처리)

| 형태 | 필드 | 의미 | 구현 재사용 대상 |
|---|---|---|---|
| 무적 버프 | `{"invuln_sec": float}` | 사용 즉시 n초간 무적 | `Hurtbox.invulnerable` (roll iframe과 동일 플래그) |
| 이동속도 버프 | `{"move_speed_mult": float, "duration_sec": float}` | n초간 이동속도 배수 적용 | 요리 버프(GDD 5.3, 스탯 배수+타이머) 패턴 |
| 돌진+무적 | `{"dash_px": float, "invuln_sec": float}` | 사용 즉시 앞으로 px만큼 이동 + n초 무적 | roll의 거리/무적 로직 재사용, 이동 애니메이션만 교체 |

이 외의 키 조합은 검증 오류 처리한다(godot-engineer가 신규 self_effect 타입을 추가하려면 이 문서와 `validate_tables.py::SKILL_SELF_EFFECT_KEYS`를 함께 갱신).

---

## 4. M3-3 스킬 6종 요약

| id | series | 효과(한 줄) | cd | stamina | dmg_mult | hitbox | self_effect |
|---|---|---|---|---|---|---|---|
| blade_power_slash | blade | 부채꼴 강타+넉백 | 4.0 | 15 | 1.8 | arc 60/90° | - |
| blade_thrust | blade | 직선 찌르기(저비용) | 2.5 | 10 | 1.3 | line 80×20 | - |
| guard_shield_bash | guard | 원형 넉백기 | 5.0 | 20 | 1.0 | circle r40 | - |
| guard_iron_wall | guard | 단기 무적 자기 버프 | 8.0 | 15 | 0 | null | invuln_sec 1.0 |
| trick_dash_strike | trick | 돌진 후 관통 타격 | 6.0 | 20 | 1.4 | line 100×24 | dash_px 80 / invuln_sec 0.15 |
| trick_fleet_step | trick | 이동속도 버프 | 12.0 | 10 | 0 | null | move_speed_mult 1.3 / duration_sec 4.0 |

전부 `_balance_todo`(수치 미확정, 플레이테스트 후 game-designer 조정). Fin(검·방패) 기준 "지금 쓸 수 있는 것 위주"로 선정 — blade 2·guard 2·trick 2, 투사체·소환·상태이상 없음.

---

## 5. `validate_tables.py` 검증 항목 (`validate_skills`, `validate_stats` 확장)

1. `stats.allocation.initial`이 5스탯 키와 정확히 일치 + 각 0 이상, `max_per_stat`이 `null`\|양의 정수.
2. `skills.*.node_type == "active"` (M3-3 범위 강제).
3. `cooldown_sec > 0`, `stamina_cost >= 0`, `damage_mult >= 0`.
4. `hitbox.shape ∈ {arc, line, circle}`, `hitbox.range_px > 0`; `damage_mult > 0`인데 `hitbox`가 `null`이면 오류.
5. `self_effect`가 있으면 키 집합이 §3의 3종 중 하나와 정확히 일치.
6. `requires` 참조 무결성(대상 id가 `skills.json`에 존재) + DFS 기반 순환 참조 검출.

---

## 결정 로그 참조

D-158~D-161은 이 문서와 `04-decisions.md`에 함께 기록한다(이번 세션은 game-designer 계획 문서 갱신까지만, `04-decisions.md` 반영은 release-manager 몫 — 기존 관례와 동일).
