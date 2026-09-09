# 오디오 스펙 — 버스·크로스페이드·우선순위·드랍·설정 연동·AudioManager

> 기준 문서: `docs/GDD-도트액션RPG-기획안.md` 10장(사운드)·11장(UI·접근성)·6장(아이템 등급)
> 데이터 원본: `docs/audio/sound-map-m1.md` (이벤트→파일 매핑, 이 문서는 배선·시스템 규칙만 다룬다)
> 소유: game-designer(본 문서). 구현은 godot-engineer — 이 문서는 구현 명세이지 구현 자체가 아니다(`game/` 미수정).

---

## 1. Godot 오디오 버스 구성

`game/`에 버스 레이아웃 리소스(`default_bus_layout.tres`)가 아직 없다 — godot-engineer가 아래 5버스 구조로 신규 생성.

```
Master
 ├─ BGM       (지역/전투 테마)
 ├─ SFX       (전투·상호작용 원샷)
 ├─ UI        (메뉴 커서/확인/취소)
 └─ Ambient   (환경음 루프 — 바람·강물 등, M1은 미사용이나 구조 선반영)
```

| 버스 | 기본 볼륨(dB) | 이펙트 | 용도 |
|---|---|---|---|
| Master | 0 | **Limiter**(ceiling -1dB, soft-knee) | 다수 히트 동시 재생 시 클리핑 방지 — 전투 SFX가 겹쳐도 왜곡 없이 뭉개지도록 |
| BGM | -8 | 없음(루프 스트림이라 이펙트 불필요) | `sound-map-m1.md` §9 지역/전투 테마 |
| SFX | -3 | 없음 | `sound-map-m1.md` §1~§5, §7, §10, §11 대부분 |
| UI | -6 | 없음 | `sound-map-m1.md` §8 |
| Ambient | -14 | Low-pass(선택, 실내/동굴 진입 시 필터 조여 톤 다운 — M2) | M1 미사용, 버스만 선반영(향후 우기·바람 루프) |

- 각 사운드 고유 `volume_db`(sound-map의 값)는 버스 페이더 **위에 추가**로 적용된다(합산). 예: `hit_normal`(-4dB) 재생 시 실제 출력 ≈ Master(0) + SFX(-3) + 사운드 고유(-4) = -7dB 상당.
- Limiter는 Master에만 건다 — 버스별로 걸면 SFX 폭주 시 BGM까지 같이 눌려 "덕킹처럼 들리는 의도치 않은 부작용"이 생긴다.

---

## 2. BGM 크로스페이드 규칙

### 2-1. 구현 방식 — 핑퐁 2-플레이어
`AudioManager`는 BGM 버스에 `AudioStreamPlayer` 2개(`_bgm_a`, `_bgm_b`)를 두고 매번 재생 안 하는 쪽으로 다음 트랙을 미리 로드·재생 시작한 뒤 볼륨을 크로스페이드한다(둘 다 같은 프레임에 동시 재생 상태). Equal-power(코사인) 커브 사용 — 선형 크로스페이드는 중간 지점에서 체감 음량이 살짝 꺼지는 것처럼 들린다.

```
t = clamp(elapsed / fade_sec, 0, 1)
out_player.volume_db = linear_to_db(cos(t * PI/2))       # 나가는 트랙
in_player.volume_db  = linear_to_db(sin(t * PI/2))       # 들어오는 트랙
```

### 2-2. 지역 전환 — 1.5초
- 트리거: `Events.region_entered(region_id)`.
- `AudioManager`가 `region_id → bgm_id` 매핑(`sound-map-m1.md` §9, M1 유일 매핑: `greenfield_prototype → "bgm_grassland_1"`)을 조회해 `play_bgm(bgm_id, 1.5)` 호출.
- 같은 지역 재진입(동일 `region_id` 연속 emit) 시 **크로스페이드 스킵**(재생 중인 트랙 유지) — `play_bgm()`이 현재 재생 중인 id와 동일하면 no-op.

