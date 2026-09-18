# 야간 개발 인계 — 2026-09-13

> 이후 상태: 02:48경 사용량 제한으로 중단됐고, 사용자 요청으로 21:11 KST경 재개했다. 현재 상태는 [저녁 재개 기록](resume-20260913.md)을 우선한다. 아래 “진행” 문단은 당시 인계이며 07:00까지 실제 작업이 지속됐다는 뜻이 아니다.

현재 소유와 완료 상태는 아래 ‘최신 실행 스냅샷’을 우선한다. MQ UI저장22검사와 빌드 보루궁수C1 수정은 독립 검수를 마쳤다. 다른 heartbeat 담당은 진행 파일을 중복 수정하지 않는다.

사용자 승인 범위: 오전 07:00 KST까지 게임 개발·콘텐츠 확장을 최대한 진행한다. 00:55경 시작한 작업의 인계 문서이며 자동 재개 heartbeat ID 7(15분, 07:00 종료)은 오케스트레이터의 생성 확인 보고에 근거한다. 자동 재개 등록은 모든 시간 동안 실제 작업 중이거나 결과가 보장됨을 뜻하지 않는다.

## 역할과 우선순위

### 최신 실행 스냅샷 — 02:44경, 아래 과거 인계보다 우선

**02:46 후속 우선:** 사망검사는 첫 create10PASS/native0·새processverify6PASS1FAIL/native1을 보존했고 인벤토리 전체Dictionary 숫자타입 비교 오탐가능성을 조사 중이다. 아직아이템유실/합격단정금지. root는 **create재실행 없이 read-only verify v2만** 새외부하네스·manifest·고유probe/native로그로 실행승인했다. 수량1.5를int1로통과시키지않도록정수동등성/모든슬롯필드·JSON의미비교, saveSHA불변필수. 원QA `death-save-boundary-ae1c07a77c30456081427119383e31ee`, 수동저장SHA `3C49EDBB0503198DAA95C6EC479E037E0F6128189CBB2915035AE90EFF3E670D`, 첫probe파일두번째로덮인한계명시.

NPC12줄은 source hud.gd/ui_ko.csv에 연결됐으나 현재 helper추출QA295PASS(CSV236행포함)/native0까지만. 실제새12문장직접11/15폭최대112/152px. root는 **story 새 fullgame QA copy1개**로 실제HUD·Events검사를 추가승인했다(기존14779/14781불변). 새CSV의 import번역이실제로갱신됐는지 vs임시Translation주입인지명확히구분, 원본editorimport금지/오류무시ready금지. 작은noautoload CSV import단면대안은출처·해시기록필수. 현재생산HUD해시는E28시점과달라졌으므로66검사를새12대사검증으로재사용하지 않는다.

- **E28 완료·독립검수:** [동일copy 렌더4단면](../qa/integrated-render-20260913.md),66PASS/native4×0/FHD실제PNG4장. root코드/4이미지 직접확인, story3문구보완후필수0(MQ02표시, late/fhd저장구독해제·FHD몹제거, probe/run비동결 명시). game14781+engine3 전후hash 동일이며 이후 새NPC production패스 이전소스다. rootFHD아이콘화면 공유완료, 기존14779/14781 모두보존. 정식ready0/핀모션미완료.
- **monsters 진행 / 새 승인:** 실제 Hitbox치명상→Dead→정상타이머부활→전투잠금 실제대기→저장→별도프로세스load 경계1개. 고정copy는수정하지 않고 새GUID QA에 외부 SceneTree스크립트/로그/새APPDATA만 사용, 외부입력도 별도SHA/전후기록. 기존캐시parse실패면패치/추가copy없이중단보고. noautoloadprobe·60초상한·FAILnonzero·timeout로그보존, 기존아이템/죽는중저장거부/기준저장SHA/부활HP·stamina·위치 검사. 몹제거와fixture주입이며실전AI완주아님, 새부활자동저장기능추가금지.
- **story 진행 / 실제 콘텐츠 소유:** production `hud.gd`, `ui_ko.csv`,NPC unit/검증기록에 핀토3·로젤3·다미전3/완료후3=12인사추가. 기존3NPC 모두 QuestNpc→npc_talked 경로확인, 새상점hook없음. 몽실은양분기숲으로사라지므로행복한재회로정본왜곡금지, 조용한감사·쉼으로구성. 기존테오/머루12·QuestUI·보상·세이브·큰글씨코드불변. 현재helper추출/noautoload작은QA와실제CSV·직접11/15폰트폭부터 검사; 기존14779/14781변경금지. 완료후monsters독립DA.
- **E20 후속 작성자완료 / story 후속DA:** 읽기전용도감12빌드예시·60검사명세 연결,19tests/JSsyntax/작성자실브라우저 통과. root server/app전체읽기 및보루궁수5명세→고요한시위링크/궁술선택 확인, 새화면도구출력 공유. 원본3JSON/본게임불변,60전투실행아님. 서버8767 **새session52288**, 기존82294정상종료. rootCua reset후browser1/tab1 `masteryLive`, URL `#node/v3_bow_still_string`, handoff유지.
- **classes 새 아트:** `grass-ground-tile-v1` 잔디바닥후보 builtin1회+원본보존·4×3 Godot반복배치 미리보기. 시험64px타일은생산타일규격변경아님. noautoload/probe/Dummy/minimized, 경로·꽃·수집물·새지역없음, 실제seam/시점검수전맵교체금지. 사용자생성예고/imagegen스킬사용알림완료.
- **E27 후속15 DA 완료:** classes필수0, memory10의중간순서전체assert는없고순차append코드확인; 새행은기존timer종료후추가이므로진행중경합전체성공으로과장않음. 스크롤/가시행정책은미채택, 본게임큰글씨미수정.
- **관리 검수:** E26/E27/02:36/물약LICENSES 문단 story필수0. 이번 E20/E27/E28/C03 및02:44 상태는후속DA대상.

