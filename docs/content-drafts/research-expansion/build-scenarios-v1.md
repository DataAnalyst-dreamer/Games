# 초반 지역 빌드 상호작용 시나리오 v1

2026-09-13 · **설계/구현 검증용 초안, 런타임 미반영.** [JSON 카탈로그](build-scenarios-v1.json)가 시나리오별 정본이다. 별도 새 스킬이나 직업을 추가한 것이 아니라 [96 계열 노드](mastery-nodes-v3.json)·[28 조합 특성](hybrid-classes-v3.json)의 실제 ID를 검증 가능한 사용 사례로 묶었다. 원본 제안의 8계열·124성장 노드·36직업을 유지했다.

## 정책과 사용 범위

사용자가 요청한 넓은 트리·조합 전직 및 D-142의 높은 골드+수집 아이템+가벼운 레벨다운 방향은 유지한다. 아래의 활성 계열2·액티브 슬롯2·액티브당 변형1·고유 특성1은 [기존 v3 제안](class-progression-v3.md)의 검증 가정이지 새 사용자 확정이 아니다.

각 빌드는 나중에 구현할 학습/전직 완료 테스트 fixture다. 초반 지역의 적·공간을 재사용한다는 뜻이며, 첫 20~30분 안에 모든 직업과 상위 노드를 획득할 수 있다는 뜻이 아니다. JSON의 learning_order는 선행 노드를 먼저 배운 순서이며, 각 계열에 1단계 액티브와 2단계 노드가 존재하는지 검사한다. 실제 단계별 투자량·SP 예산·해금 레벨·전직 체험 과제는 미확정/미구현으로 남긴다.

활성 슬롯에 없는 선행 액티브/변형도 학습 목록에 있을 수 있다. **배웠다고 자동 장착·효과 적용하지 않는다.** 예를 들어 제련 받침을 배우기 위한 해머 선행 기술은 학습 기록에 있지만, 받침+원소 fixture에서 보이지 않는 해머를 꺼내 공격하지 않는다. 장비 검사는 장착 액티브와 연결 변형의 태그를 대상으로 하며, 새 장비 호환 정책을 승인하지 않는다.

모든 context 배치는 제안이다. monster/location/material ID가 실제 데이터에 있다고 해서 해당 위치에 그 적·소품이 현재 배치되어 있다는 주장이 아니다. 기존 재료는 관찰/인벤토리 비교용이며 스킬 비용·전직 재료·새 드롭·레시피로 확정하지 않는다. 초점도구는 기존 제안대로 허리 매개·장비 촉매를 포함하며 양손 스태프를 강제하지 않는다.

## 12개 빌드의 다른 선택

| 시나리오 | 조합 직업 | 액티브 두 슬롯 | 핵심 검증 | 순서 |
|---|---|---|---|---|
| BSV1_blade_guard | 철위기사 | 간격 베기 / 낮춘 방패 | 울타리 앞에서 받기와 물러서기 | P1 |
| BSV1_blade_trick | 결투가 | 간격 베기 / 옆으로 비키기 | 측면 회피와 후퇴 보행을 구분하기 | P2 |
| BSV1_blade_element | 마검사 | 간격 베기 / 잔불 획 | 잔향과 물리 피해를 중복 합산하지 않기 | P2 |
| BSV1_guard_bow | 보루궁수 | 낮춘 방패 / 고요한 시위 | 활의 버팀은 방패가 아니다 | P2 |
| BSV1_bow_trick | 그늘사냥꾼 | 고요한 시위 / 마른 가지 소리 | 미끼가 전투를 초기화하지 않기 | P3 |
| BSV1_bow_element | 원소궁수 | 고요한 시위 / 잔불 획 | 시전과 사격의 순서 | P2 |
| BSV1_bow_life | 숲길순찰자 | 고요한 시위 / 잎의 덧댐 | 회수 동선에 남는 위험 | P2 |
| BSV1_trick_life | 약초추적자 | 옆으로 비키기 / 쉬어가는 풀 | 무적 보행 없이 되밟기 | P3 |
| BSV1_element_life | 계절술사 | 잔불 획 / 쉬어가는 풀 | 치료 자리를 방해 자리로 바꾸기 | P3 |
| BSV1_element_forge | 마도공학자 | 잔불 획 / 접이식 받침 | 저장된 한 발을 직접 방출하기 | P3 |
| BSV1_life_faith | 치유성직자 | 잎의 덧댐 / 접힌 보호문 | 유효 회복을 나누되 복제하지 않기 | P2 |
| BSV1_guard_forge | 철벽공병 | 낮춘 방패 / 접이식 받침 | 길을 막지 않는 접이식 방어 | P3 |

