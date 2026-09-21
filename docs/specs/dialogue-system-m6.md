# 대사 시스템 설계 (M6, `development-order.md` ⑥ — 작업 지시문 표기는 "⑪")

> 작성: godot-engineer · 대상 브랜치: `stage/m6-int`(읽기 전용 검토, 이 문서 1개만 신규 작성 — 코드/데이터/씬/`docs/brd/04-decisions.md` 미수정, 커밋 없음)
> 근거 문서: `docs/ui/dialogue-balloon.md`(레이아웃·입력 계약), `docs/story/dialogue-content-requirements-act1-hartland.md`(콘텐츠 물량), `docs/qa/dialogue-system-test-plan-template.md`(테스트 골격), `docs/specs/quest-data-schema.md`(Quest 스키마 정본), `game/data/quests/act1_hartland.json`·`game/data/world_objects.json`·`game/addons/dialogue_manager/*`·`game/tests/unit/*`(직접 확인)
> **채택 각도: C안(하이브리드 브리지)** — `.dialogue` 파일로 콘텐츠(조건·변이 포함)를 작성하되, 게임 상태 접근은 전부 `DialogueBridge`(신규 오토로드 1개) 뒤로 숨겨 `.dialogue`가 쓸 수 있는 어휘를 `quest_state()`/`has_item()`/`accept_quest()` 등 명시적 함수 집합으로 제한한다. 이 워크트리에는 이 문서의 이전 버전들(B안: 자체 JSON 런타임 / A안: `.dialogue`에서 `QuestSystem`/`GameState`를 직접 호출)이 같은 경로에 있었다 — 이번 리비전이 그것들을 대체한다. C안이 A안과 다른 지점, B안과 다른 지점은 각각 0.1·0.2절에서 근거와 함께 밝힌다.
> 사실 표기: "(확인)" = 이 워크트리 소스를 직접 읽어 확인, "(제안)" = 이 문서가 새로 정하는 설계 결정, "(결정 필요)" = 14장으로 넘긴 질문.

---

## 0. 왜 C안인가

### 0.1 B안(자체 JSON 런타임)을 버리는 이유

B안은 조건·분기가 몽실이 1건뿐이라는 전제로 "그래프 없는 선형 노드 리스트 + 상태별 배열"을 자체 구현하려 했다. 그런데 `dialogue-content-requirements-act1-hartland.md`(narrative-designer)는 이미 "진행 중 재대화", "완료 후 재대화", NPC별 잡담(`characters.md` D-60 `chat` 슬롯)까지 요구한다 — 조건부 대사가 계속 늘어나는 구조다. 그때마다 손코딩한 "합성 액션 표"를 늘리는 것보다, 이미 조건(`if/elif/match`)·변이(`do/set`)·정적 ID·CSV 번역을 갖추고 **오토로드로 이미 등록까지 되어 있는** `addons/dialogue_manager`(확인: `game/project.godot:32,45`, `game/addons/dialogue_manager/compiler/*`)를 쓰는 편이 실제로는 더 적은 코드다(ladder 2번: 이미 코드베이스에 있다).

### 0.2 A안(`.dialogue`에서 `QuestSystem`/`GameState` 직접 호출)을 버리는 이유

A안은 애드온을 최대한 그대로 쓰기 위해 `.dialogue`가 `if QuestSystem.get_state(...)`/`do QuestSystem.choose_branch(...)`를 직접 부르게 한다. 동작은 하지만(오토로드는 `using` 없이도 이름만으로 호출 가능 — 아래 0.3절), 그 결과 **밸런스·세이브·게임 상태 로직 전체가 `game/data/dialogues/*.dialogue`라는, `Data.gd`의 스키마 검증도 GUT의 타입 체크도 거치지 않는 텍스트 파일에 흩어진다.** 신규 대사를 쓰는 사람(narrative-writer)이 실수로 `do GameState.add_gold(500)`처럼 밸런스 수치를 대사에 하드코딩해도(프로젝트 규칙 위반) 막을 방법이 A안 구조엔 없다 — 애드온이 모든 오토로드를 기본 노출하기 때문이다(0.3절). 이 문서가 받은 지시(하이브리드 브리지)의 핵심이 바로 이 구멍을 막는 것이다.

### 0.3 확인된 사실 — 애드온은 기본값으로 "전부 노출"한다

`_get_game_states()`가 매 대사 줄마다 이렇게 동작한다(확인: `game/addons/dialogue_manager/dialogue_manager.gd:717-733`):

```gdscript
func _get_game_states(extra_game_states: Array) -> Array:
	if not _has_loaded_autoloads:
		_has_loaded_autoloads = true
		for child in Engine.get_main_loop().root.get_children():
			if child.name == &"DialogueManager": continue
			if Engine.get_main_loop().current_scene and child.name == Engine.get_main_loop().current_scene.name: continue
			_autoloads[child.name] = child
		game_states = [_autoloads]
		...
```

`Engine.get_main_loop().root`의 모든 직속 자식(=`project.godot`의 `[autoload]` 전부: `QuestSystem`/`GameState`/`Events`/`SaveManager`/`Settings`/`Data`/`Progression`/`Metrics`/`AudioManager`/`PhantomCameraManager`)이 이름 그대로 `game_states`에 들어가고, 조건·변이 평가 때 **항상** 합쳐진다(`extra_game_states + [current_scene] + game_states`). `using` 선언 여부와 무관하다 — `using`은 "안 써도 되게" 앞에 항목을 추가해줄 뿐(확인: `dialogue_manager.gd:106-112`), `_autoloads`를 제거하지 않는다.

**결론**: "DialogueBridge 뒤로 숨긴다"를 런타임이 저절로 지켜주지 않는다 — **강제 수단을 따로 설계해야 한다**(3장). `game_states`(언더스코어 없음, 확인: `dialogue_manager.gd:42`)는 공개 변수라 이론적으로 덮어쓸 수 있지만, `_get_game_states()`가 **처음 호출될 때** `_has_loaded_autoloads`(관례상 private — GDScript엔 진짜 private가 없어 접근 자체는 됨)가 `false`면 그 값을 다시 `[_autoloads]`로 덮어써 버린다. 완전 차단은 애드온 내부 private 변수에 결합해야 해서(버전업 시 깨질 위험) 이 문서는 정적 검증(3장)을 1차 수단으로, 런타임 차단은 결정 필요(14-2)로 남긴다.

---

## 1. 기존 계약과의 관계 (요구 (2))

### 1.1 유지 (변경 없음)

