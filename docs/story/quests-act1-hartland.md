# 1막 하트랜드 퀘스트 설계 — 《이슬란드 연대기》

> 작성: narrative-designer · 대상 구간: 1막 "출항" 중 하틀랜드/브릿지포트 구간(2막 월드맵 개방 이전, D-26)
> 근거: `docs/story/main-storyline.md` 2장(main_a1_s01~s08), `docs/story/characters.md` 3.1절(하틀랜드 NPC)·5.1절(일일 의뢰 문안)·6장(플레이버), `docs/story/foreshadowing.md`, `docs/brd/03-features/05-퀘스트-내러티브.md`(F5-1·F5-2·F5-3), `docs/specs/quest-data-schema.md`
> 데이터: `game/data/quests/act1_hartland.json` / 텍스트: `game/localization/quest_ko.csv`

## 0. 범위·원칙

- **메인 퀘스트 체인 7개**는 main-storyline.md의 s01~s06, s08 씬을 그대로 퀘스트화한다(1:1 대응, 새 사건을 만들지 않음). **s07(몽실이)**는 main-storyline.md 자신이 "톤 계약 서브퀘스트"로 명명했으므로 사이드 퀘스트로 분류한다.
- **사이드 퀘스트 5개** 중 3개(S2·S3·S4)는 `characters.md`가 이미 설계해 둔 로젤·핀토·머루 할머니의 **"지인(acq)" 단계 개방 장면**(`npc_heartland_rozel_acq_01` 등)을 실제 플레이 가능한 퀘스트로 구현한 것이다 — 새 대사를 짓지 않고 기존 key를 퀘스트 완료 트리거에 그대로 연결한다(F5-3 "선물 또는 관련 퀘스트 완료로 상승" 요건 충족).
- **대사 소유권 원칙**: main-storyline.md·characters.md가 이미 확정한 대사 key는 이 문서에서 **재인용만** 하고 `quest_ko.csv`에 다시 옮기지 않는다(중복 관리 방지). `quest_ko.csv`에는 이 문서가 새로 만드는 것 — 퀘스트 제목·수주 설명·목표 문구·퀘스트 전용 신규 대사(질문/납품 등 실무 대사) — 만 싣는다. 신규 퀘스트 전용 대사는 `quest_<퀘스트id>_line_<번호>` key를 쓴다(characters.md 1.1절의 npc_/main_ 체계와 충돌 방지).
- 모든 몬스터·아이템 id는 `game/data/monsters.json`·`items.json`이 아직 없어(이번 작업 시점) 전부 `_todo_ids`로 분리했다(3장 참고).

---

## 1. 메인 퀘스트 체인 (7개)

### MQ01 `quest_main_a1_01_arrival` — "안개 건너 뭍으로"
- **장소**: 브릿지포트 부두 | **의뢰자**: 테오(시스템 안내역) | **선행**: 없음
- **목표 단계**: ① talk `npc:teo` → ② interact `object:cargo_pile`("짐부터 챙기자")
- **보상**(`_balance_todo`): 골드 0 / 경험치 5
- **분기·실패**: 없음(전투 없는 순수 튜토리얼, 포기 불가)
- **완료 시**: `register_quest: quest_main_a1_02_firstlook`
- **핵심 대사**(key만, ko는 main-storyline.md 소유): `main_a1_s01_bridgeport_teo_01~03`
- **복선**: 없음
- **게임플레이 훅**: 탐험(이동/카메라/상호작용 튜토리얼)

### MQ02 `quest_main_a1_02_firstlook` — "초원의 첫인사"
- **장소**: 하틀랜드 진입로 → 민들레 마을 어귀 | **의뢰자**: 테오 | **선행**: MQ01 완료
- **목표 단계**: ① reach `location:heartland_dandelion_village` → ② talk `npc:meru`
- **보상**: 골드 0 / 경험치 5
- **분기·실패**: 없음
- **완료 시**: `register_quest: quest_main_a1_03_shadowfall`
- **핵심 대사**: `main_a1_s02_heartland_meru_01~03`
- **복선**: 없음
- **게임플레이 훅**: 탐험(마을 시설 위치 안내, 전투 없음)

