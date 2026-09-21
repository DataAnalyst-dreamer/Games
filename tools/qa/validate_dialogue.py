#!/usr/bin/env python3
"""대사(.dialogue) 파일 참조 무결성 검사(⑪-1, D-251/D-253, docs/specs/dialogue-system-v1.md §9.2).

`game/dialogue/*.dialogue` 를 정규식으로 훑어 4개 규칙을 확인한다. Dialogue Manager
애드온의 전체 GDScript 컴파일러를 옮기지 않고 필요한 규칙만 가볍게 재구현한, Godot
없이도 도는 오프라인 게이트다. `validate_tables.py`(612줄, D-157 500줄 상한 초과)에
더 얹지 않고 새 파일로 분리했다 — D-157은 tools/*.py 에도 적용된다(D-253).

검사 규칙:
  1. 응답의 `do resolve_branch_outcome("choice_id")` 또는
     `do QuestSystem.choose_branch("quest_id", "choice_id")` 의 choice_id가 그 퀘스트의
     `branch.choices[].id` 와 일치하는가(quests/*.json).
  2. `[ID:xxx]`(콜론 뒤 공백 없음) 태그의 키가 quest_ko.csv/ui_ko.csv 에 존재하는가 —
     `[ID: xxx]`(공백 포함) 형태는 그 자체를 오류로 잡는다(§5 실패 재발 방지).
  3. 응답(`- `) 블록 하나의 선택지가 4개를 넘지 않는가(dialogue-balloon.md §1 하드 상한).
  4. `using` 선언이 QuestSystem 외 이름을 쓰지 않는가(NpcDialogueController는 `using`
     대상이 될 수 없다 — 있으면 오히려 컴파일 에러를 놓치는 통과 조건이 된다, §3.4).

종료 코드: 0 = 통과, 1 = 하나 이상 위반.
사용법: python3 tools/qa/validate_dialogue.py [--dialogue-dir game/dialogue] [--data-dir game/data] [--loc-dir game/localization]
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Set

_USING_RE = re.compile(r"^using (?P<name>.+)$")
_ID_TAG_RE = re.compile(r"\[ID:(?P<id>[^\]]*)\]")
_BAD_ID_TAG_RE = re.compile(r"\[ID:\s+[^\]]*\]")
_DO_RESOLVE_RE = re.compile(r"do\s+resolve_branch_outcome\(\s*\"(?P<choice_id>[^\"]*)\"\s*\)")
_DO_CHOOSE_BRANCH_RE = re.compile(
    r"do\s+QuestSystem\.choose_branch\(\s*\"(?P<quest_id>[^\"]*)\"\s*,\s*\"(?P<choice_id>[^\"]*)\"\s*\)")

ALLOWED_USING = {"QuestSystem"}


def _load_localization_keys(loc_dir: Path) -> Set[str]:
    keys: Set[str] = set()
    if not loc_dir.is_dir():
        return keys
    for csv_path in loc_dir.glob("*.csv"):
        with csv_path.open(encoding="utf-8-sig", newline="") as f:
            for row in csv.reader(f):
                if row and row[0].strip():
                    keys.add(row[0].strip())
    return keys


def _load_branch_choice_ids(data_dir: Path) -> Dict[str, Set[str]]:
    """quest_id -> 그 퀘스트 branch.choices[].id 집합(quests/*.json 전체 스캔)."""
    result: Dict[str, Set[str]] = {}
    quests_dir = data_dir / "quests"
    if not quests_dir.is_dir():
        return result
    for json_path in sorted(quests_dir.glob("*.json")):
        data = json.loads(json_path.read_text(encoding="utf-8"))
        for quest in data.get("quests", []):
            if not isinstance(quest, dict):
                continue
            quest_id = str(quest.get("id", ""))
            branch = quest.get("branch")
            if quest_id and isinstance(branch, dict):
                result[quest_id] = {str(c.get("id", "")) for c in branch.get("choices", [])}
    return result


def validate_dialogue(dialogue_dir: Path, data_dir: Path, loc_dir: Path) -> List[str]:
    errors: List[str] = []
    if not dialogue_dir.is_dir():
        return errors
    loc_keys = _load_localization_keys(loc_dir)
    branch_choices = _load_branch_choice_ids(data_dir)

    for path in sorted(dialogue_dir.glob("*.dialogue")):
        text = path.read_text(encoding="utf-8")
        response_run = 0
        for raw_line in text.splitlines():
            line = raw_line.strip()
            if not line or line.startswith("~"):
                response_run = 0

            using_match = _USING_RE.match(line)
            if using_match:
                name = using_match.group("name").strip()
                if name not in ALLOWED_USING:
                    errors.append(f"{path.name}: using '{name}' 은 허용되지 않음(허용: {sorted(ALLOWED_USING)})")
                continue

            if line.startswith("- "):
                response_run += 1
                if response_run > 4:
                    errors.append(f"{path.name}: 선택지가 4개를 초과함(dialogue-balloon.md §1 하드 상한)")
            elif line and not line.startswith(("do ", "do!", "set ", "$>", "=>")):
                response_run = 0  # 새 대사 줄(응답/변이/goto가 아님) → 이전 응답 블록 종료.

            for bad in _BAD_ID_TAG_RE.findall(line):
                errors.append(f"{path.name}: '{bad}' — [ID:xxx]는 콜론 뒤 공백 없이 써야 함(§5)")
            for match in _ID_TAG_RE.finditer(line):
                key = match.group("id")
                if key and not key[0].isspace() and key not in loc_keys:
                    errors.append(f"{path.name}: [ID:{key}] 키가 quest_ko.csv/ui_ko.csv 어디에도 없음")

            resolve_match = _DO_RESOLVE_RE.search(line)
            if resolve_match:
                choice_id = resolve_match.group("choice_id")
                if not any(choice_id in choices for choices in branch_choices.values()):
                    errors.append(f"{path.name}: resolve_branch_outcome(\"{choice_id}\") 가 "
                                  f"어떤 퀘스트의 branch.choices에도 없음")

            choose_match = _DO_CHOOSE_BRANCH_RE.search(line)
            if choose_match:
                quest_id = choose_match.group("quest_id")
                choice_id = choose_match.group("choice_id")
                if choice_id not in branch_choices.get(quest_id, set()):
                    errors.append(f"{path.name}: QuestSystem.choose_branch(\"{quest_id}\", \"{choice_id}\") 의 "
                                  f"choice_id가 branch.choices에 없음")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dialogue-dir", default=None, help="game/dialogue 경로")
    parser.add_argument("--data-dir", default=None, help="game/data 경로")
    parser.add_argument("--loc-dir", default=None, help="game/localization 경로")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    root = (script_dir / ".." / "..").resolve()
    dialogue_dir = Path(args.dialogue_dir) if args.dialogue_dir else root / "game" / "dialogue"
    data_dir = Path(args.data_dir) if args.data_dir else root / "game" / "data"
    loc_dir = Path(args.loc_dir) if args.loc_dir else root / "game" / "localization"

    errors = validate_dialogue(dialogue_dir, data_dir, loc_dir)
    print(f"[validate_dialogue] dialogue_dir={dialogue_dir}")
    if errors:
        print(f"\n오류 {len(errors)}건:")
        for e in errors:
            print(f"  - {e}")
        print("\nFAIL")
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
