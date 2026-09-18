# 플레이어 방향 매핑 및 전투 회귀검증

2026-09-12 · Godot 4.4.1 · 로컬 브랜치 stage/astra-cq-redesign-01

## 수정

기존 Knight 시트의 열은 방향(아래 x=0, 위 x=16, 왼쪽 x=32, 오른쪽 x=48), 행 y=0/16/32/48은 걷기 시간 프레임이다. 기존 씬과 과거 테스트가 이를 반대로 해석하여 걷는 중 방향이 바뀌었다. Player.tscn과 smoke_sprite_axis.gd를 함께 수정했다.

y=64의 네 그림도 방향별 단일 공격 포즈다. 방향별 1프레임, speed=3, loop=false로 설정하여 기존 4/12초 공격 길이를 유지했다. 신규 6프레임 공격 제작 완료를 의미하지 않는다.

전투 테스트에서 첫 피격 시 없는 메타데이터를 읽는 hit_flash.gd 오류를 발견했다. has_meta 확인 후 기존 Tween을 조회하도록 수정했다.

## 결과

| 검사 | 결과 |
|---|---|
| SmokeSpriteAxis | 종료 코드 0. 4방향 걷기·대기·공격 atlas, 공격 길이 검사 통과 |
| SmokePlayerKillsSlime 재검증 (--fixed-fps 60) | 종료 코드 0. 슬라임 2타 처치, 999→964의 3타 피해량, 공격 종료 후 무기 숨김 통과. 로그에 ERROR/FAIL 없음 |
| test_player_facing + test_hitstop_overlap (--fixed-fps 60) | 17/17 테스트, 31 assertions 통과 |

고정 FPS 없는 첫 GUT 실행은 17개 중 1개가 실패했다. 0.05초 hitstop을 2프레임 뒤 검사하는 시간 의존 테스트였으며, 동일 소스를 --fixed-fps 60으로 재실행해 통과했다. 모든 환경에서 무조건 통과한다고 해석하지 않는다.

초기 editor import 실행은 종료 코드 1이었다. 후속 씬/테스트 실행은 성공했으나 전체 깨끗한 import 통과로 보고하지 않는다. 기존 데이터의 LUK/INT cap 경고는 이번 수정 범위 밖이다.

실행 로그: 저장소 상위 reviews/games-2026-09-12/runtime의 sprite-axis.log, combat-smoke-recheck.log, gut-motion-fixed.log. 새 외형의 실제 게임 적용·사람의 플레이 검증·전체 테스트 스위트는 포함하지 않는다.

## 재실행

저장소 루트에서 Godot 4.4.1 실행파일을 godot으로 지정한다.

```powershell
godot --headless --path game res://tests/smoke/SmokeSpriteAxis.tscn --quit-after 120
godot --headless --fixed-fps 60 --path game res://tests/smoke/SmokePlayerKillsSlime.tscn --quit-after 400
godot --headless --fixed-fps 60 --path game -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_facing.gd,res://tests/unit/test_hitstop_overlap.gd -gexit
```