### 최신 실행 스냅샷 — 02:36경, 아래 과거 인계보다 우선

- **완료·독립검수 / E26:** 소형 체력 물약 builtin1회 후보와20/24/32px UI비교,10PASS/native0. source1254² RGB SHA `F10EF7D73E47EF312DACEB31CFAD3D129AF880343B4AD62154EE9999AE20D645`, root/story 원본 또는표시샘플 직접view/필수0. 새시안 공유완료, 기존potion_hp_small 매핑·효과·가격·드롭은 불변. root 중앙LICENSES에 출처링크추가(관리문단DA후속).
- **완료·독립검수 / E27:** 큰글씨별도UI28PASS/native0/640×360. 기존11px169×67, 직접15px229×84, wrap+오래된행제거대안154×64 최신3메시지. QA아이콘 IGNORE_SIZE와생산차이 문서보완하여 classes 재DA필수0. root직접뷰. **story 진행:** 단일긴문장/연속입력/타이머경합 별도시험과 대안, 아직 본게임HUD·글자/가시행정책 변경없음. 스크롤 대안도 미채택.
- **classes 새 소유:** 기존 읽기전용 성장도감에 기존 `build-scenarios-v1.json`의12빌드예시 열람을 추가한다. 기존 `/api/catalog` 허용범위 유지/원본3JSON 읽기·검증·해시, 노드상세교차링크·미정SP/장비/약점/5검사명세 등을표시. 전투·학습·SP·전직·저장/본게임0. 서버8767 기존본인세션82294 필요시정상재시작, 독립DA와root실브라우저검수는완료후배정.
- **monsters 진행:** 승인된 새통합QA copy1개 생성, 원본assert 유지/testguard·출력환경매개화/3아이콘하네스배치, 해시검사 중. 이후D28/MQlate/3icons/FHD4모드 각새userdata/probe/native종료/실렌더 검사. 아직4모드완료 아님, 기존14779baseline·fixture·production보존. 자세한승인조건 아래02:29 유지.
- **관리 DA:** E21/E23/E25/B03 및02:27/02:29 인계 story 필수0 완료. 새 E26/E27/02:36 및LICENSES물약문단은 후속독립DA 대상. 정식ready0·핀 실제모션 미완료 유지.

### 최신 실행 스냅샷 — 02:27경, 아래 과거 인계보다 우선

**02:27 후속(아래 02:17 진행 문장보다 최신):** 진단런처·초상화 크기 비교·반응문 실제폰트 검사가 완료되고 각각 독립 DA를 거쳤다. root도 코드·보고서·초상화640×360 PNG를 직접 확인했다. 정식ready는 여전히0이며 GUI -Play는 실행하지 않았다.