| 계약 | 위치 | 유지 이유 |
|---|---|---|
| `Events.npc_talked(npc_id)` 시그널, `QuestNpc.talk()` | `game/scripts/world/quest_npc.gd:71-81`(확인) | `smoke_quest_layout.gd`가 `teo.talk()`/`meru.talk()`를 UI 없이 직접 호출(확인: `game/tests/smoke/smoke_quest_layout.gd:134,166`). `talk()`은 지금처럼 `Events.npc_talked`만 즉시 emit — 밸룬이 열려도 QuestSystem의 talk형 목표 자동 진행·타이밍은 그대로다. |
| `get_tree().call_group("quest_npc_ui", "open_quest_npc", npc_id)` | `quest_npc.gd:75`(확인) | `QuestNpc.gd`는 한 줄도 건드리지 않는다. 그룹 이름·메서드 시그니처 불변, `UiRoot` 내부 구현만 바뀐다. |
| `QuestSystem.accept()/advance()/choose_branch()/get_state()` 반환 스키마 | `quest_system.gd:187-259`(확인) | D-164("새 조회 함수 2개만 허용", 이미 소진 — 확인: `docs/brd/04-decisions.md:298`)와 D-157 때문에 `quest_system.gd`(현재 644줄)에 새 공개 함수를 추가하지 않는다. `DialogueBridge`는 이 4개만 감싼다. |
| `Events.quest_accepted/quest_completed/quest_objective_updated` 등 | `events.gd`(확인) | HUD 표식(`quest_npc.gd:_on_any_quest_signal`)·퀘스트 로그가 계속 구독. 새 시그널 추가 없음. |
| `SaveManager`의 `quest_system` 슬라이스 1개 | `save_manager.gd:109-110,285-286`(확인) | 8장에서 설명 — 신규 세이브 필드 없음. |
| `Hud._next_npc_greeting(npc_id, cave_done, montsil_done)` 함수 본체·시그니처 | `hud.gd:329-337`(확인) | `test_npc_greeting.gd`가 `hud._next_npc_greeting()`을 **직접** 호출해 3줄 로테이션(everyday/after_cave/after_montsil)을 단언한다(확인: `test_npc_greeting.gd:8-23`). 함수는 그대로 두고 **호출부만** 옮긴다(1.5절). |

### 1.2 대체

`QuestNpcPanel`(`game/scripts/ui/quest_npc_panel.gd`, 126줄)을 삭제하고 `DialogueBalloon`(신규)으로 대체한다 — 제목+본문+버튼 2개뿐이라 초상·화자·선택지를 표현 못 하고, `SUPPORTED` 4개 하드코딩 배열이 신규 퀘스트를 못 다룬다(요구 (2)). `SUPPORTED` 배열은 `quest_npc.gd._refresh_marker()`가 이미 쓰는 "quests 테이블 전체 스캔(giver==npc_id)" 방식으로 통일한다 — 이 스캔 로직은 `DialogueBridge.find_offer_quest()`(2장)로 옮긴다.

### 1.3 새로 발견한 계약 충돌 — `QuestObject`도 건드려야 한다 (요구 (1) 몽실이 분기)

**사실 확인**: 몽실이 분기(`quest_side_heartland_montsil.branch`, `act1_hartland.json:421-436`)는 giver `다미`와의 대화가 아니라 **`montsil_rabbit`이라는 `QuestObject`(NPC 아님)와의 상호작용**에서 확정된다(확인: `game/data/world_objects.json:120-134`):

```json
"montsil_rabbit": {
  "kind": "object", "scene": "res://scenes/world/QuestObject.tscn",
  "branch_quest_id": "quest_side_heartland_montsil",
  "branch_choice_id": "release",
  "_comment": "상호작용 즉시 queue_free (D-94: 선택 UI 없음 → 첫 상호작용=release 고정, 문서화)."
}
```

`QuestObject.interact()`(`game/scripts/world/quest_object.gd:92-104`)는 `branch_quest_id`/`branch_choice_id`가 둘 다 채워져 있으면 `QuestSystem.choose_branch(...)`를 **자동·즉시** 호출한다. 지금 구조에서는 토끼를 건드리는 순간 "release"로 확정되고, 다미와 대화해도 이미 결정은 끝나 있다. 이 하드코딩은 **`game/tests/unit/test_quest_layout_spawner.gd:123-130`이 `montsil.branch_choice_id == "release"`를 데이터 그대로 단언**하고 있어(확인), 값을 바꾸면 이 GUT 테스트도 함께 갱신해야 한다(14장 표).

반면 narrative 요구사항 문서는 "완료 가능" 상태에서 다미에게 "release/capture_attempt 각 1" 대사가 필요하다고 적었고, 몽실이 자체는 "대사 없음, 플레이어 발화(선택지 2종)로 감정 전달"이라고 못박았다. 이 둘을 맞추면 설계가 자연스럽게 나온다:

- **선택 자체(요구 (1)의 "몽실이 분기 선택 UI")는 `montsil_rabbit` 상호작용 시점에, 화자 없는 선택지 전용 대사로 연다.**
- **다미의 "완료 가능"/"완료 후" 대사는 그 결과(`story_flags`의 `montsil_released`/`montsil_capture_tried`, 이미 `choose_branch()`가 기록 — `quest_system.gd:255`)를 조건으로 갈라 반응만 보여준다.** 이게 narrative-designer가 요구한 "release/capture_attempt 각 1"이다.
- **선택지 텍스트는 이미 존재한다** — `game/localization/quest_ko.csv:36-37`에 `quest_side_heartland_montsil_choice_release`("그냥 놓아준다")/`_choice_capture`("붙잡아 본다", note: "저강도 미니게임 or 대치 후 퇴각, 결과는 release와 동일하게 수렴")가 이미 등록되어 있다(확인). 신규 로컬라이징 없이 그대로 재사용한다.

**필요한 코드/데이터 변경(이 문서 범위 밖, 다음 구현 단계용으로 명시)**: `world_objects.json`에서 `montsil_rabbit.branch_choice_id: "release"`를 제거하고, `QuestObject.interact()`에 "분기 대사 밸룬을 연다"는 새 동작을 추가한다(6장 구체화) — `branch_choice_id`가 **비어 있고** `branch_quest_id`만 있으면 `get_tree().call_group("quest_npc_ui", "open_dialogue_choice", branch_quest_id)`를 호출하는 1줄이 `QuestObject`가 받는 유일한 로직 변경이다.

### 1.4 스모크·유닛 테스트 갱신 범위