### 2-3. 전투 진입/이탈
- M1에는 "전투 시작/종료" 시그널이 없다(`events.gd` 확인 완료 — `enemy_spawned`/`enemy_died`만 존재, 어그로 상태 시그널 없음). **신규 Events 시그널 추가 대신** `AudioManager`가 0.25초 간격 타이머로 `get_tree().get_nodes_in_group(&"monster")`를 순회해 `state`가 `TELEGRAPH`/`ATTACK`/`CHASE`인 개체가 하나라도 있는지 폴링한다(M1 몬스터 수가 한 화면에 소수라 비용 무시 가능; `monster_base.gd`의 `state`는 `_`접두어 없는 공개 var라 외부 조회 가능).
- **전투 진입**(폴링 결과 false→true 전이): `play_bgm("bgm_battle", 0.5)` — 지역 전환(1.5s)보다 빠르게, 위협을 즉시 체감시킨다.
- **전투 이탈**(true→false 전이 후 **3.0초 유예**, 그 사이 다시 true가 되면 유예 취소): 유예 종료 시 `play_bgm(<현재 region_id의 bgm_id>, 2.0)` — 진입보다 느리게 복귀해 "완전히 끝났다"는 확신을 준 뒤 서서히 평온해지는 곡선.
- 유예(3.0초)를 두는 이유: 슬라임이 후딜(`attack_recovery_sec`) 중 잠깐 `CHASE`를 벗어나는 프레임에 즉시 지역 BGM으로 복귀했다가 곧바로 다시 전투 BGM으로 튀는 "깜빡임"을 방지.

### 2-4. 루프 포인트
- 모든 BGM 트랙은 임포트 설정에서 `loop: true`(Godot `.ogg` 임포트 옵션) — Ninja Adventure Musics는 앰비언트 루프용으로 제작된 트랙이라 별도 루프 포인트 지정 없이 파일 끝→처음 루프로 충분(끊김 발생 시 godot-engineer가 페이드 아웃 테일 트리밍 검토).

---

## 3. 동시 재생 상한과 우선순위

### 3-1. 버스 전역 상한
| 버스 | 동시 보이스 상한 | 초과 시 |
|---|---|---|
| SFX | 16 | §3-2 우선순위 규칙으로 스틸 |
| UI | 4 | 낮은 우선순위(오래된 것)부터 즉시 컷 |
| BGM | 2 (핑퐁 구조 고정) | 해당 없음(크로스페이드 설계상 항상 2 이하) |
| Ambient | 4 | M1 미사용 |

### 3-2. 우선순위 티어 (숫자가 낮을수록 우선)
| 티어 | 이벤트 | 스틸 규칙 |
|---|---|---|
| 0 | 플레이어 피격/사망, 저스트 가드 성공 | 항상 재생, 필요 시 1~3티어 보이스를 스틸 |
| 1 | 플레이어 공격 임팩트(일반/강공격/크리), 공격 휘두름 | 0티어에는 밀리지만 2~3티어는 스틸 |
| 2 | 몬스터 예고/공격/피격/사망 | 0~1티어에 밀림, 3티어 스틸 가능 |
| 3 | UI, 비석, 드랍 사운드 등 비전투 원샷 | 상한 도달 시 새 재생 자체를 드롭(스틸하지 않음 — 이 티어끼리 경쟁 시 그냥 최신 것만 재생) |

- 스틸 대상 선정: 같은 버스에서 **현재 재생 중인 보이스 중 가장 낮은 우선순위(숫자 큰 쪽)의 가장 오래된 것**부터.
- `sound-map-m1.md`에 명시된 이벤트별 보이스 상한(예: `hit_normal` 4보이스)은 위 버스 전역 상한(16)보다 **먼저** 적용되는 세부 제한이다 — 이벤트별 상한에 걸리면 버스 전역 상한 이전에 이미 스틸/드롭이 일어난다.

---

## 4. 등급별 드랍 사운드 차별화 규칙

GDD 6.1의 6개 등급(일반/고급/희귀/영웅/전설/유물)과 GDD 10장 "등급별 아이템 드랍 사운드 차별화, 전설 드랍 = 전용 효과음 + 빛기둥"을 다음 3원칙으로 구현한다. 파일 매핑은 `sound-map-m1.md` §11(6종 전부 `tools/audio/sfxr_synth.py` 자체 저작 완료, `game/data/audio_sfx.json`에 `drop_common`..`drop_relic` 반영 완료 — `item_drop.gd:_play_drop_sfx()`가 이미 grade→id 직접 호출을 구현해 두어 테이블만 채우면 바로 재생된다).