### MQ03 `quest_main_a1_03_shadowfall` — "그림자가 내려앉다"
- **장소**: 민들레 마을 광장·외곽 | **의뢰자**: 시스템(습격 이벤트 자동 발동) | **선행**: MQ02 완료
- **목표 단계**: ① kill `monster:horn_rabbit` ×4 (안개에 물든 들짐승 무리 — 연출상 혼합 스폰이나 데이터는 대표 종 1개로 집계, 실제 혼합 구성은 레벨 디자인 소관)
- **보상**: 골드 10 / 경험치 15
- **분기·실패**: 없음(전투 튜토리얼, 패배 시 즉시 재시도)
- **완료 시**: `register_quest: quest_main_a1_04_theshard`
- **핵심 대사**: `main_a1_s03_heartland_rozel_01~03`
- **복선**: 없음(습격 몬스터 중 하나가 마을 아이의 옛 반려동물이었다는 설정은 S1에서 회수 — main-storyline.md 원문 그대로)
- **게임플레이 훅**: 전투(공격 3콤보·구르기·가드 순차 튜토리얼)

### MQ04 `quest_main_a1_04_theshard` — "파편이 답하다"
- **장소**: 민들레 마을 결계석 앞 | **의뢰자**: 없음(자동) | **선행**: MQ03 완료
- **목표 단계**: ① reach `location:heartland_ward_stone` → ② interact `object:ward_stone_dandelion`
- **보상**: 골드 0 / 경험치 5
- **분기·실패**: 없음
- **완료 시**: `register_quest: quest_main_a1_05_reclaim`
- **핵심 대사**: `main_a1_s04_heartland_teo_01~03`, `main_a1_s04_heartland_rozel_01~02`
- **복선**: **예(구조적)** — "성물지기" 개념 최초 언급(`foreshadowing.md` 표에는 별도 항목 없음, main-storyline.md 2장 s04 원문 표기를 그대로 계승. 문서 표기: `narrative:guardian_concept_intro`)
- **게임플레이 훅**: 없음(스킵 가능한 컷 연출)

### MQ05 `quest_main_a1_05_reclaim` — "마을을 되찾다"
- **장소**: 민들레 마을 전역 | **의뢰자**: 시스템 | **선행**: MQ04 완료
- **목표 단계**: ① kill `monster:horn_rabbit_big` ×1(정예, "덩치 뿔토끼"급) → ② reach `location:heartland_dandelion_village_square`
- **보상**: 골드 40 / 경험치 30 / 아이템 `wool_soft` ×2
- **분기·실패**: 없음(정예 패배 시 즉시 재도전, 골드 손실 없음 — D-23 원칙 준용)
- **완료 시**: `unlock_facility:smith`·`shop`·`inn`·`board`·`mailbox`, `save_checkpoint`, `register_quest: quest_main_a1_06_echocave`
- **핵심 대사**: `main_a1_s05_heartland_meru_01~02`
- **복선**: 없음
- **게임플레이 훅**: 전투(첫 정예 몬스터전) — 클리어 즉시 마을 시설 개방

### MQ06 `quest_main_a1_06_echocave` — "메아리 굴"
- **장소**: 하틀랜드 외곽 소형 동굴(별도 튜토리얼 던전) | **의뢰자**: 테오 | **선행**: MQ05 완료
- **목표 단계**: ① talk `npc:teo`(입구) → ② reach `location:heartland_echo_cave_entrance` → ③ interact `object:echo_cave_puzzle_01` → ④ collect `item:iron_ore` ×1(보물상자)
- **보상**: 골드 30 / 경험치 25 / 아이템 `iron_ore` ×1
- **분기·실패**: 없음
- **완료 시**: `grant_skill_point:1`, `register_quest: quest_main_a1_07_fiveroads`
- **핵심 대사**: `main_a1_s06_heartland_teo_01~03`
- **복선**: 없음
- **게임플레이 훅**: 탐험+파밍(스킬 슬롯·퀵슬롯 튜토리얼, 소형 퍼즐 1개, 보물상자 1개)

### MQ07 `quest_main_a1_07_fiveroads` — "다섯 개의 길"
- **장소**: 민들레 마을 결계석 앞(MQ04와 동일 장소) | **의뢰자**: 테오 | **선행**: MQ05 완료(D-92, MQ06과 병렬 가능)
- **목표 단계**: ① reach `location:heartland_ward_stone` → ② talk `npc:teo`
- **보상**: 골드 20 / 경험치 20 / 아이템 `horn_shard` ×1(목자들이 대대로 물려온 물건의 파편 — characters.md 6.2절 기존 플레이버 재사용)
- **분기·실패**: 없음(메인 퀘스트 포기 불가, F5-1)
- **완료 시**: `unlock_worldmap`, `register_main_act2_regions`(2막 5개 지방 퀘스트 동시 등록 — 실제 quest id는 2막 데이터 작성 시 확정, 이번 파일에서는 추상 이벤트 태그만 남김)
- **핵심 대사**: `main_a1_s08_heartland_teo_01~03`
- **복선**: 없음
- **게임플레이 훅**: 없음(월드맵 개방 연출과 동기화, 이후 오픈월드·파밍 루프 시작)

