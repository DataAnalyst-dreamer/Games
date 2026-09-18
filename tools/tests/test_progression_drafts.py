import copy
import json
from itertools import combinations
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_progression_drafts import validate


def fixture():
    masters = []
    for m in range(8):
        mid = f"master_{m}"
        nodes = []
        for j, kind in enumerate(["active"] * 4 + ["modifier"] * 4
                                 + ["passive"] * 3 + ["keystone"]):
            node = dict(id=f"{mid}_node_{j}", name="name", type=kind,
                        tier=1 if j < 4 else 2, requires_all=[], tags=["test"],
                        effect="effect", tradeoff="tradeoff", equipment=["any"],
                        animation="existing")
            if kind == "modifier":
                node["modifies"] = f"{mid}_node_{j - 4}"
                node["requires_all"] = [node["modifies"]]
            nodes.append(node)
        masters.append(dict(id=mid, name="master", pure_class="pure", nodes=nodes))
    classes = []
    for a, b in combinations(range(8), 2):
        classes.append(dict(id=f"class_{a}_{b}", name="class",
                            masteries=[f"master_{a}", f"master_{b}"],
                            signature=dict(id=f"signature_{a}_{b}", name="signature",
                                           trigger="trigger", effect="effect", tradeoff="cost",
                                           compatible_tags=["test"], anti_loop="once"),
                            play_pattern="pattern", equipment_note="note",
                            example=dict(active_slots=[f"master_{a}_node_0", f"master_{b}_node_0"],
                                         equipment="test", sequence="first then second",
                                         status="requires_runtime_implementation")))
    return dict(status="design_draft_not_runtime", masteries=masters,
                policy=dict(active_masteries=2, active_slots=2,
                            max_modifiers_per_active=1, runtime_changes=False)), dict(
        status="design_draft_not_runtime", classes=classes)


class ProgressionTests(unittest.TestCase):
    def setUp(self):
        self.m, self.h = copy.deepcopy(fixture())
        self.nodes = self.m["masteries"][0]["nodes"]

    def bad(self, fragment):
        errors, _ = validate(self.m, self.h)
        self.assertTrue(any(fragment in error for error in errors), errors)

    def test_valid(self):
        errors, report = validate(self.m, self.h)
        self.assertEqual(errors, [])
        self.assertEqual(report["total_growth_nodes"], 124)
        self.assertEqual(report["active_nodes"], 32)

    def test_duplicate_id(self):
        self.nodes[1]["id"] = self.nodes[0]["id"]
        self.bad("duplicate id")

    def test_cycle(self):
        self.nodes[0]["requires_all"] = [self.nodes[1]["id"]]
        self.nodes[1]["requires_all"] = [self.nodes[0]["id"]]
        self.bad("cycle")
        self.bad("unreachable")

    def test_missing_reference(self):
        self.nodes[0]["requires_all"] = ["missing"]
        self.bad("missing reference")

    def test_illegal_pair(self):
        self.h["classes"][0]["masteries"] = ["master_0", "master_0"]
        self.bad("illegal mastery pair")

    def test_empty_field(self):
        self.nodes[0]["effect"] = "  "
        self.bad("empty/invalid effect")

    def test_modifier_wrong_type(self):
        self.nodes[4]["modifies"] = self.nodes[8]["id"]
        self.bad("target not active")

    def test_modifier_not_ancestor(self):
        self.nodes[4]["modifies"] = self.nodes[1]["id"]
        self.bad("not reachable prerequisite")

    def test_tier_inversion(self):
        self.nodes[0]["tier"] = 4
        self.bad("tier inversion")

    def test_cross_mastery_modifier(self):
        self.nodes[4]["modifies"] = "master_1_node_0"
        self.bad("target cross-mastery")

    def test_duplicate_pair(self):
        self.h["classes"][1]["masteries"] = list(reversed(self.h["classes"][0]["masteries"]))
        self.bad("exactly once")

    def test_duplicate_signature(self):
        self.h["classes"][1]["signature"]["id"] = self.h["classes"][0]["signature"]["id"]
        self.bad("duplicate id")

    def test_wrong_distribution(self):
        self.nodes[0]["type"] = "passive"
        self.bad("expected 4 active")

    def test_empty_equipment(self):
        self.nodes[0]["equipment"] = []
        self.bad("invalid equipment")

    def test_policy_mutations(self):
        for key, value in (("active_masteries", 3), ("active_slots", 3),
                           ("max_modifiers_per_active", 2), ("runtime_changes", True),
                           ("runtime_changes", 0)):
            with self.subTest(key=key, value=value):
                self.m, self.h = fixture()
                self.m["policy"][key] = value
                self.bad(f"policy: invalid {key}")

    def test_unknown_example_active(self):
        self.h["classes"][0]["example"]["active_slots"][0] = "missing"
        self.bad("unknown example active")

    def test_nonactive_example(self):
        self.h["classes"][0]["example"]["active_slots"][0] = "master_0_node_8"
        self.bad("example node not active")

    def test_wrongmastery_example(self):
        self.h["classes"][0]["example"]["active_slots"][0] = "master_7_node_0"
        self.bad("example active wrong mastery")

    def test_example_count(self):
        self.h["classes"][0]["example"]["active_slots"] = ["master_0_node_0"]
        self.bad("2 distinct active slots")

    def test_example_duplicate(self):
        self.h["classes"][0]["example"]["active_slots"] = ["master_0_node_0"] * 2
        self.bad("2 distinct active slots")

    def test_example_status(self):
        self.h["classes"][0]["example"]["status"] = "implemented"
        self.bad("invalid example status")

    def test_example_empty_sequence(self):
        self.h["classes"][0]["example"]["sequence"] = ""
        self.bad("empty/invalid sequence")

    def test_no_tier1_active(self):
        for node in self.nodes[:4]:
            node["tier"] = 2
        self.bad("no reachable tier1 active")

    def test_no_tier2_node(self):
        for node in self.nodes[4:]:
            node["tier"] = 3
        self.bad("no reachable tier2 node")

    def test_real_documents_when_present(self):
        folder = Path(__file__).resolve().parents[2] / "docs/content-drafts/research-expansion"
        paths = [folder / "mastery-nodes-v3.json", folder / "hybrid-classes-v3.json"]
        if not all(path.exists() for path in paths):
            self.skipTest("real draft documents not yet available")
        docs = [json.loads(path.read_text(encoding="utf-8-sig")) for path in paths]
        errors, report = validate(*docs)
        self.assertEqual(errors, [])
        self.assertEqual(report["total_growth_nodes"], 124)
        self.assertEqual(report["active_nodes"], 32)


if __name__ == "__main__":
    unittest.main()
