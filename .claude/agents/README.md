# 《이슬란드 연대기》 개발 에이전트 팀

`docs/GDD-도트액션RPG-기획안.md`를 기준 문서로 삼는 12인 서브에이전트 팀.
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
| `audio-designer` | 사운드 선별·생성·버스 설계 | `docs/audio/`, `tools/audio/` |
| `content-researcher` | 세계관·스토리·디자인 레퍼런스 웹 리서치 | `docs/story/research/` |
| `build-verifier` (Haiku) | 헤드리스 3단계 검증 실행·보고 | 검증 보고서 |
| `release-manager` (Haiku) | 단계 브랜치·커밋·푸시·PR 생성 | PR |
| `asset-wrangler` (Haiku) | 스프라이트 변환·인벤토리·라이선스 표 | `game/assets/sprites/`, `tools/art/` |

## 협업 파이프라인 (M1 프로토타입 기준)

```
game-designer (수치 명세)
      ↓
godot-engineer (구현) ←— pixel-artist (규격 맞춘 placeholder)
      ↓
qa-tester (검증 → 리포트) —→ 담당 에이전트가 수정
      ↓
build-verifier (헤드리스 3단계 검증, Haiku)
      ↓
release-manager (stage 브랜치 커밋·푸시·PR, Haiku)
```

- 기능 하나의 흐름: **명세 → 구현 → 검증**. 검증을 통과해야 완료로 간주.
- 병렬 가능: level-designer / narrative-writer / ui-ux-designer는 독립 문서 작업을 동시에 진행할 수 있다.
- 공용 규칙: 밸런스 수치는 데이터 테이블로만, 텍스트는 로컬라이징 key로만, 아트는 규격 맞춘 placeholder 우선.

## 사용법

- 자동 위임: 작업 내용을 설명하면 메인 세션이 description을 보고 적합한 에이전트를 호출한다.
- 명시 호출: "godot-engineer 서브에이전트로 구르기 무적시간을 구현해줘"처럼 이름을 지정.
- 대규모 병렬 작업(예: 5개 지역 문서 동시 작성)은 여러 에이전트를 한 번에 띄워 진행한다.

## 운영 규칙 (2026-09-08 확정)

### 모델 배정 — 토큰 효율 우선
| 티어 | 모델 | 대상 작업 | 호출 방법 |
|---|---|---|---|
| 1 | **Haiku** | 기계적 작업: 파일 정리·변환, 인벤토리 조사, 라이선스 표 정리, 단순 데이터 테이블 채우기, 로그 요약 | Agent 호출 시 `model: haiku` 오버라이드 |
| 2 | **Sonnet** (기본) | 콘텐츠·코드 작업: GDScript 구현, 기획 문서, 밸런스 수치, 레벨 설계, 대사, UI 구현, 테스트 작성 | 에이전트 정의의 기본값 |
| 3 | **Opus급** | 아키텍처 결정, 다중 시스템에 걸친 난해한 버그, 성능 설계(청크 스트리밍 등) | 메인 세션이 직접 처리하거나 `model: opus` 오버라이드 |

- 기본은 Sonnet. 메인 세션(디렉터)이 작업을 위임할 때마다 티어를 판단해 오버라이드한다.
- 한 작업에 여러 티어가 섞이면 쪼갠다 (예: "애셋 조사(Haiku) → 변환 스크립트 작성(Sonnet)").

### PR 정책 — 단계마다 자동 생성
- 저장소 기본 브랜치: `claude/dot-action-rpg-design-cwwlgc` (통합 브랜치 역할).
- 각 단계는 `stage/<번호>-<이름>` 브랜치에서 작업 → 검증 통과 → 기본 브랜치로 PR 생성. 머지는 사람이 GitHub에서 한다.
- "단계"의 단위: 독립적으로 검증·리뷰 가능한 묶음 (예: 프로젝트 골격, 이동+카메라, 3타 콤보+히트스톱, 구르기+가드, 몬스터 1종+드랍).
- PR 본문에는 반드시 ① 변경 요약 ② 검증 명령과 실제 출력 요약 ③ 남은 이슈 ④ 관련 GDD/BRD 항목을 적는다.
- 문서만 바뀐 작은 변경은 기본 브랜치에 직접 커밋해도 된다.
