"""Read-only design-fixture validation. Does NOT simulate combat or approve SP budgets."""
import argparse
import json
from pathlib import Path

from validate_progression_drafts import validate as validate_sources

ROOT = Path(__file__).resolve().parents[1]
DRAFT = ROOT / "docs/content-drafts/research-expansion"


def read_sources():
    def read(path):
        return json.loads(path.read_text(encoding="utf-8-sig"))
    return {
        "master": read(DRAFT / "mastery-nodes-v3.json"),
        "hybrid": read(DRAFT / "hybrid-classes-v3.json"),
        "monsters": read(ROOT / "game/data/monsters.json"),
        "items": read(ROOT / "game/data/items.json"),
        "world": read(ROOT / "game/data/world_objects.json"),
        "draft_text": "\n".join((DRAFT / name).read_text(encoding="utf-8") for name in
                               ("monsters-items-v2.md", "story-quests-v2.md")),
    }


def validate(document, sources):
    errors, _source_summary = validate_sources(sources["master"], sources["hybrid"])
    errors = ["source: " + e for e in errors]

    def require(ok, message):
        if not ok:
            errors.append(message)

    def strings(value, label, nonempty=True):
        if not isinstance(value, list) or not all(isinstance(v, str) and v.strip() for v in value):
            errors.append(label + ": expected string list")
            return []
        require(not nonempty or bool(value), label + ": empty")
        require(len(value) == len(set(value)), label + ": duplicates")
        return value

    def text(obj, name, label):
        require(isinstance(obj.get(name), str) and bool(obj[name].strip()), label + ": missing " + name)

    if not isinstance(document, dict):
        return ["catalog must be object"], {}
    require(document.get("status") == "design_draft_not_runtime", "catalog draft status")
    boundary = document.get("policy_boundary", {})
    require(isinstance(boundary, dict), "policy_boundary must be object")
    if isinstance(boundary, dict):
        require(boundary.get("runtime_changes") is False, "runtime changes prohibited")
        require(boundary.get("draft_assumptions") == {
            "active_masteries": 2, "active_slots": 2,
            "max_modifiers_per_active": 1, "identity_traits": 1}, "draft policy mismatch")
    nodes, owner = {}, {}
    for mastery in sources["master"]["masteries"]:
        for node in mastery["nodes"]:
            nodes[node["id"]] = node
            owner[node["id"]] = mastery["id"]
    classes = {c["id"]: c for c in sources["hybrid"]["classes"]}
    scenarios = document.get("scenarios")
    if not isinstance(scenarios, list):
        return errors + ["scenarios must be list"], {}
    require(len(scenarios) >= 12, "at least 12 scenarios required")
    ids, class_ids, case_ids, coverage = set(), set(), set(), set()
    case_count = 0
    for i, s in enumerate(scenarios):
        label = f"scenario[{i}]"
        if not isinstance(s, dict):
            errors.append(label + ": expected object")
            continue
        for name in ("id", "title", "class_id", "class_name", "weakness", "basic_alternative", "equipment_note"):
            text(s, name, label)
        sid = s.get("id")
        if isinstance(sid, str):
            require(sid not in ids, "duplicate scenario " + sid)
            ids.add(sid)
            label = sid
        require(s.get("status") == "design_draft_not_runtime", label + ": runtime status")
        require(s.get("priority") in ("P1", "P2", "P3"), label + ": priority")
        mid = strings(s.get("active_masteries"), label + ": masteries")
        require(1 <= len(mid) <= 2, label + ": active mastery limit")
        coverage.update(mid)
        cid = s.get("class_id")
        cls = classes.get(cid) if isinstance(cid, str) else None
        require(cls is not None, label + ": unknown class")
        if cls:
            require(cid not in class_ids, label + ": class duplicates another build")
            class_ids.add(cid)
            require(set(mid) == set(cls["masteries"]), label + ": class/mastery mismatch")
            require(s.get("class_name") == cls["name"], label + ": class name mismatch")
            require(s.get("identity_trait") == cls["signature"]["id"], label + ": exactly matching signature required")
        order = strings(s.get("learning_order"), label + ": learning order")
        learned = set()
        for nid in order:
            node = nodes.get(nid)
            require(node is not None, label + ": unknown node " + nid)
            if node:
                require(owner[nid] in mid, label + ": inactive mastery node " + nid)
                require(set(node["requires_all"]) <= learned, label + ": prerequisite/order failure " + nid)
                require(node["type"] != "keystone", label + ": hybrid fixture cannot equip/stack pure keystone")
            learned.add(nid)
        for m in mid:
            learned_here = [nodes[n] for n in learned if n in nodes and owner[n] == m]
            require(any(n["type"] == "active" and n["tier"] == 1 for n in learned_here), label + ": missing tier1 active in " + m)
            require(any(n["tier"] == 2 for n in learned_here), label + ": missing tier2 entry qualification in " + m)
        qualification = s.get("qualification", {})
        require(isinstance(qualification, dict) and qualification.get("tier_point_budget") == "unresolved_not_validated", label + ": SP budget not validated")
        require(isinstance(qualification, dict) and qualification.get("advancement_task") == "assumed_completed_in_future_test_fixture_not_implemented", label + ": advancement fixture boundary")
        equipment = strings(s.get("equipment_tags"), label + ": equipment")
        require(not ("활" in equipment and "방패" in equipment), label + ": incompatible simultaneous bow/shield")
        slots = s.get("active_slots")
        if not isinstance(slots, list):
            errors.append(label + ": slots must be list")
            slots = []
        require(1 <= len(slots) <= 2, label + ": active slot limit")
        used_actives, used_mods = [], []
        for slot in slots:
            if not isinstance(slot, dict):
                errors.append(label + ": slot must be object")
                continue
            aid, modifier = slot.get("active"), slot.get("modifier")
            a = nodes.get(aid) if isinstance(aid, str) else None
            require(a is not None and a.get("type") == "active", label + ": slot must use active node")
            require(isinstance(aid, str) and aid in learned, label + ": unlearned active")
            if isinstance(aid, str): used_actives.append(aid)
            equipped = [a] if a else []
            if modifier is not None:
                mod = nodes.get(modifier) if isinstance(modifier, str) else None
                require(mod is not None and mod.get("type") == "modifier", label + ": invalid modifier (only one scalar ID allowed)")
                require(isinstance(modifier, str) and modifier in learned, label + ": unlearned modifier")
                if mod:
                    require(mod.get("modifies") == aid, label + ": modifier target mismatch")
                    equipped.append(mod)
                    used_mods.append(modifier)
            for entry in equipped:
                require(set(entry["equipment"]) - {"공통"} <= set(equipment), label + ": equipment mismatch for " + entry["id"])
        require(len(used_actives) == len(set(used_actives)), label + ": duplicate active slots")
        require(len(used_mods) == len(set(used_mods)), label + ": duplicate modifier")
        strings(s.get("implementation_needed"), label + ": implementation requirements")
        context = s.get("context")
        if not isinstance(context, dict):
            errors.append(label + ": missing context")
        else:
            require(context.get("placement_status") == "proposed_test_arrangement_not_current_spawn_claim", label + ": placement not approved")
            require(context.get("material_role") == "observation_or_inventory_reference_only_not_skill_cost", label + ": material must not become cost")
            for field, table in (("monster_ids", "monsters"), ("location_ids", "world"), ("material_ids", "items")):
                for key in strings(context.get(field), label + ": " + field):
                    require(key in sources[table] and not key.startswith("_"), label + ": missing " + table + " ID " + key)
                    if key in sources[table] and table == "world":
                        require(sources[table][key].get("kind") == "location", label + ": not a location")
                    if key in sources[table] and table == "items":
                        require(sources[table][key].get("category") == "material", label + ": not a material")
            for ref in strings(context.get("draft_refs"), label + ": draft refs"):
                require(ref in sources["draft_text"], label + ": missing draft reference " + ref)
        cases = s.get("checklist")
        if not isinstance(cases, list):
            errors.append(label + ": checklist must be list")
            continue
        require(len(cases) >= 5, label + ": at least five concrete checks")
        for case in cases:
            if not isinstance(case, dict):
                errors.append(label + ": invalid case")
                continue
            for field in ("id", "given", "action", "expected", "reject", "evidence"):
                text(case, field, label + ": case")
            key = case.get("id")
            if isinstance(key, str):
                require(key not in case_ids, label + ": duplicate case ID")
                case_ids.add(key)
            case_count += 1
    require(coverage == {m["id"] for m in sources["master"]["masteries"]}, "all 8 masteries must be covered")
    return errors, {"scenarios": len(scenarios), "distinct_hybrid_classes": len(class_ids),
                    "masteries": len(coverage), "checklist_cases": case_count,
                    "runtime_simulated": False, "sp_budget_validated": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DRAFT / "build-scenarios-v1.json")
    args = parser.parse_args()
    try:
        document = json.loads(args.catalog.read_text(encoding="utf-8-sig"))
        errors, summary = validate(document, read_sources())
    except (OSError, ValueError) as error:
        print("FAIL:", error)
        return 1
    print(json.dumps(summary, ensure_ascii=False))
    for error in errors:
        print("FAIL:", error)
    print("BUILD_SCENARIOS_RESULT:", "FAIL" if errors else "PASS")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
