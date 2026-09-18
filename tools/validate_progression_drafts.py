"""Structural validation only; never changes runtime data or checks SP balance."""
import argparse
from collections import Counter
from itertools import combinations
import json
from pathlib import Path


def validate(master_document, hybrid_document):
    errors = []

    def require(condition, message):
        if not condition:
            errors.append(message)

    def fields(obj, names, location):
        for name in names:
            value = obj.get(name)
            require(isinstance(value, str) and bool(value.strip()),
                    f"{location}: empty/invalid {name}")

    def strings(obj, name, location, nonempty=False):
        value = obj.get(name)
        valid = (isinstance(value, list)
                 and all(isinstance(x, str) and x.strip() for x in value))
        require(valid and (bool(value) or not nonempty), f"{location}: invalid {name}")
        return value if valid else []

    if not isinstance(master_document, dict) or not isinstance(hybrid_document, dict):
        return ["documents must be objects"], {}
    for document in (master_document, hybrid_document):
        require(document.get("status") == "design_draft_not_runtime", "invalid draft status")
    policy = master_document.get("policy")
    expected_policy = dict(active_masteries=2, active_slots=2,
                           max_modifiers_per_active=1, runtime_changes=False)
    require(isinstance(policy, dict), "missing/invalid policy")
    for key, value in expected_policy.items():
        actual = policy.get(key) if isinstance(policy, dict) else None
        require(type(actual) is type(value) and actual == value,
                f"policy: invalid {key}")
    masters = master_document.get("masteries")
    classes = hybrid_document.get("classes")
    if not isinstance(masters, list) or not isinstance(classes, list):
        return errors + ["masteries/classes must be lists"], {}
    require(len(masters) == 8, "expected 8 masteries")
    require(len(classes) == 28, "expected 28 hybrid classes")
    all_ids, master_ids, nodes, owners, requirements = set(), set(), {}, {}, {}

    def unique(obj, location):
        fields(obj, ["id"], location)
        identifier = obj.get("id")
        if not isinstance(identifier, str) or not identifier.strip():
            return None
        require(identifier not in all_ids, f"duplicate id: {identifier}")
        all_ids.add(identifier)
        return identifier

    for index, master in enumerate(masters):
        if not isinstance(master, dict):
            errors.append(f"mastery {index}: must be object")
            continue
        mid = unique(master, f"mastery {index}")
        fields(master, ["name", "pure_class"], str(mid))
        if mid:
            master_ids.add(mid)
        entries = master.get("nodes")
        if not isinstance(entries, list):
            errors.append(f"{mid}: nodes must be list")
            continue
        require(len(entries) == 12, f"{mid}: expected 12 nodes")
        kinds = Counter()
        for entry in entries:
            if not isinstance(entry, dict):
                errors.append(f"{mid}: node must be object")
                continue
            nid = unique(entry, str(mid))
            fields(entry, ["name", "type", "effect", "tradeoff", "animation"], str(nid))
            kind = entry.get("type")
            if isinstance(kind, str):
                kinds[kind] += 1
            tier = entry.get("tier")
            require(type(tier) is int and 1 <= tier <= 4, f"{nid}: invalid tier")
            deps = strings(entry, "requires_all", str(nid))
            require(len(deps) == len(set(deps)), f"{nid}: duplicate dependency")
            strings(entry, "tags", str(nid), True)
            strings(entry, "equipment", str(nid), True)
            if nid:
                nodes[nid], owners[nid], requirements[nid] = entry, mid, deps
        require(kinds == Counter(active=4, modifier=4, passive=3, keystone=1),
                f"{mid}: expected 4 active/4 modifier/3 passive/1 keystone")

    for nid, deps in requirements.items():
        for dep in deps:
            require(dep in nodes, f"{nid}: missing reference {dep}")
            if dep in nodes:
                require(owners[dep] == owners[nid], f"{nid}: cross-mastery dependency {dep}")
                a, b = nodes[dep].get("tier"), nodes[nid].get("tier")
                if type(a) is int and type(b) is int:
                    require(a <= b, f"{nid}: tier inversion from {dep}")

    reached = set()
    while True:
        ready = {nid for nid, deps in requirements.items() if set(deps) <= reached}
        added = ready - reached
        if not added:
            break
        reached.update(added)
    for nid in nodes.keys() - reached:
        errors.append(f"{nid}: unreachable from roots")
    for mid in master_ids:
        available = [nodes[nid] for nid in reached if owners[nid] == mid]
        require(any(n.get("tier") == 1 and n.get("type") == "active" for n in available),
                f"{mid}: no reachable tier1 active")
        require(any(n.get("tier") == 2 for n in available),
                f"{mid}: no reachable tier2 node")

    visiting, done = set(), set()

    def visit(nid):
        if nid in visiting:
            errors.append(f"cycle at {nid}")
            return
        if nid in done or nid not in nodes:
            return
        visiting.add(nid)
        for dep in requirements[nid]:
            visit(dep)
        visiting.remove(nid)
        done.add(nid)

    for nid in nodes:
        visit(nid)
        if nodes[nid].get("type") != "modifier":
            continue
        target = nodes[nid].get("modifies")
        require(isinstance(target, str) and target in nodes,
                f"{nid}: missing/invalid modifier target")
        if not isinstance(target, str) or target not in nodes:
            continue
        require(nodes[target].get("type") == "active", f"{nid}: modifier target not active")
        require(owners[target] == owners[nid], f"{nid}: modifier target cross-mastery")
        ancestors, pending = set(), list(requirements[nid])
        while pending:
            dep = pending.pop()
            if dep in ancestors:
                continue
            ancestors.add(dep)
            pending.extend(requirements.get(dep, []))
        require(target in ancestors and target in reached,
                f"{nid}: modifier target not reachable prerequisite")

    pairs = Counter()
    signature_count = 0
    for index, entry in enumerate(classes):
        if not isinstance(entry, dict):
            errors.append(f"class {index}: must be object")
            continue
        cid = unique(entry, f"class {index}")
        fields(entry, ["name", "play_pattern", "equipment_note"], str(cid))
        pair = strings(entry, "masteries", str(cid), True)
        valid_pair = len(pair) == 2 and len(set(pair)) == 2 and set(pair) <= master_ids
        require(valid_pair, f"{cid}: illegal mastery pair")
        if valid_pair:
            pairs[tuple(sorted(pair))] += 1
        example = entry.get("example")
        if not isinstance(example, dict):
            errors.append(f"{cid}: example must be object")
        else:
            fields(example, ["equipment", "sequence", "status"], str(cid))
            require(example.get("status") in (
                "requires_runtime_implementation", "requires_weapon_swap_system"),
                f"{cid}: invalid example status")
            slots = strings(example, "active_slots", str(cid), True)
            require(len(slots) == 2 and len(set(slots)) == 2,
                    f"{cid}: example requires 2 distinct active slots")
            for slot in slots:
                require(slot in nodes, f"{cid}: unknown example active {slot}")
                if slot in nodes:
                    require(nodes[slot].get("type") == "active",
                            f"{cid}: example node not active {slot}")
                    require(owners[slot] in pair,
                            f"{cid}: example active wrong mastery {slot}")
        signature = entry.get("signature")
        if not isinstance(signature, dict):
            errors.append(f"{cid}: signature must be object")
            continue
        signature_count += 1
        unique(signature, str(cid))
        fields(signature, ["name", "trigger", "effect", "tradeoff", "anti_loop"], str(cid))
        strings(signature, "compatible_tags", str(cid), True)
    expected = set(combinations(sorted(master_ids), 2))
    require(set(pairs) == expected and all(n == 1 for n in pairs.values()),
            "unordered mastery pairs must cover 8 choose 2 exactly once")
    report = {"masteries": len(masters), "mastery_nodes": len(nodes),
              "active_nodes": sum(n.get("type") == "active" for n in nodes.values()),
              "hybrid_signatures": signature_count,
              "total_growth_nodes": len(nodes) + signature_count}
    return errors, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("masteries", type=Path)
    parser.add_argument("hybrids", type=Path)
    args = parser.parse_args()
    try:
        documents = [json.loads(p.read_text(encoding="utf-8-sig"))
                     for p in (args.masteries, args.hybrids)]
        errors, report = validate(*documents)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    for error in errors:
        print(f"ERROR: {error}")
    print("FAIL" if errors else "PASS (structure only; not runtime/SP/economy validation)")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