P1은 핀 검술/수호 첫 세로 단면 후보 하나다. P2도 이미 구현 가능하다고 판정한 것이 아니며 공통 액티브/변형/특성 연결이 필요하다. P3는 조사 AI·회복 구역·설치물 등 신규 상태가 필요한 후속 목록이다. 순서는 제안이며 상위 노드 학습 시점을 확정하지 않는다.

## 구현자가 사용할 상세 체크리스트

각 JSON 항목은 시작 조건(given) → 직접 행동(action) → 관찰할 결과(expected) → 금지할 오작동(reject) → 남길 근거(evidence) 5항목을 갖는다. 로그 이름과 이벤트 부모 ID 등은 **향후 계측 요구**이지 현재 게임에 그 API가 존재한다는 뜻이 아니다.

### BSV1_blade_guard · 철위기사

- 학습 선행 순서: `v3_blade_measured_cut` → `v3_guard_low_brace` → `v3_blade_edge_stop` → `v3_guard_yield_brace`.
- 장착: `v3_blade_measured_cut` + 변형 `v3_blade_edge_stop` / `v3_guard_low_brace` + 변형 `v3_guard_yield_brace`. 고유 특성은 `v3_bridge_blade_guard` 하나.
- 맥락: `horn_rabbit` / `heartland_pasture_boundary` / 기존 소재 `rabbit_horn`. 연결 초안 `draft_encounter_rabbit_fence`, `SQH-V2-06`.
- 약점: 끝선 멈춤은 후퇴를 없애며 충격 흘리기는 뒤 공간을 내준다. 방패 없이 가드 토큰을 만들 수 없다.
- 기본 대안: 넓은 흙길로 돌아가거나 기본 회피 후 기본 공격한다.
- 신규 구현 요구: 가드 성공 토큰과 직접 근접 기술 연결; 변형별 후퇴/접지 모션; 벽 뒤 이동 충돌.

검사 `BSV1_blade_guard_C1`, `BSV1_blade_guard_C2`, `BSV1_blade_guard_C3`, `BSV1_blade_guard_C4`, `BSV1_blade_guard_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 방패 장착, 뿔토끼 정면 예고가 보임 → 기본 가드 성공 후 슬롯1을 직접 누른다 → 받아낸 틈이 다음 근접 기술에만 소비된다

### BSV1_blade_trick · 결투가

- 학습 선행 순서: `v3_blade_measured_cut` → `v3_trick_side_feint` → `v3_blade_edge_stop` → `v3_trick_back_feint`.
- 장착: `v3_blade_measured_cut` + 변형 `v3_blade_edge_stop` / `v3_trick_side_feint` + 변형 `v3_trick_back_feint`. 고유 특성은 `v3_bridge_blade_trick` 하나.
- 맥락: `slime` / `bridgeport_dock` / 기존 소재 `slime_jelly`. 연결 초안 `draft_encounter_slime_gutter`, `SQH-V2-02`.
- 약점: 좁은 후퇴는 무적이 아니며 광역 대응을 포기한다.
- 기본 대안: 슬라임을 피해서 넓은 길로 걷거나 기본 구르기 뒤 기본 공격한다.
- 신규 구현 요구: 공격 방향과 상대 측면 관계 판정; 기본 회피 성공 이벤트 구분; 변형과 조합 특성 우선순위 결정 전 fixture.

검사 `BSV1_blade_trick_C1`, `BSV1_blade_trick_C2`, `BSV1_blade_trick_C3`, `BSV1_blade_trick_C4`, `BSV1_blade_trick_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 슬라임 공격선 옆에 빈 공간 → 기본 회피로 실제 유효 공격을 벗어난 뒤 측면 슬롯1 입력 → 빈자리 찌르기 조건을 만족한 직접 기술만 좁게 변한다

### BSV1_blade_element · 마검사