- **완료 / E25:** `Launch-Game-Diagnostic.ps1`, [가이드](../qa/diagnostic-launch-guide.md). 고정copy의14779파일 baseline1회 생성/재생성거부. 새세션 `ec775449711e4346afcafff95ebf9f5c` probe/native0 →3PNG실로드/실보행MQ01/autoSave1/native0 →전후hash동일. classes 기본상태독립재실행/코드DA필수0. 기존보행fixture·정식런처·production 불변. **monsters 후속소유:** timeout 자식종료 때도 로그보존 및 작은독립fixture 검증 보완, 실제 baseline/game을 오염시키지 않음. classes 후속DA.
- **완료 / E23:** [핀16/32/48/64px 비교](../qa/fin-portrait-size-20260913.md), noautoload/minimized/Dummy 실제SubViewport640×360, 최초검사좌표오류8PASS1FAIL 보존→9PASS/native0. story native명령근거 보완 확인, 원본SHA불변. 16px표정식별불충분/32이상인상판독이며 HUD확대/본게임교체승인 아님. root이미지공유 완료.
- **완료 / E21:** [실제 반응40단문 폰트](../qa/reactivity-font-width-20260913.md), 같은theme/font/Control→Control→VBox→Label에서2설정80행/최대101px/154초과0/native0. monstersDA필수0. 큰글씨부모15도 자식은11임을 발견하여15px통과로 주장하지 않음. **story 후속소유:** count80/입력오류 guard와 문서상 Control/VBox 표현 보완·검사, 이어 기존큰글씨HUD 문제는 읽기진단/제안만(아직production수정 승인 안함).
- **새 아트 / classes 소유:** 기존 `potion_hp_small` 아이콘1개 builtin생성+원본보존+가능시20/24/32px 실제UI표시. 짙은갈색불투명배경/기존SD풍, 기존효과·가격·드롭 불변. `item-potion-hp-small-v1` 시안만이며 mapping변경 아직금지. rootimagegen스킬/refs완독·사용자새애셋예고완료. 독립DA는 완료 후배정.
- **관리 DA:** 이전 E22–24/A13/B03·02:17인계·LICENSES Fin문단 story 필수0 종결. 이번 E21/E23/E25/B03·02:27 업데이트는 다음독립DA 대상. 기존 완료결과를 다시 실행/생성하지 말고 위 후속소유를 이어받는다.
- **02:27 후속 역할:** 진단timeout 출력보존/작은fixture5검사(classes 독립재실행0/필수0) 완료, monsters는 font guard 재DA 후 동일고정copy 통합렌더 검사 가능성 읽기계획만 작성(아직새copy/실행금지). story는 font guard 정상80/native0·빈입력0/native1 증거를 보존했고, 다음은 큰글씨15px 직접Label override의 별도 noautoload 레이아웃 시험/샘플이다. 실제154×64에4행·아이콘이 들어가는지 확인하고 최소대안 제안, 아직 본게임 HUD 변경 승인 아님. classes는 소형물약 아트1개 진행.
- **02:29 추가 승인(위 monsters 계획만 단계보다 최신):** 기존 고정copy의 D28/MQlate/FHD 하네스는 과거 서로다른 절대userdata guard 및기존출력경로가 남아 있어 그대로 통합실행불가. root는 `integrated-render-monsters-v1` **새 QA copy 1개만** 승인했다. 기존캐시1회복사·생산코드/데이터해시동일검증, 테스트guard/출력만환경매개화 및3아이콘하네스추가를별도동결전에배치, 각4모드새userdata/probe/Dummy/minimized/고유PNG/native0 확인. 기존14779baseline·fixture·production 수정금지, noeditorimport/no외부설치. 실제4단면동일copy검사이지20분완주/새핀완성이 아님. 재현코드 `tools/qa/integrated-render`, 독립DA는 결과 후배정. font guard 후속DA도 monsters 필수0 완료.

**02:17 후속(아래 진행 문장보다 최신):** 실제보행 MQ01 v2는 native0/자연키입력/원래몬스터10개체(6타입)/완료와autoSave1을 확인했다. v1접근범위 원인은 유력추정으로, EXP5·무피격은 출력/Metrics 관찰값으로 정정하여 story 재DA 필수0 종결. [v2 보고서](../qa/walk-mq01-second-attempt-20260913.md),419걷기프레임≈6.98시뮬레이션초(UI대기별도). `autoload-exit-diag-monsters-v1`의 생성 slot0_auto fixture는 보존하며 재실행 덮기 금지. 소스7656일치/2생성·서식차이는 정확byte전체동일이 아님.

- **진행 / monsters 새 소유:** `Launch-Game-Diagnostic.ps1` 별도 진단 실행기 구현 승인. 정식 Launch/readygate 불변·ready작성 금지. 실제보행 검증copy만 고정/파일·필수실행캐시·엔진hash 검사, 기본상태검사 창0, 명시-Play에서만 새play-session APPDATA+LOCALAPPDATA와 noautoloadprobe 선행. 매실행 새세이브/이전세션자동로드 없음 명시. SelfTest는 별도 새전용세션 headless Main/3PNG/입력 검증, 실제-Play GUI는 아직열지 않음. 이 경로는 엔진편집기오류를 해결했다고 표시하지 않는다. 설계만이던 단계에서 root 승인하여 구현 중, 독립DA classes 예정.
- **완료·독립 검수 / A13:** [오디오 정적감사](../qa/audio-static-audit-20260913.md)37SFX/2BGM/48파일,7tests 재실행 필수0. 동적몬스터24후보 미배정/일반UI3호출미발견/전역voice cap·priority 미구현 분리. 실제청취·루프·믹스·권리심사 아님.
- **아트 완료·독립 검수 / classes:** [핀 초상화v1](../art/preview/ai-local-pass/fin-portrait-v1-prompt.md) builtin1회,1254² RGB 불투명 어깨위 후보. 승인컨셉과 root/story 직접view, 동일성 핵심요소 및 원본byte SHA `E44618A2C5C49C5D9F15BD25675C50957A0AFCFBC595976F6C69D9D518FE917E` 일치. 본게임/64×96모션 미적용. classes 다음은 noautoload 16/32/48/64px 실제UI표시 비교(이미지편집 아닌TextureRect렌더), 그뒤 진단런처DA.
- **진행 / story 새 소유:** 반응40단문의 실제 HUD동일폰트·크기·154px 폭 측정. 문자수 한계를 실측으로 보완하는 별도 noautoload QA, 본게임/정본/소스등록 불변. 도감stale-summary 수정 코드재DA도 필수0 종결; root실브라우저오류복원/제련→수호확인기록 QA에 반영됨.
- **검수 갱신 / root:** 엔진두보고서 환경차이·중단/native구분 및 E20/E21 관리표갱신 classes DA 필수0. 새 E22/E23/E24/A13/B03 관리표 갱신은 다음독립DA 필요. 운영 역할은 이 최신문단을 우선하며 아래 오래된 '진행'은 완료경과다.

