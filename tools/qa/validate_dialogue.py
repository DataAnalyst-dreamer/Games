#!/usr/bin/env python3
"""1막 하틀랜드 giver 잡담 `.dialogue` 원고 정합성 검사 (⑪-2, D-251/D-253).

`game/dialogue/*.dialogue`(`_smoke_test.dialogue` 제외, 워크스트림 A 소유)를 정규식
기반으로 가볍게 파싱해 title 명명 규칙(D-261)·[ID:] 로컬라이징 키 존재·몽실이 분기
선택지 id·응답 개수·`using` 화이트리스트를 확인한다. `validate_layout.py`와 같은
패턴으로 stdlib(re/json/csv)만 쓰는 자체완결 모듈이며 `validate_tables.py`를
import하지 않는다(순환 참조 회피 — D-251 결정에 따라 그쪽에서 나중에 1줄로 이 모듈을
불러 쓴다).

Dialogue Manager 문법 자체의 정확성(중첩 조건·멀티라인 표현식 등)은 이 스크립트의
책임이 아니다 — 그건 `tools/qa/compile_dialogue_check.gd`(DMCompiler)가 담당한다.
이 스크립트는 그보다 빠른 오프라인 사전 게이트(퀘스트/NPC id, CSV 키 참조 무결성)다.

ponytail 단순화(알려진 한계): 정규식 기반 파서라 실제 문법 트리를 만들지 않는다.
`do`/`title`을 잘못 추출하면 거짓 통과·거짓 실패가 날 수 있다 — 정확한 문법 검증은
DMCompiler(compile_dialogue_check.gd)가 전담한다는 역할 분담을 전제로 한다.

사용: python3 tools/qa/validate_dialogue.py [--repo-root .]
종료 코드: 0 = 통과(경고 있어도 0), 1 = 오류 1건 이상.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

DIALOGUE_DIR = "game/dialogue"
QUEST_JSON = "game/data/quests/act1_hartland.json"
CSV_FILES = ("game/localization/quest_ko.csv", "game/localization/ui_ko.csv")

# D-261: giver 잡담 title 규칙. `_done`은 죽은 title(everyday 내부 분기로 접었으므로
# NpcDialogueController가 이 title을 절대 요청하지 않는다) — 존재 자체가 오류.
TITLE_QUEST_STATE_RE = re.compile(r"^(?P<qid>quest_[a-z0-9_]+)_(?P<state>offer|active|ready|done)$")
TITLE_EVERYDAY_RE = re.compile(r"^(?P<npc>teo|meru|pinto|rozel|dami)_everyday$")

TITLE_LINE_RE = re.compile(r"^~\s+(?P<title>\S+)\s*$")
USING_LINE_RE = re.compile(r"^using\s+(?P<state>\S+)\s*$")
RESPONSE_LINE_RE = re.compile(r"^-\s")
STATIC_ID_RE = re.compile(r"\[ID:(?P<id>[^\]]*)\]")
STATIC_ID_SPACE_RE = re.compile(r"\[ID:\s")
DO_RESOLVE_RE = re.compile(r'do\s+resolve_branch_outcome\("(?P<choice>[^"]*)"\)')
CHOICE_ID_TAG_RE = re.compile(r"^(?P<qid>quest_[a-z0-9_]+)_choice_(?P<cid>[a-z0-9_]+)$")

MAX_RESPONSES_PER_TITLE = 4
WARN_MAX_LINES = 3
WARN_MAX_CHARS_NO_SPACE = 16


def _load_quests(repo_root: Path) -> Dict[str, Dict[str, Any]]:
    data = json.loads((repo_root / QUEST_JSON).read_text(encoding="utf-8"))
    return {q["id"]: q for q in data["quests"]}


def _load_csv_keys(repo_root: Path) -> Dict[str, str]:
    keys: Dict[str, str] = {}
    for rel in CSV_FILES:
        path = repo_root / rel
        if not path.exists():
            continue
        with path.open(newline="", encoding="utf-8") as f:
            reader = csv.reader(f)
            header = next(reader, None)
            for row in reader:
                if len(row) >= 2 and row[0]:
                    keys[row[0]] = row[1]
    return keys


def _dialogue_files(repo_root: Path) -> List[Path]:
    d = repo_root / DIALOGUE_DIR
    if not d.exists():
        return []
    return sorted(p for p in d.glob("*.dialogue") if p.name != "_smoke_test.dialogue")


class _Block:
    """title 하나의 원문 줄 구간(제목 다음 줄부터 다음 제목 전까지)."""

    def __init__(self, title: str, lines: List[str]):
        self.title = title
        self.lines = lines


def _split_blocks(lines: List[str]) -> Tuple[List[str], List[_Block]]:
    """파일 최상단(첫 title 이전) using 선언들과, title별 블록으로 나눈다."""
    preamble: List[str] = []
    blocks: List[_Block] = []
    current: _Block | None = None
    for raw in lines:
        m = TITLE_LINE_RE.match(raw)
        if m:
            current = _Block(m.group("title"), [])
            blocks.append(current)
            continue
        if current is None:
            preamble.append(raw)
        else:
            current.lines.append(raw)
    return preamble, blocks


def validate_dialogue(repo_root: Path) -> List[str]:
    errors: List[str] = []
    warnings: List[str] = []

    quests = _load_quests(repo_root)
    csv_keys = _load_csv_keys(repo_root)
    files = _dialogue_files(repo_root)

    for path in files:
        rel = path.relative_to(repo_root).as_posix()
        npc_id = path.stem[len("npc_"):] if path.stem.startswith("npc_") else None
        text = path.read_text(encoding="utf-8")
        lines = text.split("\n")
        preamble, blocks = _split_blocks(lines)

        # (5) using 화이트리스트: QuestSystem 외 금지.
        for raw in preamble:
            m = USING_LINE_RE.match(raw.strip())
            if m and m.group("state") != "QuestSystem":
                errors.append(f"{rel}: using \"{m.group('state')}\" 금지 — QuestSystem만 허용(D-261/§3.4)")

        seen_titles: Set[str] = set()
        for block in blocks:
            title = block.title
            if title in seen_titles:
                errors.append(f"{rel}: title \"{title}\" 중복 정의")
            seen_titles.add(title)

            # (1) title 규칙 검사.
            m_state = TITLE_QUEST_STATE_RE.match(title)
            m_everyday = TITLE_EVERYDAY_RE.match(title)
            if m_state:
                qid, state = m_state.group("qid"), m_state.group("state")
                if state == "done":
                    errors.append(f"{rel}: title \"{title}\" — _done은 죽은 title(완료 후 로테이션은 <npc>_everyday 내부 분기로 접는다, 심사 must_change)")
                elif qid not in quests:
                    errors.append(f"{rel}: title \"{title}\" — 퀘스트 id \"{qid}\"가 {QUEST_JSON}에 없음")
                elif npc_id is not None and quests[qid].get("giver") != npc_id:
                    errors.append(f"{rel}: title \"{title}\" — 퀘스트 \"{qid}\"의 giver는 \"{quests[qid].get('giver')}\"인데 파일은 npc_{npc_id}.dialogue")
            elif m_everyday:
                if npc_id is not None and m_everyday.group("npc") != npc_id:
                    errors.append(f"{rel}: title \"{title}\" — everyday 파일 자신({npc_id})과 다른 npc")
            # 그 외 title(예: 몽실이류 "start")은 giver 잡담 규칙 대상이 아니므로 검사하지 않는다.

            # (4) 응답 개수.
            response_count = sum(1 for l in block.lines if RESPONSE_LINE_RE.match(l.strip()))
            if response_count > MAX_RESPONSES_PER_TITLE:
                errors.append(f"{rel}: title \"{title}\" — 응답 {response_count}개 (상한 {MAX_RESPONSES_PER_TITLE})")

            # (2)+(3) [ID:] 추출 + do resolve_branch_outcome 페어링.
            pending_choice: Tuple[str, str] | None = None  # (qid, cid) — 직전 응답의 choice id 태그
            for raw in block.lines:
                if STATIC_ID_SPACE_RE.search(raw):
                    errors.append(f"{rel}: title \"{title}\" — \"[ID: \" 공백 오류(§5, 콜론 뒤 공백 금지): {raw.strip()}")

                for id_match in STATIC_ID_RE.finditer(raw):
                    tag = id_match.group("id")
                    if RESPONSE_LINE_RE.match(raw.strip()):
                        cm = CHOICE_ID_TAG_RE.match(tag)
                        if cm:
                            pending_choice = (cm.group("qid"), cm.group("cid"))
                    if tag not in csv_keys:
                        errors.append(f"{rel}: title \"{title}\" — [ID:{tag}] 키가 quest_ko.csv/ui_ko.csv에 없음")
                    else:
                        # (6) 경고: 3줄/16자 상한.
                        segments = [s.strip() for s in csv_keys[tag].split("/")]
                        if len(segments) > WARN_MAX_LINES:
                            warnings.append(f"{rel}: [ID:{tag}] — {len(segments)}줄(상한 {WARN_MAX_LINES})")
                        for seg in segments:
                            no_space = re.sub(r"\s", "", seg)
                            if len(no_space) > WARN_MAX_CHARS_NO_SPACE:
                                warnings.append(f"{rel}: [ID:{tag}] — 한 줄 {len(no_space)}자(공백 제외, 상한 {WARN_MAX_CHARS_NO_SPACE}): \"{seg}\"")

                do_match = DO_RESOLVE_RE.search(raw)
                if do_match:
                    choice_arg = do_match.group("choice")
                    if pending_choice is None:
                        warnings.append(f"{rel}: title \"{title}\" — resolve_branch_outcome(\"{choice_arg}\") 앞에 짝이 되는 [ID:..._choice_<id>] 응답 태그를 찾지 못함(퀘스트 id를 추정 못해 branch 검사 생략)")
                    else:
                        # 응답의 [ID:..._choice_<X>] 태그는 로컬라이징 key 이름일 뿐(예:
                        # 기존 key가 "..._choice_capture"이지만 실제 branch choice id는
                        # JSON에 "capture_attempt"로 정의된 경우처럼 텍스트가 다를 수 있다)
                        # — 여기서는 qid만 빌려 쓰고, 실제 choice id 검증은 do 인자 대
                        # 그 퀘스트의 branch.choices만으로 한다(D-94, quest_ko.csv 기존
                        # key 명명과 branch choice id 명명이 애초에 1:1이 아님을 확인).
                        qid, _cid_tag = pending_choice
                        quest = quests.get(qid)
                        branch = (quest or {}).get("branch") or {}
                        choice_ids = {c["id"] for c in branch.get("choices", [])}
                        if quest is None:
                            errors.append(f"{rel}: title \"{title}\" — 응답 태그의 퀘스트 id \"{qid}\"가 {QUEST_JSON}에 없음")
                        elif choice_arg not in choice_ids:
                            errors.append(f"{rel}: title \"{title}\" — resolve_branch_outcome(\"{choice_arg}\")가 \"{qid}\".branch.choices {sorted(choice_ids)}에 없음")

    return errors + [f"[warn] {w}" for w in warnings]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=None, help="레포 루트 경로(기본: 이 스크립트 기준 ../..)")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = Path(args.repo_root).resolve() if args.repo_root else (script_dir / ".." / "..").resolve()

    print(f"[validate_dialogue] repo root = {repo_root}")
    results = validate_dialogue(repo_root)
    errors = [r for r in results if not r.startswith("[warn] ")]
    warnings = [r for r in results if r.startswith("[warn] ")]

    if warnings:
        print(f"\n경고 {len(warnings)}건:")
        for w in warnings:
            print(f"  - {w}")
    if errors:
        print(f"\n오류 {len(errors)}건:")
        for e in errors:
            print(f"  - {e}")
        print("\nFAIL")
        return 1
    print("PASS - 대사 원고 참조 무결성 검사 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