- 학습 선행 순서: `v3_blade_measured_cut` → `v3_element_ember_stroke` → `v3_blade_edge_stop` → `v3_element_ember_point`.
- 장착: `v3_blade_measured_cut` + 변형 `v3_blade_edge_stop` / `v3_element_ember_stroke` + 변형 `v3_element_ember_point`. 고유 특성은 `v3_bridge_blade_element` 하나.
- 맥락: `slime` / `heartland_dandelion_village` / 기존 소재 `slime_jelly`. 연결 초안 `draft_encounter_slime_tally`, `SQH-V2-01`.
- 약점: 물리 이득 일부를 속성으로 바꾸며 좁은 투사체는 벽에 막힌다.
- 기본 대안: 기본 근접 공격과 회피, 관찰 후 표지 상호작용을 쓴다.
- 신규 구현 요구: 속성 전환 원천 표시; 검 장착 촉매 시전 포즈; 잔향 파생 이벤트 재귀 차단.

검사 `BSV1_blade_element_C1`, `BSV1_blade_element_C2`, `BSV1_blade_element_C3`, `BSV1_blade_element_C4`, `BSV1_blade_element_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 검과 휴대 촉매 장착 → 모은 잔불을 시전한 뒤 슬롯1을 직접 입력 → 다음 근접 기술에 준비된 속성 잔향이 소비된다

### BSV1_guard_bow · 보루궁수

- 학습 선행 순서: `v3_guard_low_brace` → `v3_bow_still_string` → `v3_guard_yield_brace` → `v3_bow_quick_string`.
- 장착: `v3_guard_low_brace` + 변형 `v3_guard_yield_brace` / `v3_bow_still_string` + 변형 `v3_bow_quick_string`. 고유 특성은 `v3_bridge_guard_bow` 하나.
- 맥락: `horn_rabbit` / `heartland_pasture_boundary` / 기존 소재 `wool_soft`. 연결 초안 `draft_encounter_rabbit_brush`, `SQH-V2-06`.
- 약점: 양손 활은 피해를 받으며 버팀 유지와 공격은 병행하지 못한다.
- 기본 대안: 돌진을 기본 회피로 피하고 넓은 길을 이용한다.
- 신규 구현 요구: 무방패 버팀; 정지조준 완료/첫 넉백 토큰; 활 동작과 버팀 배타 상태.

검사 `BSV1_guard_bow_C1`, `BSV1_guard_bow_C2`, `BSV1_guard_bow_C3`, `BSV1_guard_bow_C4`, `BSV1_guard_bow_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 활만 장착, 방패 없음 → 슬롯1 유지 중 돌진 피해를 받는다 → 받는 피해는 유지하며 충격 흘리기 변형에 따라 짧게 후퇴하고, 뒤가 벽이면 충돌에서 멈춘다. 고정 버팀의 넉백 억제를 동시에 적용하지 않는다. 사격 준비 완료 뒤 첫 넉백 억제는 C3의 조합 고유 특성으로 분리한다.

### BSV1_bow_trick · 그늘사냥꾼

- 학습 선행 순서: `v3_bow_still_string` → `v3_trick_dry_twig` → `v3_bow_quick_string` → `v3_trick_close_rattle`.
- 장착: `v3_bow_still_string` + 변형 `v3_bow_quick_string` / `v3_trick_dry_twig` + 변형 `v3_trick_close_rattle`. 고유 특성은 `v3_bridge_bow_trick` 하나.
- 맥락: `horn_rabbit` / `heartland_pasture_boundary` / 기존 소재 `rabbit_horn`. 연결 초안 `draft_encounter_rabbit_brush`, `SQH-V2-02`.
- 약점: 새 조사 AI가 없으면 성립하지 않는 후속 빌드다. 가까운 소란은 자신 근처로 적을 끌 수 있다.
- 기본 대안: 현재는 미끼 없이 기본 회피와 큰길 우회를 쓴다.
- 신규 구현 요구: 비전투 적 조사 AI 신규; 인지 상태/관찰한 미끼 ID; 첫발과 다른 사선의 관계.

