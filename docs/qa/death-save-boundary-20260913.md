# 사망·부활·저장 경계 실행 — 2026-09-13

현재 **기존 create 10PASS/native0 + 별도 read-only verify v3 29PASS/native0**. v3는 비교기 자기검사14건과 실제 저장 fixture 검사15건이며, 29건 전부를 게임 행동 검사로 세지 않는다. 기존 첫 verify6PASS·1FAIL/native1 및 v2의 결과·입력을 보존했다. v3 독립 DA와 root 코드/기록 검토를 마쳤고 필수 수정0이다. 독립 담당은 코드·기존 실행 로그·manifest와 입력5/원본외부4/세이브3의 현재SHA를 확인했으며 프로세스 재실행이나 전체14781파일 재해싱은 하지 않았다. 생산 게임 코드는 변경하지 않았다.

## 재개 후 verify v3 결과

사용량 제한 후 재개 때 기존 `verify-v2-c4ff22acbe96412a9ab77106343145be/verify.log`에서 이미 실행된 12PASS/native0 결과를 발견했다. v2를 다시 실행하거나 수정하지 않았다. 해당 폴더에 당시 v2 하네스/실행기의 동일 byte 복사본도 추가 보존했다. v2의 capacity 비교에는 `int()` 절삭 허점이 있었고, 재사용한 실행기의 `external=4` 출력은 당시 입력 manifest의5개와 달랐다. 이 한계는 v2 역사 결과에 남기고 별도 v3로 보강했다.

- v3 하네스: `tools/qa/death-save-verify-v3.gd` (SHA256 `AAEF4BCD91036D5FB7021EB9C0ED21886DCDE5B66C1F13E20FF4D623771CE0C5`).
- 실행기: `tools/qa/run-death-save-verify-v3.ps1` (SHA256 `53E173D4DFB80081ABEED8556369F64B532FAC017E22257FE808D6DBDB45463D`). 명령은 Games 폴더에서 `./tools/qa/run-death-save-verify-v3.ps1`.
- run: 기존 QA root 아래 `verify-v3-b93ee019153546029a7f51e30b0929bb`. `inputs.json`, 독립 `probe.log`, `verify.log`, 전후 두 줄 `audit.log`를 보존했다. runner 자체 exit0, probe/verify 각각 native0, timed_out=False/forced=False. --quit-after나 editor import는 쓰지 않았다.
- 원본 create가 기록한 `expected-inventory.json`을 그대로 사용했다(SHA256 `3839BB001A443445CD6D6AA63BC8ED0E8F7F3408820E003A0C6FCBD9CBA5EACD`). 새 기대값으로 덮거나 create를 재실행하지 않았다.
- 실제 값은 expected/saved의 `capacity_bonus=0.0`, loaded의 `capacity_bonus=0`이고 모두 수치0이다. 로그의 **3/2/3은 값이 아닌 Variant 타입 코드**(FLOAT/INT/FLOAT)다. 슬롯의 uid=`death_qa_jelly`, item_id=`slime_jelly`, grade=`common`, quantity=`1.0`은 세 데이터 모두 동일했다. 고정 snapshot의 Inventory.from_dict가 capacity_bonus만 int로 복원하는 코드와도 일치한다.
- 최초 전체 Dictionary 비교 실패는 이 숫자 표현 타입 차이였으며, v3에서는 저장 JSON/기존 expected/로드된 전체 인벤토리의 재귀 의미 비교가 통과했다. 객체의 키 순서는 무시하지만 키 누락·추가, 배열 순서, 모든 필드 및 중첩 필드의 값은 그대로 비교한다. capacity와 quantity는 유한한 정확한 정수 값인지도 별도 검사하며 `int(1.5)==1` 식 절삭을 허용하지 않는다. 안전하게 비교할 수 없는 큰 숫자(절댓값 2^53-1 초과)는 거부한다.
- 비교기 자기검사14건은 정상 int/float표현·객체키순서 수용1건과 분수 quantity/capacity, bool/string 숫자 강제변환, 슬롯순서, UID/item/grade/중첩affix 변경, 키추가/누락, 슬롯누락, 비유한값 거부13건이다. 실제 fixture는 슬롯1개이고 affix가 없으므로 여러 슬롯 및 affix 로드 보존은 실게임 fixture 시험이 아니라 비교기 음성검사 범위다.
- 실제 fixture15검사는 원본 manual SHA, 새 프로세스 load, 인벤토리 키/정수capacity/슬롯수/슬롯키/UID·item·grade/정수quantity/슬롯전체/인벤토리전체/디스크·expected·loaded 삼자 비교, HP·스태미나 전량, alive Idle, 비석위치·death_count1, load 전후 manual SHA다.
- 전후 해시 감사는 game14781 파일(캐시 포함), 기존 engine manifest의3파일, 원본 외부입력4파일, 현행 입력5파일, saves의3파일(자동/수동/수동bak)의 개수·SHA 모두 불변이다. current_inputs5는 v3 하네스·runner·고정 manifest·원본 QA manifest·expected JSON이다. 원본 외부4는 최초 하네스·runner·probe.gd·probe/project.godot이다. 엔진 폴더 전체나 모든 OS 파일을 검사했다는 뜻은 아니다.
- no-autoload probe가 실제 userdir과 기대 경로의 정확한 일치를 먼저 확인한 뒤 Main/autoload를 실행했다. 기존 QA fixture의 **save 파일은 읽기 전용**이나 Godot 로그와 Metrics playtest 로그는 QA 사용자 디렉터리에 새로 기록된다. 사용자 원본 세이브는 대상으로 삼지 않았고 별도 byte 감사도 하지 않았다.
- 수동 save SHA는 실행 전후 `3C49EDBB0503198DAA95C6EC479E037E0F6128189CBB2915035AE90EFF3E670D`. 기존 인증서 store 오류 및 stats 경고는 남아 있으나 SCRIPT ERROR는 없었다. 사망·부활을 v3에서 다시 수행한 것이 아니라, 앞선 create10검사의 저장을 새 프로세스에서 검증한 연결 결과다.