- **완료·독립 검수:** MQ01/02 입력 UI와 3프로세스 저장22검사, MQ06/07 기존 NPC 패널 연결31검사/렌더32검사. 후자는 fixture 단면이며 동굴 전투 완주나 Act2 전환 구현은 아니다.
- **완료·독립 검수:** 선방문 장소 및 화물 진행막힘 수정, 관찰6문장. 후속 D28 같은 물리 결계석/Waystone의 E 입력 회귀도 PAUSABLE 월드에서 3FAIL→6PASS/native0, 기존 UI22PASS/native0 확인. 첫 MQ04완료+비석활성은 기존 별도 사건으로 자동저장2회, 반복 추가0. 최종 QuestObject SHA256 `970AF6E8B795491433B101AC11FEEE8961BA4ED9716D3325F148FE29B5EE47C6`. [근거/실제 HUD4장](../qa/object-observation-20260913.md), 렌더16PASS/native0. 관찰 GUT assertion83통과 뒤 native AV는 별도 한계로 보존.
- **완료·독립 검수:** [재료 아이콘3종 실제 UI](../qa/item-three-materials-inventory-v1.md), jelly/horn/cap 기존 ID에만20px 연결, 17PASS/실캡처1280×720. 원본1254² RGB 불투명 카드 그대로 보존, 등급/수량/이름/설명/선택 및 타 아이템 fallback 유지. 정확 번역문 equality 강화는 후속 개선. 드롭·수치·전역 item_icons 불변.
- **완료·독립 검수:** 기존640×360 논리 게임의 실제 FHD readback1920×1080, 10PASS. QA 창 재요청 결과이며 새 핀64×96·월드/카메라 이관 또는 물리 창 전체 가시성 완료는 아니다. FHD 문서 로그 예시 경로 수정 완료.
- **준비 미완료 / 런처:** [실행 가이드](../qa/overnight-playtest-guide.md), `Launch-Overnight-Game.ps1` 작성. 3개 보존 snapshot의 편집기 import 종료AV로 **ready.json 0개**, 기본 실행은 안전 중단. 마지막 `20260913-014740-cce9e52e`에서 probe 재확인 뒤 Main/실입력/젤리load23PASS/native0이므로 게임 로드 불가와 구분한다. 이 복사본은 최종 D28/3아이콘 전 소스다. monsters가 별도 최소 엔진/프로젝트 종료 원인 분리 진단 중이며 오류 무시/ready 승격/새엔진 다운로드 금지.
- **런처 DA / story 완료:** 치명0, 주의2. 파일별 해시 재검사는 전체 디렉터리 원자적 freeze가 아니며 신규 파일 추가를 놓칠 수 있다. 경로 경계는 문자열 기준이며 junction/reparse 보증이 아니다. 현재 신생 일반폴더/팀 소스동결 상태로 한정하고 root가 보완·후속검수 관리한다. 아직 준비 성공으로 올리지 않는다.
- **완료·독립 검수 / classes:** 별도 [성장 도감](../../prototypes/mastery-catalog/README.md), 8계열96노드+28조합특성124항목을 읽기 전용으로 표시. localhost Python 허용파일 서버, 원본 JSON2개 읽기/검증/해시. 12tests 독립 재실행 및 코드DA 필수0, root 실제화면·제련→수호 상세 교차링크 확인. invalidhash→정상노드 시 오류가 남던 문제는 classes 보완/root 실제복원 확인, story 최종 코드 재DA 대기. 서버 `127.0.0.1:8767`, exec session82294 유지; root iab browser1/tab1 handoff. 본게임·SP·효과·비용 불변. 파일 PNG 저장 없이 실제 브라우저 스크린샷 도구 출력으로 공유했다.
- **완료·독립 검수 / story:** [퀘스트 반응40대사쌍](../content-drafts/research-expansion/quest-reactivity-v1.md), 기존6퀘스트24상태+4발견8상태=32카드. validator7tests 독립 재실행, MD-JSON exact문장 누락0/필수0. HUD최장11문자/확장38문자, 실제폰트폭 미검증/런타임 미연결. 장화밑창 단서는 해당경로 전용이며 다른해결에 추가조건 아님.
- **진행 / monsters:** 실제 Main 기본spawn→테오→화물→테오 MQ01 보행 입력 단면. [첫 시도](../qa/walk-mq01-first-attempt-20260913.md)는 NPC수락 후 화물E 실패/native1 보존. 원본몬스터·피해유지/순간이동·Quest API직접진행 없음. root제안 화물좌표가 실제20×20범위 밖일 수 있어 실제overlap 읽기/원래화물중심 기반 v2 자연보행으로 검증 중이다. 잘못된 하네스 그룹의 monsters=0을 실제몹제거로 해석하지 않는다. slot0_auto가 없을 때만 시행/probe선행, 새test는 `tools/qa/walk-mq01`이며 본게임 소스 불변.
- **진행 / story:** A13 기존오디오 정적감사/재현가능 검증기. root선행 읽기집계37SFX이벤트+2BGM,48파일참조/48실파일missing0. 아직 청취/재생동기/믹스 검증은 아니다. 기존 validator 재사용 여부부터 확인하고 본게임 오디오·볼륨·음원 불변.
- **진단 종료 / monsters:** [폰트·테마 최소4조건](../qa/editor-exit-resource-isolation-20260913.md) native0이나 원본binary/processAPPDATA 환경이며 기존copybinary+_sc_ 환경과 다르다. [autoload 제거/복원 새copy1개](../qa/editor-exit-autoload-isolation-20260913.md)는 동일copybinary+_sc_로 검사했으나 제거1669SCRIPT ERROR, 복원0오류 뒤 양쪽 종료지연으로 자체세션 Ctrl-C. 자연nativeAV코드 재현이나 정상import합격 아님. 추가 bisect 중단, classes 독립DA 진행. 원본·기존failedcopy·readygate 불변.
- **root 소유:** 이 인계·중앙 관리표·freeze·DA·최종 실검수. C04/B03 오래된 상태2개는 story 종결확인 완료. 새 재료3종의 중앙 출처대장 LICENSES 링크 추가도 story DA 필수0. E20/E21/A12/C03/C06 갱신은 classes DA 대기. 이후 실제 통합 단면과 준비완료를 계속 구분한다.
- 이후 유효한 통합 검사에서는 최신 D28+MQ06/07+3아이콘을 **동일한 새 snapshot**에 넣어야 한다. 기존 분리 테스트 결과를 통합 성공으로 합산하지 않는다. 핀 실제 모션 업그레이드·신규 성장 런타임·20~30분 플레이 완주 미완료.