| 파일 | 영향 | 이유 |
|---|---|---|
| `game/tests/smoke/smoke_quest_npc_panel.gd`(140줄) | **갱신** — `ui.quest_npc_panel.*` 참조 → `ui.dialogue_balloon.*` | `QuestNpcPanel` 삭제(1.2절) |
| `game/tests/smoke/smoke_quest_npc_late.gd`(99줄) | **갱신** — `QuestNpcPanel.new()` → `DialogueBalloon.new()`, `confirm_button.disabled` → `not balloon.has_pending_choice()`류 헬퍼(5장), 기대 텍스트 소스가 `.dialogue` 컴파일 결과로 변경 | 상동 |
| `game/tests/smoke/smoke_quest_ui_save.gd`(약 80줄) | **갱신** — `ui.quest_npc_panel.*` 참조 1곳 교체 | 상동 |
| `game/tests/unit/test_quest_layout_spawner.gd:123-130`(151줄) | **갱신** — `assert_eq(String(montsil.branch_choice_id), "release")` → `assert_eq(String(montsil.branch_choice_id), "")`(또는 필드 자체 제거 시 그 단언 삭제) | 1.3절 데이터 변경과 직접 충돌(확인된 실제 단언) |
| `game/tests/unit/test_quest_system.gd:210-241`(`test_branch_choice_sets_outcome_flag`, `test_branch_defaults_to_first_choice_when_unresolved`) | **무변경** | `QuestSystem.choose_branch()`를 직접 호출해 `QuestObject`/대사를 거치지 않는다(확인) |
| `game/tests/unit/test_npc_greeting.gd` | **무변경** | `hud._next_npc_greeting()` 시그니처·본체 불변(1.1절) |
| `game/tests/smoke/smoke_quest_layout.gd` | **무변경** | `talk()`만 사용(1.1절) |
| (신규) `game/tests/smoke/smoke_dialogue_montsil_branch.gd` | 신규 | 10장 |
| (신규) `game/tests/unit/test_dialogue_bridge.gd` | 신규 | 10장 |

### 1.5 "토스트 대체" (요구 (1)의 세 번째 항목)

**사실 확인**: 지금은 `Hud._on_npc_talked()`(`hud.gd:322-326`)가 `Events.npc_talked` 하나만 구독해 `_next_npc_greeting()`으로 뽑은 key를 좌하단 로그에 3초 토스트로 띄운다. 이 로직은 대사 밸룬이 생기면 **완전히 대체된다** — `QuestNpc._unhandled_input()`이 이미 매번 `talk()` 직후 `"quest_npc_ui"` 그룹을 부르므로(1.1절), 앞으로는 그 호출이 항상 밸룬을 연다.

**설계(제안)**: `hud.gd`에서 `Events.npc_talked.connect(_on_npc_talked)` 구독과 로그 push만 제거하고, `_on_npc_talked()`의 계산 로직(2줄: `cave_done`/`montsil_done` 판정)은 이름을 바꿔 공개 함수로 남긴다:

```gdscript
## (구 _on_npc_talked 로직) DialogueBalloon이 "이 NPC에게 열어줄 퀘스트 대사가 없을 때"
## 잡담 폴백으로 재사용한다(1.1절 — _next_npc_greeting 자체는 건드리지 않는다).
func greeting_key_for_chat(npc_id: StringName) -> StringName:
	var cave_done := QuestSystem.get_state("quest_main_a1_06_echocave") == "completed"
	var montsil_done := QuestSystem.get_state("quest_side_heartland_montsil") == "completed"
	return _next_npc_greeting(npc_id, cave_done, montsil_done)
```

`DialogueBalloon`이 열릴 때 `DialogueBridge.find_offer_quest(npc_id)`가 빈 문자열이면(giver인 퀘스트가 없거나 전부 완전히 끝난 상태) 이 키로 `DialogueManager.create_resource_from_text()`(확인: `dialogue_manager.gd:488-508`, 즉석 컴파일 API)를 호출해 1줄짜리 대사를 즉석 생성해 보여준다 — **`ui_ko.csv`의 기존 잡담 문구 48줄(everyday/after_* ×3, 확인: `ui_ko.csv:20-47`)을 그대로 재사용**, 신규 콘텐츠 0. `_npc_visit_lines`(로테이션 인덱스, `hud.gd`)는 지금처럼 세이브 안 함(1.1절 함수가 그대로라 동작 동일).

`hud.gd` 순변화: 약 -3/+3줄(현재 486줄, 여유 큼).

---

## 2. `DialogueBridge` — 허용 어휘 (요구 (1) 핵심)

`game/scripts/systems/dialogue_bridge.gd`(신규 오토로드, `project.godot`에 `DialogueBridge="*res://scripts/systems/dialogue_bridge.gd"`로 `SaveManager` 다음·`DialogueManager` 앞에 삽입 **(제안)** — `QuestSystem`/`GameState`가 먼저 준비돼 있어야 하고, `DialogueManager`와의 순서 자체는 무관함, 0.3절 근거).

```gdscript
## .dialogue 파일이 게임 상태를 만지는 유일한 창구(결정 필요 14-1). QuestSystem/
## GameState/Events를 직접 노출하지 않는다 — 여기 없는 동작은 .dialogue에서
## 원천적으로 할 수 없어야 한다(강제 방법은 3장 — 이 파일 자체는 "화이트리스트가
## 이것뿐"이라는 선언일 뿐, 런타임 차단 기능은 없음).
extends Node

## if DialogueBridge.quest_state("quest_side_heartland_montsil") == "available"
func quest_state(quest_id: String) -> String:
	return QuestSystem.get_state(quest_id)

## if DialogueBridge.has_item("herb_common")
func has_item(item_id: String) -> bool:
	return GameState.inventory.count_item(item_id) > 0

## if DialogueBridge.has_story_flag("montsil_released")
func has_story_flag(flag: String) -> bool:
	return QuestSystem.has_story_flag(flag)

## do DialogueBridge.accept_quest("quest_main_a1_01_arrival")
## 실패(이미 수주됨 등)해도 조용히 무시한다 — .dialogue는 항상 quest_state()로
## "available"을 먼저 확인한 뒤에만 호출하도록 콘텐츠 규칙(3장 검증기)이 강제한다.
func accept_quest(quest_id: String) -> void:
	QuestSystem.accept(quest_id)

## do DialogueBridge.complete_quest("quest_side_heartland_montsil")
func complete_quest(quest_id: String) -> void:
	QuestSystem.advance(quest_id)

## do DialogueBridge.choose_branch("quest_side_heartland_montsil", "release")
func choose_branch(quest_id: String, choice_id: String) -> void:
	QuestSystem.choose_branch(quest_id, choice_id)

## 현재 활성 목표 문구(기존 QuestNpcPanel._refresh()가 하던 일, 확인:
## quest_npc_panel.gd:80-84).
func active_objective_text_key(quest_id: String) -> String:
	var qdef: Dictionary = Data.get_value("quests", quest_id, {})
	var idx: int = QuestSystem.get_active_objective_index(quest_id)
	var objectives: Array = qdef.get("objectives", [])
	if idx < 0 or idx >= objectives.size():
		return ""
	return String((objectives[idx] as Dictionary).get("text_key", ""))

## npc_id가 giver인 퀘스트 중 지금 말 걸었을 때 열어야 할 것 하나를 고른다
## (quest_npc.gd._refresh_marker()의 "전체 스캔" 방식 재사용 — 확인:
## quest_npc.gd:136-158, SUPPORTED 하드코딩 배열은 만들지 않는다. 우선순위:
## complete_ready > available > active. 없으면 "" — 그러면 1.5절 잡담 폴백).
func find_offer_quest(npc_id: String) -> String:
	var quests: Dictionary = Data.table("quests")
	var available_id := ""
	var active_id := ""
	for quest_id: String in quests.keys():
		if String((quests[quest_id] as Dictionary).get("giver", "")) != npc_id:
			continue
		match QuestSystem.get_state(quest_id):
			"complete_ready": return quest_id
			"available": if available_id.is_empty(): available_id = quest_id
			"active": if active_id.is_empty(): active_id = quest_id
	return available_id if not available_id.is_empty() else active_id
```

