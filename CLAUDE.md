# 《이슬란드 연대기》 프로젝트 규칙

- 기획 기준 문서: `docs/GDD-도트액션RPG-기획안.md` (v1.1) + `docs/brd/` (PRD·영역·기능·결정 기록). 기획 변경은 `docs/brd/04-decisions.md`에 결정 ID를 남기고 GDD를 함께 갱신한다.
- 엔진: Godot 4.4.1, 프로젝트 루트 `game/`. 검증용 헤드리스 바이너리는 세션 스크래치에 두고 `--import` → GUT → 씬 실행 3단계로 검증한다.
- 밸런스 수치는 `game/data/` 테이블로만, 텍스트는 로컬라이징 key로만, 임시 상수는 `game/scripts/tuning.gd` 한 파일에만.
- 외부 애셋은 `docs/art/asset-sources.md` 등급 규칙과 `docs/art/LICENSES.md` 기록 없이는 쓰지 않는다. 립 스프라이트 사용 금지.
- 서브에이전트 위임 시 모델 티어(Haiku/Sonnet/Opus급)와 단계별 PR 정책은 `.claude/agents/README.md`의 운영 규칙을 따른다.
- 단계 작업은 `stage/<번호>-<이름>` 브랜치 → 검증 → 기본 브랜치(`claude/dot-action-rpg-design-cwwlgc`)로 PR. 머지는 사람이 한다.