### 과거 실행 스냅샷 — 01:30~01:40 기록(위 현재 상태 우선)

- **완료·독립 검수:** MQ01/02 NPC 수주·완료 UI(매핑 입력 22검사, 캡처 포함 23검사), 장소 선방문 트리거 수정(25검사, 기존 GUT 22테스트/142assert, 배치31검사), 인벤토리9설명과 상세패널 격자 제거. 새 UI의 실제 화면은1280×720이며 FHD 성공이 아니다.
- **완료·독립 검수:** [UI→자동저장→새프로세스 복원](../qa/quest-ui-save-2026-09-13.md) create6/resume9/verify7, 총22검사. 입력→버튼→기존 API→실제 저장 경로다. 전용 QA 경로/probe 및 실행복사본 코드 일치를 확인했다. 이동은 위치 지정 후 실제 겹침 검사이며 전 경로 보행이나 로드 메뉴 UI 검사는 아니다.
- **문서·검수:** [12개 빌드 시나리오](../content-drafts/research-expansion/build-scenarios-v1.md), 8계열/60개 시나리오 검사 명세, 정적 검증기21테스트. 보루궁수의 변형 후퇴와 사격 넉백 억제 혼동1건을 수정하고 독립 재검수했다. 실제60개 전투검사가 실행된 것이 아니며 슬롯·수치·직업 정책은 제안 상태다.
- **아트·검수:** [슬라임 젤리 그림](../art/preview/ai-local-pass/item-slime-jelly-v1-prompt.md) 내장 생성1회,1254×1254 RGB 불투명 카드. 원본 불변/24·32논리px 표시 확인 및 독립검수. 정확한 픽셀 격자·최종 팔레트 완성품 아님. 메아리 굴v2도 여전히 배경 콘셉트다.
- **구현·검사, 최종DA 대기 / monsters:** 슬라임 젤리1개만 기존 인벤토리20×20 그림 영역에 연결. [실제 슬롯 검사](../qa/item-slime-jelly-inventory-v1.md)14검사와 기존 설명10검사 및 캡처 완료. 등급 흰점·수량·선택 표시와 다른 아이템 fallback 유지. 공용 대장간 셀은4인자 API 호환 검사이며 실제 대장간 UI 검사는 아니다. 공용 item_icons 매핑/슬롯 크기 불변, 원본 프로젝트 새PNG import는 미실행이고 검사는 격리복사본에서 했다. classes에 최종DA 배정.
- **검사 완료 보고·독립DA 대기 / classes:** FHD 요청 후 native client1920×1061→정수배율2→1280×720 readback을 재현했다. QA Window.size만1920×1080으로 재요청 후 실제1920×1080 렌더와 배율3·UI경계/본문 검사 등10PASS를 보고했다. [새 FHD 캡처](../qa/quest-panel-fhd-native.png)는 root도 직접 확인했다. 논리640×360/시야/좌표/본게임 설정은 불변이며, 모니터 사용 가능 높이1032라 창 전체 물리 가시성 검증은 아니다. 보고서 작성 및 젤리 최종DA 진행 중. QuestSystem/QuestObject는 편집하지 않는다.
- **진행 / monsters 후속:** `quest_npc_panel.gd`만 기존 MQ06/07까지 지원 확대한다. 데이터상 MQ03~05는 system, MQ06/07은 teo·분기 없음임을 root가 확인했다. 첫2개에 한정된 UI를 기존 NPC 메인4개로 연결하는 작업이며 새 퀘스트·보상·사이드/일일 목록은 추가하지 않는다. story의 QuestObject/HUD/QuestSystem 소유와 분리한다. MQ05 완료 fixture를 이용한 UI 검사는 앞선 전투 완주가 아님을 표시해야 한다.
- **01:30대 후속 갱신:** 젤리20px 연결은 classes 최종DA 필수0 및 root 실제캡처 확인 완료. 다만 선택적 PNG가 없거나 미import일 때 const preload가 인벤토리 전체 로드를 막는 개선점이 있어 monsters에게 지연·존재검사 로드/null fallback 및 실패경로 검사 추가를 배정했다. 이 소규모 보완은 아직 완료로 올리지 않는다.
- **진행 / classes 다음:** FHD 산출물은 story_world 독립DA에 배정했고, classes는 안전한 `Launch-Overnight-Game.ps1` 및 실행 가이드를 준비한다. 원본 세이브를 쓰지 않는 검증된 독립 snapshot/custom user dir/probe, 버전·해시 인계와 준비/실행 검사가 목적이다. 지금 사용자에게 보이는 게임창을 띄우지 않으며, 기존 Fin 프로토타입 런처는 보존한다. 새 저장 메뉴나 최종 그래픽 완성으로 확대하지 않는다.
- **01:40 직전 인계(위 진행 기록보다 최신):** FHD DA는 story에서 monsters로 재배정하여 필수0으로 완료했다. 문서 예시 로그 경로의 사소한 혼동만 classes 보완 중이다. MQ06/07 패널 연결은 monsters 구현 완료,31검사/캡처포함32검사·기존MQ1/2 22검사 통과, classes 최종DA 대기다. 원본 MQ07의 Act2 등록 이벤트가 미구현이라는 경고는 남아 있다. 젤리 선택적 자원 로드도 missing-path 포함15검사 통과 보고, classes 재DA 대기다. [메아리굴 UI 샘플](../qa/quest-npc-mq06-v1.png)을 root 직접 확인했다.
- **화물/관찰 검사 상태:** story는 선탐험 실패를 재현한 뒤 수정했으며 관찰7테스트/39assert, NPC포함10테스트/83assert가 통과했지만 GUT 종료에서 native access violation이 있어 정상 프로세스 종료로 보고하지 않는다. 별도 실제 E입력·저장/로드 smoke와 MQ회귀 검사 중이다. monsters가 코드 사전DA를 시작하고 최종 실행 로그를 기다린다.
- **런처 현재 구성:** classes의 `-Prepare`는 기존 것을 덮지 않는 새 versioned snapshot을 만들고 probe/import/main·입력 smoke를 거쳐야 ready manifest를 남기는 방식이다. 기본 실행은 최신 ready만 사용한다. 기존 보유 Godot를 작업 폴더에 복사하는 self-contained 모드를 조사 중이며 새 다운로드/설치/전역 설정 변경은 하지 않는다. 이것은 아직 준비 중으로, 사용자에게 실행 가능하다고 안내하기 전 검증이 필요하다.
- **진행 / story_world:** 기존 화물더미/결계석 관찰6줄 연결 및 검증. 조사 중 cargo_pile 수주 전 one_shot 소진으로 후수주 MQ01 진행이 막히는 기존 버그를 발견하여 재현→수정도 배정했다. quest_object.gd/HUD/번역 및 필요한 QuestSystem 읽기 전용 interact목표 조회만 소유한다. 수주/로드만으로 상호작용 목표를 자동 완료하지 않고 새 명시적 입력을 요구한다. 기존 UI·목표·보상 회귀 검사 후 독립 검수 필요.
- 오케스트레이터는 이번 구간 인계 갱신·결과 검수 담당이다. 동일 작업을 다시 생성하지 말고 위 진행 담당을 이어받는다. 미완료 핀 모션·FHD 통합·신규 성장 런타임을 완료로 올리지 않는다.

