# 스토리 문서 패키지 병합·정합성 검수 리포트

- 검수 대상: `docs/story/world-bible.md`, `docs/story/main-storyline.md`, `docs/story/characters.md`, `docs/story/foreshadowing.md`(A+B 병합본, v1.1)
- 기준 문서: `docs/GDD-도트액션RPG-기획안.md`(v1.1.1), `docs/brd/04-decisions.md`(D-19·D-22·D-26·D-38~D-41), 리서치 01~03
- 작업일: 2026-09-08 · 작업자: QA(스토리 문서 병합·정합성)
- 브랜치: `stage/story-02-world-story` 워크트리에서 작업, 커밋은 release-manager 담당

## 0. 요약

| 심각도 | 건수 | 상태 |
|---|---|---|
| Blocker | 1 | 설계 판단 필요 (수정 안 함, 표로만 반영) |
| Major | 8 | 4건 수정, 4건 설계 판단 필요 |
| Minor | 5 | 3건 수정, 2건 설계 판단 필요 |

병합 후 복선 총 개수: **18개 (F-01~F-18, 불변)** — B 버전이 제안한 5개 슬롯(NPC 대사 기반)이 모두 기존 F-01/F-03/F-04/F-05에 1:1로 대응해, 신규 F-19+ 추가는 없었다.

---

## 1. Blocker

### B-1. '마녀의 기억' 안전장치가 실제로는 오델 호감도 게이팅에 걸려 있다 — D-19 진엔딩 접근성 파괴 위험

- **파일·위치**: `docs/story/world-bible.md` 4.3절 표 #5, 4.4절 "놓쳐도 회수 가능한 장치" / `docs/story/main-storyline.md` 1장 구조도·5.1절 / `docs/story/characters.md` 3.6절 오델 "단짝 — 성물지기의 축문"
- **내용**:
  - 세계관 바이블 4.3 표 #5: "3막 진입 조건 충족 시 **자동 대사**"
  - 세계관 바이블 4.4: "추가 안전장치로 브릿지포트의 왕실 사서 NPC가 **3막 진입 후 '구술로 대신 들려주는' 요약본**을 제공" — 조건은 오직 "3막 진입"
  - main-storyline.md 1장 구조도·5.1절: "3막: 재의 마녀 (고정 순서, **성물 5개 회수 시 개방**)" — 호감도 언급 없음
  - 그런데 실제 구현 스펙인 characters.md 3.6절은 이 정확히 같은 서사 비트(축문 유래 공개 + 놓친 마녀의 기억 구술 요약)를 **"오델 호감도 3단계(단짝) + 3막 진입 조건"**으로 게이팅한다.
- **왜 문제인가**: 오델과 친분(잡담 풀 소진 또는 선물)을 쌓지 않고 3막에 진입한 플레이어는 축문의 유래도, 놓친 마녀의 기억 구술 요약본도 받지 못한다. D-19의 엔딩 분기(마녀의 기억 5/5 = 진엔딩)를 위해 바이블이 명시적으로 설계한 "영구 소실 방지 안전장치"(4.4절 금지 사항: "진엔딩 수집물을 놓치면 영구 회수 불가능하게 만드는 설계" 금지)가 이 게이팅 때문에 사실상 무력화될 수 있다.
- **재현 절차**: (문서상 시뮬레이션) ① 4개 지방에서 마녀의 기억을 모두 놓치고 진행(가능 — 4.4절 "놓쳐도 회수 가능") → ② 오델과 대화를 최소한만 하고(지인 단계 유지) 성물 5개를 회수 → ③ 3막 진입 → characters.md 스펙대로면 오델의 단짝 미니 스토리가 열리지 않으므로 구술 요약본을 받을 방법이 없다 → 마녀의 기억 4/5 이하로 엔딩 분기, 그러나 플레이어 입장에선 "분명 안전장치가 있다고 들었는데 왜 안 열리지"라는 이해 불가 상태.
- **조치**: 수정하지 않음(설계 판단 필요). `docs/story/foreshadowing.md` F-05 행과 "놓쳤을 때의 안전장치 요약"에 명시적으로 플래그를 남겨두었다.
- **권장 방향(참고용, 확정 아님)**: (a) characters.md의 오델 단짝 조건에서 "3막 진입" 단독으로도 발동하는 별도 트리거를 추가하거나, (b) 세계관 바이블 쪽 문구를 "오델과 친분이 있어야 한다"로 낮추고 호감도를 올릴 다른 강제 동선(예: 2막 중반 폭로 이벤트에서 자동으로 지인→친구 단계까지는 강제 상승)을 만드는 방법이 있다. 담당: narrative-designer + game-designer(퀘스트 트리거 설계).

