# 대사 시스템 설계 v1 (개발 순서 ⑪, D-145 로드맵 6번째)

> 작성: godot-engineer · 대상 브랜치: `stage/m6-int`(읽기 전용 검토, 이 문서 1개만 신규 작성).
> 코드·데이터·씬·`docs/brd/04-decisions.md` 미수정, 커밋 없음.
> 골격: 각도 A(addon-max, 심사 23점) — `.dialogue` 파일이 `QuestSystem`을 `using` 선언으로 직접 호출하고, `QuestNpcPanel`은 그대로 둔 채 대사 풍선을 병렬 레이어로 얹는다.
> 접목: hybrid/data-min 심사안(23점/16점)에서 4건을 선택 편입했다 — §0.2에 근거와 함께 명시.
> 표기: **(확인)** = 이 워크트리 소스를 직접 grep/read로 확인, **(제안)** = 이 문서의 신규 설계 판단, **(결정 필요)** = 11장으로 넘긴 질문.

---

## 0. 배경과 골격 선택

D-145 로드맵 6번째 단계. 현재 "대사"라 부를 것은 `Hud._on_npc_talked`의 좌하단 3초 토스트 한 줄(`npc.<id>.greeting/everyday/after_*`)뿐이고 **(확인**: `game/scripts/ui/hud.gd:322-330`, 화이트리스트 `[teo,meru,pinto,rozel,dami]`는 `hud.gd:330`**)**, `QuestNpcPanel`은 수락/완료 전용으로 초상·타이프라이터·선택지가 없다 **(확인**: `game/scripts/ui/quest_npc_panel.gd`**)**. `addons/dialogue_manager`(v3.10.5)는 오토로드 등록만 돼 있고 미배선이다 **(확인**: `game/project.godot:32,45`**)**.

### 0.1 각도 A를 고른 이유
- B안(자체 JSON 대사 러너)은 조건·분기가 늘어날수록 손코딩 표가 커진다. 이미 오토로드로 등록된 애드온이 `if/elif/do/set/[ID:]/CSV 번역`을 전부 갖추고 있으므로(사다리 2번: 이미 코드베이스에 있다) 새로 만들지 않는다.
- C안(전용 `DialogueBridge` 오토로드로 `QuestSystem` 호출을 전부 감싸는 안)은 채택하지 않는다. `quest_system.gd`가 이미 644줄로 500줄 상한(D-157)을 넘겨(확인) 더 건드리지 않는 게 원칙인데, 브리지 전면 도입은 어차피 골격을 C안으로 바꾸는 것이라 채택 지시(addon-max 골격 유지)와 어긋난다. 대신 §3.3에서 **범위를 좁힌 버전**(방문 횟수 헬퍼 1개)만 편입한다.

### 0.2 편입한 접목 아이디어 (출처 표기)
1. **(data-min)** 대사 참조 무결성 검사는 새 스크립트가 아니라 기존 `tools/qa/validate_tables.py`에 편입 — 이미 `validate_quests`/`validate_world_objects`가 있음(확인: `tools/qa/validate_tables.py:410,375`). → §9.2.
2. **(data-min)** 밸룬은 무상태(열 때마다 처음부터 재생)이며 `skip_typing()` 공개 함수를 갖는다 — 실시간 대기 없이 헤드리스에서 결정적으로 검증하기 위함. → §7.4, §9.3.
3. **(hybrid)** `DialogueManager.show_dialogue_balloon_scene()`을 거치지 않고, `NpcDialogueController`(UiRoot 상시 자식)가 `DialogueResource.get_next_dialogue_line()`을 직접 await한다 — 애드온 공식 경로 이탈이므로 D-250으로 별도 결정 필요. → §3.2.
4. **(addon-max §8-3 보강, 검증 이후 수정)** `after_*` 3줄 로테이션을 잃지 않도록 `NpcDialogueController.visit_count(npc_id)` 함수 1개만 추가한다. **당초안(`using NpcDialogueController`)은 컴파일 에러라 폐기**(§3.3/§3.4, D-242) — 대신 컨트롤러가 자기 자신을 `extra_game_states`로 넘기고 `.dialogue`는 접두어 없이 `visit_count("dami") % 3`을 호출한다. 새 오토로드는 여전히 없다. → §3.3, D-242.

**기각한 접목**: (hybrid) `DialogueBridge`로 `QuestSystem`/`GameState` 접근 전체를 감싸는 안 — §0.1 사유로 기각. (addon-max) 로직: 위 4건 외 나머지 접목 후보는 이미 addon-max 원안 안에 포함돼 있어 별도 편입 표기 불필요.

---

## 1. 목표 · 비목표

**목표**: 1막 하틀랜드 giver 5명(teo/meru/pinto/rozel/dami, `hud.gd:330` 화이트리스트와 동일)의 수락 전/진행 중/완료 가능/완료 후 대사, 몽실이(`quest_side_heartland_montsil`) 분기 선택 UI.

**경고(검증 이후 추가, D-258 — §4.5 참고)**: 위 4가지 상태 중 "진행 중/완료 가능/완료 후"는 teo의 메인 4퀘스트를 제외한 나머지(다미/로젤/핀토/메루의 사이드·일일 퀘스트, teo의 waypoint 퀘스트)에서는 **현재 설계로는 실제 플레이 경로로 도달 불가능**하다 — 이 문서만으로는 목표를 달성할 수 없다. 근거와 결정 필요 항목은 §4.5.

**비목표**: `QuestNpcPanel` 대체, 세이브 스키마 변경, `quest_system.gd`/`game_state.gd`에 함수 추가(둘 다 500줄 상한 초과 상태, D-157/D-164), 신규 로컬라이징 CSV 파일, `main`/`system` giver 3개 퀘스트(shadowfall/theshard/reclaim, 확인: `act1_hartland.json` giver="system")의 NPC 대사(대화 상대 없음, 범위 밖).

---

## 2. 데이터 형식

`game/data/dialogue/*.dialogue` (Dialogue Manager 컴파일러 문법, 애드온 그대로 사용). 신규 JSON/CSV 스키마 없음. 예시 2개 전문은 §8, §9.4.

---

## 3. 런타임 구조

### 3.1 신규 파일 (D-157 500줄 상한 확인 완료)

| 파일 | 역할 | 예상 줄 수 |
|---|---|---|
| `game/scripts/ui/dialogue_balloon.gd` + `scenes/ui/DialogueBalloon.tscn` | 대사 풍선(CanvasLayer). `docs/ui/dialogue-balloon.md`(확인: 181줄, v0.1) 좌표·입력 계약 구현. `start()`은 구현하지 않는다(§3.2, D-250) — 대신 `show_line(line: DialogueLine)`/`show_responses(responses)`/`skip_typing()`/`is_typing()` 공개 API만 갖는다 | 220~260 |
| `game/scripts/ui/npc_dialogue_controller.gd` | `UiRoot`의 상시 자식. 진입 경로는 **`"npc_dialogue_ui"` 그룹 메서드 2개뿐**(제안, 검증 이후 정정 — 예전 판의 "`Events.npc_talked` 구독" 경로는 폐기, §4.3 참고): (1) `open_npc_dialogue(npc_id: StringName)` — giver 잡담, 파일·title을 컨트롤러가 §4.3 매핑 규칙으로 직접 계산, (2) `open_dialogue_resource(resource: DialogueResource, title: String, extra_state: Object = null)` — 몽실이류, 호출자(`QuestObject`)가 리소스·title·자기 자신을 이미 알고 넘김(§4.2). 두 경로 모두 `res.get_next_dialogue_line(title, extra_game_states)`를 직접 await하고(§3.2, `extra_game_states`는 (1)에서 `[self]`, (2)에서 `[self, extra_state]`) 결과를 `dialogue_balloon.gd`에 넘긴다. `visit_count(npc_id)`(§3.3), giver→`.dialogue`/title 매핑(§4.3 신규), 재생 중 재진입 가드(§4.4, D-259), 전체화면 모달이 열려 있는 동안의 입력 소비 가드(§4.4, D-254)까지 이 파일 하나가 맡는다 — 예상 줄 수는 그만큼 늘렸다(검증 이후 상향) | 130~170 |

### 3.2 D-250: 왜 `show_dialogue_balloon_scene()`을 안 쓰는가 (hybrid 접목, 검증 이후 보강)
애드온 공식 경로는 `DialogueManager.show_dialogue_balloon_scene(scene, resource, title, extra_game_states) -> Node`이며 balloon이 `has_method("start")`를 가져야 하고 실패 시 assert로 크래시한다 **(확인**: `game/addons/dialogue_manager/dialogue_manager.gd:530-538,554-564`**)**. 이 경로는 balloon을 매번 새 인스턴스로 만들어 `get_current_scene.call().add_child(balloon)`으로 씬 트리에 붙이는데, `smoke_quest_rewards_ui.gd:6` 주석이 명시하는 "UiRoot를 `current_scene`으로 두지 않는" 관례와 재부모 시점이 충돌할 위험이 있고(확인: 코드 구조상 위험, 실행 검증 안 됨 — 추정 표시), GUT이 매번 새로 생기는 인스턴스를 잡기도 번거롭다.

**놓쳤던 대안(검증 이후 추가)**: 애드온은 이 재부모 지점을 `DialogueManager.get_current_scene: Callable`로 공개 오버라이드할 수 있게 열어 둔다 — 기본값은 `Engine.get_main_loop().current_scene`이고 주석이 "Override if your game manages the current scene itself"라 명시한다 **(확인**: `dialogue_manager.gd:56-61`**)**. 즉 `DialogueManager.get_current_scene = func(): return ui_root`로 한 줄만 덮어써도 공식 경로(`show_dialogue_balloon_scene`)를 그대로 쓰면서 재부모 위험을 없앨 수 있다. 이 대안은 §11 D-250에 대안 B로 추가한다.

**시그널 비대칭(검증 이후 발견, 확인)**: 직접 호출 경로(`get_next_dialogue_line`)는 `_start_balloon` 내부에서만 발생하는 `dialogue_started` 시그널을 절대 emit하지 않는다 — `_start_balloon`은 `show_dialogue_balloon_scene` 경로에서만 호출되기 때문이다(확인: `dialogue_manager.gd:554-557`). 반면 `get_next_dialogue_line`의 공개 래퍼는 줄이 바닥나면 항상 `dialogue_ended.emit(resource)`를 호출한다(확인: `dialogue_manager.gd:90-94`). 즉 이 설계는 `dialogue_started` 없이 `dialogue_ended`만 발생하는 비대칭 상태가 된다 — 대사 시작을 감지해야 하는 향후 리스너(예: BGM 덕킹, 다른 NPC AI 일시정지)가 생기면 `dialogue_started`에 의존할 수 없다는 뜻이므로 D-250에 명시한다.

**(결정 필요, D-250, 안 갱신)**: 대안 A(직접 호출, 원안 유지 — 시그널 비대칭 감수) vs 대안 B(`get_current_scene` 오버라이드 + 공식 `show_dialogue_balloon_scene()` 사용 — 시그널 정상, balloon 인스턴스가 매번 새로 생겨 GUT 결합이 번거로움) 중 채택.

