#!/usr/bin/env python3
"""M2 아이템/드랍/정예/파밍 소스/스탯 테이블 검증 스크립트.

game/data/{items,affixes,drop_tables,enhance,monsters,farming_sources,stats}.json 을
읽어 docs/specs/data_tables.md·items-and-drops-m2.md §6·elite-and-farming-m2.md §4의
검증 규칙을 확인한다. game/scripts/core/data.gd가 런타임(Godot 부팅 시)에 동일한
규칙을 이식해 두고 있지만, 이 스크립트는 Godot 없이도(CI 등) 빠르게 돌릴 수 있는
오프라인 게이트다 — 두 곳의 규칙은 항상 같이 갱신할 것.

종료 코드: 0 = 통과, 1 = 하나 이상 위반.
사용법: python3 tools/qa/validate_tables.py [--data-dir game/data]
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any, Dict, List

ITEM_GRADES = ["common", "uncommon", "rare", "epic", "legendary", "relic"]
AFFIX_SLOT_BY_GRADE = {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 3, "relic": 3}
ITEM_CATEGORIES = {
    "weapon", "sub", "head", "armor", "boots", "ring", "amulet",
    "costume_hat", "costume_outfit", "costume_backpack",
    "consumable", "material",
}
EQUIP_CATEGORIES = {"weapon", "sub", "head", "armor", "boots", "ring", "amulet"}
DEX_ROLL_COST_FORMULA_CANONICAL = "cost * (1 - min(0.5, DEX/300))"
FARMING_TYPE_RESPAWN_SECONDS = {
    "field": 0, "gathering": 0, "treasure_map": 0, "region_dungeon": 0,
    "elite": 1800, "mini_dungeon": 86400, "world_boss": 259200,
}
FARMING_MAP_ICON_TYPES = {"elite", "world_boss"}
EPS = 1e-6


class Report:
    def __init__(self) -> None:
        self.errors: List[str] = []
        self.warnings: List[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def ok(self) -> bool:
        return not self.errors


def load_json(path: Path, report: Report) -> Dict[str, Any]:
    if not path.exists():
        report.error(f"파일 없음: {path}")
        return {}
    try:
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        report.error(f"JSON 파싱 실패: {path}: {e}")
        return {}


def entries(table: Dict[str, Any]) -> Dict[str, Any]:
    """밑줄(_)로 시작하는 메타 키(_comment 등)를 제외한 실제 데이터 항목만."""
    return {k: v for k, v in table.items() if not k.startswith("_")}


def validate_items(items: Dict[str, Any], report: Report) -> Dict[str, Any]:
    data = entries(items)
    for item_id, item in data.items():
        for field in ("item_id", "category", "grade", "sell_price"):
            if field not in item:
                report.error(f"items.{item_id}: 필수 키 누락 '{field}'")
        if item.get("item_id") != item_id:
            report.error(f"items.{item_id}: item_id 필드값('{item.get('item_id')}')이 키와 불일치")
        category = item.get("category")
        if category is not None and category not in ITEM_CATEGORIES:
            report.error(f"items.{item_id}: category '{category}' 가 enum에 없음")
        grade = item.get("grade")
        if grade is not None and grade not in ITEM_GRADES:
            report.error(f"items.{item_id}: grade '{grade}' 가 enum에 없음")
        if category in EQUIP_CATEGORIES:
            if "affix_slot_count" not in item:
                report.error(f"items.{item_id}: 장비인데 affix_slot_count 없음")
            else:
                expected = AFFIX_SLOT_BY_GRADE.get(grade)
                if expected is not None and item["affix_slot_count"] != expected:
                    report.error(
                        f"items.{item_id}: affix_slot_count={item['affix_slot_count']} "
                        f"!= grade '{grade}' 규칙값({expected})"
                    )
        if item.get("unique_skill_id") not in (None,) and grade != "legendary":
            report.error(f"items.{item_id}: unique_skill_id가 있으면 grade는 legendary여야 함 (현재 {grade})")
        if item.get("set_id") not in (None,) and grade != "relic":
            report.error(f"items.{item_id}: set_id가 있으면 grade는 relic이어야 함 (현재 {grade})")
        if item.get("sell_price", 0) is not None and item.get("sell_price", 0) < 0:
            report.error(f"items.{item_id}: sell_price는 0 이상이어야 함")
        if "base_stats" in item:
            for k, v in item["base_stats"].items():
                if k.endswith("_min"):
                    max_key = k[: -len("_min")] + "_max"
                    if max_key in item["base_stats"] and v > item["base_stats"][max_key]:
                        report.error(f"items.{item_id}: base_stats.{k}({v}) > {max_key}({item['base_stats'][max_key]})")
    return data


def validate_affixes(affixes: Dict[str, Any], item_ids: Dict[str, Any], report: Report) -> Dict[str, Any]:
    data = entries(affixes)
    stat_types = set()
    for affix_id, affix in data.items():
        for field in ("affix_id", "stat_type", "value_min", "value_max", "applicable_categories", "weight"):
            if field not in affix:
                report.error(f"affixes.{affix_id}: 필수 키 누락 '{field}'")
                continue
        if affix.get("affix_id") != affix_id:
            report.error(f"affixes.{affix_id}: affix_id 필드값이 키와 불일치")
        if "value_min" in affix and "value_max" in affix and affix["value_min"] > affix["value_max"]:
            report.error(f"affixes.{affix_id}: value_min({affix['value_min']}) > value_max({affix['value_max']})")
        if affix.get("weight", 0) <= 0:
            report.error(f"affixes.{affix_id}: weight는 0보다 커야 함 (현재 {affix.get('weight')})")
        for cat in affix.get("applicable_categories", []):
            if cat not in ITEM_CATEGORIES:
                report.error(f"affixes.{affix_id}: applicable_categories의 '{cat}' 가 items 카테고리 enum에 없음")
        stat_types.add(affix.get("stat_type"))
    if len(stat_types) < 20:
        report.error(f"affixes: stat_type 종류가 {len(stat_types)}개 (GDD 6.3 '20종' 미달)")
    return data


def validate_drop_tables(drop_tables: Dict[str, Any], item_ids: Dict[str, Any], report: Report) -> Dict[str, Any]:
    if "_luck_formula" not in drop_tables:
        report.error("drop_tables: 최상단 '_luck_formula' 필드 없음 (D-52 단일 소스 위반)")
    else:
        luk = drop_tables["_luck_formula"]
        coeff = luk.get("luk_coefficient", {})
        for grade in ITEM_GRADES:
            if grade == "common":
                continue
            if grade not in coeff:
                report.error(f"drop_tables._luck_formula.luk_coefficient: '{grade}' 계수 없음")
            elif coeff[grade] <= 0:
                report.error(f"drop_tables._luck_formula.luk_coefficient.{grade}: 0보다 커야 함")
        # 등급이 높을수록 계수가 커야 함(문서 규칙)
        ordered = [g for g in ITEM_GRADES if g != "common" and g in coeff]
        for a, b in zip(ordered, ordered[1:]):
            if coeff[a] >= coeff[b]:
                report.error(f"drop_tables._luck_formula.luk_coefficient: {a}({coeff[a]}) >= {b}({coeff[b]}) - 등급이 높을수록 커야 함")

    data = entries(drop_tables)
    data.pop("_luck_formula", None)
    for source_id, table in data.items():
        if table.get("source_id") != source_id:
            report.error(f"drop_tables.{source_id}: source_id 필드값이 키와 불일치")
        gbw = table.get("grade_base_weight")
        if gbw is None:
            report.error(f"drop_tables.{source_id}: grade_base_weight 없음")
        else:
            missing = [g for g in ITEM_GRADES if g not in gbw]
            if missing:
                report.error(f"drop_tables.{source_id}: grade_base_weight에 등급 누락 {missing}")
            total = sum(gbw.get(g, 0) for g in ITEM_GRADES)
            if abs(total - 1.0) > EPS:
                report.error(f"drop_tables.{source_id}: grade_base_weight 합계={total} (1.0이어야 함)")
        for entry in table.get("entries", []):
            item_id = entry.get("item_id")
            if item_id not in item_ids:
                report.error(f"drop_tables.{source_id}: entries의 item_id '{item_id}' 가 items.json에 없음")
            if entry.get("weight", 0) <= 0:
                report.error(f"drop_tables.{source_id}: entries[{item_id}].weight는 0보다 커야 함")
            qmin, qmax = entry.get("qty_min"), entry.get("qty_max")
            if qmin is not None and qmax is not None and qmin > qmax:
                report.error(f"drop_tables.{source_id}: entries[{item_id}] qty_min({qmin}) > qty_max({qmax})")
        gold = table.get("gold_drop")
        if gold is not None:
            if gold.get("min", 0) > gold.get("max", 0):
                report.error(f"drop_tables.{source_id}: gold_drop.min > gold_drop.max")
            if gold.get("min", 0) < 0:
                report.error(f"drop_tables.{source_id}: gold_drop.min < 0")
        # 아이템이 아직 없는 등급(예: M2 범위 밖 epic+)에 0이 아닌 가중치를 줬는데
        # 해당 등급 아이템이 entries에 하나도 없으면 드랍 시 참조가 빈다.
        if gbw:
            grade_of = {iid: it.get("grade") for iid, it in item_ids.items()}
            covered_grades = {grade_of.get(e.get("item_id")) for e in table.get("entries", [])}
            for grade in ITEM_GRADES:
                if gbw.get(grade, 0) > 0 and grade not in covered_grades:
                    report.error(
                        f"drop_tables.{source_id}: grade_base_weight.{grade}>0 인데 "
                        f"entries에 해당 등급 아이템이 하나도 없음(드랍 시 빈 풀)"
                    )
    return data


def validate_enhance(enhance: Dict[str, Any], report: Report) -> None:
    levels = enhance.get("enhance_levels", {})
    expected_full_success = ["+1", "+2", "+3", "+4", "+5", "+6"]
    expected_rates = {"+7": 0.70, "+8": 0.55, "+9": 0.40, "+10": 0.25}
    for lv in expected_full_success:
        rate = levels.get(lv, {}).get("success_rate")
        if rate != 1.0:
            report.error(f"enhance.enhance_levels.{lv}.success_rate={rate} (D-14: +1~+6은 1.0이어야 함)")
    for lv, expected in expected_rates.items():
        rate = levels.get(lv, {}).get("success_rate")
        if rate != expected:
            report.error(f"enhance.enhance_levels.{lv}.success_rate={rate} (D-14 고정값 {expected} 위반)")
    prev_mult = 0.0
    for lv in ["+1", "+2", "+3", "+4", "+5", "+6", "+7", "+8", "+9", "+10"]:
        entry = levels.get(lv)
        if entry is None:
            report.error(f"enhance.enhance_levels: '{lv}' 단계 없음")
            continue
        mult = entry.get("stat_multiplier", 0)
        if mult <= prev_mult:
            report.error(f"enhance.enhance_levels.{lv}.stat_multiplier={mult} 가 이전 단계({prev_mult}) 이하 - 단조증가 위반")
        prev_mult = mult

    refine = enhance.get("refine", {})
    if refine.get("max_attempts") != 3:
        report.error(f"enhance.refine.max_attempts={refine.get('max_attempts')} (D-13: 3이어야 함)")
    if "common" in refine.get("cost_by_grade_and_attempt", {}):
        report.error("enhance.refine.cost_by_grade_and_attempt: 'common'은 affix_slot_count=0이라 재련 대상이 아님")

    yields = enhance.get("disassemble", {}).get("yield_by_grade", {})
    prev_stone, prev_mat = -1, -1
    for grade in ITEM_GRADES:
        y = yields.get(grade)
        if y is None:
            report.error(f"enhance.disassemble.yield_by_grade: '{grade}' 없음")
            continue
        if y.get("stone_qty", 0) <= prev_stone:
            report.error(f"enhance.disassemble.yield_by_grade.{grade}.stone_qty가 이전 등급 이하 - 단조증가 위반")
        if y.get("material_qty", 0) <= prev_mat:
            report.error(f"enhance.disassemble.yield_by_grade.{grade}.material_qty가 이전 등급 이하 - 단조증가 위반")
        prev_stone, prev_mat = y.get("stone_qty", 0), y.get("material_qty", 0)


def validate_stats(stats: Dict[str, Any], report: Report) -> None:
    """elite-and-farming-m2.md §4-3 규칙 1~3 (규칙4는 코드 리뷰 항목, 런타임/오프라인
    검증 불가)."""
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

    max_points = float(stats.get("stat_points_per_levelup", 3)) * float(int(stats.get("max_level", 50)) - 1)
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


def validate_farming_sources(
    farming_sources: Dict[str, Any], drop_table_ids: Dict[str, Any], monsters: Dict[str, Any], report: Report
) -> None:
    """elite-and-farming-m2.md §4-2 규칙 1~4."""
    data = entries(farming_sources)
    for source_id, entry in data.items():
        type_ = entry.get("type")
        respawn = entry.get("respawn_seconds", -1)
        if respawn < 0:
            report.error(f"farming_sources.{source_id}: respawn_seconds는 0 이상이어야 함 (현재 {respawn})")
        if type_ in FARMING_TYPE_RESPAWN_SECONDS and respawn != FARMING_TYPE_RESPAWN_SECONDS[type_]:
            report.error(
                f"farming_sources.{source_id}: type='{type_}'의 respawn_seconds={respawn} 가 "
                f"GDD 6.5 기준값({FARMING_TYPE_RESPAWN_SECONDS[type_]})과 다름"
            )

        for list_field in ("first_clear_reward_table_ids", "repeat_reward_table_ids"):
            for ref_id in entry.get(list_field, []):
                if ref_id not in drop_table_ids:
                    report.error(f"farming_sources.{source_id}.{list_field}: '{ref_id}' 가 drop_tables.json에 없음")

        if type_ == "elite":
            repeat_ids = entry.get("repeat_reward_table_ids", [])
            expected_drop_table = repeat_ids[0] if repeat_ids else ""
            found = any(
                m.get("tier") == "elite" and m.get("drop_table_id") == expected_drop_table
                for m in entries(monsters).values()
            )
            if not found:
                report.error(
                    f"farming_sources.{source_id}: type=elite인데 tier='elite'·"
                    f"drop_table_id='{expected_drop_table}'인 monsters.json 엔트리가 없음"
                )

        show_icon = bool(entry.get("show_respawn_icon_on_map", False))
        expected_icon = type_ in FARMING_MAP_ICON_TYPES
        if show_icon != expected_icon:
            report.error(
                f"farming_sources.{source_id}: show_respawn_icon_on_map={show_icon} 가 "
                f"type='{type_}' 기준({expected_icon})과 다름"
            )


def validate_blueprints(blueprints: Dict[str, Any], item_ids: Dict[str, Any], report: Report) -> Dict[str, Any]:
    """F3-4, M2-4 신설. result_item_id·materials[].item_id 참조 무결성, cost_gold/qty 범위."""
    data = entries(blueprints)
    for blueprint_id, bp in data.items():
        for field in ("blueprint_id", "name_key", "desc_key", "result_item_id", "cost_gold", "materials"):
            if field not in bp:
                report.error(f"blueprints.{blueprint_id}: 필수 키 누락 '{field}'")
        if bp.get("blueprint_id") != blueprint_id:
            report.error(f"blueprints.{blueprint_id}: blueprint_id 필드값이 키와 불일치")
        result_item_id = bp.get("result_item_id")
        if result_item_id is not None and result_item_id not in item_ids:
            report.error(f"blueprints.{blueprint_id}: result_item_id '{result_item_id}' 가 items.json에 없음")
        if bp.get("cost_gold", 0) < 0:
            report.error(f"blueprints.{blueprint_id}: cost_gold는 0 이상이어야 함")
        for material in bp.get("materials", []):
            mat_id = material.get("item_id")
            if mat_id not in item_ids:
                report.error(f"blueprints.{blueprint_id}: materials의 item_id '{mat_id}' 가 items.json에 없음")
            if material.get("qty", 0) <= 0:
                report.error(f"blueprints.{blueprint_id}: materials[{mat_id}].qty는 0보다 커야 함")
    return data


def validate_monsters_cross_ref(monsters: Dict[str, Any], drop_table_ids: Dict[str, Any], report: Report) -> None:
    data = entries(monsters)
    for monster_id, monster in data.items():
        dt_id = monster.get("drop_table_id")
        if dt_id is None:
            continue  # null 허용(확정된 드랍 없음)
        if dt_id not in drop_table_ids:
            report.error(f"monsters.{monster_id}: drop_table_id '{dt_id}' 가 drop_tables.json에 없음 (D-67 위반)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", default=None, help="game/data 경로 (기본: 이 스크립트 기준 ../../game/data)")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    data_dir = Path(args.data_dir) if args.data_dir else (script_dir / ".." / ".." / "game" / "data")
    data_dir = data_dir.resolve()

    report = Report()
    print(f"[validate_tables] data dir = {data_dir}")

    items = load_json(data_dir / "items.json", report)
    affixes = load_json(data_dir / "affixes.json", report)
    drop_tables = load_json(data_dir / "drop_tables.json", report)
    enhance = load_json(data_dir / "enhance.json", report)
    monsters = load_json(data_dir / "monsters.json", report)
    farming_sources = load_json(data_dir / "farming_sources.json", report)
    stats = load_json(data_dir / "stats.json", report)
    blueprints = load_json(data_dir / "blueprints.json", report)

    item_ids = validate_items(items, report)
    validate_affixes(affixes, item_ids, report)
    drop_table_ids = validate_drop_tables(drop_tables, item_ids, report)
    validate_enhance(enhance, report)
    validate_monsters_cross_ref(monsters, drop_table_ids, report)
    validate_stats(stats, report)
    validate_farming_sources(farming_sources, drop_table_ids, monsters, report)
    blueprint_ids = validate_blueprints(blueprints, item_ids, report)

    print(f"[validate_tables] items={len(item_ids)} affixes={len(entries(affixes))} "
          f"drop_tables={len(drop_table_ids)} monsters={len(entries(monsters))} "
          f"farming_sources={len(entries(farming_sources))} blueprints={len(blueprint_ids)}")

    if report.warnings:
        print(f"\n경고 {len(report.warnings)}건:")
        for w in report.warnings:
            print(f"  - {w}")

    if report.errors:
        print(f"\n오류 {len(report.errors)}건:")
        for e in report.errors:
            print(f"  - {e}")
        print("\nFAIL")
        return 1

    print("\nPASS - 모든 검증 규칙 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