---

## 2. Major

### M-1. GDD 2.1이 "재의 마녀가 성물을 흩뜨렸다"는, 나중에 뒤집히는 공식 서사를 사실인 것처럼 서술

- **파일·위치**: `docs/GDD-도트액션RPG-기획안.md` 2.1절 "300년 전, 왕국을 지키던 다섯 개의 수호 성물이 '재의 마녀'에 의해 흩어지며..." vs `docs/story/world-bible.md` 1.2절 연표·4.1절("재난→지목→추방의 5단계")
- **내용**: 바이블은 성물이 "셀라의 처형 충격으로 스스로 부서져 흩어진 것"이며, 마녀(셀라)는 가해자가 아니라 희생양이라는 것이 이 게임의 핵심 반전이라고 명확히 설계했다(4.1·4.2절). 그런데 GDD 2.1은 "성물이 재의 마녀에 **의해** 흩어지며"라고 써서, 마녀를 성물 파괴의 행위 주체로 단정한다. GDD 2.2절 3막 요약은 반대로 "마녀는 과거 왕국의 희생양이었다"고 정확히 쓰고 있어 GDD 문서 **내부에서도 2.1과 2.2가 서로 다른 인과관계**를 말한다.
- **재현 절차**: `docs/GDD-도트액션RPG-기획안.md` 49행과 58행을 나란히 읽으면 확인된다.
- **조치**: 수정 안 함(GDD는 이 작업 범위 밖 파일이며, 문구 변경은 GDD 소유자의 판단 필요). world-bible/main-storyline/characters.md에는 이 오류가 전파되지 않았음을 확인했다.
- **권장**: GDD 2.1을 "성물이 재의 날 사건으로 부서져 흩어지며"처럼 인과관계를 중립화하거나, "(이후 3막에서 뒤집히는 공식 서사)"라는 각주를 붙이는 것을 권장.

### M-2. GDD 7.1 ASCII 지도와 세계관 바이블 1.1절의 지방 간 방위 서술이 어긋난다

- **파일·위치**: `docs/GDD-도트액션RPG-기획안.md` 7.1절 ASCII 다이어그램 vs `docs/story/world-bible.md` 1.1절 표
- **내용**: GDD 다이어그램은 세로선(│) 연결로 **이그니스가 사마르 아래(사마르의 남쪽)**, **브릿지포트가 하틀랜드 바로 아래(하틀랜드의 남쪽)**에 위치하는 것으로 그려져 있다. 반면 바이블 1.1절 표는 "이그니스 = 하틀랜드 남쪽 약 10분", "브릿지포트 = 하틀랜드 남서쪽 약 6분"이라고 명시한다. 즉 이그니스의 기준점이 다르고(사마르 vs 하틀랜드), 브릿지포트의 방위도 다르다(정남 vs 남서).
- **재현 절차**: GDD 189~198행 ASCII 다이어그램과 world-bible.md 26~35행 표를 나란히 비교.
- **조치**: 수정 안 함(레벨 디자인 실제 좌표가 아직 확정되지 않은 상태에서 임의로 한쪽에 맞추면 진짜 설계 의도를 왜곡할 위험). level-designer가 실제 맵 좌표를 정할 때 이 두 문서 중 무엇을 기준으로 할지 확정 필요.

