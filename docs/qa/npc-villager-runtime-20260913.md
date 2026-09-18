# 주민 대사 12줄 — 실제 번역/HUD 실행 검증

2026-09-13 재개 결과: Pinto·Rozel·Dami의 새 대사 12줄과 실제 Godot CSV 번역 산출물을 반영했다. 최종 **286 PASS / 0 FAIL / 자연 종료 native 0**. 이 중 236개는 CSV 전체 번역 일치 검사이며, 286개의 서로 다른 게임플레이 시나리오를 뜻하지 않는다. 독립 DA 완료, 필수 수정 0건이다.

## 반영 내용

- Pinto 일상 3줄: 망치 연습과 불똥 주의.
- Rozel 일상 3줄: 목초지·울타리·발밑 주의.
- Dami 일상 3줄: 몽실이를 찾는 부탁.
- Dami 몽실 퀘스트 완료 후 3줄: 함께 찾아준 것에 대한 감사와 잠시 쉬기. 몽실이와 재회했다는 문장은 추가하지 않았다.
- 기존 Teo·Meru의 일상/동굴 완료 12줄을 유지한다. 순환 카운터는 NPC와 상태 그룹별로 분리되며 알 수 없는 NPC는 기존 `npc.<id>.greeting` 폴백을 사용한다.
- 새 상점·퀘스트·보상·저장 정책·폰트 크기를 추가하지 않았다. NPC의 기존 입력/신호 경로는 그대로이다.

## 실제 실행 증거

기존 야간 작업에서 만들어 둔 복사본 `reviews/games-2026-09-12/runtime/npc-villager-runtime-v1/game`만 사용했다(Games 부모 기준). 새 전체 복사, 고정 14779/14781 프로젝트 변경, 원본 editor import는 하지 않았다.

최종 실행:

```powershell
& ./tools/qa/reactivity-font/run-npc-imported-v3.ps1
```

최종 세션은 `npc-villager-runtime-v1/resume-f34df6a5b82a4e339c02212bf9155039`이다.

- `probe-v2.result.json`: no-autoload probe native 0, exact user dir 확인. 실제 경로는 위 세션의 `appdata/NpcVillagerRuntime`이다.
- `csv-import-v2.result.json`: 작은 no-autoload CSV 전용 프로젝트의 Godot editor importer native 0. 최초 실제 reimport 출력은 바로 이전 성공 세션 `resume-1a0e0771108240e18bbe42b8d07f52da/csv-import-v2.stdout.log`에 `ui_ko.csv`와 reimport 완료가 남는다. v3에서는 이 동일 산출물을 재사용했다.
- `runtime-v3.stdout.log`, `.stderr.log`, `.result.json`: 실제 프로젝트 autoload + 실제 `Hud.tscn` + `Events.npc_talked`로 검사, `NPC_RUNTIME_IMPORTED_RESULT PASS=286 FAIL=0`, natural exit true/native 0.
- `game-before.json`/`game-after.json`: runtime 전후 **14804개** 복사본 game 파일 SHA 동일. import 산출물을 복사본에 넣은 뒤 freeze했고, runtime이 파일을 바꾸지 않았다는 범위이다.
- `inputs.json`: 실행기/외부 검사 스크립트/순수 probe/프로젝트 설정/CSV/import 산출물/원본 HUD·CSV/console engine SHA 10개. engine 디렉터리 전체 pre/post 감사는 아니다.

검사 구성은 한국어 locale 1 + CSV 키 개수 1 + 전체 236키 번역 일치 + 신규 12키 번역 일치 + 5 NPC 일상 순환 20 + 초기 퀘스트 상태 유지 1 + 완료 그룹 순환 12 + 완료 상태 유지 1 + unknown 폴백 1 + 자동저장 부재 1 = 286이다. 신규 12키는 전체 236키 검사와 의도적으로 중복된다.

CSV는 기대 문자열을 읽는 용도로만 쓴다. 검사 코드에서 `Translation.new()`/`add_translation()`으로 번역을 주입하지 않는다. 실제 프로젝트 설정의 `.translation` 리소스가 읽히는 결과와 CSV 전체를 비교한다. 완료 그룹은 `QuestSystem.from_dict`로 두 퀘스트 완료 fixture를 주입한 것이다.