**의도적으로 뺀 것(YAGNI)**: 골드/인벤토리 증감, 아이템 지급, 임의 `story_flag` 대입(`set`) 함수는 만들지 않는다 — 보상은 `QuestSystem.advance()`가 `rewards` 테이블(데이터)에서만 지급해야 한다는 규칙(밸런스 수치는 `game/data/`로만)을 대사 쪽 `do` 한 줄로 우회할 구멍을 원천적으로 안 만든다. 15개 퀘스트 콘텐츠 요구사항 어디에도 "대사가 직접 아이템을 준다"는 요구가 없다(narrative 문서 확인) — 필요해지면 그때 `grant_item(id, qty)` 같은 함수를 **데이터가 아니라 이 화이트리스트에** 추가하고 내부에서 `Data.get_value("items", id)` 기반 수량을 강제한다.

예상 줄 수: 약 70~90줄(9장).

---

## 3. 어휘 제한을 실제로 강제하는 방법 (요구 (1))

`DialogueBridge`를 만드는 것만으로는 0.3절 문제가 안 풀린다 — `QuestSystem.choose_branch(...)`가 여전히 `.dialogue`에서 그대로 호출된다(A안이 실제로 그렇게 했다). 강제 수단 2단(1차를 기본 채택, 2차는 결정 필요):

### 3.1 (제안, 기본 채택) 정적 검증 게이트

`tools/qa/validate_tables.py`(확인: 612줄, 이미 `validate_layout.py`/`validate_progression.py`로 모듈 분리 — `from validate_layout import validate_layout` 패턴, 확인: 26-27행)와 같은 자리에 `tools/qa/validate_dialogues.py`(신규, import 1줄 + 호출 1줄만 `validate_tables.py`에 추가)를 둔다. **컴파일된 리소스가 아니라 `.dialogue` 원문 텍스트**를 정규식으로 스캔한다(컴파일 아티팩트는 바이너리라 파싱 비용이 더 큼 — ladder 6번):

- `game/addons/dialogue_manager/compiler/compiler_regex.gd`가 이미 정의한 패턴 재사용(확인: `CONDITION_REGEX`/`MUTATION_REGEX`/`WRAPPED_CONDITION_REGEX`): `if/elif/while/match/when ...`, `do/do!/set/$>/$>> ...`, `[if ...]` 안에서 `<Identifier>.` 형태를 전부 뽑아 그 `Identifier`가 `DialogueBridge`가 아니면 오류.
- 각 `.dialogue` 파일의 `using` 선언 줄(`^using (?<state>.*)$`)이 `DialogueBridge` 이외의 이름을 선언하면 오류.
- 오탐 방지: `self`, 리터럴(문자열/숫자/`true`/`false`), `DialogueBridge` 자체는 허용 목록.

한계(정직하게 명시): 이건 커밋 전 린트지 런타임 방벽이 아니다 — 검증을 건너뛰고 배포하면 여전히 `QuestSystem.xxx()`가 동작한다. 그래도 "테스트·세이브·로컬라이징 통제"라는 실질 목적은 충족한다: 리뷰·CI에서 걸러지고, `DialogueBridge` 화이트리스트 하나만 보면 "대사가 게임 상태에 할 수 있는 일 전체"가 드러난다(애드온 기본값처럼 "사실상 뭐든 가능"이 아니게 됨).

### 3.2 (결정 필요, 14-2) 런타임 상한선 추가

`DialogueManager.game_states`/`_autoloads`/`_has_loaded_autoloads`를 부팅 시(`DialogueBridge._ready()`) 덮어써 `game_states`에 `{"DialogueBridge": self}` 하나만 들어가게 강제하는 안. 정적 검증을 우회한 실수까지 막지만, 애드온 private 관례 변수 이름에 결합돼 버전업 시 조용히 깨질 수 있다(확인 불가 — 향후 버전 소스를 지금 볼 수 없음). 3.1만으로 충분하다고 보고 이번 설계는 **채택하지 않음**을 기본값으로 제안, 최종 채택 여부는 결정 필요.

---

## 4. `.dialogue` 콘텐츠 구조 (요구 (1)(3))

### 4.1 파일 배치

`game/data/dialogues/npc_<npc_id>.dialogue` — giver 1명당 1파일. `act1_hartland.json`의 `giver` 필드를 실제로 집계해 확인한 값: `teo`(5퀘스트: MQ01/02/06/07 + 사이드 웨이포인트), `dami`(1: 몽실이), `rozel`(2: festival_prep + 게시판 일일), `pinto`(2: orefetch + 게시판 일일), `meru`(2: herbrun + 게시판 일일). `giver: "system"`인 MQ03/04/05(3개)는 대사 파일 대상이 아니다 — 이 3개는 애초에 NPC 팝업 진입 경로 자체가 없다(확인: `grep`상 `QuestSystem.accept(` 호출부는 현재 `quest_npc_panel.gd` 1곳뿐, 14-5).

`.dialogue`는 Godot 임포터가 처리하므로(확인: `game/addons/dialogue_manager/import_plugin.gd`가 `EditorImportPlugin`으로 등록됨) **`Data.gd`를 전혀 건드릴 필요가 없다** — `load("res://data/dialogues/npc_dami.dialogue")`로 바로 `DialogueResource`를 얻는다. `game/scripts/core/data.gd`(1148줄 — 이미 D-157 초과 파일)와 `game/scripts/systems/quest_system.gd`(644줄, D-164 소진)는 이 시스템으로 인한 변경이 **0줄**이다.

### 4.2 타이틀 명명 규칙 (제안)

퀘스트 상태 4갈래를 `.dialogue`의 title(`~ 제목`, 확인: `compilation.gd:915`)로 나눈다: `~ <quest_id>_offer` / `~ <quest_id>_active` / `~ <quest_id>_ready` / `~ <quest_id>_done`. `DialogueBalloon`(5장)이 `DialogueBridge.quest_state(quest_id)`로 상태를 읽어 `available→_offer`, `active→_active`, `complete_ready→_ready`, `completed→_done`으로 매핑해 `get_next_dialogue_line(resource, title)`을 호출한다. 몽실이처럼 NPC가 아닌 오브젝트에서 여는 선택 전용 대사는 `~ <quest_id>_branch`(6장).

### 4.3 실제 예시 1개 — `game/data/dialogues/npc_dami.dialogue`