### M-3. 대사 로컬라이징 key의 지방 코드 컨벤션이 문서마다 다르다 (`heartland` vs `htl`)

- **파일·위치**: `docs/story/characters.md` 1.1절(전체 표기: heartland·eldwood·frostheim·samar·ignis·bridgeport) vs `docs/story/main-storyline.md` 0장(약어: htl·eld·frs·smr·ign·brp, `main_a{막}_{지방코드}_s{씬번호}_...` 전체 키에 사용)
- **내용**: 두 문서가 각자 "이 문서의 로컬라이징 key 규칙"이라는 절을 갖고 있는데, 서로 다른 지방 코드 팔레트를 선언했다. characters.md의 규칙은 이번 작업에서 실제로 `foreshadowing.md`에도 흡수시켰지만(v1.1), main-storyline.md 자체의 `main_a2_htl_letter_teo_first_01` 같은 기존 키 40여 개는 여전히 약어 컨벤션을 쓴다. 실제 `game/data/dialogue/ko.json` 하나로 합쳐질 때 지방 코드 vocabulary가 두 개 존재하는 셈이라, 자동화 스크립트(정합성 검사 등)를 짤 때 지방 코드로 필터링/집계가 어긋날 수 있다.
- **재현 절차**: `grep -oP '\`main_a[0-9][a-z_0-9]+\`' docs/story/main-storyline.md`로 뽑은 키와 `grep -oP '\`npc_[a-z]+_' docs/story/characters.md`로 뽑은 지방 슬러그를 비교하면 htl/eld/frs/smr/ign/brp ↔ heartland/eldwood/frostheim/samar/ignis/bridgeport로 전혀 겹치지 않음이 보인다.
- **조치**: 수정 안 함. main-storyline.md의 기존 사용 키 40여 개(순서 분기·보스 처치 대사 등)를 일괄 개명하는 것은 이 문서의 소유 작가(narrative-designer, main-storyline 담당) 판단이 필요한 대규모 변경이라 QA가 임의로 손대지 않았다. `foreshadowing.md`에서 새로 만든/정정한 key들은 모두 characters.md 컨벤션(전체 표기)으로 통일해 최소한 새 항목에서는 혼선이 없게 했다.
- **권장**: 다음 중 하나를 팀이 확정: (a) main-storyline.md의 `main_a*` 키를 전체 표기로 통일, (b) 두 컨벤션이 각자 다른 네임스페이스(main_* vs npc_*/quest_*/item_*)라는 점을 두 문서 모두의 0장/1.1절에 명시적으로 교차 표기.

### M-4. main-storyline.md 1막(section 2) 전체 대사에 로컬라이징 key가 없다

- **파일·위치**: `docs/story/main-storyline.md` 2장(1막: 출항), `main_a1_s01`~`main_a1_s08` 8개 씬
- **내용**: 문서 0장은 씬별 개별 대사 key 규칙과 예시(`main_a1_s03_npc_alarm_01`)까지 제시하지만, 정작 본문 2장의 "핵심 대사" 목록(테오·머루 할머니·로젤·다미 등, 8개 씬에 걸쳐 30줄 이상)에는 단 하나의 key도 붙어 있지 않다. 4장(2막 중반 폭로) 오델의 대사 3줄도 마찬가지로 key가 없다(씬 트리거 key `main_a2_mid_reveal`만 있음).
- **재현 절차**: `grep -c '\`main_a1_s' docs/story/main-storyline.md` = 0 (본문에서 실제 사용된 적 없음, 0장 예시 문구에만 등장). 2장 전체(75~180행)를 훑으면 "핵심 대사" 불릿에 key 컬럼이 아예 없는 것이 확인된다.
- **조치**: 수정 안 함(대사마다 key를 새로 발번하는 것은 원 저자가 직접 할 몫 — QA가 임의 채번하면 이후 실제 구현 키와 어긋날 위험). `game/data/dialogue/` JSON화 작업 전에 반드시 채워야 할 구멍으로 플래그.

