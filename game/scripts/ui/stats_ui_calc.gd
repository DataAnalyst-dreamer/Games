## 스탯 분배 패널(M3-4, F1-2) 순수 계산. `skill_panel_tab.gd`가 사용한다.
## Data/GameState 싱글턴을 직접 참조하지 않고 전부 인자로 받아 GUT에서 격리 테스트한다
## (inventory_ui_calc.gd·quest_log_ui_calc.gd와 같은 관례 — docs/ui/skill-panel.md §1 참고).
##
## `Progression.get_derived()`(stage/m3-3, 아직 미병합)와 별개로, 이 파일은 stats.json에
## 이미 있는 계수만으로 "포인트 1개를 이 스탯에 넣으면 파생치가 얼마나 바뀌는가" 미리보기를
## 계산한다 — 로직 병합 전에도 동작해야 하고(D-165), 실제 절대값은 소비만 할 뿐 재계산하지
## 않는다는 원칙(로직 담당 M3-3 소비 전용)을 지키기 위함이다.
class_name StatsUiCalc
extends RefCounted

const STAT_KEYS: Array[String] = ["str", "dex", "int", "vit", "luk"]
## 미리보기에서 다루는 4개 파생치만(GDD 5.2 중 DEX 공속/원거리, INT 쿨감은 이번 범위 밖 —
## docs/ui/skill-panel.md §1 참고).
const DERIVED_KEYS: Array[String] = ["attack", "max_hp", "defense", "crit_chance"]


## stat_key에 포인트 1개를 투자하면 DERIVED_KEYS 중 어느 것이 얼마나 바뀌는지.
## stats_table: Data.table("stats")와 같은 모양. 영향 없는 파생치는 결과 Dictionary에
## 아예 넣지 않는다(호출부가 "미리보기 없음"으로 판단).
static func preview_derived_delta(stat_key: String, stats_table: Dictionary) -> Dictionary:
	var coeffs: Dictionary = stats_table.get(stat_key, {})
	match stat_key:
		"str":
			return {"attack": float(coeffs.get("physical_damage_per_point", 0.0))}
		"vit":
			return {
				"max_hp": float(coeffs.get("hp_per_point", 0.0)),
				"defense": float(coeffs.get("defense_per_point", 0.0)),
			}
		"luk":
			return {"crit_chance": float(coeffs.get("crit_chance_per_point", 0.0))}
		_:
			return {}


## GameState.stat_points 필드는 이미 존재하지만, GameState.stats(스탯별 투자값)는
## stage/m3-3 병합 전엔 없을 수 있다 — 그 경우 stats.json의 allocation.initial로 대체.
static func default_stats(stats_table: Dictionary) -> Dictionary:
	var initial: Dictionary = stats_table.get("allocation", {}).get("initial", {})
	var result: Dictionary = {}
	for key in STAT_KEYS:
		result[key] = int(initial.get(key, 0))
	return result