- root: 작업 분해·중복 방지·승인 경계·검수 배정·최종 보고 관리. 전문 담당의 실제 산출물과 테스트 결과를 확인한다.
- classes: 격리된 핀 프로토타입의 설정 기반 프레임 로더 최소 구현과 실행 검사. 새 아트 제작이나 본 게임 교체로 완료 범위를 확대하지 않는다.
- monsters: AI 제작 후보 근거와 몬스터·콘텐츠의 독립 단면 제작/검수. 새 종·효과·수치는 확정으로 등록하지 않는다.
- story_world: 본 인계 및 관리표 최소 갱신, 기존 메아리 굴 진입부 배경 콘셉트 1장, 프로토타입 시간 기반 재생 self-test 보완. 프로토타입 DA는 monsters가 담당하며, 이후 classes 본 게임 MQ 후속 코드의 DA는 story_world가 담당한다. 본인이 만든 계획·그림·코드는 다른 담당이 검수한다.

우선순위는 ① 현재 코드 변경의 구조·실행 회귀 검증 ② 내장 이미지 도구로 작은 아트 단위 제작 및 공유 ③ 기존 지역·인물을 이용한 콘텐츠 확장 ④ 안전한 격리 통합 실험이다. 기능 실행과 아트 품질을 별도 판정한다. 각 후속 세션은 현재 파일·진행 상태를 먼저 확인하고 완료 작업을 반복하지 않는다.