### M-5. 기능 NPC 대사·NG+ 추가 대사가 "14자×3줄" 텍스트 규칙을 다수 위반 (수치는 §3 참고)

- **파일·위치**: `docs/story/characters.md` 4.1절(기능 NPC 대사 42개 중 13개), `docs/story/main-storyline.md` 6장(회차 요소, 3개 항목)
- **내용**: 세계관 바이블 7.2절 규칙("한 줄 14자 내외 × 최대 3줄", 넘으면 표 안에서 `/`로 줄바꿈 표시)을 캐릭터·NPC 호감도 대사는 잘 지켰지만(§3 샘플링 참고), 기능 NPC 대사 42개 중 13개(31%)가 `/` 줄바꿈 없이 15~21자 한 줄로 작성됐다. main-storyline.md의 NG+ 추가 대사 3개는 22~24자로 상한의 거의 2배이며 역시 줄바꿈이 없다.
- **재현 절차**: `docs/story/characters.md` 415·429·430·433·435·441·447행(예: `npc_func_shop_greet_01` "어서 오세요, 오늘도 좋은 물건 있어요" 21자) / `docs/story/main-storyline.md` 357~359행(예: `main_ng_heartland_meru_extra_01` "...설마 그게, 그 축문이었을 줄이야." 22자).
- **조치**: 수정 안 함(문장을 줄이거나 자연스럽게 줄바꿈하는 것은 톤·리듬을 아는 작가의 손이 필요 — 기계적으로 `/`만 끼워 넣으면 오히려 어색한 위치에서 끊길 위험). 목록은 §3에 전량 정리.

### M-6. 호감도 비종속 NPC "잡담" 대사에 대한 key 슬롯이 정의되어 있지 않다

- **파일·위치**: `docs/story/characters.md` 1.1절 key 네이밍 표 vs `docs/story/foreshadowing.md` F-09(다라)·F-10(오르카)
- **내용**: characters.md 1.1절은 거점 NPC 대사 key를 `npc_<지방>_<이름>_<단계>_<번호>`로만 정의하며, `<단계>`는 `acq`(지인)·`fri`(친구)·`bff`(단짝) 셋뿐이다. 그런데 바이블 5장 전승·foreshadowing.md F-09/F-10처럼 호감도 단계와 무관하게 항상 나오는 "잡담"성 전승 대사(예: 다라가 늘 하는 오아시스 거인 전설, F-09)는 이 세 단계 중 어디에도 속하지 않는다. 실제로 F-10(오르카의 "매일 같은 시각" 소문)은 우연히 오르카의 **친구** 단계 미니 스토리와 내용이 겹쳐 그 key로 대체할 수 있었지만, F-09(다라의 오아시스 전설)는 다라의 기존 지인/친구/단짝 세 스토리 어디와도 겹치지 않아 대체할 key가 없다.
- **재현 절차**: `docs/story/characters.md` 3.4절 다라 항목(지인 "물값 흥정"/친구 "잃은 낙타"/단짝 "그래도 오는 길")과 `docs/story/foreshadowing.md` F-09(오아시스 거인 전설)의 내용을 비교하면 겹치는 부분이 없음이 확인된다.
- **조치**: `docs/story/foreshadowing.md` F-09 행에 이 gap을 각주로 남기고, 임시로 `npc_samar_dara_legend_01`(지방명은 characters.md 컨벤션으로 정정)을 유지했다. 신규 단계 슬러그(예: `lore`) 신설 여부는 characters.md 소유 작가의 판단 필요.

### M-7. 아이템 설명 key 컨벤션이 두 갈래였다 (`item_flavor_<슬러그>` vs `item_<지방>_..._desc_01`)