검사 `BSV1_bow_trick_C1`, `BSV1_bow_trick_C2`, `BSV1_bow_trick_C3`, `BSV1_bow_trick_C4`, `BSV1_bow_trick_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 비전투·반응 가능 뿔토끼 fixture; 새 AI 구현 필요 → 발밑 소란을 던지고 사격각을 바꾼다 → 소리를 관찰한 적의 첫 직접 화살만 조건 충족

### BSV1_bow_element · 원소궁수

- 학습 선행 순서: `v3_bow_still_string` → `v3_element_ember_stroke` → `v3_bow_quick_string` → `v3_element_ember_point`.
- 장착: `v3_bow_still_string` + 변형 `v3_bow_quick_string` / `v3_element_ember_stroke` + 변형 `v3_element_ember_point`. 고유 특성은 `v3_bridge_bow_element` 하나.
- 맥락: `mushroom` / `heartland_echo_cave_entrance` / 기존 소재 `mushroom_cap`. 연결 초안 `draft_encounter_mushroom_steps`, `SQH-V2-04`.
- 약점: 가까운 속성 준비와 정지 사격 때문에 장판 재배치 압박을 받는다.
- 기본 대안: 장판을 기본 이동으로 우회하고 나무판을 일반 상호작용한다.
- 신규 구현 요구: 활 촉매 시전 자세; 시전회수와 사격 준비 배타; 원소전환/착지선형 판정.

검사 `BSV1_bow_element_C1`, `BSV1_bow_element_C2`, `BSV1_bow_element_C3`, `BSV1_bow_element_C4`, `BSV1_bow_element_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 장판 밖 안전 자리 → 슬롯2 직접 시전 후 슬롯1 준비·발사 → 다음 화살이 준비 속성으로 전환된다

### BSV1_bow_life · 숲길순찰자

- 학습 선행 순서: `v3_bow_still_string` → `v3_life_leaf_dressing` → `v3_bow_quick_string` → `v3_life_slow_dressing`.
- 장착: `v3_bow_still_string` + 변형 `v3_bow_quick_string` / `v3_life_leaf_dressing` + 변형 `v3_life_slow_dressing`. 고유 특성은 `v3_bridge_bow_life` 하나.
- 맥락: `mushroom` / `heartland_hilltop_waypoint` / 기존 소재 `herb_common`. 연결 초안 `draft_encounter_mushroom_steps`, `SQH-V2-01`.
- 약점: 씨앗 회복은 원래 사격지점으로 돌아와야 하며 그 자리에 장판이 깔릴 수 있다.
- 기본 대안: 씨앗을 포기하고 기본 우회 또는 기존 허용 회복 수단을 사용한다.
- 신규 구현 요구: 판매불가 씨앗 흔적 상태; 사격 원점/회수/만료; 지속회복 피격중단.

검사 `BSV1_bow_life_C1`, `BSV1_bow_life_C2`, `BSV1_bow_life_C3`, `BSV1_bow_life_C4`, `BSV1_bow_life_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 손상 상태에서 안전하게 원거리 적중 → 사격지점을 떠난 뒤 안전할 때 되돌아온다 → 한정된 씨앗 흔적을 회수하며 직접 회복 경로와 구분한다

### BSV1_trick_life · 약초추적자

- 학습 선행 순서: `v3_trick_side_feint` → `v3_life_thorn_thread` → `v3_life_branching_thorn` → `v3_life_resting_patch` → `v3_trick_back_feint`.
- 장착: `v3_trick_side_feint` + 변형 `v3_trick_back_feint` / `v3_life_resting_patch` (변형 없음). 고유 특성은 `v3_bridge_trick_life` 하나.
- 맥락: `horn_rabbit` / `heartland_pasture_boundary` / 기존 소재 `herb_common`. 연결 초안 `draft_encounter_rabbit_fence`, `SQH-V2-03`.
- 약점: 왕복 동선이 돌진과 겹칠 수 있다. 후퇴 보행은 회피 성공이 아니다.
- 기본 대안: 회복 구역을 떠나 기본 이동·구르기로 안전을 우선한다.
- 신규 구현 요구: 생명 구역 단일 인스턴스; 구역 통과 후 기본회피 방향 기록; 되밟기 회복 한도/중복 금지.

검사 `BSV1_trick_life_C1`, `BSV1_trick_life_C2`, `BSV1_trick_life_C3`, `BSV1_trick_life_C4`, `BSV1_trick_life_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 쉬어가는 풀을 준비해 생성 → 구역 통과 후 다른 방향 기본 회피, 이후 통과점 복귀 → 되밟는 약초 조건을 만족한 흔적만 회복에 사용한다