## 변경하지 않는 조건

- 핀 승인 외형, 몸체 64×96, 게임 FHD 1920×1080 유지. 96×128 셀·정수 2배·8fps는 시험안이며 최종 확정으로 올리지 않는다.
- 기존 기획 정본·주요 인물·지역·재전직의 사용자 지정 네 조건을 임의 변경하지 않는다. 미정 가격·레벨 하락폭·성장 수치·슬롯 정책은 제안으로 남긴다.
- 외주는 보류한다. 외주 연락/발주, 계정 구매·유료 서비스 결제·새 인증 연결, 별도 외부 서비스로 파일 업로드, git push 금지. 내장 이미지 생성 도구만 이번 아트 제작에 사용하며 외부 API로 우회하지 않는다.
- 기존 dirty 파일은 사용자 작업으로 간주하고 보존한다. 덮어쓰기·삭제·강제 git 복구를 하지 않는다. 담당 파일이 겹치면 조정 후 진행한다.
- 거절된 핀 다리 절단·압축·직사각형 메우기·독립 생성 프레임 나열을 보행 성공으로 재사용하지 않는다. 흔들기와 실제 발 접지·체중 이동을 구분한다.
- 문서 작성≠실제 연결≠런타임 검증≠사용자 시각 승인. 생성 이미지는 크기/알파/시점/동일성을 검수하고 공유하며 자동 합격 또는 본 게임 적용으로 보고하지 않는다.

## 중단·보고와 시간 제한

중요 의사결정·새 권한이 필요하면 해당 부분은 멈추고 질문/차단 이유를 기록한다. 사용자가 자는 동안 답을 가정하지 않고 독립적인 승인 범위 작업만 계속한다. 비용·원본 공개·외형 변경을 야간 승인에 포함된 것으로 해석하지 않는다.

06:45 KST부터 큰 변경·장시간 생성·새 시스템 착수를 중단하고 기존 작업 저장, 회귀 검사, 미완료/위험 목록 정리에 집중한다. 07:00까지 완료 파일, 실제 실행한 테스트, 실패/미검증, 생성 이미지, 필요한 결정과 다음 순서를 보고한다. 시간 부족으로 검증하지 못한 작업은 그 상태 그대로 남기며 완료로 올리지 않는다.

각 인계에는 담당·변경 파일·실행 명령/결과·게임 데이터 영향·남은 검증을 남긴다. 기준 목록은 [중앙 관리표](master-work-register.md), AI 연결 후보는 [AI 제작 조사](../art/ai-sprite-pipeline-options.md)다.

## 01:00경 인계 상태
 
최신 01:10 관리 갱신(root/담당 보고 기준): 프로토타입33 PASS는 재DA 지적 해소. classes는 MQ 저장34assert와 기존GUT7test/92assert PASS를 보고했으나 수주/턴인 UI 없이 API 검사한 범위다. 현재 `quest_trigger` 조기 방문 소진 버그 재현/수정 중이므로 다른 담당은 해당 코드에 쓰지 않는다. 다음 최우선 구현 후보는 퀘스트 수주/완료 UI 단면이며 중복 착수 전 root 배정 확인.

monsters는 인벤토리9desc·10 PASS·실제캡처 완료, story_world 독립DA 대기. story_world는 HUD/ui_ko.csv/NPC unit 소유로12대사 단면8test/45assert PASS 후 좁은154px토스트를 문구 단축 및 실제font폭 검사로 보완 중(보상로그 레이아웃 유지); 완료 후 monsters 재DA. story_world가 classes MQ 코드도 독립DA 예정. 활성 작업은 이 소유권을 유지하고 heartbeat 재개 시 동일 파일 작업을 재생성하지 않는다.

아트: 슬라임은 RGB 배경 실패, 메아리 굴은 시점·추가폭포·샛길합류 한계를 root가 실제뷰로 확인했다. 생성 사실과 품질 보류를 분리하며 자동 게임 적용하지 않는다.