## 원본 번역 리소스 반영

추적 중인 `game/localization/ui_ko.ko.translation` 한 파일만 importer 결과와 byte-copy로 동기화했다. 원본 기존 파일은 최종 세션 `production-before/ui_ko.ko.translation`에 먼저 보존했다. `production-promotion.json`은 원본 localization 8파일 전후 SHA를 담고, 번역 산출물 1파일만 변경·나머지 7파일 동일을 확인한다.

| 파일 | 최종 SHA256 |
|---|---|
| `game/scripts/ui/hud.gd` | `7961C5397AFE5DAE9850F9BEBE4046A724C5E2B802538F891640FC7E86BEA828` |
| `game/localization/ui_ko.csv` | `D0025895F2D7BCF5C38E6A298394A5510B3E3969451242EAE922830F0FEB4255` |
| `game/localization/ui_ko.ko.translation` | `2AA97D0C56E1382C689DFB27091F6E126D07D25D51934D1464D929BFDB1FE711` |

위 세 파일은 실제 성공한 QA 복사본과 일치한다. 이전 번역 파일 SHA는 `B83AA70537D7BFF79A322F566B1D216A3F81824C0186398A6D1E24879B243C24`이다. 다른 번역 파일이나 전체 원본 cache를 덮어쓰지 않았다.

## 실패 보존 및 한계

- 재개 첫 probe는 QA 설정의 `config/name` 누락 때문에 custom user dir가 무시되어 native 1이었다. `resume-81c7060b7267490e81614dbe700cd983`에 보존했다. 실제 fallback은 해당 세션 `appdata/Godot/app_userdata/[unnamed project]`였으며 no-autoload 단계에서 중단되어 게임 autoload는 실행하지 않았다. QA probe와 CSV 전용 프로젝트에만 이름을 추가했다.
- 실제 HUD v2 49 PASS/native 0 기록과 스크립트를 보존한 뒤, v3에 전체 236키/정확한 키 개수 검사 및 실패 시 finally 사후 snapshot 기록을 추가했다. v3 실행이 실패하면 실패를 그대로 전달한다. 자체 child 60초 초과 시 종료하고 stdout/stderr/exit 증거를 남기나 이번 실행은 timeout이 아니었다.
- 이전 격리 adapter 검사 295 PASS는 helper·CSV 구조·11/15px 문자열 폭 검사였다. 실제 import/HUD 검사를 대체하지 않는다. 12줄의 24개 폭 측정 최대는 11px 112, 15px 152로 기존 154px 범위 안이었다. production의 큰 글씨 전파 문제를 고쳤다는 뜻이 아니다.
- 이번 검증은 **headless 텍스트/신호 실행**이다. 새 FHD 렌더, 화면 가독성, 자연 보행→E 입력, 실제 몽실 퀘스트 완료, 장기 플레이를 추가 검증하지 않았다. 앞서 성공한 FHD 66검사는 신규 NPC 대사 반영 전 버전이다.
- 기존 인증서 store 읽기 오류와 stats 경고는 stderr에 남았다. SCRIPT ERROR나 종료 후 crash는 없었다. Metrics는 격리 user dir에 playtest 로그를 썼다. 자동저장 부재 검사와 세션 전체 무쓰기 주장을 혼동하지 않는다.

## 독립 DA

save_verification 담당이 최종 보고서, v3 스크립트 2개, 실행 로그/result, 14804개 전후 manifest의 동일성, inputs 10개 현재 SHA, promotion 8파일 현재 SHA 및 이전 backup SHA를 검토했다. 이전 고정 복사본의 224 CSV 항목과 현행 236 항목을 별도 비교해 기존 값 변경 0·신규 12를 확인했다. 필수 수정 0건이다. 독립 담당이 전체 14804 파일을 다시 해싱하거나 Godot 실행을 반복한 것은 아니다. 실행기는 SCRIPT ERROR 문자열을 자동 거부하지 않으므로 이번 stderr의 수동 검사 결과를 기록한 것이지 모든 오류를 자동 차단한다는 주장은 하지 않는다.
