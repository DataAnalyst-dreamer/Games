## 스탯 분배 패널(M4-5 v2, ro-benchmark-progression-v1.md §1~2) 순수 계산.
## `skill_panel_tab.gd`가 사용한다. Data/GameState/Progression을 직접 참조하지 않고 전부
## 인자로 받아 GUT에서 격리 테스트한다(inventory_ui_calc.gd·quest_log_ui_calc.gd와 같은
## 관례).
##
## `Progression.get_derived()`/`Progression.next_stat_cost()`(stage/m4-4, 병합 전)와
## 별개로, 이 파일은 stats.json에 이미 있는 계수·공식 문자열만으로 "포인트 1개를 이
## 스탯에 넣으면 무엇이 얼마나 바뀌는가" 미리보기와 "다음 포인트 비용"을 계산한다 —
## 로직 병합 전에도 동작해야 하고, 실제 절대값(파생치 자체)은 소비만 할 뿐 재계산하지
## 않는다는 원칙(로직 담당 M4-4 소비 전용)을 지키기 위함이다.
class_name StatsUiCalc
extends RefCounted

## D-158/M4-0 v2: AGI 신설로 5→6스탯.
const STAT_KEYS: Array[String] = ["str", "agi", "dex", "int", "vit", "luk"]

## `Progression.get_derived()`가 반환하는 것과 동일한 키만 다룬다(D-195 코디네이터
## 확정 목록). 코디네이터가 명시하지 않은 키(예: cooldown_mult)는 일부러 다루지 않는다
## — 존재 여부가 불확실한 키를 미리 넣어 두면 영구 숨김 데드코드가 된다.
const DERIVED_KEYS: Array[String] = [
	"atk", "matk", "def", "mdef", "max_hp", "max_sp", "sp_regen",
	"crit_chance", "hit_scale", "flee_iframe_bonus", "move_speed_mult",
	"combo_frame_mult", "post_recovery_mult",
]

## D-195: 코디네이터가 확정한 파생치별 표시 서식. 정수/소수/퍼센트/부호 있는 퍼센트로
## 나뉜다 — "원시값 덤프 금지, 눈에 보이는 효과로" 요구사항 반영.
const _INT_KEYS: Array[String] = ["max_hp", "max_sp"]
const _RAW_1DP_KEYS: Array[String] = ["atk", "matk", "def", "mdef"]
const _PCT_TOTAL_UP_KEYS: Array[String] = ["hit_scale", "move_speed_mult"] # (v-1)*100, "+N%"
const _PCT_SPEEDUP_KEYS: Array[String] = ["combo_frame_mult"] # (1-v)*100, "+N%"(작을수록 빠름)
const _PCT_REDUCTION_KEYS: Array[String] = ["post_recovery_mult"] # (1-v)*100, "-N%"


## stats.json.allocation.point_cost_curve_formula(D-184 확정, "floor(n/10)+1")를 직접
## 계산한다. `Progression.next_stat_cost(key)`(stage/m4-4, 병합 전엔 없음)가 있으면 그쪽이
## 정본이고, 이 함수는 병합 전 폴백 + GUT 검증용이다.
static func next_point_cost(current_value: int) -> int:
	return int(current_value / 10) + 1


## stat_key에 포인트 1개를 투자하면 DERIVED_KEYS 중 어느 것이 얼마나 바뀌는지(선형
## 계수만 다루는 4스탯: str/vit/int/luk). AGI/DEX 효과는 상한(cap)이 있는 비선형 배율이라
## 여기서 다루지 않고, 화면 쪽 상시 효과 설명 한 줄(ui.stat.effect.*)로 대신한다.
static func preview_derived_delta(stat_key: String, stats_table: Dictionary) -> Dictionary:
	var coeffs: Dictionary = stats_table.get(stat_key, {})
	match stat_key:
		"str":
			return {"atk": float(coeffs.get("physical_damage_per_point", 0.0))}
		"vit":
			return {
				"max_hp": float(coeffs.get("hp_per_point", 0.0)),
				"def": float(coeffs.get("defense_per_point", 0.0)),
				"mdef": float(coeffs.get("mdef_per_point", 0.0)),
			}
		"int":
			return {
				"matk": float(coeffs.get("magic_damage_per_point", 0.0)),
				"mdef": float(coeffs.get("mdef_per_point", 0.0)),
				"max_sp": float(coeffs.get("max_sp_per_point", 0.0)),
				"sp_regen": float(coeffs.get("sp_regen_per_point", 0.0)),
			}
		"luk":
			return {"crit_chance": float(coeffs.get("crit_chance_per_point", 0.0))}
		_:
			return {}


## GameState.stats 필드는 stage/m4-4 병합 전엔 5키(구 스키마)이거나 없을 수 있다 —
## 그 경우 stats.json의 allocation.initial(6키)로 대체.
static func default_stats(stats_table: Dictionary) -> Dictionary:
	var initial: Dictionary = stats_table.get("allocation", {}).get("initial", {})
	var result: Dictionary = {}
	for key in STAT_KEYS:
		result[key] = int(initial.get(key, 0))
	return result


## derived 표시값 서식(D-195). key가 DERIVED_KEYS 밖이면 "%.2f"로 그냥 표시(안전망).
static func format_derived_value(key: String, value: float) -> String:
	if key in _INT_KEYS:
		return str(int(round(value)))
	if key == "crit_chance":
		return "%.1f%%" % (value * 100.0)
	if key in _PCT_TOTAL_UP_KEYS:
		return "+%.1f%%" % ((value - 1.0) * 100.0)
	if key in _PCT_SPEEDUP_KEYS:
		return "+%.1f%%" % ((1.0 - value) * 100.0)
	if key in _PCT_REDUCTION_KEYS:
		return "-%.1f%%" % ((1.0 - value) * 100.0)
	if key == "flee_iframe_bonus":
		return "+%.2fs" % value
	if key == "sp_regen":
		return "%.2f/s" % value
	if key in _RAW_1DP_KEYS:
		return "%.1f" % value
	return "%.2f" % value