### 3.3 방문 횟수 헬퍼 (addon-max §8-3 보강, 새 오토로드 없음, **검증 이후 전면 수정**)
**당초안 폐기 사유**: `using NpcDialogueController`는 컴파일 자체가 실패한다(§3.4) — `NpcDialogueController`가 UiRoot의 평범한 자식(오토로드 아님)이기 때문. `.dialogue` 임포트가 막히면 `visit_count` 호출 여부와 무관하게 이 시스템 전체가 로드되지 않는다.

**수정안**: 컨트롤러는 `using` 없이, 자기 자신을 `extra_game_states`로 넘긴다. 애드온은 익명 함수 호출을 해석할 때 `_get_game_states(extra_game_states)`를 순회하며 이름이 일치하는 메서드를 찾으므로(확인: `dialogue_manager.gd:1120-1128`, `_thing_has_method`/`_resolve_thing_method`) `using` 선언 없이도 `visit_count(...)`를 접두어 없이 호출할 수 있다.
```gdscript
# npc_dialogue_controller.gd 내부, 새 필드 1개 + 함수 1개만 추가
var _visits: Dictionary = {}  # npc_id(String) -> int, 세이브 안 함(§6)

func visit_count(npc_id: String) -> int:
    return _visits.get(npc_id, 0)

func _play(dialogue_path: String, title: String, npc_id: String) -> void:
    var res: DialogueResource = load(dialogue_path)
    var line: DialogueLine = await res.get_next_dialogue_line(title, [self])  # self를 extra_game_states로 주입
    _visits[npc_id] = visit_count(npc_id) + 1
    ...
```
`.dialogue`에서는 `using QuestSystem`만 선언하고(QuestSystem은 실제 오토로드이므로 정상 — §3.4), `visit_count("dami") % 3 == 1` 형태로 접두어 없이 호출한다. 재시작 시 0으로 리셋(비저장, §6) — 세션 내 다양성만 보장, 세이브 간 연속성은 없음(제안, D-242에서 확정 필요).

### 3.4 `using` 선언과 오토로드 접근 — **컴파일 단계에서 막힌다(검증 이후 정정)**
`.dialogue` 파일 최상단에 `using <이름>`을 쓰면 컴파일러가 `USING_REGEX`(`^using (?<state>.*)$`)로 파싱한다 **(확인**: `game/addons/dialogue_manager/compiler/compiler_regex.gd:6`**)**. 이 시점에 컴파일러는 그 이름을 **`project.godot`의 `[autoload]` 섹션 키 목록**(`DialogueManager` 자신은 제외)과 즉시 대조하고, 목록에 없으면 **`ERR_UNKNOWN_USING`(=135)를 컴파일 에러로 추가하고 임포트를 실패시킨다** **(확인**: `compilation.gd:148,163-165`(`get_autoload_names()` 대조 후 `add_error`), `compilation.gd:830-836`(`get_autoload_names()`가 `project.godot` `[autoload]` 섹션 키만 반환), `constants.gd:117`(`ERR_UNKNOWN_USING = 135`), `game/project.godot:19-32`(autoload 키 목록에 `NpcDialogueController` 없음)**)**. 즉 이전 판(§0.2 원안)이 말한 "못 찾으면 `runtime.unknown_autoload` 에러만 출력, 크래시 아님"은 **`using`이 성공적으로 통과한 뒤 런타임에 오토로드를 못 찾는 별개 경우**(예: 오토로드 등록은 됐지만 아직 트리에 안 올라온 시점)의 이야기이지, 컴파일 단계에서 이름이 애초에 화이트리스트에 없는 이번 경우와 다르다.

**따라서 `.dialogue`에서 `using`으로 선언 가능한 이름은 `QuestSystem` 하나뿐이다.** `NpcDialogueController`는 `using` 대상이 될 수 없고, §3.3처럼 `extra_game_states`로만 주입한다. `QuestSystem`은 이미 오토로드이므로(확인: `project.godot:26`) `using QuestSystem` 한 줄로 `.dialogue`에서 `QuestSystem.get_state(...)`/`QuestSystem.choose_branch(...)`를 함수 이름 그대로 호출할 수 있다.

---

## 4. 퀘스트 연동

### 4.1 유지하는 계약 (변경 없음, 전부 확인됨)
`Events.npc_talked(npc_id)` 시그널(`quest_npc.gd:71-81`), `QuestNpc.talk()` 공개 함수(스모크가 UI 없이 직접 호출, `smoke_quest_layout.gd:134,166`), `"quest_npc_ui"` 그룹 + `open_quest_npc(npc_id)` 메서드 계약(`quest_npc.gd:75`), `QuestNpcPanel.SUPPORTED` 4개 하드코딩 배열과 그 열림 흐름(`quest_npc_panel.gd:6-7,56`) — 대사 풍선은 이 위에 병렬로만 얹힌다(addon-max 원칙, §0.1). **주의(검증 이후, §4.5 참고)**: `SUPPORTED`를 "변경 없음"으로 유지하는 이 방침은 §1 목표(giver 5명 전원의 진행 중/완료 가능/완료 후 대사)와 정면으로 상충한다 — D-258 확정 전까지는 이 항목의 "변경 없음"을 최종으로 보지 말 것.

### 4.2 몽실이 분기: `dialogue_path` 필드
`quest_object.gd`는 이미 `@export var branch_choice_id: StringName`을 갖고, 상호작용 즉시 `QuestSystem.choose_branch(branch_quest_id, branch_choice_id)`를 호출한다 **(확인**: `game/scripts/world/quest_object.gd:29,107-108`**)**. `world_objects.json`의 `montsil_rabbit`은 이 값을 `"release"`로 하드코딩하고 주석에 "선택 UI 없음 → 첫 상호작용=release 고정"이라 명시한다 **(확인**: `game/data/world_objects.json:120-134`**)**.

제안: `branch_choice_id`(즉시 확정) 대신 `dialogue_path: String`(빈 문자열이면 기존 동작 유지, 하위호환) 필드를 추가한다. 값이 있으면 상호작용 시 그 `.dialogue` 리소스를 열어 플레이어가 선택지를 직접 고르고, 응답의 `do` 절이 분기를 확정한다(구체적인 호출 방식은 아래 **타이밍 결함**에서 밝혀진 문제 때문에 `QuestSystem.choose_branch(...)` 직접 호출에서 `resolve_branch_outcome(choice_id)`로 바뀐다 — §8 예시 전문).

**타이밍 결함(검증 이후 발견, blocker) — 아래 diff는 폐기, §4.2-수정판으로 대체**: `quest_object.gd.interact()`의 실제 흐름은 `Events.object_interacted.emit(object_id)`(확인: 함수 내 96-110행 구간 중 대략 105행) → (기존) `branch_quest_id` 분기 → `vanish_on_complete`면 `queue_free()`(확인: 같은 함수, emit 직후·109행 부근)의 **완전 동기 순서**다. 위 원안대로 그 분기 자리에 `dialogue_path` 열기(비동기 `call_group` 호출, 응답은 나중에 옴)를 끼워 넣으면 `object_interacted.emit()`(→`obj_03` 완료 → `complete_ready`로 전이, `quest_system.gd:298-336`)과 `queue_free()`(월드에서 몽실이 즉시 사라짐)가 **플레이어가 아직 아무 선택도 하기 전에** 이미 끝나 버린다. 대사가 중간에 끊기면(D-241 무효화 규칙 적용 전 상태, 씬 이탈 등) `_resolve_branch_default()`(`quest_system.gd:262-272`)가 조용히 `choices[0]`(release)로 확정하고, `choose_branch()` 자체도 `_active`에 없어도(퀘스트가 아직 `active`가 아니어도) `_story_flags[outcome_flag]=true`를 무조건 세운다(확인: `quest_system.gd:248-259`) — 즉 몽실이 퀘스트를 **수락하기도 전에** 오브젝트만 먼저 상호작용해도 조우 진행·분기 플래그가 확정돼 버릴 수 있다.

**수정판(제안, D-262)**: emit/분기/vanish를 dialogue_path 경로에서는 상호작용 시점이 아니라 **플레이어가 실제로 응답을 고른 뒤**로 미룬다. `NpcDialogueController`가 이미 쓰는 자기-주입 패턴(§3.3)을 그대로 재사용해, `open_dialogue_resource(resource, title, extra_state)`(§3.1)를 호출할 때 **`QuestObject` 인스턴스 자신을 `extra_state`로 함께 넘기고**, `.dialogue`의 각 응답 `do` 절이 `QuestSystem.choose_branch(...)` 대신 `QuestObject` 공개 함수 1개(`resolve_branch_outcome(choice_id: String)`)를 접두어 없이 호출하게 한다 — 이 함수 안에서 `choose_branch()` → `Events.object_interacted.emit()` → `vanish_on_complete`면 `queue_free()` 순서를 그대로 수행한다. 또한 이 함수/`dialogue_path` 오픈 자체를 **`QuestSystem.get_state(branch_quest_id) == "active"`일 때만** 허용하는 가드를 추가한다(퀘스트를 수락하기 전에는 몽실이가 그냥 관찰 대상일 뿐 선택지가 뜨지 않음 — `observation_key()` 경로로만 반응).

```gdscript
# quest_object.gd, 기존 107-108행("branch_quest_id" 분기) 자리 대체 (제안, ~26줄 diff — 원안 18줄보다 늘어난 이유: emit/vanish를 함수로 분리)
if not dialogue_path.is_empty():
    if QuestSystem.get_state(branch_quest_id) == "active":
        get_tree().call_group("npc_dialogue_ui", "open_dialogue_resource", load(dialogue_path), "start", self)
    return  # 대사 응답이 emit/vanish를 대신 수행(아래), 여기서는 진행시키지 않는다
elif not branch_quest_id.is_empty() and not branch_choice_id.is_empty():
    QuestSystem.choose_branch(branch_quest_id, branch_choice_id)  # 기존 동작 유지(하위호환)

# quest_object.gd, 신규 공개 함수 — .dialogue의 do 절에서 접두어 없이 호출(§3.3과 동일 주입 방식)
func resolve_branch_outcome(choice_id: String) -> void:
    QuestSystem.choose_branch(branch_quest_id, choice_id)
    Events.object_interacted.emit(object_id)
    if vanish_on_complete: queue_free()
    elif one_shot: _swap_to_used_visual()
```
`dialogue_path`가 비어 있는 기존 경로(`branch_choice_id`)는 그대로 두므로 하위호환은 유지된다. `resolve_branch_outcome`가 새 공개 API이므로 `quest-data-schema.md`/스모크 문서에 반영 필요(§10 파일 목록 갱신).