---

## 2. 사이드 퀘스트 (5개)

### S1 `quest_side_heartland_montsil` — "몽실이를 찾아서"
- **장소**: 마을 외곽 목초지 → 안전지대 경계 | **의뢰자**: 다미(1회성 기능 NPC) | **선행**: MQ06 완료(MQ07 이전 아무 때나, 강제 아님)
- **목표 단계**: ① talk `npc:dami` → ② reach `location:heartland_pasture_boundary` → ③ interact `object:montsil_rabbit`
- **분기**: interact 시점에 선택지 — `release`(놓아주기) / `capture_attempt`(붙잡기 시도, 저강도 미니게임 or 대치 후 퇴각). **결과 수렴**: 어느 쪽이든 몽실이는 결국 숲 너머로 사라진다 — 서사 연출만 다르고 보상·이후 진행은 동일(결정 필요 D-94 참고)
- **보상**: 골드 15 / 경험치 10 / 아이템 `stew_basic` ×1
- **실패 조건**: 없음(시간제한 없음)
- **완료 시**: 없음(다음 퀘스트에 영향 없음, 순수 정서 비트)
- **핵심 대사**: `main_a1_s07_heartland_dami_01~06`(main-storyline.md 소유, 재인용만)
- **복선**: **예(구조적)** — "안개에 물든 것들도 원래는 무해했다"는 공유 감정축의 최초 체험판(`narrative:mist_creatures_were_once_harmless`, F-06~F-10 패턴의 원형이나 `foreshadowing.md` 표에는 미등재 — main-storyline.md 원문 그대로 계승)
- **게임플레이 훅**: 비전투(추적·상호작용, 붙잡기 미니게임은 저강도)

### S2 `quest_side_heartland_festival_prep` — "목자 시험: 민들레제 리본"
- **장소**: 목초지 전역 | **의뢰자**: 로젤 | **선행**: MQ05 완료
- **목표 단계**: ① talk `npc:rozel`(민들레제 경기 준비 부탁) → ② kill `monster:horn_rabbit` ×3(가축을 겁먹게 하는 들짐승 정리) → ③ collect `item:ribbon_dandelion` ×5(경기용 리본 재료 채집)
- **보상**: 골드 35 / 경험치 20 / 아이템 `ribbon_charm` ×1(로젤이 직접 엮어준 서투른 리본 부적) / 호감도 로젤 acq 단계 개방
- **분기·실패**: 없음
- **완료 시**: `affinity_stage:rozel:acq`(characters.md 3.1절 "지인 — 목자 시험" 대사 재생 트리거)
- **핵심 대사**: 수주 `quest_side_heartland_festival_prep_line_01`(신규) / 완료 `npc_heartland_rozel_acq_01`(characters.md 소유, 재인용)
- **복선**: **F-06** — 완료 후 마을 잡담 로테이션에서 로젤의 예언 잡담(`npc_heartland_rozel_chat_03`, "새벽뿔피리가 다시 울리면 평화로워진댔어")이 노출 확률에 가중되도록 이벤트 노트만 남김(구현은 잡담 시스템 소관)
- **게임플레이 훅**: 전투+파밍(토벌 후 채집)

### S3 `quest_side_heartland_orefetch` — "핀토의 첫 담금질"
- **장소**: 대장간 뒤편 소형 광맥 굴 | **의뢰자**: 핀토 | **선행**: MQ05 완료
- **목표 단계**: ① talk `npc:pinto` → ② kill `monster:mushroom` ×3(굴 입구를 막은 버섯돌이 정리) → ③ collect `item:iron_ore` ×4
- **보상**: 골드 35 / 경험치 20 / 아이템 `iron_ore` ×2 / 호감도 핀토 acq 단계 개방
- **분기·실패**: 없음
- **완료 시**: `affinity_stage:pinto:acq`(characters.md 3.1절 "지인 — 첫 망치질" 대사 재생 트리거)
- **핵심 대사**: 수주 `quest_side_heartland_orefetch_line_01`(신규) / 완료 `npc_heartland_pinto_acq_01`(characters.md 소유, 재인용)
- **복선**: 없음("무른 쇠" 반전은 친구 단계 이후 콘텐츠, characters.md 소관)
- **게임플레이 훅**: 전투+파밍

