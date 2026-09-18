"""Validate unregistered writing drafts, NOT quest execution or rendered width."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT / "docs/content-drafts/research-expansion/quest-reactivity-v1.json"


def validate(doc):
    errors = []
    def require(ok, why):
        if not ok:
            errors.append(why)
    require(doc.get("status") == "draft_unconnected" and doc.get("runtime_registered") is False, "draft status")
    source_path = ROOT / doc.get("source_document", "missing")
    require(source_path.is_file(), "missing source document")
    source = source_path.read_text(encoding="utf-8") if source_path.is_file() else ""
    world = json.loads((ROOT / "game/data/world_objects.json").read_text(encoding="utf-8-sig"))
    for path in doc.get("canon_refs", []):
        require((ROOT / path).is_file(), "missing canon reference: " + path)
    speakers = doc.get("speaker_refs", {})
    for key, ref in speakers.items():
        path = ROOT / ref["path"]
        require(path.is_file() and ref["token"] in path.read_text(encoding="utf-8-sig"), "missing speaker: " + key)
    expected = {f"SQH-V2-{i:02}": {"start", "progress", "complete", "revisit"} for i in range(1, 7)}
    expected.update({f"ENVH-V2-{i:02}": {"observe", "revisit"} for i in range(1, 5)})
    choices = {
        "SQH-V2-02": {"식탁", "출입구 짐받침"},
        "SQH-V2-04": {"판 고정", "그대로 두고 기록"},
        "SQH-V2-05": {"머루 여관", "로젤 작업장"},
        "SQH-V2-06": {"직접 가지 치움", "로젤에게 위치 보고"},
    }
    seen, coverage = set(), {}
    rows = doc.get("reactions", [])
    require(len(rows) == 32, "expected 32 state cards")
    for row in rows:
        ident, source_id, state = row.get("id", ""), row.get("source_id", ""), row.get("state", "")
        require(ident.startswith("draft_reactivity_") and ident not in seen, "invalid/duplicate ID: " + ident)
        seen.add(ident)
        require(source_id in expected and state in expected.get(source_id, set()), "invalid source/state: " + ident)
        pair = (source_id, state)
        require(pair not in coverage, "duplicate source/state: " + ident)
        coverage[pair] = True
        require(f"| {source_id} | `{row.get('source_code', '')}` |" in source, "source ID/code mapping: " + ident)
        require(row.get("location_anchor") in world, "missing runtime location anchor: " + ident)
        require(bool(row.get("condition")), "missing condition: " + ident)
        required_choices = choices[source_id] if source_id in choices and state in {"complete", "revisit"} else {"common"}
        lines = row.get("lines", [])
        require({line.get("choice") for line in lines} == required_choices and len(lines) == len(required_choices), "choice set: " + ident)
        for line in lines:
            require(line.get("speaker_ref") in speakers, "unknown speaker: " + ident)
            short, expanded = line.get("hud_short", ""), line.get("expanded", "")
            require(isinstance(short, str) and 1 <= len(short) <= 13 and "\n" not in short, "short text length: " + ident)
            require(isinstance(expanded, str) and 1 <= len(expanded) <= 110, "expanded length: " + ident)
    require(set(coverage) == {(key, state) for key, states in expected.items() for state in states}, "incomplete state coverage")
    return errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("path", nargs="?", type=Path, default=DEFAULT)
    args = parser.parse_args()
    document = json.loads(args.path.read_text(encoding="utf-8"))
    problems = validate(document)
    for problem in problems:
        print("FAIL " + problem)
    lines = [line for row in document["reactions"] for line in row["lines"]]
    print(f"QUEST_REACTIVITY {'FAIL' if problems else 'PASS'} cards={len(document['reactions'])} variants={len(lines)} max_short_chars={max(len(x['hud_short']) for x in lines)} max_expanded_chars={max(len(x['expanded']) for x in lines)} render_width=UNTESTED runtime=UNCONNECTED")
    raise SystemExit(bool(problems))
