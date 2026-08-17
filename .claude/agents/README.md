# 《이슬란드 연대기》 개발 에이전트 팀

`docs/GDD-도트액션RPG-기획안.md`를 기준 문서로 삼는 7인 서브에이전트 팀.
메인 Claude Code 세션이 **디렉터(PD)** 역할로 작업을 분배·조율하고, 각 에이전트는 자기 영역의 산출물을 만든다.

## 팀 구성

| 에이전트 | 역할 | 주요 산출물 |
|---|---|---|
| `game-designer` | 시스템 기획·밸런싱 | `game/data/` 테이블, `docs/specs/` |
| `godot-engineer` | 게임플레이 프로그래밍 (Godot 4.x) | `game/scenes/`, `game/scripts/` |
| `level-designer` | 월드·던전·배치 | `game/maps/`, `docs/levels/` |
| `pixel-artist` | 도트 아트 디렉션·placeholder | `docs/art/`, `game/assets/sprites/`, `tools/art/` |
| `narrative-writer` | 스토리·퀘스트·대사 | `docs/story/`, `game/data/quests/`, `game/data/dialogue/` |
| `ui-ux-designer` | 게임 UI 설계·구현 | `docs/ui/`, `game/ui/` |
| `qa-tester` | 검증·리뷰·테스트 | `docs/qa/`, `game/tests/`, `tools/qa/` |

## 협업 파이프라인 (M1 프로토타입 기준)

```
game-designer (수치 명세)
      ↓
godot-engineer (구현) ←— pixel-artist (규격 맞춘 placeholder)
      ↓
qa-tester (검증 → 리포트) —→ 담당 에이전트가 수정
```

- 기능 하나의 흐름: **명세 → 구현 → 검증**. 검증을 통과해야 완료로 간주.
- 병렬 가능: level-designer / narrative-writer / ui-ux-designer는 독립 문서 작업을 동시에 진행할 수 있다.
- 공용 규칙: 밸런스 수치는 데이터 테이블로만, 텍스트는 로컬라이징 key로만, 아트는 규격 맞춘 placeholder 우선.

## 사용법

- 자동 위임: 작업 내용을 설명하면 메인 세션이 description을 보고 적합한 에이전트를 호출한다.
- 명시 호출: "godot-engineer 서브에이전트로 구르기 무적시간을 구현해줘"처럼 이름을 지정.
- 대규모 병렬 작업(예: 5개 지역 문서 동시 작성)은 여러 에이전트를 한 번에 띄워 진행한다.
