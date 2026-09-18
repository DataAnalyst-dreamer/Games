# NPC 생활 대사 단면 검사

실제 변경: `game/scripts/ui/hud.gd`, `game/localization/ui_ko.csv`, `game/tests/unit/test_npc_greeting.gd`. 테오/머루 각 일반3·메아리 굴 MQ06 completed 이후3, 총12줄. 기존 NPC 신호를 소비해 방문마다 짧은 한 문장만 출력한다. 세션 내 NPC/완료구간별 순환이며 순환 위치는 저장하지 않는다. 로젤 등 다른 NPC는 기존 인사 key를 유지한다. 퀘스트 상태·보상·전이·세이브 스키마는 변경하지 않았다.

CSV 파서 검사:214행, 중복키0, 새대사12, 빈번역0. 원본 Godot import는 CSV와 Hud/test 스크립트 처리까지 완료했으나 기존 DialogueManager 사용자설정 null, editor_settings 권한오류로 exit1(`npc-greeting-import.log`). 이를 전체 import 성공으로 보지 않는다.

독립 복사: 원본 game 전체를 `reviews/games-2026-09-12/runtime/npc-greeting-game`에 복사했다. 복사본 project.godot만 custom_user_dir와 에디터 플러그인 비활성으로 수정했으며 원본 프로젝트 설정은 변경하지 않았다. 외부 서비스/사용자 세이브 호출은 없다. 같은 HUD/CSV/번역캐시를 복사해 검사했다.

무오토로드 probe에서 실제 user_data가 `C:/Users/freer/AppData/Roaming/Games-QA-npc-greeting-20260913-story`와 정확히 일치함을 확인했다(`npc-greeting-isolation-v3.log`). 앞선 probe 두 번은 설정/절대경로 해석 불일치로 실패해 테스트를 진행하지 않았고 로그를 남겼다. 본 게임 기본 user_data는 사용하지 않았다.

실제 명령: 격리 복사본에서 Godot4.4.1 `--headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_npc_greeting.gd,res://tests/unit/test_hud_math.gd -gexit`.

결과:2 scripts/8 tests/45 asserts PASS, exit0(`npc-greeting-unit.log`). 신규2개는 순환/완료구간 분리/기존NPCfallback, 실제 import된12개 번역 메시지를 검사한다. 기존 HUD 수학6개도 통과했다. 실제 화면의 토스트 잘림·플레이어 입력·완료 직후 신호순서까지 검증한 것은 아니다.

환경 경고: 시스템 인증서/기존 LUK·INT 밸런스 경고와 격리 user_data의 Metrics 생성·저장 권한오류(err7)가 남았다. 결과는 테스트 assertions PASS이며 전환경 무오류/저장 테스트 통과가 아니다. 원본 세이브 접근·삭제·덮어쓰기는 하지 않았다.

## 좁은 로그 폭 보완

보상로그 레이아웃을 바꾸지 않고12문장을 단축했다. 기존 theme를 사용하는 Label의 실제 font/font_size로12개 문자열 너비를 측정했다. 첫 검사에서 머루 완료후1문장이171px로 실패하여 다시 단축했다(실패로그 보존). 최종 `npc-greeting-bounds-unit-v2.log`:9 tests/57 asserts PASS, exit0, 문장 너비112~150px로 기존154px 이내. 기존 HUD수학6개 포함. 화면 전체 가독성·3초 읽기 테스트·NPC 실제 신호/완료후 분기 검증은 별도다.

복사본 CSV 재import는 plugin 비활성 상태로 CSV 처리 완료했으나 전역 editor_settings 쓰기오류 뒤 종료가 지연되어 해당 검사 프로세스만 Ctrl-C로 종료했다. 원본 설정/세이브를 수정하지 않았다. 이후 독립 unit를 실행했다. 최종 CSV는 원본과복사본에 동일하고 원본 번역캐시는 다음 정상 Godot import에서 갱신된다(최종 단축 번역의 검사 대상은 복사본에서 실제 재import한 캐시).