```
using DialogueBridge

~ quest_side_heartland_montsil_offer
다미: [ID: quest_side_heartland_montsil_offer_01]저기... 부탁이 있는데.
다미: [ID: quest_side_heartland_montsil_offer_02]목장 근처에서 하얀 애를 봤는데, 무서워서 못 가겠어.
- [ID: ui_quest_npc_accept]들어볼게 [if DialogueBridge.quest_state("quest_side_heartland_montsil") == "available"]
	do DialogueBridge.accept_quest("quest_side_heartland_montsil")
	=> END
- [ID: ui_quest_npc_close]나중에
	=> END

~ quest_side_heartland_montsil_active
다미: [ID: quest_side_heartland_montsil_active_01]그 근처엔 아직 안 가봤어?
다미: [ID: quest_side_heartland_montsil_objective_hint]{{DialogueBridge.active_objective_text_key("quest_side_heartland_montsil")}}
=> END

~ quest_side_heartland_montsil_ready
if DialogueBridge.has_story_flag("montsil_released")
	다미: [ID: quest_side_heartland_montsil_ready_release]정말 놓아줬어? ...다행이다.
elif DialogueBridge.has_story_flag("montsil_capture_tried")
	다미: [ID: quest_side_heartland_montsil_ready_capture]잡으려고 했다고? 괜찮아, 다치진 않았지?
- [ID: ui_quest_npc_complete]이야기 끝냈어
	do DialogueBridge.complete_quest("quest_side_heartland_montsil")
	=> END
```

`~ quest_side_heartland_montsil_branch`(몽실이=`QuestObject`가 여는 선택 전용 타이틀, 화자 없음, 기존 로컬라이징 키 재사용)은 6.2절.

**검증 필요(솔직히 표시)**: `{{...}}` 인라인 치환(`REPLACEMENTS_REGEX`, 확인: `compiler_regex.gd:20`) 및 `- 텍스트 [if 조건]` 조건부 응답(`WRAPPED_CONDITION_REGEX`, 확인: 같은 파일 8행) 문법 존재 자체는 컴파일러 소스로 확인했지만, 이 예시를 실제로 `godot --headless --import`에 태워 컴파일이 성공하는지는 이번 세션에서 실행하지 않았다 — 구현 단계에서 1회 검증 필요.

---

## 5. `DialogueBalloon` — `show_dialogue_balloon*()`를 쓰지 않는 이유

`DialogueManager.show_dialogue_balloon()`/`show_dialogue_balloon_scene()`(확인: `dialogue_manager.gd:515-538`)은 매번 밸룬을 새로 `instantiate()`해 **`get_current_scene().add_child(balloon)`**으로 붙인다(확인: `_start_balloon()`, 같은 파일 558행). 이건 `UiRoot`가 인벤토리/대장간/우편함/(구)`QuestNpcPanel`을 전부 "상시 자식 노드 + `.visible` 토글"로 관리하는 기존 패턴(확인: `ui_root.gd:20-31`)과 충돌한다 — 이미 트리에 붙어 있는 노드를 넘기면 `add_child()`가 "이미 부모 있음" 에러를 낸다.

**설계(제안)**: `show_dialogue_balloon*()` 계열을 아예 안 쓴다. `example_balloon.gd`가 내부적으로 하는 일(확인: `example_balloon.gd:110-118` `start()`, `139-172` `apply_dialogue_line()`)을 그대로 가져와 `DialogueBalloon`이 `DialogueResource.get_next_dialogue_line(title, extra_game_states)`를 직접 반복 호출한다 — `UiRoot`가 지금 `QuestNpcPanel`을 다루는 것과 동일하게 상시 자식으로 두고 `start(resource, title, extra_game_states)`만 호출한다(공개 계약 함수 시그니처는 애드온 규격 그대로 유지 — `has_method("start")` 계약, 확인: `dialogue_manager.gd:561-564`).

`game/scripts/ui/dialogue_balloon.gd`(신규, `QuestNpcPanel` 대체) 골자:

```gdscript
class_name DialogueBalloon
extends Control

signal close_requested

var dialogue_line: DialogueLine:
	set(value):
		if value == null:
			close_requested.emit()
		else:
			dialogue_line = value
			_apply_line()

@onready var _portrait: ColorRect   # placeholder, 13장
@onready var _name_tab: Label
@onready var _body: Label           # 타이프라이터는 Timer + visible_ratio
@onready var _choice_list: VBoxContainer
var _resource: DialogueResource

func start(resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	_resource = resource
	visible = true
	dialogue_line = await resource.get_next_dialogue_line(title, extra_game_states)

func _apply_line() -> void:
	_name_tab.visible = not dialogue_line.character.is_empty()
	_name_tab.text = tr(StringName(dialogue_line.character))
	_start_typing(dialogue_line.text)
	# 타이핑 끝난 뒤(await) responses.size()>0 이면 선택지 렌더, 아니면 "다음" 대기.

func _confirm() -> void:
	if _is_typing(): skip_typing(); return
	if _choice_list.get_child_count() > 0: return  # 선택은 클릭/상하+확정으로만
	dialogue_line = await _resource.get_next_dialogue_line(dialogue_line.next_id)

func _pick_choice(response: DialogueResponse) -> void:
	dialogue_line = await _resource.get_next_dialogue_line(response.next_id)

func has_pending_choice() -> bool:
	return _choice_list.get_child_count() > 0
```

입력은 project.godot 실제 액션명(확인: `ui_confirm`/`ui_cancel` — `docs/ui/dialogue-balloon.md`가 쓴 "`ui_accept`"는 이 프로젝트 액션명이 아니다, 확인: `game/project.godot` grep 결과 `ui_confirm=`만 존재하고 `ui_accept=` 없음, 코드에서도 `Input.is_action_just_pressed("ui_confirm")`이 8곳에서 쓰임):

| 입력 | 동작 |
|---|---|
| `ui_confirm`(Enter/패드 A) | 타이핑 중 스킵, 완료 시 다음 줄, 선택지 있으면 포커스 확정 |
| `ui_cancel`(Esc/패드 B) | 밸룬 닫기, `DialogueBridge` 호출 없음(선택지 화면도 동일 — 강제 선택 없음) |
| `ui_up`/`ui_down`(Godot 기본값, project.godot 재정의 없음, 확인) | 선택지 포커스 이동 |
| 마우스 좌클릭(선택지 행) | `gui_input` + `MOUSE_BUTTON_LEFT` pressed → 즉시 확정(D-196 패턴, 확인: `inventory_menu.gd`) |
| `interact` | `ui_confirm`과 동일 취급(기존 `QuestNpcPanel._unhandled_input()`이 이미 그렇게 함, 확인: `quest_npc_panel.gd:125`) |