**경로 정정(검증 이후)**: 위 리소스 경로와 §8/§9.3 예시가 이전 판에서 `res://game/data/dialogue/...`로 잘못 적혀 있었다. 프로젝트 루트는 `game/`(즉 `game/project.godot`이 res:// 루트)이므로 **`res://data/dialogue/obj_montsil_rabbit.dialogue`**가 맞다 — 기존 관례도 전부 `game/` 접두어 없이 `res://scenes/...`, `res://scripts/...`로 쓴다(확인: `game/project.godot:26` `QuestSystem="*res://scripts/systems/quest_system.gd"`, `game/data/world_objects.json`의 `"scene": "res://scenes/world/QuestObject.tscn"`). 이 문서의 모든 `.dialogue` 경로를 이 표기로 정정했다.

**빠졌던 배선(검증 이후 추가)**: `quest_object.gd`에 `dialogue_path` export를 추가해도 `world_objects.json`에서 그 값을 읽어 인스턴스에 옮기는 코드가 없으면 아무 효과가 없다. `quest_layout_spawner.gd._spawn_one()`은 알려진 키 4개(`one_shot`/`vanish_on_complete`/`branch_quest_id`/`branch_choice_id`)만 `instance.set()`으로 옮기는 화이트리스트 방식이다(확인: `game/scripts/world/quest_layout_spawner.gd:68-75`). 아래 한 줄을 그 옆에 추가해야 한다(⑪-1 diff에 포함, §10 파일 목록 갱신):
```gdscript
# quest_layout_spawner.gd, 기존 74행("branch_choice_id" 블록) 바로 아래
if entry.has("dialogue_path"):
    instance.set("dialogue_path", String(entry["dialogue_path"]))
```

**필수 테스트 갱신**: `test_quest_layout_spawner.gd:129-130`이 `montsil.branch_choice_id == "release"`를 단언한다(확인, 위 §"quest_layout_spawner test" grep). `dialogue_path`로 전환하면 이 두 줄을 `dialogue_path == "res://data/dialogue/obj_montsil_rabbit.dialogue"` 단언으로 교체해야 한다. `world_objects.json`의 `montsil_rabbit` 항목도 `branch_choice_id: "release"` 하드코딩 대신 `"dialogue_path": "res://data/dialogue/obj_montsil_rabbit.dialogue"`로 바꿔야 스포너가 옮길 값이 생긴다(데이터 변경이므로 이 PR의 데이터 diff에 포함, level-designer 확인 필요 — D-249).

**일반화 범위 (결정 필요, D-252)**: 이번 PR은 몽실이 1건만 전환할지, `dialogue_path` 필드 자체를 2막의 다른 분기 오브젝트에도 쓸 수 있게 스키마 문서(`docs/specs/quest-data-schema.md`)에 먼저 등재할지.

### 4.3 giver NPC 잡담·수주 안내 대사 (검증 이후 진입 경로·매핑 규칙 전면 보강)
`teo`(5퀘스트: arrival/firstlook/echocave/fiveroads/waypoint), `dami`(1: montsil), `rozel`(2: festival_prep/daily_01), `pinto`(2: orefetch/daily_03), `meru`(2: herbrun/daily_02) — 확인: `act1_hartland.json` giver 필드 grep 결과. `QuestNpcPanel`은 그대로 수락/완료 버튼을 담당하고, `.dialogue`는 그 앞뒤에 "잡담용" 대사만 보여준다.

**진입 경로는 1개로 확정한다 (검증 이후 정정, D-260)**: 예전 판은 "컨트롤러가 `Events.npc_talked`를 구독"(§3.1 원안)과 "`quest_npc.gd`에 `call_group("npc_dialogue_ui", ...)` 1줄 추가"(§10 ⑪-1 diff)를 동시에 적어 interact 1회에 대사가 2번 열리는 모순이 있었다. **`Events.npc_talked` 구독은 제거하고, `quest_npc.gd._unhandled_input()`의 `call_group("npc_dialogue_ui", "open_npc_dialogue", npc_id)` 호출 1개만 진입 경로로 삼는다**(§3.1 표 갱신). 이 호출은 기존 `talk()`(→`Events.npc_talked.emit()`) 바로 다음 줄에서 실행되므로(§4.4 diff), `QuestSystem._on_npc_talked`(오토로드, `quest_system.gd:72,290`)가 그 `talk()` 호출 안에서 **동기적으로 먼저** 목표 진행을 갱신한 뒤에 컨트롤러가 상태를 읽는다 — 시그널 연결 순서에 기대는 게 아니라 **호출 순서 자체로 강제**되므로 "대사 진행 중 목표가 먼저 완료되는지" 여부가 모호하지 않다. 즉 컨트롤러가 `QuestSystem.get_state(quest_id)`를 조회하는 시점엔 이미 이번 interact가 반영된 최신 상태다.

**npc_id/퀘스트 상태 → `.dialogue` 파일·title 매핑 규칙 (검증 이후 신규, D-261)**: 이전 판은 giver별 퀘스트 목록과 CSV 키 패턴만 주고 실제 선택 규칙이 없었다. 제안 규칙:
1. **파일**: giver 1명당 `.dialogue` 파일 1개 — `res://data/dialogue/npc_<npc_id>.dialogue`(예: `npc_dami.dialogue`). giver가 가진 여러 퀘스트의 잡담을 title로 구분해 한 파일에 모은다(파일 6개 = giver 5 + 몽실이 1, §10 기존 표와 일치).
2. **title**: `<quest_id>_<offer|active|ready|done>`(퀘스트별) 또는 giver 소관 퀘스트가 전혀 없을 때 `<npc_id>_everyday`(기존 `everyday`/`after_*` 로테이션 대체, D-242). 상태 문자열은 `QuestSystem.get_state(quest_id)`의 리턴값(`available`→`offer`, `active`→`active`, `complete_ready`→`ready`, `completed`→`done`)을 그대로 접미어 매핑에 쓴다.
3. **퀘스트 선택**: `quest_npc.gd._refresh_marker()`와 동일한 전체 스캔(확인: `quest_npc.gd:127-135`)으로 그 npc_id가 giver인 퀘스트를 모두 모은 뒤 "완료 보고 가능(`complete_ready`) > 수주 가능(`available`) > 진행 중(`active`)" 우선순위로 1건만 고른다(D-244 확정, 아래). 해당 퀘스트가 하나도 없으면(전부 `completed`이거나 giver 소관 퀘스트가 없으면) `<npc_id>_everyday` title로 폴백한다.
4. 이 선택 로직은 `NpcDialogueController` 안에 함수 1개(`_resolve_title(npc_id) -> String`)로 둔다 — §3.1 예상 줄 수(130~170)에 이미 반영.

**복수 퀘스트 동시 보유 시 순서 (D-244, 확정 권고)**: 위 3번 규칙대로 "완료 보고 가능 > 수주 가능 > 진행 중" 우선순위 확정. 5명 중 teo만 동시에 2개 이상 걸릴 수 있어(arrival→firstlook 순차 언락이라 실제 동시성은 낮음, 나머지 4명은 사이드+일일 1개씩) 영향은 제한적.

### 4.4 giver 동시 열림 시 입력 중재 · 재개 · 재진입 (검증 이후 신규 및 전면 보강, D-254/D-259)
`teo`/`meru`/`pinto`/`rozel`/`dami`는 첫 interact 한 번에 `QuestNpcPanel`(모달, `paused=true`, `hud.visible=false`, 전체화면 0.65 검정 shade + `MOUSE_FILTER_STOP`, 확인: `quest_npc_panel.gd:16-24`)과 잡담 대사 풍선이 **같은 프레임에** 열린다 — `quest_npc.gd._unhandled_input()`이 `not get_tree().paused`일 때만 `talk()`(→`Events.npc_talked`)과 `call_group("quest_npc_ui", "open_quest_npc", ...)`를 함께 실행하기 때문(확인: `quest_npc.gd:68-72`). 두 번째 interact부터는 `paused=true`라 이 핸들러 자체가 다시 안 열리므로(같은 가드) `smoke_quest_npc_panel.gd:94` "modal interact does not fire world talk again"은 이 기존 가드만으로 이미 안전하다.

문제는 **패널이 열려 있는 동안의 `ui_cancel`/`interact`**다. `Node._unhandled_input`은 뷰포트에 늦게 추가된(트리상 나중에 add_child된) 노드가 먼저 받는다. `NpcDialogueController`/풍선이 `PROCESS_MODE_ALWAYS`라 `paused` 중에도 계속 입력을 받는데, 이 스펙에 노드 추가 순서·입력 소비 규칙이 없어 `quest_npc_panel.gd:118-126`의 `ui_cancel`(닫기)/`interact`(수락) 처리보다 먼저 풍선이 그 입력을 가로챌 위험이 있다 — 그러면 `smoke_quest_npc_panel.gd:100-101`("cancel closes without accepting")이 깨질 수 있다. §9.1의 "영향 없음"은 이 경로를 검토하지 않은 상태의 주장이었으므로 철회한다(§9.1 갱신).

**수정안(제안)**: 캐스터/캐스티(개별 우선순위) 대신, 사다리 최소안 — 공유 게이트 하나로 막는다. `NpcDialogueController`/풍선이 `ui_cancel`/`interact`를 소비하기 전에 `UiRoot.is_quest_npc_open()`(이미 공개 API, 확인: `ui_root.gd:117-119`)을 확인해 **true면 아예 입력을 넘기고 자기 줄을 그대로 둔다**(패널이 닫히면 그다음 입력부터 다시 정상 처리). 이러면 패널의 `_unhandled_input`은 지금처럼 무조건 먼저 처리되고(가로채는 코드가 아예 없으므로 노드 add 순서에 의존하지 않는다), giver 잡담은 패널이 열려 있는 동안만 "일시정지"됐다가 패널이 닫히면 이어서 재생된다. 몽실이류(패널이 아예 없는 `QuestObject`) 분기 대사는 이 가드의 영향을 받지 않는다(`is_quest_npc_open()`이 애초에 false).

**빠졌던 지점: 패널이 닫힌 "다음" 입력 (검증 이후 발견, blocker)**: 위 게이트는 패널이 열려 있는 동안만 막는다. 패널을 `ui_cancel`(ESC)로 닫으면 `is_quest_npc_open()`이 즉시 false가 되므로, **그다음 입력부터는 게이트가 없다**. 그런데 `interact`와 `ui_confirm`은 패드에서 같은 물리 버튼(button 0, `project.godot:150-154/205-209` 확인)이다. 패널을 닫은 직후 플레이어가 패널을 다시 열려고 그 버튼을 누르면(`smoke_quest_npc_panel.gd:100-103`이 정확히 이 순서를 검증), 아직 열려 있는(이어서 재생 중인) 풍선이 게이트 없이 그 입력을 **`ui_confirm`으로 먼저 소비**해 대사를 한 줄 넘겨버리고, `quest_npc.gd`의 `interact` 핸들러(패널 재오픈 담당)에는 입력이 도달하지 못한다 — 패널이 다시 열리지 않는다.

**수정안 갱신(제안)**: 게이트 조건을 `is_quest_npc_open()` 단독에서 `is_quest_npc_open() or _just_closed_this_frame`으로 넓히지 않는다(사다리상 프레임 카운팅은 더 비싼 상태를 늘린다). 대신 **패널이 `close_requested`를 emit하는 그 콜백에서 풍선도 함께 `skip_typing()` 없이 그 줄을 그대로 유지한 채, 다음 물리 프레임까지 컨트롤러가 입력 소비를 한 번 더 건너뛴다** — 즉 게이트를 "패널이 열려 있는 동안" 대신 **"이번 프레임에 패널이 열려 있었거나 방금 닫혔는가"**로 1프레임만 넓힌다(`UiRoot`에 `quest_npc_just_closed: bool`을 `close_quest_npc()`에서 1프레임만 세팅 — 기존 `is_quest_npc_open()` 패턴과 동일한 크기의 diff). 이러면 같은 버튼 입력이 "패널 닫기"와 "패널 재오픈"에 한 프레임 안에서 겹쳐도 풍선이 가로채지 않는다.

**재진입 규칙 (검증 이후 신규, D-259)**: 위 수정으로도 패널이 닫힌 뒤 다음 interact는 정상적으로 `quest_npc.gd._unhandled_input()`까지 도달해 `talk()`(→`Events.npc_talked`)과 새 `call_group("npc_dialogue_ui", ...)` 호출을 다시 실행한다(§4.3). 이때 풍선이 **이미 이전 대사를 재생 중**이면 컨트롤러가 어떻게 반응할지 이전 판에 규칙이 없었다. 제안: **컨트롤러는 재생 중이면 새 요청을 무시하지 않고, 현재 재생을 즉시 중단하고 `_resolve_title()`(§4.3)로 다시 계산한 title부터 처음부터 재생한다**(§7.4 "무상태 원칙"과 일관 — 밸룬은 애초에 항상 줄 0부터 다시 시작하므로 "재시작" 쪽이 추가 상태 없이 가장 싸다). 대기 중이던 `await get_next_dialogue_line()`은 Godot 코루틴 특성상 자연히 취소되지 않으므로, 컨트롤러는 재생 세대 번호(`_gen: int`, 필드 1개)를 두고 `await` 복귀 시 `_gen`이 바뀌었으면 그 결과를 버린다(추가 diff는 필드 1개 + 비교 1줄).

### 4.5 giver 4명 + teo 5번째 퀘스트의 수락/완료 UI 부재 (검증 이후 신규, D-258, blocker)
`QuestNpcPanel.SUPPORTED`는 teo의 메인 4퀘스트뿐이다(확인: `quest_npc_panel.gd:6-7` `["quest_main_a1_01_arrival","quest_main_a1_02_firstlook","quest_main_a1_06_echocave","quest_main_a1_07_fiveroads"]`). `QuestSystem.accept()`/`advance()`를 호출하는 곳은 리포 전체에서 **`quest_npc_panel.gd:114` 한 줄뿐**이며(grep, 나머지 호출은 전부 테스트 코드가 백엔드 API를 직접 찍는 것) `open_for_npc()`(53-65행)는 `SUPPORTED`에 없는 퀘스트에 대해 무조건 `false`를 반환한다(확인).

결과: `dami`(montsil), `rozel`(festival_prep/daily_01), `pinto`(orefetch/daily_03), `meru`(herbrun/daily_02), `teo`의 5번째 퀘스트(waypoint) — 이 8개 퀘스트는 **플레이어가 실제로 수락(`available`→`active`)하거나 완료 확정(`complete_ready`→`completed`)할 UI 경로가 하나도 없다**. `quest_side_heartland_montsil`(giver `dami`)이 대표 사례다: `prerequisites`가 충족돼도(확인: `act1_hartland.json:392-396`) `accept()`가 호출되지 않으므로 영원히 `available`에 머물고, `_active`에 들어가지 않으므로 `obj_01`(`talk npc:dami`)조차 진행되지 않는다(`quest_system.gd:298-336` `_apply_progress`가 `_active.keys()`만 순회).

즉 이 문서 §1이 목표로 삼은 "진행 중/완료 가능/완료 후" 대사 3종과 §8의 몽실이 분기 예시는 **`QuestNpcPanel.SUPPORTED`를 건드리지 않는 한 실제 플레이로 도달 불가능**하다. 그런데 §4.1은 이 배열을 "변경 없음"으로 고정한다 — 이 문서 자신의 설계 원칙과 §1의 목표가 서로 모순된다.

**(결정 필요, D-258)**: 아래 중 확정 필요 — 이 스펙만으로는 판단할 수 없다(game-designer/PM):
1. `SUPPORTED`에 나머지 8개 퀘스트 id를 추가한다(`open_for_npc`의 매칭 로직은 giver 필드로 이미 범용이라 배열 원소만 늘리면 그대로 동작 — 사다리상 가장 싼 수정, 단 §4.1 "변경 없음" 문구와 상충하므로 그 문구부터 정정해야 함).
2. 이번 PR의 목표(§1)를 "teo 4퀘스트 + 몽실이 분기"로 좁히고, 나머지 4명 giver 잡담은 상태 무관 `<npc_id>_everyday` 1종(§4.3 규칙 4)만 재생하도록 범위를 줄인다(코드 변경 없음, 목표 문구만 정정).
3. 나머지 4명 giver용 별도의 경량 수락/완료 트리거(예: `.dialogue`의 `do` 절에서 직접 `QuestSystem.accept(...)`/`advance(...)` 호출 — 몽실이의 `choose_branch` 패턴과 동일)를 이 PR에 새로 만든다(가장 비쌈, `using QuestSystem`으로 이미 가능은 하나 UX·중복 확인 버튼 흐름 설계가 새로 필요).
권고: 사다리 원칙상 1번(배열 확장)이 가장 싸지만, "왜 4개만 하드코딩했는지"의 원래 의도(teo 메인 라인만 UI로 노출)를 게임 디자이너가 의도적으로 정한 것인지 이 스펙만으로는 알 수 없어 확정하지 않는다.

---

## 5. 로컬라이징 키

신규 CSV 파일 없음, **단 1개 예외** — 몽실이 조우 대사 1줄(§8 `[ID:quest_side_heartland_montsil_encounter]`)은 새 키가 필요하다(**정정, 검증 이후**: 이전 판은 "몽실이는 신규 키 없음"이라 했으나 `quest_ko.csv:31-37`을 확인하면 montsil 키는 title/desc/obj_01~03/choice_release/choice_capture 6개뿐이고 `_encounter`는 없다 — §9.2 검사기 규칙 2(태그 키가 CSV에 존재해야 함)를 스펙 자신의 §8 예시가 위반하는 상태였다). 그 외 giver 잡담은 기존 `game/localization/quest_ko.csv`(이미 `project.godot`의 `locale/translations`에 등록, 확인)에 `quest_<quest_id>_<offer|active|ready|done>_NN` 키를 추가한다(§4.3 규칙 2의 title 접미어와 1:1 대응). 몽실이 선택지 라벨은 기존 `quest_side_heartland_montsil_choice_release`/`_capture`(확인: `quest_ko.csv:36-37`)를 `.dialogue` 응답의 `[ID:quest_side_heartland_montsil_choice_release]` 정적 ID로 그대로 재사용한다(**콜론 뒤 공백 없음 — 아래 문법 설명 정정 참고**). giver 소관 퀘스트가 하나도 없을 때의 잡담(`<npc_id>_everyday`, §4.3 규칙 2)은 기존 `ui_ko.csv` 키(`npc.<id>.everyday.N`)를 재사용한다 — `Hud._next_npc_greeting()` 토스트가 대사 풍선으로 완전히 대체되는 것은 이번 범위가 아니다(§0.1, D-245).

**정적 ID 문법 정정(검증 이후)**: 정규식은 `STATIC_LINE_ID_REGEX = \[ID:(?<id>.*?)\]`이며, 캡처된 `id`를 strip 없이 그대로 `line.translation_key`에 대입한다 **(확인**: `compilation.gd:969-975`(`extract_static_line_id`, strip 없음), `compilation.gd:508`·`676`(둘 다 캡처값을 그대로 `translation_key`에 대입)**)**. `compilation.gd:675`의 `.replace(" [ID:", "[ID:")`는 **줄 앞의 공백**(대사 텍스트와 태그 사이 공백)만 제거하며, `[ID:` 뒤·`xxx` 앞의 공백은 건드리지 않는다. 즉 **`[ID: xxx]`(콜론 뒤 공백)로 쓰면 `translation_key`가 `" xxx"`(선행 공백 포함)로 저장되어** CSV 키(`quest_..._encounter` 등, 공백 없음)와 어긋나 번역이 실패한다. 애드온 정규 표기는 **`[ID:xxx]`(공백 없음)** 뿐이다 — 이 문서의 §8 예시·검사기 설명(§9.2)을 모두 이 표기로 정정했다.

---

## 6. 세이브

신규 세이브 필드 없음. 몽실이 분기 선택은 이미 `QuestSystem._active[quest_id].branch_choice`로 `to_dict()`/`from_dict()`에 왕복 저장된다 **(확인**: `quest_system.gd:590,604`, 필드 존재는 `choose_branch()` 본문 확인**)**. `visit_count`(§3.3)는 의도적으로 비저장 — 세션 내 잡담 다양성용이며 퀘스트로 환원되지 않는 진행도이므로 저장이 필요하면 `QuestSystem._story_flags`(기존 딕셔너리, 신규 스키마 아님) 재사용을 향후 검토(범위 밖, D-181 참고 대상이나 이번 PR엔 불필요).

---

## 7. UI 풍선 계약

좌표·입력·상태는 `docs/ui/dialogue-balloon.md`(v0.1, 181줄, ui-ux-designer 작성, 확인)를 그대로 구현 기준으로 삼는다. 요약(전문은 원본 문서 참조):

- 패널 `(40,240)` `560×96`, 초상 `64×64`, 이름표, 본문 3줄, 선택지 최대 4개.
- 입력: `ui_confirm`(확인: `project.godot:205`에 이미 정의됨) = 다음/스킵, `ui_cancel` = 정책 미정(D-241), `ui_up`/`ui_down`(Godot 기본값, 재정의 없음) = 선택지 이동, 좌클릭(D-196 `gui_input` + `MOUSE_BUTTON_LEFT` 패턴, `inventory_menu.gd` 확인) = 선택지 확정.
- `QuestNpcPanel`의 4종 전체화면 UI 상호배타(`is_menu_open`/`is_blacksmith_open`/`is_mailbox_open`/`is_quest_npc_open`, `ui_root.gd:52-134` 확인)에는 넣지 않는다 — `paused` 여부는 D-240/D-248로 미해결.

**`docs/ui/dialogue-balloon.md`와의 상충 (검증 이후 발견, D-255/D-256)**: 이 문서 §7이 "그대로 구현 기준"으로 삼은 그 문서와 두 지점이 충돌한다.
1. 그 문서 §3 항목 4는 "선택 결과가 퀘스트 상태를 바꾸는 분기 대사는 [잡담·컷신용] 풍선 범위 밖"이라고 명시하는데, 이 문서 §8의 몽실이 예시는 같은 풍선 컴포넌트에서 `QuestSystem.choose_branch(...)`를 직접 호출한다. → **D-255**: 그 문서를 v0.2로 갱신해 "퀘스트 상태를 바꾸되 보상은 갈리지 않는(`converges: true`, D-94) 분기"만 예외로 명시할지, 이 스펙에서 몽실이류를 별도 카테고리로 문서화하고 그 문서는 그대로 둘지 — ui-ux-designer 확인 필요, 이 스펙만으로는 확정 불가.
2. 그 문서 §3 항목 3은 대사 진행 중 `menu`/`quest_log` 입력을 막기 위해 `UiRoot` 상호배타 목록에 `is_dialogue_open()` 조건을 추가하라고 하는데, 바로 위 불릿은 반대로 "넣지 않는다"고 한다. 이대로면 대사 중 `menu`로 인벤토리가 열려 `paused=true`가 걸려도(`ui_root.gd:34-49`에 대사 조건이 없음, 확인) 풍선은 `PROCESS_MODE_ALWAYS`라 계속 타이핑이 진행되는, 정의되지 않은 이중 UI 상태가 생긴다. → **D-256**: `ui_root.gd`의 `menu`/`quest_log` 핸들러에 `is_dialogue_open()` 가드 한 줄씩(기존 `is_blacksmith_open()` 등과 같은 패턴, ~+3줄)을 추가하는 쪽을 권고 — 새 분기가 아니라 기존 화이트리스트에 항목만 하나 늘리는 것이므로 사다리상 가장 싼 수정이다.

**패널+풍선 동시 열림의 시각 상태 미정의 (검증 이후 신규, D-263, major)**: §4.4는 패널이 열려 있는 동안 풍선의 **입력**만 "일시정지"시키고, **화면에 무엇이 보이는지**는 정하지 않았다. 실측 좌표가 겹친다: `QuestNpcPanel`은 `(52,28)`+`(376,214)`(하단 y=242, 확인: `quest_npc_panel.gd:25-26`)이고 풍선 이름표는 절대 `(48,224)`+`20`(즉 y=224~244, 확인: `dialogue-balloon.md:55-57`) — 두 사각형이 y=224~242 구간에서 겹친다. `QuestNpcPanel`은 별도 `Control`(`UiRoot`의 자식)이고 풍선은 "별도 `CanvasLayer`"(§3.1)인데, `CanvasLayer.layer` 값이 이 스펙에 없어 패널의 0.65 검정 shade(`MOUSE_FILTER_STOP`) 위에 풍선이 그려질지 아래에 가려질지 정의돼 있지 않다. 여기에 더해 `hud.gd:117,322-326`의 `_on_npc_talked` 좌하단 토스트(3초, D-245로 유지 확정)가 풍선과 **같은 인사말 텍스트**를 동시에 띄운다 — `ui_root.gd:117-120`은 `is_quest_npc_open()`일 때 `hud.visible=false`만 제어할 뿐 풍선과는 무관하다.
→ **D-263 임시 권고(제안)**: 패널이 열려 있는 동안 풍선을 `visible=false`로 완전히 숨긴다(패널이 이미 전체화면 shade를 깔고 있어 어차피 안 보여야 자연스럽다 — 사다리상 z-order 계산보다 훨씬 싸다) — 패널이 닫히면 §4.4의 1프레임 유예 이후 다시 `visible=true`로 이어서 재생. `Hud` 토스트 중복 표시는 이번 PR 범위(D-245 보류)로 남기되, 최소한 풍선이 열려 있는 동안만은 `_push_log_line` 호출을 건너뛰는 안(`hud.gd` 쪽에 `is_dialogue_open()` 가드 1줄)을 후속 검토로 기록한다.

### 7.4 무상태 원칙 + `skip_typing()` (data-min 접목)
밸룬은 열릴 때마다 항상 줄 0부터 재생하며 내부 진행 상태를 세이브하지 않는다(§6과 일치). `skip_typing() -> void`는 타이핑 중 전체 텍스트를 즉시 표시하는 공개 함수로, GUT이 `await`/프레임 대기 없이 결정적으로 다음 상태로 넘길 수 있게 한다(§9.3).

---

## 8. 몽실이 분기 `.dialogue` 예시 (전문)

`res://data/dialogue/obj_montsil_rabbit.dialogue`(경로 정정, §4.2 참고, 제안, 미생성):

```
~ start
다미: (몽실이가 코를 씰룩이며 이쪽을 보고 있다) [ID:quest_side_heartland_montsil_encounter]
- 그냥 놓아준다 [ID:quest_side_heartland_montsil_choice_release]
    do resolve_branch_outcome("release")
    => END
- 붙잡아 본다 [ID:quest_side_heartland_montsil_choice_capture]
    do resolve_branch_outcome("capture_attempt")
    => END
```
(정정, §4.2 D-262 갱신 반영: 예전 판은 `using QuestSystem` + `do QuestSystem.choose_branch(...)`를 직접 호출했으나, §4.2에서 밝혀진 타이밍 결함(선택 전에 이미 진행도가 확정되는 문제)을 고치면서 `QuestObject` 자기 자신을 `extra_game_states`로 주입받아 `resolve_branch_outcome(choice_id)` 1개만 접두어 없이 호출하는 방식으로 바꿨다 — 그래서 이 파일엔 `using` 선언이 아예 없다(§3.4의 `using` 화이트리스트는 `QuestSystem` 하나뿐이라는 결론과 무관 — 이 예시는 `using` 자체를 안 쓴다). `[ID:xxx]`는 콜론 뒤 공백 없음 — §5 참고. `using NpcDialogueController` 선언도 이 예시에 없다 — 이 대사는 giver 잡담이 아니라 `dialogue_path` 경로로 열리므로 `visit_count`가 필요 없다.)

문법 근거: 응답(`- `)은 `TYPE_RESPONSE`로 파싱(확인: `compilation.gd:936`, `constants.gd:60`), 변이(`do `)는 `MUTATION_REGEX`로 파싱(확인: `compiler_regex.gd:12`), `=> END`는 현재 title만 종료(확인: `resolved_goto_data.gd:44-51`, `constants.gd:78-79`).

`quest-data-schema.md`의 `branch.converges: true`(확인: `docs/specs/quest-data-schema.md:83`, "이번 데이터셋은 전부 true")와 일치 — 두 선택지 모두 이후 목표·보상이 동일하므로 이 `.dialogue`는 서사 연출만 가르고 파워/보상에 개입하지 않는다(D-94 그대로 준용).

---

## 9. 테스트 계획

### 9.1 영향 없음 — 및 재검토 필요 항목 (검증 이후 재정정)
`smoke_quest_layout.gd`(`talk()` 직접 호출 유지), `test_npc_greeting.gd`/`test_quest_system.gd`(branch 테스트, `QuestSystem` API 무변경) — 이 2종만 영향 없음 유지.

`smoke_quest_npc_panel.gd`/`smoke_quest_npc_late.gd`/**`smoke_quest_ui_save.gd`(정정, 검증 이후 추가)**는 **"영향 없음" 주장을 철회한다.** `smoke_quest_ui_save.gd`는 "오토세이브 트리거 체인 무관"이라 분류돼 있었지만 `_talk()`(→ teo interact) → `Enter` → `_talk()` → `ESC` → `_interact(cargo_pile)` 순서(확인: `smoke_quest_ui_save.gd:39-48`)가 `smoke_quest_npc_panel.gd`와 똑같이 "패널+풍선 동시 열림 → interact 재사용" 경로를 그대로 통과하므로 같은 위험에 노출된다. `QuestNpcPanel` 자체 필드·흐름은 안 바뀌지만, giver interact 시 대사 풍선이 같은 프레임에 열리는 새 경로가 생기므로 §4.4(D-254/D-259)의 입력 중재·재개·재진입 가드가 구현되기 전까지는 `smoke_quest_npc_panel.gd:100-103`("cancel closes without accepting", "mapped pad A opening press/release does not auto accept")과 `smoke_quest_ui_save.gd:39-48` 통과를 보장할 수 없다. D-254/D-259 확정·구현 이후 이 3개 스모크를 재실행해 확인해야 한다(⑪-1 완료 기준, §10).

**헤드리스 검증 가능 여부(검증 이후 신규, D-265, major)**: 위 3개 스모크는 전부 `OS.get_user_data_dir()`을 `C:/Users/freer/AppData/Roaming/...` 리터럴과 비교해 불일치하면 `quit(1)`하는 격리 가드를 갖는다(확인: `smoke_quest_npc_panel.gd:18-21`, `smoke_quest_npc_late.gd:9-11`, `smoke_quest_ui_save.gd:16-19`, `docs/qa/dialogue-system-test-plan-template.md` §1.3(60-79행)이 이미 "이 워크트리(리눅스)에서 그대로 실행하면 전부 결정론적으로 exit(1)"이라 문서화). 즉 **§10의 완료 기준("D-254 구현 후 이 스모크들을 재실행해 통과 확인")은 이 리눅스 워크트리에서 그대로 실행하면 검증 전에 무조건 실패한다** — 실제로 검증하려면 그 리터럴 경로를 만들거나(해당 사용자 계정 하위 디렉터리 생성) 테스트 자체를 이식 가능한 경로로 먼저 고쳐야 하는데, 이는 이 PR의 코드 변경 범위(§1 비목표에 없음)를 벗어난다. → **결정 필요**: (a) 이 3개 스모크의 격리 경로를 리눅스 CI에서도 쓸 수 있게 먼저 고치는 선행 작업을 이 PR에 포함할지, (b) 그 전까지는 "GUT 단위 테스트(§9.3, §9.6 신규)로만 검증하고 이 스모크들은 수동/윈도우 환경 검증으로 남긴다"고 완료 기준을 낮출지 — game-designer/QA 결정 필요.

### 9.2 `tools/qa/validate_tables.py` 편입 (data-min 접목)
기존 `validate_quests()`(`validate_tables.py:410`)와 같은 검사 대상:
- 응답의 `do resolve_branch_outcome(choice_id)`(§4.2 D-262 갱신, object 소유 분기) 또는 `do QuestSystem.choose_branch(quest_id, choice_id)`(§4.1 기존 `branch_choice_id` 경로) 양쪽 문법에서 `choice_id`가 해당 `quests/*.json`의 `branch.choices[].id`와 문자 그대로 일치하는가.
- `[ID:xxx]`(콜론 뒤 공백 없음, §5 정정) 태그의 키가 `quest_ko.csv`/`ui_ko.csv`에 존재하는가 — 공백 포함 키(`[ID: xxx]`)가 섞여 있으면 그 자체를 오류로 잡는다(§5의 실패 사례 재발 방지).
- 선택지가 4개를 넘지 않는가(`docs/ui/dialogue-balloon.md` §1 하드 상한).
- `using` 선언이 **`QuestSystem` 외 이름을 쓰지 않는가**(어휘 화이트리스트, 정정: `NpcDialogueController`는 §3.4에 따라 `using` 대상 자체가 될 수 없으므로 화이트리스트에서 제외 — 화이트리스트에 그 이름이 있으면 오히려 컴파일 에러를 놓치는 통과 조건이 된다).

**새 파일 여부 (검증 이후 결정 필요, D-253)**: `tools/qa/validate_tables.py`는 이미 612줄로 500줄 상한(D-157)을 넘긴 상태다(확인: `wc -l tools/qa/validate_tables.py`). D-157은 "새 로직은 반드시 분리 파일로"를 명시하는데(`docs/brd/04-decisions.md:284`), 이 문서 §3.1의 "500줄 상한 확인 완료"는 신규 `.gd` 파일만 셌고 이 파이썬 파일은 검토하지 않았다. D-157의 문구가 언어를 가리지 않으므로 이 스펙의 권고는 **신규 `tools/qa/validate_dialogue.py`(위 4개 검사 함수만)를 만들고 `validate_tables.py`의 메인 러너에서 호출**하는 쪽이나, D-157이 `.py`에는 적용되지 않는다고 볼지는 game-designer/PM 결정 필요 — §11 D-253 참고.

### 9.3 헤드리스 GUT 패턴 (렌더 없음)
```gdscript
func test_montsil_release_line() -> void:
    var res: DialogueResource = load("res://data/dialogue/obj_montsil_rabbit.dialogue")  # 경로 정정, §4.2
    var line := await res.get_next_dialogue_line("start")
    assert_eq(line.translation_key, "quest_side_heartland_montsil_encounter")  # [ID:xxx] 무공백 표기라 공백 없이 일치(§5)
    assert_eq(line.responses.size(), 2)
```
`DialogueLine.translation_key`/`responses`는 애드온 공개 필드(확인: `example_balloon.gd:107,113-172`에서 동일 필드 사용). 물리 프레임 대기 없이 `await` 한 번으로 검증 가능 — `smoke_quest_npc_panel.gd:61-64`의 "물리 프레임 수로 시간 측정" 관례(확인, `docs/qa/dialogue-system-test-plan-template.md` §1.1)조차 필요 없는, 이보다 더 싼 패턴.

### 9.4 결정 보류 항목 (미포함, §11로 이관)
`QuestObject.interact() → 대사 → choose_branch` 엔드투엔드 스모크는 이번 PR에 포함하지 않는다(D-243) — 9.3의 GUT 단위 테스트로 로직은 커버되고, E2E 스모크는 밸룬 씬 인스턴스화까지 검증해야 해 비용이 더 크다(제안, ponytail 사다리: 필요할 때 추가).

### 9.5 알려진 통합 격차 (수정 안 함, 기록만)
`SmokeMenuMouse`(D-196, 마우스 클릭 Xvfb 테스트)는 `stage/m5-int` 커밋 `6d2bd97`에만 있고 `stage/m6-int`에는 병합되지 않았다(확인: `git merge-base --is-ancestor` NOT ANCESTOR, `docs/qa/dialogue-system-test-plan-template.md` §1.2). 밸룬의 마우스 선택지 클릭 테스트는 이 병합이 선행돼야 한다 — 이번 PR 범위 밖.

### 9.6 입력 중재·재개·재진입 GUT 단위 테스트 (검증 이후 신규, D-265)
§9.1에서 밝혀진 대로 실제 리눅스 워크트리에서 3개 스모크가 결정론적으로 `quit(1)`하므로, §4.4(D-254/D-259)의 핵심 로직은 **스모크가 아니라 GUT 단위 테스트로 직접 검증**해야 한다(9.3처럼 씬 인스턴스화 없이 `NpcDialogueController`/`UiRoot`만 떼어 테스트). 이전 판에는 이 테스트 자체가 없었다(§9.3은 `get_next_dialogue_line` 리소스 파싱만 검사, 입력 소비·재진입은 무엇도 검사하지 않음). 최소 3개 제안:
```gdscript
func test_balloon_yields_input_while_quest_panel_open() -> void:
    ui.open_quest_npc(&"teo")
    var consumed := controller.try_consume_ui_confirm()  # §4.4 게이트가 감싼 내부 헬퍼
    assert_false(consumed, "quest panel open이면 풍선이 ui_confirm을 먹지 않는다")

func test_balloon_resumes_and_yields_one_more_frame_after_panel_closes() -> void:
    ui.open_quest_npc(&"teo")
    ui.close_quest_npc()
    assert_true(ui.quest_npc_just_closed, "닫힌 프레임엔 1프레임 유예 플래그가 선다")
    assert_false(controller.try_consume_ui_confirm(), "그 유예 프레임에도 풍선이 먹지 않는다")

func test_reentrant_talk_restarts_from_resolved_title() -> void:
    controller.open_npc_dialogue(&"dami")  # 이 시점 상태 == quest_x_active라 가정
    var gen_before := controller._gen
    QuestSystem.accept(...)  # 등 상태를 바꾼 뒤
    controller.open_npc_dialogue(&"dami")  # 상태가 바뀐 채 재진입 → title이 quest_x_ready로 재계산
    assert_ne(controller._gen, gen_before, "재진입은 새 세대로 이전 await 결과를 무효화한다")
```
`quest_npc_just_closed`/`_gen`/`try_consume_ui_confirm`은 §4.4 수정판에서 이미 제안한 필드·헬퍼이므로 신규 추상화가 아니다(사다리: 이미 설계된 내부 상태를 그대로 노출해 테스트).

---

## 10. 단계 분할

| 단계 | 내용 | 예상 diff |
|---|---|---|
| ⑪-1 | `dialogue_balloon.gd`+`.tscn`, `npc_dialogue_controller.gd`(self-injection 방식·재진입 세대 카운터·`_resolve_title` 매핑, §3.3/§4.3/§4.4, 130~170줄), `ui_root.gd` 배선(+6줄 + `quest_npc_just_closed` 1프레임 플래그 +3줄, D-256 채택 시 `is_dialogue_open()` 가드 +3줄 추가), `quest_npc.gd`(+1줄, `call_group("npc_dialogue_ui", "open_npc_dialogue", npc_id)` — `Events.npc_talked` 구독 경로는 채택 안 함, §4.3 D-260), `quest_object.gd`(+~26줄, `dialogue_path` 분기 + 신규 공개 함수 `resolve_branch_outcome`, §4.2 D-262 갱신), **`quest_layout_spawner.gd`(+2줄, `dialogue_path` 포워딩 — 검증 이후 추가, §4.2)**, `world_objects.json`의 `montsil_rabbit` 항목(`dialogue_path` 추가, §4.2), `test_quest_layout_spawner.gd` 갱신(2줄, 경로 정정 포함), `quest_ko.csv`(+1키, `quest_side_heartland_montsil_encounter` — §5 정정), D-257 채택 시 `player.gd`(+수 줄, 이동 차단 플래그 **+ `attack`/`roll`/`guard` 액션 가드**, §11 D-257 갱신 참고), **D-258 채택 시(§4.5) `quest_npc_panel.gd`의 `SUPPORTED` 배열에 나머지 8퀘스트 id 추가(+8줄)** | 코드 ~400줄 신규 + 기존 파일 ~45줄 diff(D-258 채택 시 +8줄 추가) |
| ⑪-1a | (조건부, D-253) `tools/qa/validate_dialogue.py` 신규 — `validate_tables.py`가 이미 500줄 상한 초과라 새 검사 로직을 분리 파일로 둘 경우 | 신규 ~60줄, `validate_tables.py`는 호출 1줄만 추가 |
| ⑪-1b (검증 이후 신규) | §9.6 GUT 단위 테스트 3개(입력 중재/재개/재진입) — 리눅스 워크트리에서 스모크 3종이 격리 가드로 `quit(1)`하는 상태(§9.1 D-265)이므로 이 테스트들이 사실상 유일한 자동 검증 수단 | 신규 ~40줄 |
| ⑪-2 | 1막 15퀘스트(giver 5명) `.dialogue` 원고, `quest_ko.csv` 키 추가(`quest_<id>_<offer|active|ready|done>_NN`, §4.3 D-261 매핑) — **D-258 미채택 시 dami/rozel/pinto/meru/teo-waypoint 8퀘스트분은 실제로 재생 불가능한 원고가 되므로 그 4명은 `_everyday` 1종만 작성** | 신규 `.dialogue` 6개(giver 5 + montsil), CSV 키 추가만 |
| ⑪-3 | `Hud` 토스트 → 대사 풍선 전환 여부(D-245), 연출 다듬기 | 결정 이후 별도 산정 |

**완료 기준 갱신(검증 이후)**: ⑪-1 병합 전 (1) §9.6 GUT 테스트 3개 통과(리눅스에서 검증 가능한 유일한 자동 게이트, D-265), (2) `smoke_quest_npc_panel.gd`/`smoke_quest_npc_late.gd`/`smoke_quest_ui_save.gd` 3종을 D-254/D-259 가드 구현 후 **격리 경로 문제(D-265)가 먼저 해결된 환경에서** 재실행해 통과 확인(§9.1) — 이 환경(리눅스, 이 사용자 홈)에서는 그 3종을 그대로 실행해 확인할 수 없다는 점을 완료 기준에 명시한다.

---

## 11. 결정 필요 항목 (D-240부터, 이 문서의 제안 번호 — `docs/brd/04-decisions.md` 미기재)

| ID | 항목 | 권고안 |
|---|---|---|
| D-240 | 대사 중 플레이어 이동/전투 입력 차단 여부 (`docs/ui/dialogue-balloon.md` §6-E와 동일 질문) | 차단 권고. **정정(검증 이후)**: 원래 권고("`NpcDialogueController`에서 `set_process_unhandled_input` 토글")는 동작하지 않는다 — 이동은 `player.gd`가 `_physics_process`에서 `Input.get_vector`로 매 프레임 폴링하므로(확인: `player.gd:129,323-324`) 어떤 노드의 `_unhandled_input` 처리 여부와도 무관하다. `get_tree().paused`는 D-248에서 이미 안 걸기로 했으므로 쓸 수 없다. → **D-257로 재질의**: `player.gd`에 최소 플래그(예: `dialogue_active: bool`, `get_move_input()` 첫 줄에서 `if dialogue_active: return Vector2.ZERO` 1줄, `NpcDialogueController`가 시작/종료 시 세터 호출) 추가가 유일한 실현 가능안 — 비목표(§1)에 `player.gd` 변경 금지가 없으므로 범위 위반은 아님 |
| D-241 | `ui_cancel`로 잡담 대사 스킵 허용 여부 (`docs/ui/dialogue-balloon.md` §6-C와 동일) | 잡담(선택지 없음)은 허용, 분기 대사(선택지 있음)는 무효화 — ui-doc 원안 그대로 |
| D-242 | 완료 후 대사를 상태당 1줄 고정 vs 기존 `after_*` 3줄 로테이션 재현 (§3.3 `visit_count` 배선 필요) | 재현 권고 — `visit_count` 헬퍼 1개로 diff가 작음 |
| D-243 | 몽실이 E2E 스모크를 이번 PR에 포함할지 | 미포함 권고(§9.4) — GUT 단위 테스트로 대체, 필요해지면 추가 |
| D-244 | 복수 퀘스트 보유 NPC의 대사 우선순위를 "완료 보고>수주 가능>진행 중" 순서로 확정할지 | 확정 권고(§4.3) |
| D-245 | `QuestNpcPanel`을 장기적으로 대사 풍선 계약(하단 중앙)에 통합할지 (`docs/ui/dialogue-balloon.md` §6-A 연계) | 이번 단계 보류, 병렬 유지 |
| D-246 | `interact` 키를 대사 중 `ui_confirm`과 동일 취급할지 (`docs/ui/dialogue-balloon.md` §6-D) | 동일 취급 권고 — `quest_npc_panel.gd`가 이미 그렇게 함(일관성) |
| D-247 | 자동 진행(접근성) 지연 시간 수치와 `Settings` 신규 필드 추가 여부 (`docs/ui/dialogue-balloon.md` §6-F) | 수치는 `game/data/` 또는 `tuning.gd`로만 — 임의 확정 안 함, game-designer 결정 필요 |
| D-248 | 대사 중 `get_tree().paused` 여부 (D-240과 연계된 별개 축 — 이동 차단과 전체 일시정지는 다른 결정) | `paused` 걸지 않음 권고 — 배경 연출/다른 NPC AI는 계속 돔(ui-doc §3 원안) |
| D-249 | `dialogue_path` 필드를 몽실이 1건에만 적용할지, 스키마 문서에 일반 필드로 등재할지 | 몽실이만 우선 적용 권고 — 일반화는 2막 착수 시 스키마 문서와 함께 |
| D-250 | 대안 A: `NpcDialogueController`가 `get_next_dialogue_line()`을 직접 호출(§3.2 원안) vs **대안 B(검증 이후 추가)**: `DialogueManager.get_current_scene` Callable을 UiRoot로 오버라이드하고 공식 `show_dialogue_balloon_scene()` 경로를 그대로 사용 | 대안 A 권고 유지 — 단 `dialogue_started` 시그널이 절대 발생하지 않는 비대칭을 감수하는 선택임을 명시(§3.2). 향후 시그널이 필요해지면 대안 B로 전환 |
| D-251 | 대사 참조 무결성 검사를 `tools/qa/validate_tables.py`에 편입할지 (§9.2) | 검사 내용 자체는 편입 권고 유지. **어느 파일에 둘지는 D-253으로 분리**(파일이 이미 500줄 상한 초과) |
| D-253 (검증 이후 신규) | `tools/qa/validate_tables.py`(612줄, 500줄 상한 D-157 초과 상태)에 대사 검사 로직 3~4개를 그대로 추가할지, `validate_dialogue.py` 신규 분리할지 — D-157이 `tools/*.py`에도 적용되는지 포함 | **분리 권고** — D-157 문구("새 로직은 반드시 분리 파일로")가 언어를 한정하지 않음. 최종 적용 범위는 game-designer/PM 결정 필요 |
| D-254 (검증 이후 신규) | giver interact 시 `QuestNpcPanel`과 대사 풍선이 동시에 열릴 때 `ui_cancel`/`interact` 입력 중재 규칙 (§4.4) | `NpcDialogueController`/풍선이 `UiRoot.is_quest_npc_open()`이 true인 동안 해당 입력을 소비하지 않도록 가드 권고 — 노드 add 순서에 의존하지 않는 가장 싼 수정 |
| D-255 (검증 이후 신규) | `docs/ui/dialogue-balloon.md` §3-4(퀘스트 상태를 바꾸는 분기 대사는 풍선 범위 밖)와 이 문서 §8 몽실이 예시의 상충을 그 문서 개정으로 풀지, 이 스펙에서 예외 카테고리로만 문서화할지 (§7) | ui-ux-designer 확인 필요 — 이 스펙만으로 확정 불가 |
| D-256 (검증 이후 신규) | `UiRoot` 4종 상호배타에 `is_dialogue_open()`을 추가할지 (`docs/ui/dialogue-balloon.md` §3-3 요구 vs 이 문서 §7 기존 "넣지 않는다" 방침의 상충) | 추가 권고 — 기존 화이트리스트 패턴에 항목 하나만 늘리는 가장 싼 수정(§7) |
| D-257 (검증 이후 신규, D-240 대체) | `player.gd`에 이동 차단용 최소 플래그(`dialogue_active` 등)를 추가하는 구체 방식 확정 (D-240의 `set_process_unhandled_input` 권고가 동작하지 않음이 밝혀져 대체). **정정(이번 검증 라운드)**: `get_move_input()` 가드만으로는 `attack`/`roll`/`guard`를 못 막는다 — 이 3개 액션은 `player.gd._unhandled_input()`이 `state_machine.handle_input(event)`로 넘겨 각 상태 스크립트(`idle.gd`/`move.gd`/`attack.gd`/`guard.gd`)가 `event.is_action_pressed(...)`로 직접 처리한다(확인, grep: `attack` 3곳, `guard` 3곳, `roll` 4곳). `attack`은 좌클릭+패드 button 2(`project.godot:77-89`)라 대사 중 선택지 밖을 클릭하면 그대로 공격이 나간다 | `get_move_input()` 1줄 가드는 유지하되, **`player.gd._unhandled_input()` 최상단에도 `if dialogue_active: return` 1줄을 추가**해 `state_machine.handle_input()` 자체를 대사 중 호출하지 않게 한다(기존 `is_dead` 얼리리턴과 같은 패턴, +2줄) — `dialogue-balloon.md` §3-1 "이동·전투 입력 차단" 요구와 D-240 표제("이동/전투")를 실제로 충족하는 최소 수정 |
| D-258 (검증 이후 신규, blocker) | `QuestNpcPanel.SUPPORTED`를 dami/rozel/pinto/meru/teo-waypoint 8퀘스트까지 확장할지, 이번 PR 목표(§1)를 teo 4퀘스트+몽실이로 좁힐지, 별도 수락/완료 트리거를 새로 만들지 (§4.5) | 이 스펙만으로 확정 불가 — game-designer/PM 결정 필요. 사다리상으로는 배열 확장(1번)이 가장 싸다는 점만 기록 |
| D-259 (검증 이후 신규, blocker) | 패널이 닫힌 직후(같은 공유 버튼 재사용) 및 대사 재생 중 `npc_talked` 재발화 시 재진입 규칙 (§4.4) | 패널 close 콜백에서 1프레임 입력 유예(`quest_npc_just_closed`) + 재진입 시 세대 카운터(`_gen`)로 이전 대사를 즉시 재시작 — 추가 상태 최소화 권고 |
| D-260 (검증 이후 신규) | giver 잡담 진입 경로를 `Events.npc_talked` 구독과 `call_group` 중 하나로 통일할지 (§4.3) | `call_group` 단일 경로 권고 — `quest_npc.gd`가 이미 `talk()` 다음 줄에서 호출해 처리 순서도 함께 보장됨(시그널 연결 순서에 안 기댐) |
| D-261 (검증 이후 신규) | npc_id/퀘스트 상태 → `.dialogue` 파일·title 매핑 규칙(§4.3 제안: giver당 파일 1개, `<quest_id>_<offer|active|ready|done>`/`<npc_id>_everyday`)을 그대로 채택할지 | 제안대로 채택 권고 — narrative-writer가 파일 6개 구조를 그대로 원고 작성에 쓸 수 있음 |
| D-262 (검증 이후 신규, blocker) | 몽실이 `dialogue_path` 분기에서 `object_interacted` emit/`queue_free`를 플레이어 선택 이후로 미루는 재설계(§4.2, `resolve_branch_outcome` 공개 함수) 채택 여부, 및 `branch_quest_id`가 `active` 상태일 때만 대사를 열도록 가드 추가 여부 | 채택 권고 — 그대로 두면 몽실이가 선택 전에 이미 사라지고 퀘스트 수락 전에도 분기 플래그가 확정될 수 있음(§4.2) |
| D-263 (검증 이후 신규) | 패널(`QuestNpcPanel`)과 풍선이 같은 프레임에 열릴 때의 시각 상태 — z-order(어느 `CanvasLayer`가 위), 풍선 숨김 여부, `Hud` 토스트와의 중복 표시 (§7) | ui-ux-designer 확인 필요 — 이 스펙만으로 확정 불가, 임시로는 풍선을 패널이 열려 있는 동안 `visible=false` 처리하는 안을 제시(§7) |
| D-265 (검증 이후 신규) | §10 완료 기준(스모크 재실행 통과)이 이 리눅스 워크트리에서 헤드리스로 검증 불가능한 문제 — 격리 경로 선행 수정 vs GUT 단위 테스트로 완료 기준 대체 (§9.1, §9.6) | GUT 단위 테스트(§9.6) 3개를 1차 게이트로 삼고, 스모크 3종 격리 경로 이식은 별도 작업으로 분리할 것을 권고 — QA 결정 필요 |

---

## 12. API·시그널 근거 표 (사용하는 애드온 함수·시그널과 출처, 검증 이후 시그널 행 추가)

| API | 시그니처 | 출처(확인) |
|---|---|---|
| `DialogueResource.get_next_dialogue_line` | `(title: String = "", extra_game_states: Array = [], mutation_behaviour: DMConstants.MutationBehaviour = Wait) -> DialogueLine` | `dialogue_resource.gd:32-33` (내부적으로 `dialogue_manager.gd:90` 위임) |
| `DialogueManager.show_dialogue_balloon_scene` | `(balloon_scene, resource, title="", extra_game_states=[]) -> Node` (이번 설계는 미사용, §3.2 대안 A. D-250 대안 B 채택 시 사용) | `dialogue_manager.gd:530` |
| `DialogueManager.get_current_scene` | `Callable`, 기본값 `Engine.get_main_loop().current_scene` 반환. "Override if your game manages the current scene itself" 주석(§3.2 대안 B) | `dialogue_manager.gd:56-61` |
| `DialogueManager.dialogue_started` (시그널) | `(resource: DialogueResource)` — `_start_balloon`(= `show_dialogue_balloon_scene` 경로)에서만 emit. **대안 A(직접 호출)에서는 절대 발생하지 않음**(§3.2) | `dialogue_manager.gd:16`, emit 지점 `:555` |
| `DialogueManager.dialogue_ended` (시그널) | `(resource: DialogueResource)` — `get_next_dialogue_line()` 공개 래퍼가 줄이 바닥나면 경로 무관하게 항상 emit | `dialogue_manager.gd:29`, emit 지점 `:92-94` |
| `DialogueManager.create_resource_from_text` | `(text: String) -> Resource` (미사용, 참고용) | `dialogue_manager.gd:488` |
| `DialogueManager.static_id_to_line_id` | `(resource, static_id: String) -> String` (미사용, 참고용) | `dialogue_manager.gd:542` |
| `using` 상태 주입 | `.dialogue` 최상단 `using <이름>` — **컴파일 시점**에 이름을 `project.godot [autoload]` 키 목록과 대조, 없으면 `ERR_UNKNOWN_USING`(135)로 임포트 자체가 실패(정정, §3.4). 통과한 이름만 런타임에 `extra_game_states` 앞에 자동 주입되며, 이 이후 단계에서 노드를 못 찾는 경우에만 `runtime.unknown_autoload`(크래시 아님) | 컴파일 대조: `compilation.gd:148,163-165,830-836`, `constants.gd:117`. 런타임 주입: `dialogue_manager.gd:106-112`. 정규식 `compiler_regex.gd:6` |
| 자기 자신 주입(오토로드 아닌 노드) | `using` 대신 호출 시 `extra_game_states` 인자로 넘기면(`res.get_next_dialogue_line(title, [self])`) `.dialogue`에서 접두어 없이 메서드 호출 가능 — `NpcDialogueController`가 이 경로로 `visit_count()`를 노출(§3.3, 검증 이후 채택) | `dialogue_manager.gd:1120-1128`(`_get_game_states` 순회 후 `_thing_has_method`/`_resolve_thing_method`) |
| 응답 문법 | `- 텍스트` → `TYPE_RESPONSE` | `compilation.gd:936`, `constants.gd:60` |
| 변이 문법 | `do`/`do!`/`set`/`$>`/`$>>` | `compiler_regex.gd:12` |
| 정적 ID 문법 | `[ID:xxx]`(콜론 뒤 공백 없음, 정정 §5) → `translation_key`(strip 없이 그대로 대입) | `compiler_regex.gd:13`(정규식), `compilation.gd:508,676,969-975`(대입) |
| 종료 문법 | `=> END`(현재 title만 종료) vs `=> END!`(전체 종료) | `resolved_goto_data.gd:44-51`, `constants.gd:78-79` |
| `DialogueLine` 필드 | `translation_key`, `responses: Array[DialogueResponse]`, `tags` | `example_balloon.gd:107,113-172` 사용례로 확인 |

확인 안 된 항목(이 워크트리에서 grep으로 재검증하지 못함, "확인 필요"): 웹(HTML5) export와의 실제 호환성 — `export_plugin.gd`에 배제 코드가 없다는 것만 확인했고 공식 보증 문서는 찾지 못함.

---

## 13. 검증 이력

이 워크트리(`stage/m6-int`) 소스로 재확인한 반박 issue 8건 반영. 전부 blocker/major이며 기각 없음.

1. **[blocker] `using NpcDialogueController` 컴파일 에러** — 확인(`compilation.gd:148,163-165,830-836`, `constants.gd:117`, `project.godot:19-32`에 그 이름 없음). §3.3/§3.4를 전면 수정: `using`은 `QuestSystem`만 허용, `NpcDialogueController`는 `res.get_next_dialogue_line(title, [self])`로 자기 자신을 `extra_game_states`에 넘기고 `.dialogue`는 `visit_count("dami")`를 접두어 없이 호출. §0.2-4, §8, §9.2 화이트리스트, §12 표도 함께 수정. (동일 취지 issue 1건이 issue 목록에 중복 제출됐으며 같은 수정으로 해소됨.)
2. **[blocker] `[ID: xxx]`(공백 포함) 정적 ID가 CSV 키와 어긋남** — 확인(`compilation.gd:508,676,969-975`가 strip 없이 그대로 대입, `:675`는 태그 앞 공백만 제거하고 콜론 뒤 공백은 그대로 둠). §5에 실패 메커니즘과 정정된 표기(`[ID:xxx]`, 무공백)를 명시하고 §8 예시·§9.2 검사 설명·§9.3 테스트·§12 표를 전부 무공백 표기로 교체.
3. **[major] D-250 근거 불완전 — `get_current_scene` 오버라이드 대안 누락, `dialogue_started`/`dialogue_ended` 비대칭 미기재** — 확인(`dialogue_manager.gd:56-61`, `:555`, `:92-94`). §3.2에 대안 B(`get_current_scene` 오버라이드 + 공식 경로 유지)와 시그널 비대칭 설명을 추가하고 D-250을 "대안 A vs 대안 B" 형태로 갱신, §12에 시그널 2종 행 추가.
4. **[blocker] `using NpcDialogueController`(중복 제출)** — 1번과 동일 근거·동일 수정으로 해소.
5. **[blocker] giver NPC 동시 열림(QuestNpcPanel + 대사 풍선) 입력 중재 미정의** — 확인(`quest_npc.gd:68-72`의 paused 가드는 재열림만 막고, `quest_npc_panel.gd:118-126`과 새 풍선 사이의 `ui_cancel`/`interact` 소비 순서는 미정의였음, `smoke_quest_npc_panel.gd:90-101`과 충돌 가능). §4.4(D-254)를 신규 작성: `NpcDialogueController`/풍선이 `UiRoot.is_quest_npc_open()`일 때 해당 입력을 소비하지 않는 가드를 권고. §9.1의 "영향 없음" 주장을 철회하고 D-254 구현 후 재실행 필요로 정정.
6. **[major] 리소스 경로 `res://game/data/dialogue/...` 오류** — 확인(`project.godot:26` 등 기존 경로가 전부 `game/` 접두어 없음). §4.2/§8/§9.3의 모든 경로를 `res://data/dialogue/...`로 정정.
7. **[major] `quest_layout_spawner.gd`가 변경 파일 목록·JSON 필드 포워딩에서 누락** — 확인(`quest_layout_spawner.gd:68-75`가 알려진 키 4개만 화이트리스트로 옮김, `dialogue_path`는 없음). §4.2에 `dialogue_path` 포워딩 diff와 `world_objects.json` 갱신 필요성을 추가하고, §10 ⑪-1 파일 목록에 `quest_layout_spawner.gd`를 포함.
8. **[major] D-240 권고(`set_process_unhandled_input`)가 이동을 차단 못함** — 확인(`player.gd:129,323-324`가 `_physics_process`에서 `Input.get_vector`로 폴링, 입력 핸들링 여부와 무관). D-240 권고를 철회하고 D-257(신규)로 `player.gd`의 최소 플래그 안을 권고.
9. **[major] `validate_tables.py`가 이미 612줄로 D-157 500줄 상한 초과** — 확인(`wc -l` 612줄, `docs/brd/04-decisions.md:284` D-157 "새 로직은 반드시 분리 파일로"). §9.2/§10에 분리 파일(`validate_dialogue.py`) 안을 추가하고 D-253(신규)으로 결정 필요 항목화 — `docs/brd/04-decisions.md`는 수정하지 않았다.
10. **[major] `docs/ui/dialogue-balloon.md`와의 상충 2건**(분기 대사 범위 밖 규정 vs §8 몽실이 예시, `is_dialogue_open()` 배제 여부 상충) — 확인(그 문서 §3 항목 3·4, `ui_root.gd:34-49`에 대사 조건 없음). §7에 상충 내용을 명시하고 D-255·D-256(신규)으로 결정 필요 항목화.

**2차 검증 라운드(이 워크트리 재확인, 반박 issue 9건 — blocker 2 · major 7, 전부 기각 없음)**

11. **[blocker] 입력 중재가 "패널 열림" 구간만 다루고 패널이 닫힌 뒤·재진입 규칙이 없음** — 확인(`interact`/`ui_confirm`이 패드 button 0 공유, `project.godot:150-154/205-209`; `quest_npc.gd:71-75`가 interact 1회에 `talk()`+`open_quest_npc` 동시 실행; `UiRoot`가 `Main.tscn:117`의 마지막 자식이라 그 하위가 `_unhandled_input`을 먼저 받음; `smoke_quest_npc_panel.gd:100-103`이 ESC 직후 pad A 재오픈을 기대; `hud.gd:117`/`quest_system.gd:72`만 `npc_talked` 구독). §4.4를 전면 보강: 패널 close 시 1프레임 입력 유예(`quest_npc_just_closed`)를 추가하고, 재생 중 재진입 시 세대 카운터(`_gen`)로 즉시 재시작하는 규칙(D-259)을 신규 작성. §9.1에 `smoke_quest_ui_save.gd`를 "영향 없음"에서 "재검토 필요"로 재분류(같은 issue가 그 스모크의 §9.1 오분류도 함께 지적).
12. **[blocker] giver 5명 중 4명(dami/rozel/pinto/meru) + teo waypoint의 수락/완료 UI 부재로 목표 상태(진행 중/완료 가능/완료 후)가 실제 플레이로 도달 불가능** — 확인(`quest_npc_panel.gd:6-7` `SUPPORTED`는 teo 메인 4개뿐, `QuestSystem.accept()`/`advance()` 호출부는 리포 전체에서 `quest_npc_panel.gd:114` 1곳, `act1_hartland.json:386-435` montsil의 giver는 dami). §4.5를 신규 작성해 이 격차와 3가지 해소안을 제시하고 D-258로 결정 필요 항목화, §1 목표에 경고 문구 추가.
13. **[major] 잡담 진입 경로가 시그널 구독+`call_group`으로 이중 기술돼 있고 처리 순서 미정** — 확인(§3.1 원안의 `Events.npc_talked` 구독과 §10 ⑪-1의 `call_group` diff가 동시에 존재, `quest_system.gd:72`가 오토로드 `_ready`에서 먼저 연결됨). §3.1/§4.3을 정정해 진입 경로를 `call_group("npc_dialogue_ui", "open_npc_dialogue", npc_id)` 1개로 통일(D-260)하고, `talk()` 다음 줄에서 호출되는 **호출 순서 자체**로 처리 순서를 강제한다고 명시.
14. **[major] npc_id/퀘스트 상태 → `.dialogue` 파일·title 매핑 규칙 부재, 컨트롤러 줄 수 추정 과소** — 확인(§4.3 원안은 giver별 퀘스트 목록과 CSV 키 패턴만 제공, 파일명·title 선택 규칙 없음). §4.3에 매핑 규칙 4개(파일 1개/giver, `<quest_id>_<offer|active|ready|done>`/`<npc_id>_everyday`, 상태 우선순위 스캔, `_resolve_title()` 함수)를 신규 작성(D-261)하고 §3.1 예상 줄 수를 70~100→130~170으로 상향.
15. **[major] 몽실이 `dialogue_path`: `object_interacted` emit·`queue_free()`가 플레이어 선택 전에 실행되고 `choose_branch`에 비활성 퀘스트 가드 없음** — 확인(`quest_object.gd` interact()의 emit→branch 분기→queue_free 동기 순서, `quest_system.gd:248-259` choose_branch가 `_active` 여부와 무관하게 story_flag 세팅, `quest_system.gd:262-272` `_resolve_branch_default`가 미선택 시 조용히 release 확정). §4.2를 재설계: emit/분기/vanish를 `QuestObject` 신규 공개 함수 `resolve_branch_outcome(choice_id)`로 옮겨 대사 응답의 `do` 절에서만 호출되게 하고(D-262), `branch_quest_id`가 `active`일 때만 대사를 열도록 가드를 추가. §8 예시의 `do` 절도 `resolve_branch_outcome(...)` 호출로 교체.
16. **[major] 패널+풍선 동시 열림 시 시각 상태(z-order·숨김·중복 토스트) 미정의** — 확인(`quest_npc_panel.gd:25-26` 패널 y=28~242와 `dialogue-balloon.md:55-57` 이름표 y=224~244가 겹침, `hud.gd:322-326` 토스트가 D-245로 그대로 유지, `ui_root.gd:117-120`은 풍선을 제어하지 않음). §7에 D-263을 신규 작성 — 패널 열림 중 풍선 `visible=false` 임시 권고, 토스트 중복은 후속 검토로 기록.
17. **[major] D-257이 이동만 막고 `attack`/`roll`/`guard`는 대사 중 그대로 통과** — 확인(`player.gd:97-100`의 `state_machine.handle_input(event)`가 `idle.gd`/`move.gd`/`attack.gd`/`guard.gd`에서 세 액션을 직접 처리, `attack`은 좌클릭+패드 button 2). §11 D-257 권고를 갱신: `get_move_input()` 가드에 더해 `player.gd._unhandled_input()` 최상단에 `if dialogue_active: return` 1줄을 추가해 `handle_input()` 자체를 대사 중 호출하지 않도록 정정.
18. **[major] §10 완료 기준이 헤드리스로 검증 불가능하고 입력 중재 GUT 테스트가 없음** — 확인(`smoke_quest_npc_panel.gd:18-21`/`smoke_quest_npc_late.gd:9-11`/`smoke_quest_ui_save.gd:16-19`가 `C:/Users/...` 리터럴 비교로 이 리눅스 워크트리에서 결정론적으로 `quit(1)`함, `docs/qa/dialogue-system-test-plan-template.md` §1.3 기존 문서화와 일치). §9.1에 D-265를 신규 작성해 이 한계를 명시하고, §9.6에 GUT 단위 테스트 3개(입력 중재/재개/재진입)를 신규 작성해 1차 자동 게이트로 삼도록 §10 완료 기준을 갱신.
19. **[major] §8 예시의 `[ID:quest_side_heartland_montsil_encounter]` 키가 `quest_ko.csv`에 없고 §5의 "몽실이는 신규 키 없음" 주장과 모순** — 확인(`quest_ko.csv:31-37` montsil 키 6개 중 `_encounter` 없음). §5를 정정: 몽실이도 신규 키 1개(`_encounter`)가 필요함을 명시하고 §10 ⑪-1 파일 목록에 `quest_ko.csv` +1키를 추가.

`docs/brd/04-decisions.md`는 이번 라운드에서도 읽기만 했고 수정하지 않았다. 위 D-253~D-265는 전부 이 스펙 문서 내부의 제안 번호이며 결정 기록 파일에는 아직 없다.
