# NPC 퀘스트 UI → 자동저장 → 새 프로세스 복원

2026-09-13 · MQ01/MQ02 한정 통합검사. 새 테스트 `game/tests/smoke/smoke_quest_ui_save.gd`, `SmokeQuestUiSave.tscn`만 작성했다. 이 작업에서 production UI/QuestSystem/QuestTrigger/SaveManager는 변경하지 않았다.

## 격리와 실행

기존검사복사본을 새 `reviews/games-2026-09-12/runtime/quest-ui-save-game`에 복사해 전용 custom_user_dir `Games-QA-quest-ui-save-20260913-story`를 지정했다. 이전 QAfixture는 덮어쓰지 않았다. 무오토로드 `quest-ui-save-probe`에서 실제경로 `C:/Users/freer/AppData/Roaming/Games-QA-quest-ui-save-20260913-story` 정확일치 확인후에만 실행했고, smoke도 매프로세스 동일경로를검사한다.

create단계는 기존 slot0_auto.json이 있으면 거부한다. 최초생성후 resume/verify 단계로만 증분검증했다. 해당 새QA디렉터리 접근을 명시한 권한승격으로 실제파일저장을 허용했고,사용자게임 세이브를 읽거나 쓰지 않았다. 전용QA의 Metrics기록도 남겼다. 테스트에서 적을 제거한 것은 메모리상의 전투간섭 방지다.

`Godot --headless --path <새복사본> --log-file <단계로그> res://tests/smoke/SmokeQuestUiSave.tscn -- --stage=create|resume|verify`를 **서로 다른3개프로세스**로 실행했다.

| 단계 | 실제 검사 | 최종 sentinel | exit |
|---|---|---|---|
| create | 물리E→NPC패널→Enter버튼수주→다시말하기·화물상호작용→Enter완료,EXP5·자동저장1회·추가확인중복0 | QUEST_UI_SAVE_RESULT stage=create PASS=6 FAIL=0 | 0 |
| resume | 실제파일로드·MQ01완료/EXP5복원→MQ02버튼수주·장소진입·머루대화·테오완료버튼→EXP10·자동저장1회 | QUEST_UI_SAVE_RESULT stage=resume PASS=9 FAIL=0 | 0 |
| verify | 다시로드·두완료/EXP10유지·완료퀘스트버튼없음·Enter추가입력후퀘스트상태/EXP/자동저장변화0 | QUEST_UI_SAVE_RESULT stage=verify PASS=7 FAIL=0 | 0 |

총22검사PASS. 로그는 같은폴더 `quest-ui-save-probe.log`, `quest-ui-save-create.log`, `quest-ui-save-resume.log`, `quest-ui-save-verify.log`. 수주/완료 API를 smoke가 직접호출하지않으며 InputEventKey의E/Enter/Escape→기존매핑→Button→backend를 통과한다. SaveManager자동저장 구독을 해제하지 않았다. 로드는 기존공개API이고 로드메뉴UI검증은 아니다. EXP는 현재백엔드 누적placeholder이며 실제레벨업검사아님.

기존이전검사에서발생한 Metrics err7/err12와달리 이번권한승격3프로세스에서는 Metrics저장오류가 없었다. 기존LUK/INT 밸런스경고는남았으며 전체게임무오류·FHD·실물컨트롤러·모든퀘스트회귀통과를의미하지않는다. 실제fixture는보존한다. independent DA 대기.