`get_tree().paused=true`+`hud.visible=false`를 그대로 쓴다 — 이 시스템이 다루는 대사는 전부 **퀘스트 수락/완료/분기 트랜잭션이 걸린 대사**라 기존 4종 전체화면 UI와 동일 취급(`docs/ui/dialogue-balloon.md` §6-E의 "잡담·컷신용 반오버레이" 제안은 순수 잡담(narrative `chat` 슬롯)이 실제 구현될 때 재검토 — 이번 스코프 밖).

예상 줄 수: 약 240~280줄(9장).

---

## 6. 몽실이 분기 UI — 구체 설계 (요구 (1))

### 6.1 트리거는 오브젝트, 반응은 NPC (1.3절 요약)

1. 플레이어가 `montsil_rabbit`(`QuestObject`)과 상호작용 → `interact()`가 `Events.object_interacted` emit(기존 그대로, obj_03 진행) → **새 동작**: `branch_choice_id`가 비어 있으면 `get_tree().call_group("quest_npc_ui", "open_dialogue_choice", "quest_side_heartland_montsil")` 호출.
2. `UiRoot.open_dialogue_choice(quest_id)`(신규 메서드, `open_quest_npc()`와 동일한 상호배타 가드) → `dialogue_balloon.start(load("res://data/dialogues/npc_dami.dialogue"), "quest_side_heartland_montsil_branch", [])`.
3. `~ quest_side_heartland_montsil_branch` 타이틀은 화자 없이(몽실이는 말 안 함) 선택지 2개만 제시하고 각각 `do DialogueBridge.choose_branch(...)`로 `story_flags`에 `montsil_released`/`montsil_capture_tried`를 남긴다(이미 `QuestSystem.choose_branch()`가 하는 일, 코드 변경 없음 — 확인: `quest_system.gd:248-259`).
4. 이후 다미에게 "완료 가능" 상태에서 말 걸면(`~ ..._ready` 타이틀) 그 flag를 `if/elif`로 갈라 반응 대사 2종을 보여준다(4.3절 예시) — narrative 요구 "release/capture_attempt 각 1"과 정확히 일치.

### 6.2 화자 없는 선택 전용 타이틀 (기존 로컬라이징 키 재사용)

```
~ quest_side_heartland_montsil_branch
- [ID: quest_side_heartland_montsil_choice_release]그냥 놓아준다
	do DialogueBridge.choose_branch("quest_side_heartland_montsil", "release")
	=> END
- [ID: quest_side_heartland_montsil_choice_capture]붙잡아 본다
	do DialogueBridge.choose_branch("quest_side_heartland_montsil", "capture_attempt")
	=> END
```

두 선택지의 `[ID:]` 키는 **`quest_ko.csv:36-37`에 이미 존재하는 키를 그대로 재사용**(1.3절에서 확인 — 신규 로컬라이징 0). `choices[].id`(`release`/`capture_attempt`)는 `act1_hartland.json`의 `branch.choices[].id`와 문자 그대로 같아야 하며, 3.1절 검증기가 두 집합의 일치를 확인한다(9-2 검증 규칙).

### 6.3 D-94와의 관계

D-94("결과·보상 완전 동일, 서사 연출만 분기")는 그대로 유지된다 — `choose_branch()`가 하는 일은 여전히 `story_flags`에 flag 하나 남기는 것뿐이고 `rewards`/`on_complete`는 분기와 무관하다(`quest_system.gd:219-241` 확인, `advance()`는 `choose_branch` 결과와 무관하게 같은 `rewards`를 지급). 이 문서는 "언제·어떻게" 고르는지만 바꾼다.

---

## 7. UI 배치 (요구 (8) 요약 — 상세는 `docs/ui/dialogue-balloon.md`)

레이아웃은 `docs/ui/dialogue-balloon.md` §1을 그대로 채택(하단 중앙 `(40,240)` `560x96`, 초상 64×64, 이름표, 본문, 선택지 최대 4개). 그 문서 §6 결정 필요 항목 중 엔지니어링으로 답이 나오는 것만 확정:

| §6 항목 | 확정 |
|---|---|
| §6-A 애드온 채택 | **채택**(0장, C안) |
| §6-D `interact`=확인 | **예**(5장 표, 기존 `QuestNpcPanel` 전례 유지) |
| §6-E paused 여부 | **`paused=true`**(5장 근거 — 퀘스트 트랜잭션 대사이므로 기존 4종과 동일 취급) |
| §6-B 내레이션 슬롯 접기 | **v1 범위 밖**(YAGNI) — 6.2절 화자 없음 선택 전용 타이틀은 이름표만 숨기고 초상 슬롯은 회색 placeholder를 그대로 둔다(레이아웃 재계산 코드를 새로 안 만들기 위한 타협) |
| §6-C `ui_cancel` 건너뛰기 | **아니오**, 닫기만(5장 표) |
| §6-F 자동 진행 | **v1 범위 밖**(14-3 결정 필요로 이월) |

테마 색 키는 `docs/ui/dialogue-balloon.md` §5 그대로(신규 키 없음 — `theme.tres`의 `parchment_fill`/`wood_frame`/`text_default`/`text_muted`/`Inventory/colors/focus`/`Inventory/styles/focus_highlight` 전부 확인됨).

---

## 8. 세이브 (요구 (4))

**결론: 신규 세이브 필드 불필요**:

- 밸룬은 무상태다. 열 때마다 `DialogueBridge.quest_state()`로 현재 상태를 읽어 해당 title부터 다시 재생한다 — "몇 번째 줄이었는지" 저장 안 함(대사 도중 종료해도 다음에 그 상태 대사를 처음부터 다시 봄, 손실 아닌 의도된 동작).
- `choose_branch()`의 결과(`branch_choice`, `story_flags`)는 이미 `QuestSystem.to_dict()`가 저장한다(확인: `quest_system.gd:591-600` `_active`에 `branch_choice` 포함, `_story_flags` 별도 필드) — `SaveManager`는 `quest_system` 슬라이스 전체를 그대로 왕복시킨다(확인: `save_manager.gd:109-110,285-286`).
- 잡담(1.5절) 로테이션 인덱스(`_npc_visit_lines`)는 지금도 세이브 안 됨 — 재시작하면 처음 인사말로 리셋되는 기존 동작 그대로, 이번 설계가 바꾸지 않는다.
- "이 NPC를 만난 적 있다" 류 신규 플래그는 이번 스코프(퀘스트 4상태+분기)에 불필요(YAGNI) — 필요해지면 `QuestSystem.to_dict()`에 필드를 순수 추가하면 되고 구필드 삭제가 아니므로 세이브 하위호환은 안 깨진다.

---

## 9. 파일 크기 예상 (요구 (5), D-157)

