# 오디오 자원·호출 정적 감사 — 2026-09-13

본게임 freeze 유지. 새 음원 생성/선정/다운로드, 데이터·볼륨·AudioManager·기존 GUT 수정 없음. **정적 자원 검사이지 실제 청취·전투 모션 동기·믹스 승인·법률 검토가 아니다.**

## 수행 및 결과

기존 `game/tests/unit/test_audio_manager.gd`는 데이터 로드/필수키/ResourceLoader 존재/버스/핵심 이벤트를 검사한다. 이를 삭제하거나 중복 대체하지 않고, 그 안의 핵심 이벤트 목록을 읽어 재사용하는 외부 보완 검사기 [validate_audio_assets.py](../../tools/qa/validate_audio_assets.py)를 추가했다. Godot/import/user 저장을 실행하지 않으므로 현재 엔진 종료 AV와 분리된다.

```powershell
python tools/qa/validate_audio_assets.py
python -m unittest discover -s tools/qa -p test_validate_audio_assets.py -v
```

- 현재 자료: **SFX 이벤트37 / BGM2 / 파일 참조48 / 중복 제외 실파일48**. WAV46개 PCM 헤더·채널/샘플크기/양수 주파수/프레임수/실제 데이터 길이 검사, OGG2개 OggS/Vorbis 식별자 검사. 누락0. OGG 전체 디코딩·정상 루프는 검사하지 않았다.
- JSON 중복키 거부, 이벤트 ID 형식, res://경계·파일 존재, 실제 버스 레이아웃의 이름, 유한 volume, 양수 순서 pitch, 비음수 cooldown, 정수 voice 상한/priority 검사 PASS(exit0). volume은 유한성만 검사하며 청감 적정 수치를 새로 정하지 않는다. voice 상한은 기존 명세 SFX16/UI4/BGM2/Ambient4를 **개별 설정 유효성**에 이용할 뿐 전역 믹서 상한 구현을 인증하지 않는다.
- Mutation tests: **7개 테스트 메서드 PASS(exit0)**. 그중 필드 오염 테스트의 11 subcase는 버스/NaN볼륨/역전·0피치/음수쿨다운/0·과대보이스/범위밖우선순위/빈파일/경계탈출/파일누락을 각각 거부한다. 핵심 이벤트 삭제, 중복 JSON키, WAV 훼손, 동적 드랍6개, 직접 호출 삭제 검출도 포함한다.
- 첫 검사기 실행에서 GUT 목록 추출이 `audio_sfx` 테이블 이름까지 이벤트로 오인한 실패와 Rarity.KEYS를 배열로 가정한 누락을 발견했다. 원본 데이터가 아닌 검사기 파서를 실제 `for id` 목록/등급 Dictionary에 맞춰 수정했고, 추출 실패 시 통과하지 않는 조건과 드랍6개 회귀검사를 추가했다. 현재 PASS는 보완 후 결과다.

## 호출 누락과 기획 TODO 구분

