# MQ01~02 NPC 수주·완료 UI 단면

범위: 기존 `act1_hartland.json`의 MQ01/MQ02만 연결. 두 퀘스트 모두 giver=teo이며 머루는 MQ02 talk 목표이지 수주/완료 NPC가 아니다. `quest-system-m2.md` 공개 accept/advance/get_state와 BRD F5-1/F5-4·GDD 퀘스트 흐름을 확인했다. 전체 대화 말풍선/타이핑/호감도 UI 구현은 아니다.

구현 파일: `game/scripts/ui/quest_npc_panel.gd`, `ui_root.gd`, `world/quest_npc.gd`, `localization/ui_ko.csv`. UiRoot가 기존 단일 pause 책임을 유지하며 새 패널도 포함한다. 실제 NPC interact는 기존 talk 신호를1회 발신하고 입력을소비한 후 패널을 요청한다. 기존 프로그래밍용 talk()는 패널을 강제로 띄우지 않는다. 다른 NPC/퀘스트는 기존 인사만 유지한다.

수주/완료 버튼을 명시적으로 선택해야 백엔드가 호출된다. 새 keybind 없음: 기존 interact, ui_accept/cancel, 기본 버튼 포커스/마우스 사용. 가용성·giver·현재상태 재검사,중복확인 방어 및 다른 메뉴겹침 차단. MQ01 수주이전 인사는 목표에 소급반영하지 않으므로 수주뒤 다시 테오에게 말을 걸면 기존 talk목표가 진행한다. 데이터·보상·선행조건·QuestSystem코드는 이 작업에서 수정하지 않았다.

## 실제 검증

이전 NPC검사의 고유 game복사본에 해당코드/CSV와 최신 quest_trigger/quest_system을 복사. 사용자디렉터리 실제값을 런타임에서 전용 `C:/Users/freer/AppData/Roaming/Games-QA-npc-greeting-20260913-story`와 비교후 진행한다. `smoke_quest_npc_panel.gd`/`SmokeQuestNpcPanel.tscn`이 플레이어를 NPC/오브젝트/장소와 실제중첩시킨 뒤 Input.parse_input_event로 interact/ui_accept/ui_cancel을 보내며 버튼→공개API 경로를 검사한다. 수주/턴인을 테스트가 직접 호출하지 않는다.

headless:21 PASS/0 FAIL/exit0(`quest-npc-panel-test.log`). 실제 렌더:캡처포함22 PASS/0 FAIL/exit0(`quest-npc-panel-render-v2.log`). 입력→패널,열기시자동수주없음,닫기,모달중추가talk없음,메뉴상호배제,수주1회,active턴인금지,화물상호작용,완료보상1회,중복보상0,MQ02선행/giver/목표흐름 확인.

UI테스트는 저장검사가 아니므로 복사본 테스트에서 main_quest_stage_completed→SaveManager 자동저장 구독을 명시해제했다. 본 게임 해당연결은 바꾸지 않았다. 플레이어 세이브를 로드/덮어쓰지 않았다. 퀘스트상태 reset과 적제거는 테스트 내 메모리에서만 수행했다.

## 실제 화면과 한계

[실제 UI 샘플](quest-npc-panel-v2.png): 기존게임1280×720창·640×360논리화면의 임시양피지 패널. 흰색글자 대비부족을 실제캡처에서 발견해 진한본문색으로 보완했다. FHD이관·최종디자인·본문번역다국어·컨트롤러실기검증 완료가 아니다. 전체퀘스트목록·사이드수주·대화말풍선은 미구현이다.

에디터import는 복사본에서 코드/CSV처리후 전역editor_settings 권한오류로 종료지연, 해당프로세스만 Ctrl-C 종료했다. runtime은 인증서/기존stats경고·격리Metrics쓰기err7이 남지만21/22개검사는 모두 실행되었다. 전체환경무오류 또는 저장테스트PASS로 확대하지 않는다. 독립DA대기.

## 실제 매핑 이벤트 추가 검사

`quest-npc-panel-mapped-input.log`:22 PASS/0 FAIL/exit0. 시작 열기를 InputEventKey 물리E, 취소를Escape, 확인을Enter로 실행했고 재열기는 InputEventJoypadButton A의 press/release를 사용했다. A가 interact/ui_accept에 겹치는 기본매핑에서도 열기이벤트로 자동수주되지 않음을 확인했다. 실제 하드웨어 입력을 사람이 조작한 검사는 아니다.

`--resolution 1920x1080`로 실제렌더 재시도(`quest-npc-panel-fhd.log`)는23 PASS/exit0이나 저장된 `quest-npc-panel-fhd.png`의 측정치는1280×720이었다. 파일명의fhd는 요청조건일 뿐 성공해상도가 아니다. FHD캡처 성공으로 보고하지 않으며 최종샘플은 대비보완된 `quest-npc-panel-v2.png`와 동일1280×720이다.
