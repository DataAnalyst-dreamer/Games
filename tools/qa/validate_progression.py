#!/usr/bin/env python3
"""M4-0 성장(스탯/SP·스킬 트리/경험치 곡선) 검증 모듈(D-157: validate_tables.py가 이미
500줄을 넘는 상태라 새 로직은 여기로 분리했다).

game/data/{stats,skills}.json · exp_curve.csv 를 읽어 docs/specs/
ro-benchmark-progression-v1.md §1~§4·§6·§7 규칙을 확인한다. `tools/qa/validate_tables.py`가
이 모듈을 import해서 호출만 하며, 오류/경고는 호출자가 넘겨준 Report 인스턴스에 그대로
쌓인다(별도 합산 로직 없음) — 두 파일은 항상 같이 갱신할 것.
"""

from __future__ import annotations

from typing import Any, Dict, List

# validate_tables.Report를 그대로 타입힌트에 쓴다. from __future__ import annotations 덕에
# 어노테이션이 런타임에 평가되지 않으므로(문자열로만 취급) import 없이도 순환참조 없이 동작한다.

SKILL_HITBOX_SHAPES = {"arc", "line", "circle"}
SKILL_SELF_EFFECT_KEYS = {
    frozenset({"invuln_sec"}),
    frozenset({"move_speed_mult", "duration_sec"}),
    frozenset({"dash_px", "invuln_sec"}),
    frozenset({"atk_buff_pct", "duration_sec"}),
    frozenset({"dmg_reduction_pct", "duration_sec"}),
}
SKILL_NODE_TYPES = {"active", "passive", "buff"}
STAT_KEYS = {"str", "agi", "dex", "int", "vit", "luk"}
DEX_ROLL_COST_FORMULA_CANONICAL = "cost * (1 - min(0.5, DEX/300))"
# docs/specs/ro-benchmark-progression-v1.md §2: stats.json.allocation.point_cost_curve_formula 정본 문자열.
STAT_POINT_COST_FORMULA_CANONICAL = "cost(n -> n+1) = floor(n/10) + 1"
# 같은 문서 §2 검산 결과(레벨 1~50, exp_curve.csv.stat_points_gain 합계 기준) — 스크립트가
# 실제로 계산한 값과 이 두 스펙값이 어긋나면 데이터나 스펙 중 하나가 깨진 것이다.
SPEC_TOTAL_STAT_POINTS = 198
SPEC_SINGLE_STAT_CAP = 58


def entries(table: Dict[str, Any]) -> Dict[str, Any]:
    """밑줄(_)로 시작하는 메타 키(_comment 등)를 제외한 실제 데이터 항목만.
    validate_tables.entries()와 동일 정의(순환 import를 피하기 위한 소규모 중복)."""
    return {k: v for k, v in table.items() if not k.startswith("_")}


def stat_point_cost(n: int) -> int:
    """stats.json.allocation.point_cost_curve_formula: cost(n -> n+1) = floor(n/10) + 1."""
    return n // 10 + 1


def stat_point_total_cost(n: int) -> int:
    """스탯을 0에서 n까지 올리는 데 드는 누적 포인트."""
    return sum(stat_point_cost(i) for i in range(n))


def stat_point_single_cap(total_points: int) -> int:
    """총 지급 포인트를 한 스탯에 몰빵했을 때 도달 가능한 최대값."""
    n = 0
    while stat_point_total_cost(n + 1) <= total_points:
        n += 1
    return n