1. 현재 `game/scripts`의 직접 문자열 SFX 호출24종은 모두 테이블에 존재한다. 동적 등급 `Rarity.KEYS` 6종도 `drop_*` 매핑이 모두 있다. 슬라임 기본4종까지 합하면34종이며, 나머지 UI 일반3종(`ui_cursor_move/ui_confirm/ui_cancel`)은 테이블은 있으나 이 정적 검색에서 재생 호출을 찾지 못했다. 입력 액션 이름 `ui_confirm`과 오디오 재생 호출은 구별했다.
2. `monster_base.gd`의 `%s_telegraph/attack/hurt/death`를 몬스터 데이터7종에 조합하면 슬라임 외 **24개 미배정 후보**가 나온다. 뿔토끼·큰뿔토끼·버섯·고블린 정찰·고블린 대장·뭉치 분열체 각4개다. 모든 상태 경로가 실제 실행되었다는 뜻은 아니다. AudioManager는 미배정 ID를 의도적으로 조용히 null 처리한다고 명시한다. 따라서 파일 손상/런타임 크래시로 분류하지 않고 **전용 음향 제작/배정 미완료**로 남긴다. 고블린 호루라기 별도 `goblin_whistle` 직접 호출은 이미 존재한다.
3. `sound-map-m1.md`/`tools/audio/README.md`에는 드랍 레이어·고블린·우편함이 미배선이라는 과거 기록이 남아 있으나 현재 `item_drop.gd:82,84`, `monster_base.gd:345,350`, `mailbox_popup.gd:127,143`에는 실제 호출이 있다. 대장간의 재련/분해/제작 `_todo: 전용 SFX 미제작` 주석도 현재 파일/매핑과 어긋난다. 오디오 맵 마지막36건 집계는 현재37건과 다르며 BGM 후보4곡과 실제 매핑2곡을 섞지 않는다. 원문 문서를 이번에 임의 수정하지 않았다.
4. `audio-spec.md §3`의 버스 전체 voice cap·priority 기반 stealing은 **현재 AudioManager에 구현 확인되지 않음**: 테이블의 priority를 읽지 않고, `_active_voices`는 이벤트 ID별로만 제한한다. §3의 '직전 소리 컷'과 달리 개별 상한 도달 시 새 요청을 버린다. 데이터 구조 PASS를 이 명세 구현 완료로 보고하면 안 된다. 추가 생산 변경은 root 조율 후 별도 작업이다.
5. BGM은 현재 `greenfield_prototype → bgm_grassland_1` 단일 지역 매핑, 전투 `bgm_battle`이다. 다른 지역 BGM/환경음은 확장 TODO다. 이번 검사로 페이드/동시 요청/정지 재시작/루프 포인트 품질을 검증하지 않았다.

정적 호출 탐색은 GDScript AST 실행 분석이 아닌 현재 단일행 문자열 패턴 검사다. 향후 별칭·래퍼·여러 줄 식으로 호출 형식이 바뀌면 검사기를 보완해야 한다. 동적 후보를 실제 재생 횟수로 집계하지 않는다.

## 출처 기록 확인 (권리 판단 아님)

현재 참조48개는 Ninja Adventure31개와 기존 자체 합성17개다. `docs/art/LICENSES.md`의 Ninja Adventure 반입 행, `game/assets/third_party/ninja_adventure/LICENSE.txt`·README 원문에 CC0 표기 및 제작자/팩 링크가 존재한다. 자체17종은 같은 대장의 기존 자체 제작 행과 `tools/audio/README.md`, `tools/audio/sfxr/*.json` 재생성 원자료를 추적할 수 있다. 외부 샘플의 새 반입은 없다.

Kenney도 기존 오디오 맵에 출처 후보로 기재되어 있으나 이번48개 실제 참조에 Kenney 파일이 있다는 뜻은 아니다. 이 감사는 해당 문서 기록과 로컬 자원 경로의 연결을 확인했을 뿐, '독점권/상용 출시 권리 심사 완료'나 새 라이선스 부여를 하지 않는다. 합성기를 실행해 파형을 다시 만들지 않았다.

## 남은 검수

AudioManager의 headless 경로는 AudioStreamPlayer를 만들지 않는다. SFX는 요청 로그만, BGM은 테이블/스트림 로드 이전에 로그 후 반환하므로 특히 headless BGM 로그만으로 파일 디코딩 성공을 증명할 수 없다. 이번 검사와 별도로 실제 청취, 예고/타격 동일 프레임, 음소거 접근성, 혼잡 시 피로·우선순위, 루프·크로스페이드, 사용자 볼륨을 평가해야 한다. 새 핀/3종 몬스터 모션 리디자인과 동기화도 미완료다.

monsters 독립 DA: 필수 수정0, 7테스트 직접 재실행 통과. 기존 GUT 함수 구조가 바뀔 때 추출기의 IndexError 대신 읽기 쉬운 실패 안내를 주는 개선은 후속으로 남긴다. 현재 정적 감사 범위만 종결하며 실제 청취/재생 품질 검증은 아니다. 신규 산출물은 검사기·mutation test·이 QA 보고서뿐이다.