- **파일·위치**: `docs/story/characters.md` 1.1절(`item_flavor_<슬러그>`) vs `docs/story/foreshadowing.md`(구 버전) F-04·F-18의 `item_relic_core_smr_desc_01`, `item_smr_old_ward_order_desc_01`
- **내용**: 두 개의 서로 다른 아이템 설명 key 패턴이 각 문서에 따로 존재했다. 이번 병합에서 foreshadowing.md의 두 항목을 characters.md 컨벤션(`item_flavor_relic_core_samar_01`, `item_flavor_relic_core_ignis_01`, `item_flavor_old_ward_order_01`)으로 통일해 **수정 완료**. 다른 문서(main-storyline.md, characters.md 본문)에는 구 패턴이 쓰인 곳이 없어 부작용 없음을 확인했다.
- **조치**: 수정함.

### M-8. F-01·F-03·F-04·F-05가 존재하지 않는 NPC/이름을 가리키는 자리 표시(placeholder) key였다

- **파일·위치**: `docs/story/foreshadowing.md`(v1.0, A 버전) — 이번에 병합·수정
- **내용**: A 버전(v1.0)은 characters.md가 작성되기 전에 만들어져, 머루 할머니를 `landlady`, 게른 원로를 `elder`라는 가상의 배역명으로, 지방은 약어(htl/frs/smr/ign)로 지칭했다(`npc_htl_landlady_affection3_01` 등). characters.md가 나중에 확정한 실제 key(`npc_heartland_meru_bff_01` 등)와 전혀 매칭되지 않아, 이대로 두면 개발팀이 둘 중 어느 것을 실제로 만들지 헷갈리거나 중복 구현할 위험이 있었다. F-05는 아예 main-storyline.md에 구현된 적 없는 key(`main_a3_intro_odel_axiom_01`)를 가리키고 있었다(복선 ID 참조 깨짐).
- **조치**: 수정함. §1(B-1)에서 다룬 새 충돌(호감도 게이팅)을 제외하고, 나머지는 모두 characters.md의 실제 key로 교체했다.

---

## 3. Minor

### N-1. 대사 14자×3줄 규칙 위반 상세 — 샘플링 결과