### S4 `quest_side_heartland_herbrun` — "머루 할머니의 특별 손님"
- **장소**: 마을 근교 초지·숲 가장자리 | **의뢰자**: 머루 할머니 | **선행**: MQ05 완료
- **목표 단계**: ① talk `npc:meru` → ② collect `item:herb_common` ×4 → ③ collect `item:mushroom_cap` ×2
- **보상**: 골드 25 / 경험치 15 / 아이템 `stew_basic` ×1 / 호감도 머루 acq 단계 개방
- **분기·실패**: 없음
- **완료 시**: `affinity_stage:meru:acq`(characters.md 3.1절 "지인 — 여관집 셈법" 대사 재생 트리거)
- **핵심 대사**: 수주 `quest_side_heartland_herbrun_line_01`(신규) / 완료 `npc_heartland_meru_acq_01`(characters.md 소유, 재인용)
- **복선**: 없음(F-01은 단짝 단계 전용, 1막에서는 도달하지 않음)
- **게임플레이 훅**: 파밍(비전투 채집)

### S5 `quest_side_heartland_waypoint` — "저 언덕 너머"
- **장소**: 민들레 마을 인근 언덕 | **의뢰자**: 테오 | **선행**: MQ05 완료(D-92, MQ06과 병렬 가능)
- **목표 단계**: ① reach `location:heartland_hilltop_waypoint` → ② interact `object:waypoint_stone_01`
- **보상**: 골드 15 / 경험치 10
- **분기·실패**: 없음
- **완료 시**: `unlock_system:warp_waypoint`(비석 워프 시스템 안내, GDD 7.3)
- **핵심 대사**: `quest_side_heartland_waypoint_line_01~02`(신규 — 테오, "저기 보이는 비석 하나쯤은/ 미리 켜두자." / "돌아올 때 편해질 거야.")
- **복선**: 없음
- **게임플레이 훅**: 탐험(워프 비석 시스템 튜토리얼)

---

## 3. 게시판 일일 의뢰 템플릿 (3종, 하틀랜드)

`characters.md` 5.1절이 이미 확정한 문안·key를 그대로 데이터화한다(신규 대사 없음).

| 데이터 id | 유형 | 요청자 | 훅 | 몬스터/아이템 풀 | 수량 범위 |
|---|---|---|---|---|---|
| `quest_daily_heartland_01` | 토벌 | 로젤 | 전투 | `pool:heartland_field_low` | 3~5 |
| `quest_daily_heartland_02` | 납품 | 머루 할머니 | 파밍 | `pool:heartland_field_material_low` | 3~5 |
| `quest_daily_heartland_03` | 토벌 | 핀토 | 전투 | `pool:heartland_field_low` | 3~5 |

- 문안(`{몬스터}`/`{수량}` 바인딩)은 characters.md 5.1절 원문 그대로, `quest_ko.csv`에 동일 key로 옮긴다.
- 몬스터/아이템 풀 태그(`heartland_field_low`, `heartland_field_material_low`)는 실제 풀 구성(어떤 몬스터·아이템이 몇 %로 뽑히는지)이 아직 없다 — 결정 필요 D-97 참고. 잠정적으로 `horn_rabbit`·`mushroom`(몬스터), `herb_common`·`wool_soft`(아이템)를 초안 구성원으로 제안한다.
- 보상(`_balance_todo`): 토벌형 골드 15~25/경험치 10, 납품형 골드 10~20 + 재료 소량. 주간 7회 누적 보너스는 F5-2 규정대로 게임 시스템(game-designer) 소관.

---

## 4. `_todo_ids` 요약 (실존 확인 필요)

