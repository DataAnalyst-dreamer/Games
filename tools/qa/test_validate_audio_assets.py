import copy
import unittest
from validate_audio_assets import GAME, call_audit, check_wave, load_json, unique_object, validate


class AudioAssetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sfx = load_json(GAME / "data/audio_sfx.json")
        cls.bgm = load_json(GAME / "data/audio_bgm.json")

    def test_real_assets(self):
        self.assertEqual(validate(self.sfx, self.bgm)[0], [])

    def test_invalid_fields(self):
        mutations = [{"bus": "missing"}, {"volume_db": float("nan")}, {"pitch_min": 2, "pitch_max": 1}, {"pitch_min": 0}, {"cooldown_sec": -1}, {"max_voices": 0}, {"max_voices": 17}, {"priority": 4}, {"files": []}, {"files": ["res://../outside.wav"]}, {"files": ["res://missing.wav"]}]
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                table = copy.deepcopy(self.sfx)
                table["atk_swing_1"].update(mutation)
                self.assertTrue(validate(table, self.bgm)[0])

    def test_missing_core_event(self):
        table = copy.deepcopy(self.sfx)
        del table["slime_attack"]
        self.assertTrue(validate(table, self.bgm)[0])

    def test_duplicate_json_key(self):
        with self.assertRaises(ValueError):
            unique_object([("id", 1), ("id", 2)])

    def test_corrupt_wav(self):
        self.assertIsNotNone(check_wave(b"not a wave"))

    def test_dynamic_drop_contract(self):
        audit = call_audit(self.sfx)
        self.assertTrue(audit["drop_contract_parsed"])
        self.assertEqual(len(audit["drop_ids"]), 6)
        self.assertEqual(audit["unmapped_drop_ids"], [])

    def test_unmapped_literal_detection(self):
        table = copy.deepcopy(self.sfx)
        del table["mailbox_claim_chime"]
        self.assertIn("mailbox_claim_chime", call_audit(table)["unmapped_literals"])


if __name__ == "__main__":
    unittest.main()