`docs/story/characters.md`·`docs/story/main-storyline.md`에서 백틱(`` ` ``) key가 붙은 대사 행을 전수 추출해 실측했다(추출 스크립트는 아래 참고, 재사용 가능).

| 항목 | 값 |
|---|---|
| 샘플링한 고유 대사 key 수 | **102개** (요구 30개 이상 충족) |
| 검사한 줄(줄바꿈 `/` 기준 분리) 수 | 155줄 |
| 14자 초과 줄 수 | 17줄 (11%) |
| 16자 초과 줄 수 | 10줄 |
| 3줄 초과(최대 3줄 규칙 위반) 항목 | 0건 (전량 준수) |

**초과 항목 분포**:

| 출처 | 초과 줄 수 | 비고 |
|---|---|---|
| `npc_func_*`(기능 NPC 대사, characters.md 4.1절) | 13 / 42줄 | M-5 참고, 전량 줄바꿈(`/`) 없이 단문으로 작성됨 |
| `main_ng_*`(회차 요소, main-storyline.md 6장) | 3 / 3줄(해당 항목 전량) | 22~24자, M-5 참고 |
| `chr_bram_end_true_01` | 1 / 2줄 | "손 내밀 줄 아는 불이었네요."(16자) — 14자 규칙 기준 경미한 초과, 그 외 브람 대사는 전량 준수 |

가장 심한 사례 5건 (글자 수 내림차순):

| key | 자수 | 원문 |
|---|---|---|
| `main_ng_a1_s04_teo_extra_01` | 24 | "그러고 보니 이름이 있었다지, 예전 그분도." |
| `main_ng_frostheim_gern_extra_01` | 23 | "이번엔 알아보겠지, 그때 그 사람이란 걸." |
| `main_ng_heartland_meru_extra_01` | 22 | "...설마 그게, 그 축문이었을 줄이야." |
| `npc_func_shop_greet_01` | 21 | "어서 오세요, 오늘도 좋은 물건 있어요" |
| `npc_func_mailbox_trade_01` | 21 | "선물이면 하루 한 번만 받을 수 있어요" |

플레이어블 4인(`chr_*`, 60개 대사)과 거점 NPC 호감도 대사(`npc_*_acq/fri/bff`, 대부분 서술문에 인용된 형태라 표 파싱상 제외됐지만 육안 확인 결과)는 규칙을 충실히 지켜 `/` 줄바꿈으로 14자 내외를 유지하고 있었다 — 위반은 "짧으니 괜찮겠지"로 여겨진 기능 대사·후반 추가분에 집중됐다.

- **조치**: 수정 안 함(M-5와 동일 사유 — 문구 재작성은 작가 판단 필요). 리스트만 정리해 전달.
- **참고 스크립트**: 아래 §5에 재실행 가능한 형태로 첨부(리포지토리에는 커밋하지 않음, 필요 시 `tools/qa/`로 옮겨 재사용 가능).

### N-2. 폐허 성소의 명칭이 문서마다 살짝 다르다

- **파일·위치**: `docs/story/world-bible.md` 5.5절("폐허가 된 대장간 성소" / "폐허 성소(옛 대장간 신전)"), `docs/story/main-storyline.md` 3.5절(지역 던전 이름 '폐허 성소'), `docs/story/foreshadowing.md` F-10("폐허 대장간 성소")
- **내용**: 세 가지 표기("폐허 성소", "폐허가 된 대장간 성소", "폐허 대장간 성소")가 혼용된다. 던전 정식 명칭은 main-storyline.md가 확정한 **'폐허 성소'**로 보인다.
- **조치**: `docs/story/foreshadowing.md` F-10의 "폐허 대장간 성소"는 서술문 중 일부라 그대로 두었다(형식적 명칭 필드가 아님). 확정 명칭 통일이 필요하면 main-storyline.md 소유 작가가 판단.

### N-3. `npc_ign_orka_rumor_01`의 로마자 표기 오기 (orka → orca)

- **파일·위치**: `docs/story/foreshadowing.md`(v1.0, A 버전) F-10
- **내용**: 이그니스의 오르카(학자 NPC)를 characters.md는 `orca`로 로마자 표기하는데, A 버전 foreshadowing.md는 `orka`로 다르게 표기했다.
- **조치**: 수정함(F-10을 `npc_ignis_orca_fri_01`로 교체하며 자동 해결).

### N-4. characters.md 8장 "바이블 추가 제안"이 이미 채택된 안(D-53~55)을 미채택 상태로 남겨둠

- **파일·위치**: `docs/story/characters.md` 8장
- **내용**: 이번 세션에서 메인 세션이 D-53~D-55로 채택하고 바이블에 반영을 요청한 3건이, characters.md 자체에는 "제안" 상태 그대로 남아 있어 향후 이 문서만 보는 사람이 "아직 반영 안 됐나?"로 오인할 수 있었다.
- **조치**: 수정함 — 8장에 "(채택 완료)" 표기와 각 행에 D-53/54/55, 반영 위치(바이블 1.6절·5.5절)를 추가.

### N-5. F-06(하틀랜드 예언)·F-06 담당 NPC 미배정

- **파일·위치**: `docs/story/foreshadowing.md` F-06
- **내용**: "새벽뿔피리가 다시 울리는 날..." 예언이 characters.md의 3인(머루 할머니·로젤·핀토) 중 누구의 대사인지, 혹은 별도 무명 원로 NPC인지 정해지지 않았다(바이블 5.1절도 "목자들의 오래된 예언"이라고만 함).
- **조치**: 수정 안 함(신규 NPC를 만들지 않는다는 characters.md 원칙과, 기존 3인 중 누구에게 배정할지는 작가 판단 필요). 지방 코드만 `heartland`로 정정.

---

## 4. 통과 확인 (문제 없음, 참고용)

교차 검증했으나 불일치가 없었던 항목들 — 향후 재검수 시 다시 볼 필요는 낮음.

- 지방 거점 마을 정식 명칭(D-38): 민들레/반딧불/모락/샘터/잉걸 — GDD·바이블·main-storyline 전부 일치.
- 언다인 호수(D-39), 브릿지포트 중립 회합지(D-40), 종족 3종(D-41) — GDD·바이블 일치.
- 성물 5종의 형태·상징·수호자(주권/지혜/수호/풍요/생명) — 바이블 2장 표, main-storyline 5.2절 나선 계단 구간 구성, characters.md 성물 회수 리액션이 모두 정확히 일치.
- '마녀의 기억' 5개의 내용·위치·트리거 조건 — 바이블 4.4절, main-storyline 3.1~3.5절, foreshadowing F-11~15가 완전히 일치(이그니스 것만 "잿빛 첨탑 진입 직전 지역"이라는 예외 트리거까지 세 문서 동일하게 기술).
- 셀라의 정체·동기·5단계 재난 서사, 안개의 정체(슬픔+혼돈) — 바이블 4장과 main-storyline 4~5장이 완전히 일치.
- 3페이즈 보스 HP 구간(100~66/66~33/33~0%) — GDD 8.2, main-storyline 5.3절 일치.
- 고유명사(성물·보스·마을·NPC 이름) 표기 — "셀라"·"재의 마녀"·성물 5종·보스 5종·거점마을 5종 전수 grep 결과 이형 표기 없음(F-10 orka 오기 제외, N-3에서 처리).
- 연애 요소 금지(F5-3) — characters.md 8행·352행에서 명시적으로 재확인, 4인 캐릭터·18 NPC 서사 전체에 로맨스 함의 문구 없음을 확인.
- 경험치·강화 등 게임 시스템 수치는 이 문서 세트(스토리)의 범위 밖(별도 game-designer 소관 데이터 파일)이라 이번 검수 대상에서 제외.

---

## 5. 재사용 가능한 검사 스크립트 (참고)

대사 길이 샘플링에 사용한 스크립트. `tools/qa/` 커밋용 정식 스크립트는 아니며(이 세션은 스토리 문서 QA로 범위가 한정됨), 다음 회차 검수 시 참고할 수 있도록 로직만 남긴다.

```python
import re

files = [
    "docs/story/characters.md",
    "docs/story/main-storyline.md",
]

rows = []
for fp in files:
    with open(fp, encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            if not line.strip().startswith("|"):
                continue
            keym = re.search(r'`((?:chr|npc|main|item|codex|quest|event|env|memory)_[a-z0-9_]+)`', line)
            if not keym:
                continue
            key = keym.group(1)
            qs = re.findall(r'"([^"]+)"', line)
            for q in qs:
                parts = [p.strip() for p in q.split("/")]
                lens = [len(p) for p in parts]
                rows.append((fp, i, key, lens, q))

for fp, i, key, lens, q in rows:
    if any(L > 14 for L in lens) or len(lens) > 3:
        print(f"{fp}:{i}\t{key}\tlens={lens}\ttext={q}")
```

---

## 6. 병합·수정한 파일 목록

- `docs/story/world-bible.md` — 1.6절 신규(유물 조사단·브람 출신·4인 대륙 출신, D-53/54/55), 5.5절에 브람 관련 한 줄 추가(D-54)
- `docs/story/main-storyline.md` — 6장 NG+ 대사 key 2건 정정(`main_ng_htl_landlady_extra_01`→`main_ng_heartland_meru_extra_01`, `main_ng_frs_elder_extra_01`→`main_ng_frostheim_gern_extra_01`)
- `docs/story/characters.md` — 8장 "바이블 추가 제안"에 채택 완료 표기(D-53/54/55)
- `docs/story/foreshadowing.md` — A(v1.0, 18항목)+B(NPC 대사 key 5슬롯) 병합, v1.1로 갱신. 헤더에 B의 "서로의 섹션을 덮어쓰지 말 것" 규칙 흡수. F-01·F-03·F-04·F-05·F-07·F-10의 담당 산출물을 실제 characters.md key로 정정, F-05 깨진 참조 수정, 지방 약어→전체 표기 통일, item_flavor_ 컨벤션 통일, 오탈자(orka→orca) 수정. 항목 수 18개 불변.
