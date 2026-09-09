#!/usr/bin/env python3
"""M2-0 아이템/드랍 테이블 검증 스크립트.

game/data/{items,affixes,drop_tables,enhance,monsters}.json 을 읽어
docs/specs/data_tables.md 의 검증 규칙(및 docs/specs/items-and-drops-m2.md
§6 검증 규칙)을 확인한다. godot-engineer의 data.gd REQUIRED_SCHEMA는 아직
items/affixes/drop_tables/enhance를 다루지 않으므로(문서 끝 "엔지니어
요청" 참고), 이 스크립트가 그 자리를 메우는 오프라인 게이트다.

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

    item_ids = validate_items(items, report)
    validate_affixes(affixes, item_ids, report)
    drop_table_ids = validate_drop_tables(drop_tables, item_ids, report)
    validate_enhance(enhance, report)
    validate_monsters_cross_ref(monsters, drop_table_ids, report)

    print(f"[validate_tables] items={len(item_ids)} affixes={len(entries(affixes))} "
          f"drop_tables={len(drop_table_ids)} monsters={len(entries(monsters))}")

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