### BSV1_element_life · 계절술사

- 학습 선행 순서: `v3_element_ember_stroke` → `v3_life_thorn_thread` → `v3_life_branching_thorn` → `v3_life_resting_patch` → `v3_element_ember_point`.
- 장착: `v3_element_ember_stroke` + 변형 `v3_element_ember_point` / `v3_life_resting_patch` (변형 없음). 고유 특성은 `v3_bridge_element_life` 하나.
- 맥락: `mushroom` / `heartland_echo_cave_entrance` / 기존 소재 `herb_common`. 연결 초안 `draft_encounter_mushroom_steps`, `SQH-V2-04`.
- 약점: 회복 구역을 전환하면 그 회복 기회를 잃는다. 적 장판과 자신의 구역을 구분해야 한다.
- 기본 대안: 기본 이동으로 장판을 우회하고 일반 관찰로 동굴 입구를 조사한다.
- 신규 구현 요구: 회복구역 소모와 방해구역 전환 원자처리; 구역 소유/원천; 원소 융합과 조합특성 중복방지.

검사 `BSV1_element_life_C1`, `BSV1_element_life_C2`, `BSV1_element_life_C3`, `BSV1_element_life_C4`, `BSV1_element_life_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 손상 상태, 생명 구역 하나 생성 → 구역에 원소 슬롯1을 직접 연결 → 원본 회복 구역을 소모해 방해 구역 후보로 전환한다

### BSV1_element_forge · 마도공학자

- 학습 선행 순서: `v3_element_ember_stroke` → `v3_forge_split_line` → `v3_forge_wide_line` → `v3_forge_field_emplacement` → `v3_element_ember_point`.
- 장착: `v3_element_ember_stroke` + 변형 `v3_element_ember_point` / `v3_forge_field_emplacement` (변형 없음). 고유 특성은 `v3_bridge_element_forge` 하나.
- 맥락: `slime` / `heartland_dandelion_village_square` / 기존 소재 `salvage_scrap`. 연결 초안 `draft_encounter_slime_tally`, `SQH-V2-05`.
- 약점: 설치·저장 동안 즉시 피해를 포기하고 파괴되면 예약을 잃는다.
- 기본 대안: 장치를 쓰지 않고 기본 공격·회피 또는 통과 동선을 택한다.
- 신규 구현 요구: 설치물 신규 상태/감지; 저장후 문맥방출 입력; 회수/파괴 시 예약 제거.

검사 `BSV1_element_forge_C1`, `BSV1_element_forge_C2`, `BSV1_element_forge_C3`, `BSV1_element_forge_C4`, `BSV1_element_forge_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 받침 설치가 완료됨 → 직접 원소를 연결한다 → 방향성 발사 하나를 저장하며 연결 순간 즉시 피해를 내지 않는다

### BSV1_life_faith · 치유성직자

- 학습 선행 순서: `v3_life_leaf_dressing` → `v3_faith_folded_sign` → `v3_faith_fixed_sign` → `v3_life_careful_recovery`.
- 장착: `v3_life_leaf_dressing` (변형 없음) / `v3_faith_folded_sign` + 변형 `v3_faith_fixed_sign`. 고유 특성은 `v3_bridge_life_faith` 하나.
- 맥락: `slime` / `heartland_dandelion_village` / 기존 소재 `herb_common`. 연결 초안 `draft_encounter_slime_gutter`, `SQH-V2-02`.
- 약점: 회복 일부를 보호로 돌려 당장 되찾는 HP를 포기하며 보호 자세는 움직임·공격을 제한한다.
- 기본 대안: 위험에서 기본 이동으로 벗어나거나 기존 회복 수단을 사용한다.
- 신규 구현 요구: 유효회복량 먼저계산/원자분배; 보호 원천과방향; 만피/사망/과잉회복 제외.

