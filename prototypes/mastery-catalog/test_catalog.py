import copy
import json
import unittest
from unittest.mock import patch
import server


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = server.catalog()

    def test_current_counts(self):
        self.assertEqual(len(self.data["masteries"]["masteries"]), 8)
        nodes = [n for m in self.data["masteries"]["masteries"] for n in m["nodes"]]
        self.assertEqual(len(nodes), 96)
        self.assertEqual(len(self.data["hybrids"]["classes"]), 28)
        self.assertEqual(len(nodes) + len(self.data["hybrids"]["classes"]), 124)

    def invalid(self, mutate):
        masters, hybrids = copy.deepcopy(self.data["masteries"]), copy.deepcopy(self.data["hybrids"])
        mutate(masters, hybrids)
        self.assertTrue(server.validator.validate(masters, hybrids)[0])

    def test_missing_prerequisite(self):
        self.invalid(lambda m, h: m["masteries"][0]["nodes"][0].update(requires_all=["missing"]))

    def test_cycle(self):
        self.invalid(lambda m, h: m["masteries"][0]["nodes"][0].update(requires_all=[m["masteries"][0]["nodes"][0]["id"]]))

    def test_duplicate_node(self):
        self.invalid(lambda m, h: m["masteries"][0]["nodes"][1].update(id=m["masteries"][0]["nodes"][0]["id"]))

    def test_missing_class(self):
        self.invalid(lambda m, h: h["classes"].pop())

    def test_broken_example_link(self):
        self.invalid(lambda m, h: h["classes"][0]["example"].update(active_slots=["missing","missing2"]))

    def test_draft_status_required(self):
        self.invalid(lambda m, h: m.update(status="runtime_approved"))

    def test_broken_modifier(self):
        self.invalid(lambda m, h: next(n for n in m["masteries"][0]["nodes"] if n["type"] == "modifier").update(modifies="missing"))

    def test_broken_mastery_pair(self):
        self.invalid(lambda m, h: h["classes"][0].update(masteries=["blade", "missing"]))

    def test_api_fails_closed(self):
        with patch.object(server, "catalog", side_effect=ValueError("invalid fixture")):
            status, _, body = server.route("/api/catalog")
            self.assertEqual(status, 422)
            self.assertIn("error", json.loads(body))

    def test_allowed_routes(self):
        for path in ("/", "/app.js", "/style.css", "/api/catalog"):
            status, _, body = server.route(path)
            self.assertEqual(status, 200)
            self.assertTrue(body)
        self.assertEqual(json.loads(server.route("/api/catalog")[2])["status"], "design_draft_not_runtime")

    def test_route_escape_and_unlisted(self):
        for path in ("/../game/project.godot", "/%2e%2e/game/project.godot", "/server.py", "/game/project.godot", "/C:/Windows/win.ini", "/api/catalog/../server.py"):
            self.assertEqual(server.route(path)[0], 404)

    def test_build_counts_and_boundaries(self):
        self.assertEqual(len(self.data["builds"]["scenarios"]), 12)
        self.assertEqual(self.data["build_validation"]["checklist_cases"], 60)
        self.assertFalse(self.data["build_validation"]["runtime_simulated"])
        self.assertFalse(self.data["build_validation"]["sp_budget_validated"])
        self.assertEqual(len(self.data["sources"]), 3)
        for source in self.data["sources"]:
            self.assertEqual(source["sha256"], server.hashlib.sha256((server.REPO / source["path"]).read_bytes()).hexdigest())

    def invalid_build(self, mutate):
        draft = copy.deepcopy(self.data["builds"])
        mutate(draft["scenarios"][0])
        self.assertTrue(server.build_validator.validate(draft, server.build_validator.read_sources())[0])

    def test_build_missing_node(self):
        self.invalid_build(lambda s: s["learning_order"].append("missing"))

    def test_build_reversed_prerequisites(self):
        self.invalid_build(lambda s: s["learning_order"].reverse())

    def test_build_extra_slot(self):
        self.invalid_build(lambda s: s["active_slots"].append(s["active_slots"][0]))

    def test_build_modifier_mismatch(self):
        self.invalid_build(lambda s: s["active_slots"][0].update(modifier=s["active_slots"][1]["modifier"]))

    def test_build_no_raw_route(self):
        self.assertEqual(server.route("/build-scenarios-v1.json")[0], 404)

    def test_build_validation_failure_blocks_api(self):
        with patch.object(server.build_validator, "validate", return_value=(["broken build"], {})):
            self.assertEqual(server.route("/api/catalog")[0], 422)


if __name__ == "__main__":
    unittest.main()