| 파일 | 종류 | 예상 줄 수 | 500줄 상한 |
|---|---|---|---|
| `game/scripts/systems/dialogue_bridge.gd`(신규 오토로드) | 코드, 2장 | 약 70~90줄 | 여유 큼 |
| `game/scripts/ui/dialogue_balloon.gd`(신규, `QuestNpcPanel` 대체) | 코드, 5장 | 약 240~280줄 | 여유 있음 |
| `game/scripts/ui/ui_root.gd`(기존 수정) | `quest_npc_panel: QuestNpcPanel` → `dialogue_balloon: DialogueBalloon` 필드 교체, `open_quest_npc()` 내부를 `DialogueBridge.find_offer_quest()`+`load()` 호출로 교체, `open_dialogue_choice()` 신규 메서드 1개 추가(6.1절) | 현재 134줄 → 약 150~160줄 | 여유 큼 |
| `game/scripts/world/quest_object.gd`(기존 수정) | `interact()`에 `branch_choice_id.is_empty()` 분기 1개 추가(1.3절) | 현재 214줄 → 약 219줄 | 여유 큼 |
| `game/scripts/ui/hud.gd`(기존 수정) | `_on_npc_talked` 구독·로그 push 제거, `greeting_key_for_chat()`로 개명·공개(1.5절) | 현재 486줄 → 약 484~487줄(순변화 미미) | 여유 큼 |
| `tools/qa/validate_dialogues.py`(신규) | 파이썬, 3.1절 | 약 100~150줄(참고: `validate_layout.py`가 비슷한 역할의 분리 모듈, 정확한 줄 수는 미확인) | Python이라 D-157 대상 아님(관례상 분리 파일 유지) |
| `game/scripts/ui/quest_npc_panel.gd` | **삭제** | -126줄 | — |
| `game/scripts/core/data.gd` | **변경 없음** | 0줄 | — |
| `game/scripts/systems/quest_system.gd` | **변경 없음**(D-164 소진, 기존 4개 함수로 충분) | 0줄 | — |
| `game/tests/unit/test_quest_layout_spawner.gd` | 단언 1줄 교체(1.4절) | 151줄 → 약 152줄 | — |
| `game/data/dialogues/npc_{teo,dami,rozel,pinto,meru}.dialogue`(신규 5개) | 데이터(D-157 대상 아님) | giver당 퀘스트 수 × 상태 4개 × 평균 2~3줄 — `teo`(5퀘스트)가 가장 커서 약 80~120줄, 나머지 30~50줄 | 해당 없음 |

---

## 10. 헤드리스 테스트 (요구 (6))

### 10.1 `--import` 필수 (프로젝트 규칙과 이미 일치)

`.dialogue`는 `EditorImportPlugin`(확인: `import_plugin.gd`)이 처리하는 임포트 자산이다 — `CLAUDE.md`가 이미 요구하는 "`--import` → GUT → 씬 실행" 3단계 검증 순서가 이 시스템에도 그대로 필요하다(신규 요구 아님).

### 10.2 오프라인(비-Godot) 검증

3.1절의 `validate_dialogues.py`는 Godot 없이 `.dialogue` 원문 텍스트만 읽으므로 완전 오프라인 — 어휘 위반, `using` 위반, `[ID:]` 키가 `quest_ko.csv`/`ui_ko.csv`(11장)에 실존하는지, `choices[].id` 집합이 `quests` 테이블의 `branch.choices[].id`와 일치하는지(9-2 규칙, 몽실이류) 검사.

### 10.3 Godot 헤드리스(GUT + 스모크)

- **GUT 단위**: `game/tests/unit/test_dialogue_bridge.gd`(신규) — `DialogueBridgeScript.new()` + `add_child_autofree()`로 격리(`test_quest_system.gd`와 동일 관례, 확인). 렌더링 없음, 100% 결정적. 대사 자체의 조건 분기 정확성은 `DialogueResource.get_next_dialogue_line()`(순수 로직, `Expression`/`RegEx` 연산)을 직접 호출하는 유닛 테스트로도 검증 가능 — 밸룬 렌더보다 먼저, 더 싸게 잡아낸다.
- **스모크**: `DialogueBalloon`은 `Control`+`Label`+`Timer` 조합이라(`QuestNpcPanel`과 동일 근거) 헤드리스에서 실제 렌더 없이 동작한다. 타이프라이터는 `skip_typing()` 공개 함수를 테스트가 직접 호출해 real-time 대기를 없앤다(`docs/qa/dialogue-system-test-plan-template.md`가 이미 이 패턴을 전제, 확인).
- **신규**: `smoke_dialogue_montsil_branch.gd` — 몽실이를 `obj_03` 직전까지 진행 → `montsil_rabbit.interact()` 직접 호출(또는 `Events.object_interacted.emit()`) → `open_dialogue_choice` 그룹 호출 확인 → `release`/`capture_attempt` 각각 선택 → `QuestSystem.has_story_flag(...)`와 `get_state(...) == "active"`(아직 `advance()` 전) 확인 → 다미 `_ready` 타이틀 재생 후 `complete_quest` → `completed` 확인. **주의**: 기존 스모크 8개가 Windows 하드코딩 `user://` 가드로 리눅스에서 결정적으로 `exit(1)`하는 문제(확인: `smoke_quest_npc_panel.gd` 등에 `C:/Users/...` 하드코딩)를 이 신규 파일에서 반복하지 않는다 — 처음부터 상대/설정 가능 경로로 작성.

### 10.4 `--check-only` 파싱 게이트

신규 `.gd` 파일(`dialogue_bridge.gd`, `dialogue_balloon.gd`) + 수정 파일(`ui_root.gd`, `quest_object.gd`, `hud.gd`)은 커밋 전 `godot --headless --check-only`로 문법 오류만 거른다 — 이 문서는 코드를 만들지 않으므로 이번 세션 실행 대상 없음(구현 단계 수행).

---

## 11. 로컬라이징 키 규칙 (요구 (3))