def validate_stats(stats: Dict[str, Any], total_stat_points: int, report: Report) -> None:
    """elite-and-farming-m2.md §4-3 규칙 1~3 (규칙4는 코드 리뷰 항목, 런타임/오프라인
    검증 불가) + M4-0 point_cost_curve 검산."""
    dex = stats.get("dex", {})
    formula = dex.get("stamina_cost_reduction_formula")
    if formula != DEX_ROLL_COST_FORMULA_CANONICAL:
        report.error(
            f"stats.dex.stamina_cost_reduction_formula='{formula}' 가 D-45 정본 문자열"
            f"('{DEX_ROLL_COST_FORMULA_CANONICAL}')과 다름"
        )

    luk = stats.get("luk", {})
    if luk.get("_luck_formula_ref") != "drop_tables.json":
        report.error(
            f"stats.luk._luck_formula_ref='{luk.get('_luck_formula_ref')}' "
            "(D-52/D-78 예정: 'drop_tables.json' 고정값이어야 함)"
        )
    if "drop_weight_formula" in luk:
        report.error("stats.luk.drop_weight_formula 필드가 존재함 — D-52/D-78(예정) 위반(공식 중복 정의 금지)")

    if "crit_chance_cap" in luk and not (0.0 <= luk["crit_chance_cap"] <= 1.0):
        report.error(f"stats.luk.crit_chance_cap={luk['crit_chance_cap']} 범위(0~1) 위반")
    int_stat = stats.get("int", {})
    if "cooldown_reduction_cap_pct" in int_stat and not (0.0 <= int_stat["cooldown_reduction_cap_pct"] <= 1.0):
        report.error(f"stats.int.cooldown_reduction_cap_pct={int_stat['cooldown_reduction_cap_pct']} 범위(0~1) 위반")

    # M4-0(§7-7 회귀 수정): 만렙 "몰빵"이 실제로 한 스탯에 넣을 수 있는 최댓값은 총
    # 지급량(198) 그대로가 아니라 체증 비용 곡선을 적용한 단일 스탯 상한(58)이다.
    # 레거시 고정 지급량(stat_points_per_levelup=3, 147p) 기반 계산은 곡선 도입 전
    # 값이라 더 이상 안 맞는다.
    max_points = float(stat_point_single_cap(total_stat_points))
    if {"base_crit_chance", "crit_chance_per_point", "crit_chance_cap"} <= luk.keys():
        projected = luk["base_crit_chance"] + max_points * luk["crit_chance_per_point"]
        if projected <= luk["crit_chance_cap"]:
            report.warn(
                f"stats.luk: 만렙 몰빵({max_points:.0f}포인트) crit_chance={projected:.4f} 가 "
                f"상한({luk['crit_chance_cap']:.4f})에 못 미침 — 상한이 사실상 의미 없음"
            )
    if {"cooldown_reduction_per_point", "cooldown_reduction_cap_pct"} <= int_stat.keys():
        projected_cd = max_points * int_stat["cooldown_reduction_per_point"]
        if projected_cd <= int_stat["cooldown_reduction_cap_pct"]:
            report.warn(
                f"stats.int: 만렙 몰빵 cooldown_reduction={projected_cd:.4f} 가 "
                f"상한({int_stat['cooldown_reduction_cap_pct']:.4f})에 못 미침 — 상한이 사실상 의미 없음"
            )

    allocation = stats.get("allocation")
    if allocation is None:
        report.error("stats.allocation 누락 (M3-3/D-158)")
        return
    initial = allocation.get("initial")
    if not isinstance(initial, dict) or set(initial.keys()) != STAT_KEYS:
        report.error(f"stats.allocation.initial 키가 {sorted(STAT_KEYS)} 5개와 정확히 일치해야 함 (현재 {initial})")
    else:
        for k, v in initial.items():
            if not isinstance(v, (int, float)) or v < 0:
                report.error(f"stats.allocation.initial.{k}={v} 는 0 이상의 숫자여야 함")
    max_per_stat = allocation.get("max_per_stat")
    if max_per_stat is not None and not (isinstance(max_per_stat, int) and max_per_stat > 0):
        report.error(f"stats.allocation.max_per_stat={max_per_stat} 는 null 이거나 양의 정수여야 함")

    # M4-0(§7-7 검산): point_cost_curve_formula 문자열이 정본과 일치하는지, 그리고 그
    # 공식을 실제로 계산했을 때 스펙 §2가 못박은 총 지급량(198)·단일 몰빵 상한(58)이
    # 그대로 나오는지 확인한다. exp_curve.csv 쪽 합계는 validate_exp_curve()가 검증한다.
    formula = allocation.get("point_cost_curve_formula")
    if formula != STAT_POINT_COST_FORMULA_CANONICAL:
        report.error(
            f"stats.allocation.point_cost_curve_formula='{formula}' 가 스펙 §2 정본 문자열"
            f"('{STAT_POINT_COST_FORMULA_CANONICAL}')과 다름"
        )
    if total_stat_points != SPEC_TOTAL_STAT_POINTS:
        report.error(
            f"stats.allocation: exp_curve.csv.stat_points_gain 합계={total_stat_points} 가 "
            f"스펙 §2 총 지급량({SPEC_TOTAL_STAT_POINTS})과 다름"
        )
    computed_cap = stat_point_single_cap(total_stat_points)
    if computed_cap != SPEC_SINGLE_STAT_CAP:
        report.error(
            f"stats.allocation: point_cost_curve_formula로 계산한 단일 스탯 몰빵 상한="
            f"{computed_cap}(총 {total_stat_points}p 기준) 가 스펙 §2 상한값"
            f"({SPEC_SINGLE_STAT_CAP})과 다름"
        )


