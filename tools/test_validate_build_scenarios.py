"""Mutation checks are in memory; never edit catalog or game data."""
from copy import deepcopy
import json
import unittest

from validate_build_scenarios import DRAFT, read_sources, validate


class BuildScenarioValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = read_sources()
        cls.original = json.loads((DRAFT / "build-scenarios-v1.json").read_text(encoding="utf-8"))

    def setUp(self):
        self.doc = deepcopy(self.original)
        self.first = self.doc["scenarios"][0]

    def rejected(self, expected):
        errors, _ = validate(self.doc, self.sources)
        self.assertTrue(any(expected in e for e in errors), errors)

    def test_valid_catalog(self):
        errors, summary = validate(self.doc, self.sources)
        self.assertEqual(errors, [])
        self.assertEqual(summary["scenarios"], 12)
        self.assertEqual(summary["checklist_cases"], 60)
        self.assertFalse(summary["runtime_simulated"])

    def test_unknown_node(self):
        self.first["learning_order"].append("nonexistent_node")
        self.rejected("unknown node")

    def test_missing_parent(self):
        self.first["learning_order"].remove("v3_blade_measured_cut")
        self.rejected("prerequisite/order failure")

    def test_parent_after_child(self):
        self.first["learning_order"].reverse()
        self.rejected("prerequisite/order failure")

    def test_third_slot(self):
        self.first["active_slots"].append(deepcopy(self.first["active_slots"][0]))
        self.rejected("active slot limit")

    def test_passive_in_active_slot(self):
        self.first["active_slots"][0]["active"] = "v3_blade_read_distance"
        self.rejected("slot must use active node")

    def test_wrong_modifier_target(self):
        self.first["active_slots"][0]["modifier"] = "v3_guard_yield_brace"
        self.rejected("modifier target mismatch")

    def test_multiple_modifiers(self):
        self.first["active_slots"][0]["modifier"] = ["v3_blade_edge_stop", "v3_blade_wide_cross"]
        self.rejected("only one scalar ID")

    def test_unlearned_active(self):
        self.first["active_slots"][0]["active"] = "v3_blade_cross_cut"
        self.rejected("unlearned active")

    def test_wrong_class_signature(self):
        self.first["identity_trait"] = "v3_bridge_life_faith"
        self.rejected("matching signature")

    def test_missing_class_entry_tier(self):
        self.first["learning_order"].remove("v3_guard_yield_brace")
        self.first["active_slots"][1]["modifier"] = None
        self.rejected("missing tier2 entry qualification")

    def test_third_mastery(self):
        self.first["active_masteries"].append("life")
        self.rejected("active mastery limit")

    def test_missing_equipment(self):
        self.first["equipment_tags"] = ["방패"]
        self.rejected("equipment mismatch")

    def test_unknown_context_monster(self):
        self.first["context"]["monster_ids"] = ["invented_monster"]
        self.rejected("missing monsters ID")

    def test_unknown_context_material(self):
        self.first["context"]["material_ids"] = ["invented_material"]
        self.rejected("missing items ID")

    def test_unknown_context_location(self):
        self.first["context"]["location_ids"] = ["invented_location"]
        self.rejected("missing world ID")

    def test_unknown_draft_reference(self):
        self.first["context"]["draft_refs"] = ["SQH-NOT-REAL"]
        self.rejected("missing draft reference")

    def test_missing_negative_check(self):
        del self.first["checklist"][0]["reject"]
        self.rejected("missing reject")

    def test_duplicate_scenario(self):
        self.doc["scenarios"][1]["id"] = self.first["id"]
        self.rejected("duplicate scenario")

    def test_unapproved_runtime_claim(self):
        self.doc["policy_boundary"]["runtime_changes"] = True
        self.rejected("runtime changes prohibited")

    def test_false_sp_budget_approval(self):
        self.first["qualification"]["tier_point_budget"] = "approved"
        self.rejected("SP budget not validated")


if __name__ == "__main__":
    unittest.main()