| 구분 | id | 비고 |
|---|---|---|
| 몬스터 | `horn_rabbit` | 뿔토끼, characters.md 6.3절 도감 예시 재사용 |
| 몬스터 | `mushroom` | 버섯돌이, characters.md 6.3절 도감 예시 재사용 |
| 몬스터 | `horn_rabbit_big` | 정예 "덩치 뿔토끼"(MQ05 전용, 신규) |
| 아이템 | `wool_soft` | 신규(양털류 소재) |
| 아이템 | `iron_ore` | 신규(저급 철광석) |
| 아이템 | `herb_common` | 신규(잡초 약초) |
| 아이템 | `mushroom_cap` | 신규(야생 버섯) |
| 아이템 | `ribbon_dandelion` | 신규(민들레제 리본 재료) |
| 아이템 | `stew_basic` | 신규(머루 할머니표 스튜) |
| 아이템 | `horn_shard` | characters.md 6.2절 기존 플레이버 재사용 |
| 아이템 | `ribbon_charm` | 신규(로젤이 엮어준 리본 부적) |

위 목록은 `game/data/quests/act1_hartland.json` 상단 `_todo_ids`와 동일하다. 장소/오브젝트 id(`heartland_ward_stone`, `montsil_rabbit` 등)는 몬스터/아이템 스키마 대상이 아니므로 별도 표로 JSON에 `_todo_ids.locations`/`.objects`로만 남겨 레벨 디자이너 확인을 요청한다.

> **M2-7 갱신(godot-engineer)**: 위 표의 몬스터·아이템 id는 전부 `monsters.json`/`items.json`에 실제 항목으로 채워 `_todo_ids.monsters`/`.items`에서 제거했다(`horn_rabbit_big`은 hp/atk만 1.5배, 나머지는 horn_rabbit과 동일 — D-95 반영). 장소/오브젝트만 `_todo_ids`에 남는다.

---

## 5. 결정 필요 (디렉터 기록용, D-92+ 기록)

| # | 쟁점 | 추천안 |
|---|---|---|
| D-92(안) | S5(워프 비석) 최초 활성화를 MQ06 이후로 배치했는데, 게시판(F5-2, MQ05에서 개방)보다 늦어 "왜 비석 활성화가 늦게 열리나" 어색할 수 있음 | S5 선행 조건을 MQ05 완료로 앞당기고 MQ06(던전)과 병렬 진행 허용 — 던전 구조상 워프 비석이 던전行 경로에 있다면 오히려 MQ06 내부에서 자동 활성화도 대안 |
| D-93(안) | 지역 사이드 퀘스트(S1~S5) 동시 보유 개수 제한 여부 — F5-2는 게시판 일일 의뢰(3개)만 규정, 지역 사이드 퀘스트는 규정 없음 | 제한 없음(모두 동시 수주·진행 가능)으로 확정 추천. 사이드 퀘스트 로그 UI 과밀 우려는 UI/UX 담당과 별도 확인 |
| D-94(안) | S1(몽실이) 분기(놓아주기/붙잡기 시도)의 결과·보상 차등 여부 | 완전 동일(서사 연출만 분기, 파워/보상 개입 금지) — "뭉클함"이 선택 자체보다 결말의 필연성에서 와야 하므로 |
| D-95(안) | MQ05 정예 몬스터(`horn_rabbit_big`) 첫 처치 확정 보상 여부 — F6-3 "정예 첫 클리어 희귀~영웅 확정" 규정은 2막부터로 보임(1막 정예는 스토리 전용 단일 개체) | 1막 정예는 F6-3 적용 예외로 명문화, 확정 지급 없이 스토리 보상(위 MQ05 보상)만 지급 |
| D-96(안) | 1막 메인/사이드 보상 골드·경험치 최종 수치 확정(현재 전부 `_balance_todo` 잠정치, 레벨 1~3 가정) | game-designer가 `items-and-drops`/경제 밸런스 스펙 확정 후 이 문서·JSON 일괄 갱신 |
| D-97(확정, M2-7) | 게시판 일일 의뢰 몬스터/아이템 풀 태그(`heartland_field_low` 등) 정식 스키마·구성원 확정 | `game/data/pools.json` 신설(godot-engineer, M2-7). `heartland_field_low`={horn_rabbit, mushroom}(균등 가중치), `heartland_field_material_low`={mushroom_cap, iron_ore, rabbit_horn}(균등 가중치) — 위 3장 초안 구성원과 다르게 herb_common/wool_soft 대신 기존 파밍 재료(mushroom_cap/iron_ore/rabbit_horn)를 채택했다(신규 퀘스트 전용 재료는 일일 의뢰 풀에서 제외). 가중치 수치 자체는 `_balance_todo`로 game-designer 확인 필요. |