def _req_skill_id(req: Any) -> Any:
    """requires 원소에서 대상 스킬 id를 뽑는다. v2 스키마는 {"skill":.., "level":..}
    딕셔너리(RO식 '선행 스킬 N레벨 이상'), 구 스키마는 문자열이었다 — v2가 정본이지만
    타입이 잘못 섞여 들어와도(예: 마이그레이션 실수) 크래시 대신 오류로 보고한다."""
    if isinstance(req, dict):
        return req.get("skill")
    return req


def validate_skills(skills: Dict[str, Any], report: Report) -> Dict[str, Any]:
    """M4-0 v2(D-161): docs/specs/ro-benchmark-progression-v1.md §4 스키마 검증.
    node_type(active/passive/buff)별 필수 필드, levels[] 1~5 단조성, requires({skill,level})
    참조 무결성·순환 검출을 확인한다."""
    data = entries(skills)
    for skill_id, sk in data.items():
        node_type = sk.get("node_type")
        if node_type not in SKILL_NODE_TYPES:
            report.error(
                f"skills.{skill_id}.node_type='{node_type}' 는 {sorted(SKILL_NODE_TYPES)} 중 하나여야 함"
            )

        max_level = sk.get("max_level")
        if not isinstance(max_level, int) or max_level <= 0:
            report.error(f"skills.{skill_id}.max_level={max_level} 는 양의 정수여야 함")
            max_level = None

        levels = sk.get("levels")
        if not isinstance(levels, list) or not (1 <= len(levels) <= 5):
            report.error(f"skills.{skill_id}.levels 길이={len(levels) if isinstance(levels, list) else levels} 는 1~5여야 함")
            levels = []
        if max_level is not None and levels and len(levels) != max_level:
            report.error(f"skills.{skill_id}.levels 길이({len(levels)})가 max_level({max_level})과 다름")
        expected_level_nums = list(range(1, len(levels) + 1))
        actual_level_nums = [lv.get("level") for lv in levels]
        if actual_level_nums != expected_level_nums:
            report.error(f"skills.{skill_id}.levels[].level 순서={actual_level_nums} 는 {expected_level_nums} 여야 함")

        # node_type별 필수 필드 + 레벨 단조성. 패시브는 SP/쿨다운/데미지가 없는 상시효과,
        # 액티브·버프는 SP+쿨다운을 쓴다(액티브만 damage_mult, 버프는 대신 self_effect).
        if node_type == "passive":
            if "hitbox" in sk:
                report.error(f"skills.{skill_id}: node_type=passive인데 hitbox 필드가 있음(패시브는 슬롯/판정 불필요)")
            if not sk.get("passive_stat"):
                report.error(f"skills.{skill_id}: node_type=passive인데 passive_stat 없음")
            _check_monotonic(report, skill_id, levels, "value", strictly_increasing=True, field_label="value")
        elif node_type in ("active", "buff"):
            _check_monotonic(report, skill_id, levels, "sp_cost", strictly_increasing=True, field_label="sp_cost")
            _check_monotonic(report, skill_id, levels, "cooldown_sec", strictly_increasing=True,
                              decreasing=True, field_label="cooldown_sec")

            has_positive_damage = False
            if node_type == "active":
                for lv in levels:
                    dmg = lv.get("damage_mult")
                    if dmg is not None:
                        if not isinstance(dmg, (int, float)) or dmg < 0:
                            report.error(f"skills.{skill_id}.levels[{lv.get('level')}].damage_mult={dmg} 는 0 이상이어야 함")
                        elif dmg > 0:
                            has_positive_damage = True
                    else:
                        report.error(f"skills.{skill_id}.levels[{lv.get('level')}]: node_type=active인데 damage_mult 없음")
                if levels:
                    _check_monotonic(report, skill_id, levels, "damage_mult", strictly_increasing=False, field_label="damage_mult")

            # hitbox는 실제로 데미지를 주는 액티브에만 필요하다. guard_iron_wall처럼
            # damage_mult=0(순수 자기 버프형 액티브)이면 hitbox가 null이어도 정상이다.
            hitbox = sk.get("hitbox")
            if node_type == "active" and has_positive_damage and hitbox is None:
                report.error(f"skills.{skill_id}: damage_mult>0인 레벨이 있는데 hitbox가 null임")
            if hitbox is not None:
                shape = hitbox.get("shape") if isinstance(hitbox, dict) else None
                if shape not in SKILL_HITBOX_SHAPES:
                    report.error(f"skills.{skill_id}.hitbox.shape='{shape}' 는 {sorted(SKILL_HITBOX_SHAPES)} 중 하나여야 함")
                elif not isinstance(hitbox.get("range_px"), (int, float)) or hitbox["range_px"] <= 0:
                    report.error(f"skills.{skill_id}.hitbox.range_px={hitbox.get('range_px')} 는 0보다 커야 함")

            if node_type == "buff":
                for lv in levels:
                    if "self_effect" not in lv:
                        report.error(f"skills.{skill_id}.levels[{lv.get('level')}]: node_type=buff인데 self_effect 없음")

            for lv in levels:
                self_effect = lv.get("self_effect")
                if self_effect is not None and frozenset(self_effect.keys()) not in SKILL_SELF_EFFECT_KEYS:
                    report.error(
                        f"skills.{skill_id}.levels[{lv.get('level')}].self_effect 키 "
                        f"{sorted(self_effect.keys())} 는 허용된 조합 "
                        f"({[sorted(s) for s in SKILL_SELF_EFFECT_KEYS]}) 중 하나와 정확히 일치해야 함"
                    )
                elif self_effect is not None:
                    for k, v in self_effect.items():
                        if not isinstance(v, (int, float)):
                            report.error(f"skills.{skill_id}.levels[{lv.get('level')}].self_effect.{k}={v!r} 는 숫자여야 함")

        for req in sk.get("requires", []):
            if not isinstance(req, dict) or "skill" not in req or "level" not in req:
                report.error(f"skills.{skill_id}.requires 원소={req!r} 는 {{'skill':.., 'level':..}} 형태여야 함")
                continue
            req_id = req["skill"]
            req_level = req["level"]
            if req_id not in data:
                report.error(f"skills.{skill_id}.requires 참조 실패: skill '{req_id}' 없음")
                continue
            req_max_level = data[req_id].get("max_level", 5)
            if not isinstance(req_level, int) or not (1 <= req_level <= req_max_level):
                report.error(
                    f"skills.{skill_id}.requires: '{req_id}'의 level={req_level} 이 유효 범위(1~{req_max_level})를 벗어남"
                )

    # requires 순환 검출 (DFS)
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {sid: WHITE for sid in data}

    def visit(sid: str, stack: List[str]) -> None:
        color[sid] = GRAY
        for req in data.get(sid, {}).get("requires", []):
            req_id = _req_skill_id(req)
            if req_id not in color:
                continue
            if color[req_id] == GRAY:
                report.error(f"skills: requires 순환 감지 {' -> '.join(stack + [sid, req_id])}")
            elif color[req_id] == WHITE:
                visit(req_id, stack + [sid])
        color[sid] = BLACK

    for sid in data:
        if color[sid] == WHITE:
            visit(sid, [])

    return data