## 최초 실행 기록 (실패 포함 보존)

이하 첫 실행 시점에는 create10PASS/native0, 새 프로세스 verify6PASS·1FAIL/native1로 전체 통과가 아니었다. 실패 로그와 fixture를 보존했으며 당시 자동 재실행하지 않았다.

- 고정 snapshot: `reviews/games-2026-09-12/runtime/integrated-render-monsters-v1`. game14781(캐시 포함), engine3는 수정하지 않았다. 전체 새 copy/import 없이 외부 `Games/tools/qa/death-save-boundary.gd`를 --script로 실행했다.
- 전용 QA root: `reviews/games-2026-09-12/runtime/death-save-boundary-ae1c07a77c30456081427119383e31ee` (Games 부모 기준). create/verify 로그, expected-inventory.json, 저장 fixture 및 qa-input-manifest.json 보존.
- 외부 하네스·실행기·probe.gd·probe/project.godot 4개 SHA 및 명시 명령 배열을 별도 manifest에 기록했다. 이 입력은 고정 snapshot manifest 밖이다. child APPDATA/LOCALAPPDATA를 새 GUID로 격리하고 두 프로세스 직전 no-autoload exact-userdir probe native0를 확인했다. probe.log는 두 번째 probe가 같은 파일에 기록하므로 첫 결과는 실행 출력에만 남는 한계다.
- 60초 상한, 자체 child만 종료하며 timeout이면 stdout/stderr/nativecode/forced 표식을 저장한다. 실제 두 실행은 timeout false/forced false였다. --quit-after 없이 검사 후 quit(0/1)한 실제 종료코드다.
- create는 기존 saves 디렉터리가 있으면 거부한다. 이번 경로는 새로 만들었고 기존 사용자·보행 fixture를 읽거나 삭제하지 않았다. 별도 사용자 디렉터리만 사용했으며 원본 사용자 세이브에 대한 byte 감사는 하지 않았다.

## 실행 결과

create: 몬스터를 제거한 Main fixture에 기존 slime_jelly1개를 주입하고 비석을 직접 활성화했다. 안전 baseline 수동 저장 후 테스트 enemy Hitbox의 실제 try_hit로 사망시켰다. Dead 상태, 사망 중 저장 player_dead 거부, 기존 수동 저장 SHA 불변, 정상 Dead 타이머 이후 Idle/HP·스태미나 전량/비석 위치/아이템 유지/death_count1, 실제 시간 경과 후 저장 성공 10검사를 통과했다. 새 부활 자동저장을 구현하지 않았다. 잠금 대기 포함 관측 wall4735ms, GameState.play_time5.006초이며 시간 값을 직접 증가시키지 않았다.

verify: 새 프로세스에서 load 성공, HP·스태미나 전량, 살아있는 Idle, 비석 위치, death_count1, load 전후 저장 SHA 동일은 통과했다. 인벤토리 Dictionary 전체 동일 검사 하나가 실패했다.

디스크 읽기 결과 저장된 슬롯에는 uid=death_qa_jelly/item_id=slime_jelly/quantity1/gradecommon이 유지되어 있다. expected JSON에는 정수0·1, 저장 JSON에는0.0·1.0이 있고 Inventory.from_dict는 capacity_bonus를 int로 복원한다. 따라서 숫자 타입을 포함한 Dictionary 비교 오탐 가능성이 있다. **로드 후 실제 Dictionary의 타입/내용을 추가 관측하지 않아 원인 확정이나 아이템 보존 합격으로 처리하지 않는다.** 후속은 create 재실행이 아닌 새 버전 read-only verify로 슬롯 필드와 정규화 비교를 관측하는 방안이며 별도 승인 전 실행하지 않았다.

수동 저장 SHA256: `3C49EDBB0503198DAA95C6EC479E037E0F6128189CBB2915035AE90EFF3E670D`.

실패 종료 후 별도 읽기 재검사에서도 game14781개/engine3/외부입력4개 SHA 차이0이었다. 고정 파일이나 하네스를 고쳐 통과시킨 것이 아니다. 기존 인증서 store 읽기 오류와 stats 경고는 로그에 남아 있다.

검사 한계: 몬스터 AI 전투 완주가 아닌 실제 피해 판정→부활→저장/재시작 경계이다. 비석 접근은 자연 보행이 아니라 직접 활성화다. 기존 smoke_death_respawn은 저장 재시작 검사를 하지 않고 실패도 quit0으로 끝나며, smoke_save_load는 is_dead 직접 주입으로 저장 거부를 보므로 이 연결을 대체하지 못한다.
