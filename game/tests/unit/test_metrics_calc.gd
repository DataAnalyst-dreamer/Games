## MetricsCalc(scripts/systems/metrics_calc.gd) 순수 로직 테스트(M1-4).
## Metrics 오토로드(Events 구독·파일 저장)는 노드/시그널/디스크 I/O가 얽혀 있어 GUT
## 유닛 테스트 대상이 아니다 — 실제 수집 경로 통합 검증은
## tests/smoke/SmokeMetrics.tscn(스모크)이 담당한다(README/완료 보고 참고).
extends GutTest


func test_success_rate_normal_case() -> void:
	assert_almost_eq(MetricsCalc.success_rate(3, 4), 0.75, 0.0001)


func test_success_rate_zero_attempts_is_zero_not_divide_by_zero() -> void:
	assert_eq(MetricsCalc.success_rate(0, 0), 0.0)


func test_success_rate_clamped_to_one() -> void:
	# 방어적 clamp: successes가 attempts보다 커지는 카운팅 버그가 있어도 100%를 넘지 않는다.
	assert_eq(MetricsCalc.success_rate(9, 4), 1.0)


func test_roll_success_count_subtracts_iframe_hits() -> void:
	assert_eq(MetricsCalc.roll_success_count(10, 3), 7)


func test_roll_success_count_never_negative() -> void:
	# iframe_hits가 attempts보다 많아지는 이례적 케이스(예: 카운터 리셋 타이밍 버그)에도
	# 음수 성공 횟수를 반환하지 않는다.
	assert_eq(MetricsCalc.roll_success_count(2, 5), 0)


func test_average_sec_of_empty_array_is_zero() -> void:
	assert_eq(MetricsCalc.average_sec([]), 0.0)


func test_average_sec_computes_mean() -> void:
	assert_almost_eq(MetricsCalc.average_sec([0.5, 0.6, 1.0]), 0.7, 0.0001)


func test_build_monster_stats_merges_kills_and_ttk_by_monster_id() -> void:
	var stats: Dictionary = MetricsCalc.build_monster_stats(
		{"slime": 3, "horn_rabbit": 1},
		{"slime": [0.5, 0.6, 0.55]})

	assert_eq(stats["slime"]["kills"], 3)
	assert_almost_eq(stats["slime"]["avg_ttk_sec"], 0.55, 0.0001)
	assert_eq(stats["slime"]["ttk_samples_sec"], [0.5, 0.6, 0.55])
	# 처치는 있지만(TTK 표본이 없는) 몬스터도 0건 평균으로 항상 포함되어야 한다
	# (예: 최초 피격 없이 즉사 판정된 디버그 상황) — 누락되면 요약에서 종이 사라진다.
	assert_eq(stats["horn_rabbit"]["kills"], 1)
	assert_eq(stats["horn_rabbit"]["avg_ttk_sec"], 0.0)
	assert_eq(stats["horn_rabbit"]["ttk_samples_sec"], [])


func test_build_monster_stats_includes_monster_with_ttk_but_zero_recorded_kills() -> void:
	# kills_by_monster에 없더라도 ttk_samples_by_monster에만 있으면 종이 빠지지 않아야 한다
	# (수집 순서 방어 — enemy_died 처리 중 카운터 갱신 순서가 바뀌어도 요약이 안전하도록).
	var stats: Dictionary = MetricsCalc.build_monster_stats({}, {"mushroom": [1.2]})
	assert_eq(stats["mushroom"]["kills"], 0)
	assert_almost_eq(stats["mushroom"]["avg_ttk_sec"], 1.2, 0.0001)


func test_build_summary_schema_has_expected_top_level_keys() -> void:
	var raw := {
		"tester": "hong",
		"session_start_unix": 1000,
		"generated_at_unix": 1300,
		"session_duration_sec": 300.0,
		"deaths": 2,
		"roll_attempts": 10,
		"roll_iframe_hits": 1,
		"guard_attempts": 5,
		"just_guard_success": 2,
		"normal_guard_count": 2,
		"combo_finisher_reached_count": 4,
		"player_hits_taken": 6,
		"player_damage_taken_total": 42,
		"kills_by_monster": {"slime": 5},
		"ttk_samples_by_monster": {"slime": [0.5, 0.5]},
	}

	var summary: Dictionary = MetricsCalc.build_summary(raw)

	assert_eq(summary["schema_version"], MetricsCalc.SCHEMA_VERSION)
	assert_eq(summary["tester"], "hong")
	assert_eq(summary["deaths"], 2)
	assert_eq(summary["roll"]["attempts"], 10)
	assert_eq(summary["roll"]["success"], 9)
	assert_almost_eq(summary["roll"]["success_rate"], 0.9, 0.0001)
	assert_eq(summary["guard"]["just_guard_attempts"], 5)
	assert_eq(summary["guard"]["just_guard_success"], 2)
	assert_almost_eq(summary["guard"]["just_guard_success_rate"], 0.4, 0.0001)
	assert_eq(summary["guard"]["normal_guard_count"], 2)
	assert_eq(summary["combo_finisher_reached_count"], 4)
	assert_eq(summary["player"]["hits_taken"], 6)
	assert_eq(summary["player"]["damage_taken_total"], 42)
	assert_eq(summary["monsters"]["slime"]["kills"], 5)
	assert_almost_eq(summary["monsters"]["slime"]["avg_ttk_sec"], 0.5, 0.0001)


func test_build_summary_is_json_serializable() -> void:
	# 실제 저장 경로(Metrics._write_json)와 동일하게 JSON.stringify가 예외 없이
	# 문자열을 만들어야 한다 — Dictionary 키가 전부 String이어야 하므로(monster_id는
	# 이미 String), 왕복(stringify → parse) 결과가 원본과 동일한지도 함께 확인한다.
	var summary: Dictionary = MetricsCalc.build_summary({
		"tester": "anon", "kills_by_monster": {"slime": 1}, "ttk_samples_by_monster": {"slime": [0.5]},
	})

	var json_text: String = JSON.stringify(summary)
	var parsed: Variant = JSON.parse_string(json_text)

	assert_typeof(parsed, TYPE_DICTIONARY)
	assert_eq(parsed["tester"], "anon")
	# JSON.parse_string()은 숫자를 항상 float로 복원한다(Godot JSON 사양) — int 리터럴과
	# 비교하면 GUT이 "Float/Int comparison" 경고를 내므로 float로 비교한다.
	assert_eq(parsed["monsters"]["slime"]["kills"], 1.0)