검사 `BSV1_life_faith_C1`, `BSV1_life_faith_C2`, `BSV1_life_faith_C3`, `BSV1_life_faith_C4`, `BSV1_life_faith_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 실제 HP 손실이 있음 → 슬롯1 직접 회복 → 유효량을 계산한 뒤 HP와 다음 보호로 나눠 적용한다

### BSV1_guard_forge · 철벽공병

- 학습 선행 순서: `v3_guard_low_brace` → `v3_forge_split_line` → `v3_forge_wide_line` → `v3_forge_field_emplacement` → `v3_guard_yield_brace`.
- 장착: `v3_guard_low_brace` + 변형 `v3_guard_yield_brace` / `v3_forge_field_emplacement` (변형 없음). 고유 특성은 `v3_bridge_guard_forge` 하나.
- 맥락: `horn_rabbit` / `heartland_pasture_boundary` / 기존 소재 `iron_ore`. 연결 초안 `draft_encounter_rabbit_fence`, `SQH-V2-01`.
- 약점: 설치 시간·위치를 지불하고 첫 충격 뒤 받침을 잃는다.
- 기본 대안: 기본 방패·회피로 대응하고 넓은 길로 우회한다.
- 신규 구현 요구: 충돌없는 단발받침 효과; 장치뒤 준비자세 조건; 설치중 피격취소.

검사 `BSV1_guard_forge_C1`, `BSV1_guard_forge_C2`, `BSV1_guard_forge_C3`, `BSV1_guard_forge_C4`, `BSV1_guard_forge_C5`의 상세 예상/금지 결과는 JSON에 있다. 첫 핵심 검사: 충돌 없는 받침 설치 → 그 뒤에서 준비 자세 후 정면 방어 충격 → 첫 충격 뒤 받침이 접히며 간격 확보 후보가 발동한다

## 공통 통과 조건과 열린 구현 판단

- 기본 이동·가드·회피·상호작용으로 탐험할 대체 경로를 남긴다. 수영·점프·속성 퍼즐을 새 필수 조건으로 만들지 않는다.
- 같은 원소라는 이유로 아무 변형을 붙이지 않는다. 장착 슬롯의 modifier는 실제 modifies 대상과 일치해야 한다.
- 단일 계열 핵심 특성과 조합 특성을 함께 쌓지 않는다. 스킬/장비 변경으로 쿨타임·소비 횟수·준비 토큰을 초기화하지 않는다.
- 회복·잔향·장치 파생 효과는 자기 자신이나 다른 특성을 재귀 발동하지 않는다. 솔로 회복에 부활·만피 보호 농사를 추가하지 않는다.
- 변형과 조합 특성이 같은 공격 형상을 바꾸는 경우(예: 결투가 끝선 멈춤 + 빈자리 찌르기)는 최종 우선순위 명세가 먼저 필요하다. 이 문서는 임의 순서를 확정하지 않는다.
- FHD·핀 본체64×96 방향을 유지한다. 신규 시전 포즈/장치/구역 VFX는 요구사항일 뿐 아직 제작되지 않았다. 저효과 설정에서도 적 예고와 아군 구역을 구분해야 한다.

## 정적 QA

신규 독립 도구 `tools/validate_build_scenarios.py`는 기존 `validate_progression_drafts.py`를 읽기 전용으로 호출한다. 기존 검증기를 수정하지 않았다. 게임 데이터·초안 파일을 덮어쓰지 않고 ID, 선행 순서, 계열 소유, 조합 자격 노드, 슬롯 종류/개수, 변형 대상, 고유 특성, 장비 태그, 몬스터·위치·재료 참조, 각 사례의 부정 조건과 근거 필드를 검사한다.

실행 결과: **12개 서로 다른 조합 빌드 / 8계열 / 60개 사례, PASS**. 신규 검증기 자체는 정상 입력 1개와 메모리 내 오염 입력 20개, 합계 **21/21 테스트 통과**. 누락 ID·부모 뒤 학습·3번째 슬롯/계열·패시브를 액티브로 장착·복수 변형·다른 대상 변형·미학습 스킬·부적합 장비·잘못된 특성·없는 장소/재료·승인되지 않은 런타임/예산 주장을 구분한다. 이 테스트 숫자는 전투 실행 테스트 숫자가 아니다.

```powershell
python tools/validate_build_scenarios.py
python -m unittest discover -s tools -p test_validate_build_scenarios.py -v
```

아직 검사하지 않은 것: 피해/회복 수치의 균형, 실제 SP 예산, 장비 애니메이션의 손·무기 일관성, 게임 입력 지연, 적 AI 반응, 공간/구역의 실제 크기, 세이브 이관. 이들은 구현 후 해당 시나리오의 evidence를 수집하여 판단해야 한다.
