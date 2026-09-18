import copy
import json
import unittest
from validate_quest_reactivity import DEFAULT, validate


class ReactivityValidation(unittest.TestCase):
    def setUp(self):
        self.doc = json.loads(DEFAULT.read_text(encoding="utf-8"))

    def test_actual_draft(self):
        self.assertEqual(validate(self.doc), [])

    def test_duplicate_rejected(self):
        self.doc["reactions"][1]["id"] = self.doc["reactions"][0]["id"]
        self.assertTrue(validate(self.doc))

    def test_reference_rejected(self):
        self.doc["reactions"][0]["source_code"] = "invented_runtime_quest"
        self.assertTrue(validate(self.doc))

    def test_state_rejected(self):
        self.doc["reactions"][0]["state"] = "paid"
        self.assertTrue(validate(self.doc))

    def test_width_budget_not_character_fiction(self):
        self.doc["reactions"][0]["lines"][0]["hud_short"] = "가" * 14
        self.assertTrue(validate(self.doc))

    def test_new_choice_rejected(self):
        self.doc["reactions"][0]["lines"].append(copy.deepcopy(self.doc["reactions"][0]["lines"][0]))
        self.assertTrue(validate(self.doc))

    def test_missing_anchor_rejected(self):
        self.doc["reactions"][0]["location_anchor"] = "new_town"
        self.assertTrue(validate(self.doc))


if __name__ == "__main__":
    unittest.main()
