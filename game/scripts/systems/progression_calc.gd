## 경험치/레벨 순수 계산 로직(M3-1, F1-2). Data/GameState 등 오토로드에 의존하지 않아
## GUT에서 곡선·몬스터 테이블을 직접 Dictionary로 주입해 테스트할 수 있다(resources.gd/
## Inventory/Equipment와 동일한 "순수 로직 vs 부수효과" 분리 원칙). 실제 프로젝트 값
## 조회·Events 발신·GameState 반영은 progression_service.gd(오토로드 Progression)가
## 이 클래스를 감싸 담당한다.
class_name ProgressionCalc
extends RefCounted


## exp_curve 테이블(Data.table("exp_curve") 형태 — {"1": {"exp_to_next":20,...}, ...},
## data.gd._load_csv()가 만드는 "첫 컬럼(level) 문자열 -> 행 Dictionary" 구조) 에서
## level -> level+1 도달에 필요한 경험치. 행이 없거나(만렙 초과 등) exp_to_next가
## 없으면 0(더 오를 곳 없음)을 반환한다.
static func exp_for_level(level: int, curve: Dictionary) -> int:
	var row: Variant = curve.get(str(level), null)
	if not (row is Dictionary):
		return 0
	return int((row as Dictionary).get("exp_to_next", 0))


## monsters 테이블(Data.table("monsters"))에서 monster_id의 exp_reward. 필드가 아직
## 없는 몬스터(game-designer 값 미기재)는 0(경험치 없음)으로 안전하게 처리한다 —
## 존재 자체는 tools/qa/validate_tables.py가 별도로 강제한다.
static func exp_reward_for_monster(monster_id: String, monsters: Dictionary) -> int:
	var entry: Variant = monsters.get(monster_id, null)
	if not (entry is Dictionary):
		return 0
	return int((entry as Dictionary).get("exp_reward", 0))


## exp_curve의 해당 레벨(막 도달한 레벨) 행에 있는 hp_bonus/atk_bonus(선택:
## stamina_bonus)를 Events.level_up payload 키(max_hp/attack/stamina)로 옮긴다.
static func stat_gains_for_level(level: int, curve: Dictionary) -> Dictionary:
	var row: Variant = curve.get(str(level), null)
	if not (row is Dictionary):
		return {}
	var r: Dictionary = row
	var gains: Dictionary = {}
	if r.has("hp_bonus"):
		gains["max_hp"] = int(r["hp_bonus"])
	if r.has("atk_bonus"):
		gains["attack"] = float(r["atk_bonus"])
	if r.has("stamina_bonus") and float(r["stamina_bonus"]) != 0.0:
		gains["stamina"] = float(r["stamina_bonus"])
	return gains


## 경험치 gained를 더한 뒤 필요한 만큼 반복 레벨업한다(한 번에 여러 레벨 상승 지원,
## 완료 보고 검증 항목 "여러 레벨 한꺼번에"). 반환: {"exp": int, "level": int,
## "level_ups": Array[Dictionary]} — level_ups의 각 원소는 {"new_level": int,
## "stat_gains": Dictionary}이고, 레벨업 1회당 1개씩 순서대로 들어 있어 호출부가 이
## 순서 그대로 Events.level_up을 여러 번 발신하면 된다(director D-151: HUD 팝업이 레벨업
## 횟수만큼 개별로 뜨도록). 이미 만렙이면 gained를 그냥 버린다(D-152 "초과 경험치 캡").
static func apply_exp(current_exp: int, current_level: int, gained: int, curve: Dictionary, max_level: int) -> Dictionary:
	var level: int = current_level
	var exp: int = current_exp
	var level_ups: Array[Dictionary] = []
	if level >= max_level:
		return {"exp": 0, "level": max_level, "level_ups": level_ups}
	exp += maxi(gained, 0)
	while level < max_level:
		var need: int = exp_for_level(level, curve)
		if need <= 0 or exp < need:
			break
		exp -= need
		level += 1
		level_ups.append({"new_level": level, "stat_gains": stat_gains_for_level(level, curve)})
	if level >= max_level:
		exp = 0
	return {"exp": exp, "level": level, "level_ups": level_ups}