1. **낮은 등급일수록 짧고 겹쳐도 무해하게**: 일반/고급은 동일 계열 사운드(피치만 미세 차이)로 파밍 스팸(몬스터 다수 처치 시 드랍 폭주)에도 청감 피로가 없게 한다. 볼륨도 가장 낮게(-8dB대).
2. **등급이 오를수록 레이어 추가, 볼륨·지속시간 증가**: 희귀(단일 사운드, -5dB) → 영웅(2레이어, -2dB) → 전설(전용 사운드+스파클 레이어, 0dB, 지속시간 가장 김).
3. **전설만 "전용"**: `legendary_drop_sparkle`(sound-map §10-3)은 다른 어떤 이벤트에도 재사용하지 않는다 — GDD가 명시적으로 "전용 효과음"을 요구하는 유일한 등급이므로, 이 원칙을 어기면(예: 다른 곳에 재사용) 전설의 특별함이 희석된다. 유물은 GDD가 전용 사운드를 요구하지 않으므로 M1 시점엔 전설과 동일 계열 재사용(§11 표 참고, 결정 요청 대상).
- **빛기둥 연동(시각)**: 전설 드랍의 빛기둥 이펙트는 pixel-artist/godot-engineer 소관(본 문서 범위 밖)이나, 오디오 재생 시점은 **빛기둥 스폰과 동일 프레임**이어야 한다 — `Events.item_dropped` 구독 시점에 `rarity == &"legendary"`면 SFX와 VFX를 같은 콜백에서 트리거하도록 구현 지점을 통일할 것을 권장.
- **레이어 2차 호출 필요(godot-engineer 전달)**: `item_drop.gd:_play_drop_sfx()`는 현재 grade당 `AudioManager.play_sfx()`를 1회만 호출한다. 영웅(`drop_epic`+`drop_epic_layer`)과 전설(`drop_legendary`+`legendary_drop_sparkle`)은 정의상 2레이어이므로, 해당 grade 분기에서 기본 id 재생 직후 레이어 id를 추가 호출해야 실제로 겹쳐 들린다(`sound-map-m1.md` §12 갱신 항목).
- **볼륨 표**: 일반 -9dB / 고급 -8dB / 희귀 -5dB / 영웅 -2dB / 전설 0dB / 유물 0dB(전설과 동일, 위 결정 요청 전까지).

---

## 5. 볼륨 설정 연동 (`settings.json`, D-64 소유 — ui-ux-designer)

`settings.json`이 아직 이 저장소에 없다(D-64는 ui-ux-designer 담당, 미착수). 본 절은 **AudioManager가 기대하는 계약(contract)**을 먼저 명시해 두어, D-64 구현 시 아래 키를 그대로 채택하거나 game-designer에게 변경을 알리도록 한다.

### 5-1. 기대 스키마 (제안, D-64 확정 전까지 잠정)
```jsonc
{
  "audio": {
    "master_volume": 1.0,   // 0.0~1.0 선형
    "bgm_volume": 1.0,
    "sfx_volume": 1.0,
    "ui_volume": 1.0,
    "ambient_volume": 1.0
  }
}
```

### 5-2. 연동 방식
- `Events.settings_changed(key, value)`가 이미 `events.gd`에 선언돼 있다 — D-64 구현체가 이 시그널로 볼륨 변경을 알리면(예: `key = &"audio.sfx_volume"`), `AudioManager`가 구독해 해당 버스에 반영한다.
- 선형(0~1) → dB 변환은 `AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clampf(value, 0.0001, 1.0)))`. `0.0`을 그대로 `linear_to_db`에 넣으면 `-inf`가 아니라 오류가 나므로 `value <= 0.0001`이면 `AudioServer.set_bus_mute(bus_idx, true)`로 처리(뮤트와 "매우 작은 볼륨"을 구분).
- **접근성 화면 흔들림 배율**(`SCREEN_SHAKE_LEVELS`, `combat-tuning-m1-addendum.md` §3-3)과 오디오 볼륨은 서로 다른 축이다 — 흔들림 배율은 시각 접근성(멀미) 문제이고 오디오 볼륨은 청감 선호 문제이므로 같은 슬라이더로 묶지 않는다. 다만 둘 다 D-64가 소유하는 설정 화면 안에 함께 노출될 가능성이 높으므로, `settings.json` 최상위 스키마에서 `audio.*`와 `accessibility.screen_shake_level`처럼 네임스페이스를 분리해 둘 것을 제안.

---

## 6. godot-engineer 구현 명세 — `AudioManager` 오토로드

### 6-1. 등록
`project.godot` `[autoload]`에 `AudioManager="*res://scripts/core/audio_manager.gd"` 추가(기존 `Data`/`Tuning`/`Events`/`GameState` 패턴과 동일 위치).