def _check_monotonic(report: Report, skill_id: str, levels: List[Dict[str, Any]], field: str,
                      strictly_increasing: bool, field_label: str, decreasing: bool = False) -> None:
    """levels[] 배열에서 field 값이 레벨이 오를수록 단조 변화하는지 확인한다.
    decreasing=True면 감소 방향(쿨다운류), False면 증가 방향(sp_cost/damage_mult/value류).
    strictly_increasing=False면 동률(=)도 허용한다(예: guard_iron_wall의 damage_mult=0 고정) —
    이름은 '증가' 기준이지만 decreasing과 조합해 감소 방향의 엄격도도 이 값으로 정한다."""
    prev = None
    for lv in levels:
        value = lv.get(field)
        if value is None:
            report.error(f"skills.{skill_id}.levels[{lv.get('level')}].{field_label} 없음")
            return
        if not isinstance(value, (int, float)):
            report.error(f"skills.{skill_id}.levels[{lv.get('level')}].{field_label}={value!r} 는 숫자여야 함")
            return
        if prev is not None:
            if decreasing:
                ok = value < prev if strictly_increasing else value <= prev
            else:
                ok = value > prev if strictly_increasing else value >= prev
            if not ok:
                direction = "감소" if decreasing else "증가"
                report.error(
                    f"skills.{skill_id}.levels[{lv.get('level')}].{field_label}={value} 가 이전 레벨({prev}) 대비 "
                    f"{direction}(단조) 규칙을 위반함"
                )
        prev = value