후속 인계: NPC 문구단축+실제Label폰트 너비 검사 완료,9test/57assert PASS(최대150px/한도154), monsters 재DA 대기. 기존 보상로그 레이아웃 불변. 인벤토리 독립DA는 실제캡처·재료도면·PO키를 확인했고 배낭의 미연결 용량효과를 실제효과처럼 설명한 문구1건 보완 권고를 root에 전달했다. monsters는 메아리 굴 v2에서 물 제거/합류 교정 내장 생성 진행 중이라는 root 보고를 받았다. classes MQ저장 DA는 범위통과 보고가 있으나 최종 sentinel 확인을 구분하고, 현재 조기방문 trigger 수정은 별도 진행 작업이다.

## 후속 최신 상태 — MQ UI 인계

01:25 이후 인계: MQ UI·인벤토리 DA 필수지적0 종결보고. story_world가 신규소유 `smoke_quest_ui_save.gd`/`SmokeQuestUiSave.tscn`으로 UI→자동저장→3프로세스복원 연결검사 완료(6+9+7=22PASS,각exit0). 새QA프로젝트/전용userdir/noautoloadprobe일치 후 실행, 기존fixture보존, 자동저장구독유지. 생산코드 추가수정없음. `docs/qa/quest-ui-save-2026-09-13.md` 독립DA대기이며 이새테스트동일fixture create재실행금지. 다음관찰텍스트는root배정후착수.

인벤토리격자 후속DA 완료: 상세패널1곳만기존Inventory/backdrop 재사용,전역theme불변·10검사/캡처PASS·view확인·추가필수지적0. story_world의 관찰콘텐츠 읽기조사: 기존cargo_pile(one_shot),ward_stone_dandelion(반복상호작용),echo_cave_puzzle_01을 확인했다. cargo_pile 완료후관찰은현interact의one_shot조기return과분리하고퀘스트신호를재발신하지않는별도표시경로가필요하다. 이는후보조사이며새관찰코드는아직없다. root다음배정전착수대기.

01:20 후속: E/Escape/Enter 키 이벤트와 JoypadA 매핑중첩 검사 추가 완료, headless22 PASS·렌더23 PASS. 패드A로 열기만 했을 때 수주0을 확인했다. 실하드웨어 조작검사는 아님. FHD요청캡처는실측1280×720이므로 논리이관/FHD검증 성공으로표시하지않는다. MQ UI는monsters DA대기이며 story_world가보유중, heartbeat에서중복구현금지. 다음후보는기존 cargo_pile/표지/기존NPC 관찰텍스트·상태반응의선택단면이나 현UI DA완료후root배정전착수하지않는다.

- story_world: MQ01/02의 기존 giver=teo 수주/완료 패널 구현과 실제Input→Button→API 검사 완료. headless21 PASS/렌더22 PASS, UI샘플 `docs/qa/quest-npc-panel-v2.png`; 진한본문색으로 대비보완. 기존논리화면 임시패널이며 FHD이관아님. monsters 독립DA 요청. 소유파일 quest_npc_panel.gd/ui_root.gd/quest_npc.gd/ui_ko.csv/SmokeQuestNpcPanel은 검수까지 추가교차수정금지.
- root 보고: classes trigger 버그 before2FAIL→final25PASS/GUT22test142assert/layout31PASS, DA필수지적0으로종결. 반복퀘스트 재수주는 미검증. classes 다음은12빌드 시나리오JSON/검증(설계제안만).
- NPC9/57 폭DA 종결, 배낭실효과오인 문구보완 재DA종결. 배경v2 물제거·샛길연결은 view검수통과이나 여전히콘셉트/비타일·비콜리전. monsters는 기존인벤토리 주황격자 theme원인조사중이며 공유theme변경시 questpanel과영향조율.

- 관리 계획과 E13 AI 조사 링크 갱신 완료. 별도 서비스는 미연결·미시험이다.
- 메아리 굴 [배경 v1 기록](../art/preview/ai-local-pass/echo-cave-background-v1-prompt.md)과 PNG 생성 완료. 실제1672×941 RGB로 FHD 출력 미달이며, 요청 밖 폭포/못·샛길 합류 불명확·과도한 정면 시점 때문에 승인 보류다. 생성 실패가 아닌 요구조건 미달 산출물이며 게임에 적용하지 않았다. root/monsters 독립 검수 예정.
- 격리 핀 프로토타입 시간 기반 재생 self-test 추가: 실제33 PASS/종료0, [로그](../qa/fin-config-timing-selftest.log). 최초 기본 로그 경로 실행은 접근 실패/엔진 종료, 작업 폴더 로그 경로로 재실행 성공. 새 그림은 만들지 않았으며 기존 거절 그림을 검사 fixture로만 사용했다. monsters 재DA 예정.
- 다음: classes의 본 게임 MQ 단면 검증 결과를 인계받고 독립 DA, 배경의 요구조건 미달은 다른 담당 검수 뒤 보정 여부 결정. 새로운 주요 설정/수치는 승인 없이 확정하지 않는다.