### 6-2. 데이터 원본
`sound-map-m1.md`의 표를 그대로 `game/data/audio_sfx.json` + `game/data/audio_bgm.json`(또는 단일 `audio_map.json`, `data_tables.md` 컨벤션에 맞춰 godot-engineer가 스키마 확정)로 옮겨 `Data` 오토로드로 로드 — 코드에 파일 경로·dB·피치 범위를 하드코딩하지 않는다(GDD 12장 원칙). 각 항목 키:

```jsonc
"hit_normal": {
  "files": ["res://.../Hit1.wav", "res://.../Hit2.wav", "res://.../Hit3.wav"],
  "bus": "SFX",
  "volume_db": -4.0,
  "pitch_min": 0.92,
  "pitch_max": 1.08,
  "max_voices": 4,
  "cooldown_sec": 0.0,
  "priority": 1
}
```

### 6-3. API

```gdscript
## id: audio_sfx.json 키. position: Vector2.INF(기본값)면 논포지셔널(2D 감쇠 없음,
## UI·전역 이벤트용) — 그 외 값이면 해당 좌표에 AudioStreamPlayer2D를 스폰(전투·월드 SFX).
## pitch_var: -1.0(기본, 테이블의 pitch_min~max 범위 사용) 또는 호출부가 직접 범위를
## 좁히고 싶을 때(예: §1 피니셔의 축소된 변주) ±비율로 override.
## 반환: 실제로 재생을 시작한 AudioStreamPlayer(2D) 또는 null(우선순위 밀려 드롭됨, §3-2).
func play_sfx(id: StringName, position: Vector2 = Vector2.INF, pitch_var: float = -1.0) -> Node:
	pass

## id: audio_bgm.json 키. fade: 크로스페이드 시간(초). 현재 재생 중인 id와 동일하면
## no-op(§2-2). id가 빈 문자열(&"")이면 무음으로 페이드아웃(정지 없이 볼륨만 내림).
func play_bgm(id: StringName, fade: float = 1.5) -> void:
	pass

## 전투 진입/이탈 폴링 결과에 따라 내부에서 play_bgm(region 또는 battle id, ...)을
## 호출하는 사적 함수(§2-3) — 외부에 노출할 필요는 없으나 시그니처는 구현 편의상 기록.
func _poll_combat_state() -> void:
	pass
```

### 6-4. 스폰되는 `AudioStreamPlayer2D`의 `process_mode`
`sound-map-m1.md` "히트스톱 동기화 총칙"과 §5 "슬라임 사망" 주의사항 재확인: `play_sfx()`가 스폰하는 노드는 **`process_mode = Node.PROCESS_MODE_ALWAYS`로 명시 설정**하고 씬 트리 루트(또는 전용 `SfxPool` 컨테이너)의 자식으로 붙인다. 피격 대상(부모가 될 뻔한 노드)의 `process_mode`가 `PROCESS_MODE_DISABLED`(히트스톱)로 바뀌거나 `queue_free()`(몬스터 사망)되어도 재생 중인 사운드가 끊기지 않도록 하기 위함이다.

### 6-5. Events 구독 vs 직접 호출
`sound-map-m1.md` §12 표를 그대로 따른다 — 안전하게 전역 구독 가능한 것은 `Events.just_guard_succeeded`, `Events.player_stamina_insufficient`, `Events.player_died`, `Events.player_respawned`, `Events.item_dropped`, `Events.region_entered`뿐이다. 타격 임팩트·가드 칩데미지·슬라임 계열·비석은 페이로드 부족(강공격 여부 등) 또는 전용 호출부 문제로 **호출부 코드에 직접 `AudioManager.play_sfx(...)` 삽입**이 필요하다. `AudioManager._ready()`에서의 구독 목록과 각 스크립트 내 직접 호출 목록을 명확히 분리해 구현할 것.

### 6-6. 검증 체크리스트 (godot-engineer 자체 확인용)
- [ ] 접근성 볼륨 0(뮤트) 상태에서 전투 20초 플레이 시 콘솔에 오디오 관련 에러(`-inf dB` 등) 없음
- [ ] 슬라임 3마리 동시 사망 시 SFX 보이스 상한(4, sound-map §5)에 걸려도 크래시 없이 드롭만 발생
- [ ] 지역 재진입(같은 비석 왕복) 시 BGM 크로스페이드가 매번 다시 트리거되지 않음(§2-2 no-op 확인)
- [ ] 히트스톱 중(화면 정지 0.05~0.1초) 타격음이 끊기지 않고 정상 재생됨(§6-4)