def validate_exp_curve(exp_curve: Dict[str, Any], stats: Dict[str, Any], report: Report) -> int:
    """exp_curve.csv 검증(M3-1, F1-2. data_tables.md §4 검증 규칙 1~3 +
    M4-0(§7-8) stat_points_gain 컬럼 검증). 반환값은 stat_points_gain 합계(총 지급
    스탯 포인트) — validate_stats()의 몰빵 상한 검산에 쓰인다."""
    max_level = int(stats.get("max_level", 50))
    prev_exp_to_next = 0
    prev_stat_points_gain = 0
    total_stat_points = 0
    for level in range(1, max_level + 1):
        row = exp_curve.get(str(level))
        if row is None:
            report.error(f"exp_curve: level {level} 행 누락(1~{max_level} 연속이어야 함)")
            continue
        if "exp_to_next" not in row:
            report.error(f"exp_curve.{level}: 필수 키 누락 'exp_to_next'")
            continue
        exp_to_next = int(row["exp_to_next"])
        # 단조 비감소·">0" 규칙은 "성장 중" 구간(레벨 1~max_level-1)에만 적용한다.
        # max_level 행의 exp_to_next=0은 "더 오를 곳 없음" 종료 표식이라 그 앞 레벨(예:
        # 49의 6860)보다 작아도 규칙 위반이 아니다(data_tables.md §4 "레벨50은 0 또는
        # 공란" 예외 그대로).
        if level < max_level:
            if exp_to_next <= 0:
                report.error(f"exp_curve.{level}: exp_to_next({exp_to_next})는 만렙({max_level}) 미만 레벨에서 반드시 >0")
            if exp_to_next < prev_exp_to_next:
                report.error(
                    f"exp_curve.{level}: exp_to_next({exp_to_next})가 이전 레벨({prev_exp_to_next})보다 작음 "
                    "— 단조 비감소 위반"
                )
            prev_exp_to_next = exp_to_next
        for required_col in ("hp_bonus", "atk_bonus"):
            if required_col not in row:
                report.error(f"exp_curve.{level}: 필수 키 누락 '{required_col}'")

        # M4-0(§7-8): stat_points_gain — 레벨1은 캐릭터 생성 시 지급 없음(0), 그 외에는
        # 체증(레벨 구간이 오를수록 지급량이 줄어들면 안 됨)만 검사한다(같은 지급량이
        # 여러 레벨 이어지는 건 스펙 §2 표대로 정상 — 10레벨 구간마다 +1이라 완전한
        # 단조 "증가"가 아니라 "비감소"가 규칙).
        if "stat_points_gain" not in row:
            report.error(f"exp_curve.{level}: 필수 키 누락 'stat_points_gain'(M4-0)")
        else:
            gain = int(row["stat_points_gain"])
            if level == 1 and gain != 0:
                report.error(f"exp_curve.1: stat_points_gain={gain} 는 캐릭터 생성 레벨이라 0이어야 함")
            if gain < 0:
                report.error(f"exp_curve.{level}: stat_points_gain={gain} 는 0 이상이어야 함")
            if level > 1 and gain < prev_stat_points_gain:
                report.error(
                    f"exp_curve.{level}: stat_points_gain({gain})이 이전 레벨({prev_stat_points_gain})보다 작음 "
                    "— 체증 곡선은 감소하면 안 됨"
                )
            prev_stat_points_gain = gain
            total_stat_points += gain
    row_count = len(entries(exp_curve))
    if row_count != max_level:
        report.error(f"exp_curve: 행 수={row_count}, max_level({max_level})과 달라야 할 이유 없음(정확히 일치해야 함)")
    return total_stat_points
