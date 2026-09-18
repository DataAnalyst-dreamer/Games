"""Read-only audio asset/schema audit; no playback, synthesis, import, or mix approval."""
import io
import json
import math
import re
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"


def unique_object(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise ValueError("duplicate JSON key: " + key)
        out[key] = value
    return out


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique_object)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def check_wave(blob):
    try:
        with wave.open(io.BytesIO(blob), "rb") as stream:
            channels, width, rate, frames = stream.getnchannels(), stream.getsampwidth(), stream.getframerate(), stream.getnframes()
            if stream.getcomptype() != "NONE" or channels not in (1, 2) or width not in (1, 2, 3, 4) or rate <= 0 or frames <= 0:
                return "invalid PCM WAV format"
            if len(stream.readframes(frames)) != frames * channels * width:
                return "truncated PCM data"
    except (wave.Error, EOFError):
        return "invalid WAV header"
    return None


def validate(sfx, bgm, game=GAME):
    errors, references = [], []
    def require(ok, why):
        if not ok:
            errors.append(why)
    buses = {"Master"} | set(re.findall(r'bus/\d+/name = &"([^"]+)"', (game / "default_bus_layout.tres").read_text(encoding="utf-8")))
    for table_name, table in (("SFX", sfx), ("BGM", bgm)):
        for ident, entry in table.items():
            if ident.startswith("_"):
                continue
            require(bool(re.fullmatch(r"[a-z][a-z0-9_]*", ident)), "invalid event ID: " + ident)
            if not isinstance(entry, dict):
                errors.append("entry must be object: " + ident)
                continue
            paths = entry.get("files") if table_name == "SFX" else [entry.get("file")]
            if not isinstance(paths, list) or not paths:
                errors.append("missing files: " + ident)
                continue
            for path in paths:
                if not isinstance(path, str) or not path.startswith("res://"):
                    errors.append("invalid resource path: " + ident)
                    continue
                disk = (game / path[6:]).resolve()
                if not disk.is_relative_to(game.resolve()):
                    errors.append("resource escapes game: " + ident)
                    continue
                references.append(path)
                if not disk.is_file():
                    errors.append("missing file: " + path)
                    continue
                blob = disk.read_bytes()
                if disk.suffix.lower() == ".wav":
                    issue = check_wave(blob)
                    if issue:
                        errors.append(issue + ": " + path)
                elif disk.suffix.lower() == ".ogg":
                    require(blob.startswith(b"OggS") and b"\x01vorbis" in blob[:128], "invalid Ogg/Vorbis signature: " + path)
                else:
                    errors.append("unsupported audit format: " + path)
            if table_name == "BGM":
                continue
            require(entry.get("bus") in buses, "unknown bus: " + ident)
            require(finite(entry.get("volume_db")), "non-finite volume: " + ident)
            lo, hi = entry.get("pitch_min"), entry.get("pitch_max")
            require(finite(lo) and finite(hi) and 0 < lo <= hi, "pitch range: " + ident)
            cooldown = entry.get("cooldown_sec")
            require(finite(cooldown) and cooldown >= 0, "cooldown: " + ident)
            voices = entry.get("max_voices")
            cap = {"SFX": 16, "UI": 4, "Ambient": 4, "BGM": 2}.get(entry.get("bus"), 16)
            require(type(voices) is int and 1 <= voices <= cap, "voice bound: " + ident)
            priority = entry.get("priority")
            require(type(priority) is int and 0 <= priority <= 3, "priority: " + ident)
    # Reuse the existing Godot test's core-event contract without changing/running it.
    gut = (game / "tests/unit/test_audio_manager.gd").read_text(encoding="utf-8")
    contract = gut.split("func test_key_m1_events_are_mapped()", 1)[1]
    contract_list = re.search(r'for id: String in \[([^]]+)\]', contract)
    if not contract_list:
        errors.append("existing core-event contract format changed")
    required = re.findall(r'"([a-z][a-z0-9_]+)"', contract_list.group(1)) if contract_list else []
    for ident in required:
        require(ident in sfx, "missing core event: " + ident)
    return errors, {"sfx_events": sum(not k.startswith("_") for k in sfx), "bgm_tracks": sum(not k.startswith("_") for k in bgm), "file_references": len(references), "unique_files": len(set(references)), "wav_files": len({p for p in references if p.lower().endswith(".wav")}), "ogg_files": len({p for p in references if p.lower().endswith(".ogg")}), "known_buses": sorted(buses)}


def call_audit(sfx):
    literal, dynamic = set(), []
    for path in (GAME / "scripts").rglob("*.gd"):
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("#", 1)[0]
            if "play_sfx(" not in code or code.lstrip().startswith("func "):
                continue
            if "StringName(" in code:
                dynamic.append(f"{path.relative_to(ROOT).as_posix()}:{line_no}: {code.strip()}")
            else:
                literal.update(re.findall(r'&?"([a-z][a-z0-9_]+)"', code))
    monsters = load_json(GAME / "data/monsters.json")
    missing_dynamic = [f"{mid}_{suffix}" for mid in monsters if not mid.startswith("_") for suffix in ("telegraph", "attack", "hurt", "death") if f"{mid}_{suffix}" not in sfx]
    rarity = (GAME / "scripts/ui/rarity.gd").read_text(encoding="utf-8")
    grades = re.search(r"const KEYS[^=]*=\s*\{([^}]+)\}", rarity)
    drops = ["drop_" + x for x in re.findall(r'"([a-z]+)"', grades.group(1))] if grades else []
    return {"literal_ids": sorted(literal), "unmapped_literals": sorted(literal - sfx.keys()), "dynamic_sites": dynamic, "unmapped_monster_candidates_not_all_paths_executed": missing_dynamic, "drop_ids": drops, "unmapped_drop_ids": [x for x in drops if x not in sfx], "drop_contract_parsed": bool(grades)}


if __name__ == "__main__":
    sfx, bgm = load_json(GAME / "data/audio_sfx.json"), load_json(GAME / "data/audio_bgm.json")
    errors, summary = validate(sfx, bgm)
    calls = call_audit(sfx)
    errors.extend("unmapped literal: " + x for x in calls["unmapped_literals"])
    errors.extend("unmapped drop: " + x for x in calls["unmapped_drop_ids"])
    if not calls["drop_contract_parsed"]:
        errors.append("Rarity.KEYS format changed; dynamic drop audit incomplete")
    print(json.dumps({"status": "FAIL" if errors else "PASS", "scope": "static_only_no_listening", "errors": errors, "summary": summary, "calls": calls}, ensure_ascii=False, indent=2))
    raise SystemExit(bool(errors))