- **키 소스는 파일 2개, 용도로 나뉜다**: 퀘스트 관련 key는 `game/localization/quest_ko.csv`(70줄, 확인 — `quest_main_a1_01_arrival_title` 등 기존 title/desc/objective key가 전부 여기 있다), 일반 UI/NPC 잡담 key는 `game/localization/ui_ko.csv`(388줄 — `npc.<id>.greeting`/`everyday.N` 등, 확인: `hud.gd:322-330`). **신규 퀘스트 대사 key는 `quest_ko.csv`에 추가**(용도가 퀘스트 진행이므로), **화자 이름표는 `ui_ko.csv`에 추가**(용도가 NPC 신원 표시로 기존 `npc.<id>.*` 네임스페이스와 같으므로).
- **신규 퀘스트 대사 key 규칙**: `quest_<id뒷부분>_<state>_<번호>`(예: `quest_side_heartland_montsil_offer_01`), 선택지는 `_choice_<id>`, 분기 반응은 `_ready_<outcome 접미사>`(4.3절 예시의 `_ready_release`/`_ready_capture`).
- **화자 이름표**: `npc.<slug>.name`(신규 5개, `teo/meru/pinto/rozel/dami`) — `ui_ko.csv`의 기존 `npc.<id>.greeting`/`everyday.N` 네임스페이스와 공유하되 `.name` 접미사는 처음 추가라 충돌 없음. `characters.md`가 이미 확정한 표기(예: "다미")를 그대로 옮긴다.
- **몽실이 분기 선택지 2개는 신규가 아니라 재사용**: `quest_side_heartland_montsil_choice_release`/`_choice_capture`가 `quest_ko.csv:36-37`에 이미 있다(1.3절에서 확인) — 이 문서가 새로 요구하는 키가 아니다.
- **`.dialogue` 파일 안의 실제 텍스트는 `[ID: <key>]` 태그로 감싼다** — 안 그러면 애드온이 원문 텍스트 자체를 번역 키로 쓴다(확인: `dialogue_manager.gd:625-657` `translate_text()` — `translation_key`가 비어 있거나 원문과 같으면 `tr(data.text)`를 그대로 호출, 즉 raw 문자열이 곧 키가 됨). `DialogueManager.translation_source`를 `DMConstants.TranslationSource.CSV`로 명시 설정(제안, `DialogueBridge._ready()` 또는 부팅 스크립트에서 1줄)해 `[ID:]` 키가 항상 `tr(translation_key)` 경로를 타게 한다 — `ui_ko.ko.translation`/`quest_ko.ko.translation`이 이미 `project.godot`의 `locale/translations`에 등록되어 있어(확인: `game/project.godot:263`) `TranslationServer`에 별도 등록 코드가 필요 없다.
- `[ID: xxx]`의 `xxx`는 CSV의 `key` 컬럼과 문자 그대로 같아야 한다 — 10-2 검증기가 확인.
- `on_complete.cutscene_key`(예: `main_a1_s07_heartland_dami_04`)는 씬/컷신 식별자 관례고 CSV key 관례와 다르므로 그대로 재사용하지 않는다(14-4 결정 필요로 유지).

---

## 12. 웹 내보내기 호환 (요구 (7))

`DialogueBalloon`/`DialogueBridge`는 `Control`/`Node`+`Timer`만 쓰고, `.dialogue` 컴파일 자체는 `game/addons/dialogue_manager/compiler/*`가 순수 GDScript(정규식·`Expression`)로 처리한다 — 렌더링 의존 코드가 없다. `export_plugin.gd`는 에디터 전용 파일 제외 로직만 있고 플랫폼(web) 배제 코드는 없다(확인, 단 공식 웹 호환 보증 문서를 찾은 것은 아님 — 추측 표시 유지). `docs/ui/dialogue-balloon.md` §7이 이미 확인한 `stretch/mode=canvas_items`+정수 배율이 좌표계를 처리하므로 이 문서가 추가할 웹 대응은 없다. 선택지 행(세로 16px)이 3배 정수 배율에서 48px가 되어 터치 타깃 최소 권장치(~44px)를 충족한다(같은 문서 §7 계산 재인용).

---

## 13. 프로토타입 에셋

`pixel-artist` 요청 목록(이번 세션 배정 없음): NPC 5명(teo/meru/pinto/rozel/dami) 초상 64×64 PNG. 없는 동안은 `docs/ui/dialogue-balloon.md` §4 그대로 64×64 단색 사각형(테두리 포함) `ColorRect` placeholder.

---

## 14. 결정 필요 항목

1. **화이트리스트 함수 목록 확정**: 2장의 `DialogueBridge` 7개 함수로 15개 퀘스트 콘텐츠를 다 감당할지, 아니면 아이템 지급형 함수(`grant_item` 등)가 실제로 필요한지 — narrative-writer가 실제 원고를 쓰다 보면 드러날 수 있어 원고 착수 전 1차 확인 요청.
2. **3.2절 런타임 상한선(애드온 private 내부 덮어쓰기)을 채택할지**: 채택하면 정적 검증(3.1)을 우회한 실수까지 막지만 애드온 버전업 시 조용히 깨질 위험을 코드베이스가 안게 된다. 미채택(현재 제안 기본값)이면 강제력은 CI/리뷰 시점으로 한정된다.
3. **자동 진행(auto-advance) 접근성 옵션을 이번 범위에 넣을지** — 넣으면 `Settings`에 `dialogue_auto_advance: bool` + 지연 시간(반드시 `game/data/` 또는 `tuning.gd`, 하드코딩 금지)이 새로 필요. GDD/기존 결정 어디에도 요구 없어 범위 밖으로 제안.
4. **`on_complete.cutscene_key`가 가리키는 `main-storyline.md` 원고를 `_done` 타이틀 실제 대사로 얼마나 그대로 옮길 수 있는지** — 콘텐츠 집필 범위 문제, 엔지니어링만으로 답 안 나옴.
5. **`giver: "system"`인 3개 메인 퀘스트(MQ03/04/05)의 수주 경로 자체가 이 대사 시스템과 무관하게 이미 갭인지** — 확인된 사실: 현재 `QuestSystem.accept(`를 부르는 UI는 `quest_npc_panel.gd` 1곳뿐이다. 이 3개가 실제로 어떻게 수주되는지는 이 설계가 다루지 않는다는 점만 확인해 남긴다 — 별도 결정 필요 항목인지 game-designer 확인 요청.
6. **나머지 11개 퀘스트(몽실이 제외)의 `_offer/_active/_ready/_done` 실제 대사 원고** — 이 문서는 스키마·연결 지점·파일 배치만 정의했다. `dialogue-content-requirements-act1-hartland.md`가 이미 물량표를 냈으니 narrative-writer가 11장 key 규칙에 맞춰 채워야 한다.
7. **게시판 일일 의뢰(`daily_template`, giver `rozel`/`meru`/`pinto`) 대사가 매일 리롤되는 `pool:` 대상(몬스터/아이템)을 대사 안에서 언급해야 하는지** — 언급 안 하면 `_offer`/`_active` 타이틀이 고정 텍스트로 충분, 언급해야 하면 `DialogueBridge`에 `daily_target_name(quest_id)` 함수가 추가로 필요 — narrative 확인 요청.
8. **`quest_object.gd`의 `open_dialogue_choice` 호출을 `"quest_npc_ui"` 그룹에 얹을지, 별도 그룹으로 뺄지**(6.1절) — 이름은 "NPC" UI인데 오브젝트가 호출하는 게 어색할 수 있다. 그룹을 분리하면 `UiRoot`가 구독 지점을 하나 더 늘려야 한다 — 이 문서의 기본 제안은 "그대로 `quest_npc_ui` 재사용"(그룹을 늘리지 않는 쪽, ladder 6번).
9. **1.5절 "잡담 폴백"(퀘스트 없는 상태의 인사말)을 이번 M6 범위에 포함할지, 순수 "퀘스트 대사"만 먼저 내보내고 잡담은 다음 단계로 미룰지** — 포함하면 요구 (1)의 "토스트 대체"가 완전해지지만 `DialogueManager.create_resource_from_text()` 경로 검증(즉석 컴파일이 헤드리스에서 항상 성공하는지)이 추가로 필요하다.
