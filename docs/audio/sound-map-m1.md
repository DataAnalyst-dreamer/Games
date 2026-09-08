# 사운드 맵 — M1

> 기준 문서: `docs/GDD-도트액션RPG-기획안.md` 10장(사운드)·4.2장(타격감)·7.2장(지역 정체성)
> 수치 근거: `docs/specs/combat-tuning-m1.md`(§2 콤보, §6 히트스톱·넉백), `docs/specs/combat-tuning-m1-addendum.md`(§2 피격 스턴·무적, §3 카메라 셰이크)
> 이벤트 기준: `game/scripts/core/events.gd` (시그널 목록) + 실제 호출부(`game/scripts/player/*.gd`, `game/scripts/entities/monster_base.gd`, `game/scripts/systems/hit_feel.gd`, `game/scripts/world/waystone.gd`) — 이 문서를 쓰기 위해 위 스크립트를 읽고 실제 훅 지점을 §12에 정리했다.
> 라이선스: 아래 파일은 전부 `docs/art/LICENSES.md`에 이미 반입 완료로 기록된 CC0 팩(Ninja Adventure, Kenney) 소속. 신규 반입 없음.
> 소유: game-designer(본 문서, 수치·매핑). 구현(AudioManager 배선, 코드 훅 삽입)은 godot-engineer.

---

## 0. 표기 규칙

**경로 축약** (실제 경로 = 접두사 + 파일명):

| 축약 | 실제 경로 |
|---|---|
| `NA/Sounds/` | `game/assets/third_party/ninja_adventure/Audio/Sounds/` |
| `NA/Musics/` | `game/assets/third_party/ninja_adventure/Audio/Musics/` |
| `NA/Jingles/` | `game/assets/third_party/ninja_adventure/Audio/Jingles/` |
| `KEN/impact/` | `game/assets/third_party/kenney/audio/impact_sounds/Audio/` |
| `KEN/rpg/` | `game/assets/third_party/kenney/audio/rpg_audio/Audio/` |
| `KEN/ui/` | `game/assets/third_party/kenney/audio/ui_audio/Audio/` |

**볼륨**: `AudioStreamPlayer(2D).volume_db` 값(버스 페이더 적용 전, 이 사운드 고유 오프셋). 버스 자체 기본 dB는 `audio-spec.md` §1.
**피치 변주**: `pitch_scale`에 곱하는 랜덤 범위. `1.0±0%`는 변주 없음(정체성이 중요한 UI·잔재 사운드).
**재생 규칙**: 중첩 허용 여부(동시 보이스 상한)·쿨다운(최소 재발동 간격)·풀에서 임의 선택 여부.
**풀(pool)**: 여러 파일을 나열한 항목은 재생 시마다 그중 하나를 무작위 선택(반복 피로 방지, "손맛" 다양성).

### 히트스톱 동기화 총칙 (모든 타격 계열 SFX 공통)

> `combat-tuning-m1-addendum.md` §2, `combat-tuning-m1.md` §6-1 근거: 히트스톱은 플레이어→몬스터, 몬스터→플레이어 **양방향**에 걸리고(`hit_feel.gd`의 `Hitstop.apply_to(nodes_to_freeze, ...)`), 몬스터 일반 공격이 플레이어에 적중할 때도 0.05초 히트스톱이 걸린다.
>
> **규칙**: 타격 SFX는 `Hitstop.apply_to(...)` 호출과 **같은 프레임**(가능하면 그 호출 직전)에 재생한다. `Hitstop`은 `process_mode`를 `PROCESS_MODE_DISABLED`로 바꿔 노드의 `_process`/`_physics_process`/애니메이션만 멈추고 `AudioStreamPlayer` 노드나 오디오 하드웨어 클록에는 영향을 주지 않으므로(`game/scripts/systems/hitstop.gd` 참고), 재생을 시작해 두면 화면이 멈춘 순간에도 소리는 정상 재생된다 — 화면이 얼어붙기 전에 소리가 이미 나고 있어야 "즉시 느껴짐"(GDD 4.2 원칙 1)이 성립한다.
> **주의**: `AudioManager.play_sfx()`로 스폰하는 `AudioStreamPlayer2D`의 `process_mode`가 부모(피격 노드)를 상속해 `PROCESS_MODE_INHERIT`이면 부모가 멈출 때 재생도 같이 멈출 위험이 있다 — godot-engineer는 스폰되는 플레이어의 `process_mode`를 `PROCESS_MODE_ALWAYS`로 명시 설정할 것 (`audio-spec.md` §6에도 명시).
>
> 카메라 셰이크(피격/강공격/크리 티어)는 반대로 **히트스톱 해제 직후** 시작한다(addendum §3-2) — SFX는 히트스톱과 동시, 셰이크는 히트스톱 다음이라는 두 타이밍을 혼동하지 않는다.

---

## 1. 전투 — 플레이어 공격 휘두름

콤보 1·2타는 가볍게, 3타(피니셔)는 무겁게 — 배율([1.0, 1.0, 1.5], `combat-tuning-m1.md` §4-1)에 맞춘 청감 곡선.

| 이벤트 | 트리거(파일:함수) | 파일 | 볼륨(dB) | 피치 변주 | 재생 규칙 |
|---|---|---|---|---|---|
| 공격 1타 휘두름 | `player/states/attack.gd:_start_current_hit()`(`hit_index==1`) | 풀: `NA/Sounds/Whoosh & Slash/Slash.wav`, `Slash4.wav` | -8 | 0.95–1.05× | 중첩 2보이스, 쿨다운 없음(콤보 버퍼 0.2s가 자연 간격) |
| 공격 2타 휘두름 | 동일(`hit_index==2`) | 풀: `NA/Sounds/Whoosh & Slash/Slash2.wav`, `Slash5.wav` | -7 | 0.95–1.05× | 동일 |
| 공격 3타(피니셔) 휘두름 | 동일(`hit_index==3`, `is_finisher`) | `NA/Sounds/Whoosh & Slash/Slash3.wav` (고정, 풀 아님) + 레이어 `NA/Sounds/Whoosh & Slash/Whoosh.wav`(-14dB, 저음 보강) | -4 | 0.97–1.03× (변주 축소 — 피니셔는 항상 같은 무게감) | 중첩 1보이스(직전 스윙음과 겹치면 컷) |

---

## 2. 전투 — 타격 판정 (공용 임팩트, `HitFeel.apply()`)

`game/scripts/systems/hit_feel.gd`의 `HitFeel.apply()`는 플레이어→몬스터, 몬스터→플레이어 **양방향** 히트를 전부 통과하는 유일한 지점이다(`hitbox.is_heavy`·원소 상성(`is_advantage`)·`defender_body`·`hitbox.source`가 모두 여기서 확정됨) — 타격 임팩트 사운드는 여기 한 곳에 훅을 걸면 방향에 무관하게 전부 커버된다. 방향별·주체별 "추가 레이어"(플레이어가 맞았을 때의 신음/슬라임이 맞았을 때의 찐득함)는 §3·§5에서 별도로 더한다.

| 이벤트 | 트리거 | 파일 | 볼륨(dB) | 피치 변주 | 재생 규칙 |
|---|---|---|---|---|---|
| 타격 적중 — 일반 (`hitbox.is_heavy == false`) | `hit_feel.gd:apply()`, `Hitstop.apply_to()` 호출과 동시 | 풀: `NA/Sounds/Hit & Impact/Hit1.wav`, `Hit2.wav`, `Hit3.wav` | -4 | 0.92–1.08× | 중첩 4보이스, 쿨다운 없음 |
| 타격 적중 — 강공격/3타 피니셔 (`hitbox.is_heavy == true`) | 동일 | 풀: `NA/Sounds/Hit & Impact/Hit6.wav`, `Hit7.wav` | 0 | 0.95–1.05× | 중첩 2보이스, 쿨다운 없음 |
| 타격 적중 — 크리티컬(확장 노트) | 동일, `is_advantage == true`일 때 위 소리에 레이어 추가 | 레이어: `NA/Sounds/Bonus/PowerUp1.wav` (-6dB, 강공격/일반 사운드 위에 얹음) | — | 1.0± 0% | 강공격/일반과 동시 재생(별도 보이스) |

> **코드 주의(godot-engineer 확인 필요)**: `hit_feel.gd`가 `Events.hit_landed.emit(hitbox.source, defender_body, damage, is_advantage)`로 emit하는 4번째 인자는 `events.gd` 시그널 선언상 `is_critical`이지만 실제 값은 **원소 상성 적중 여부(`is_advantage`)**다. M1에는 LUK 기반 진짜 크리티컬 시스템이 없으므로 이 문서의 "크리티컬" 사운드는 현재 코드베이스 기준 **원소 상성 적중**에 반응한다. 진짜 크리 시스템(M2, LUK 스탯)이 들어오면 별도 플래그로 분리해야 하며, 그 전까지는 이 사운드가 "상성 적중 피드백"과 "미래 크리 피드백"을 겸한다 — 의도적 임시 처리다.
> **구현 지점**: `Events.hit_landed.emit(...)` 라인 앞뒤로 `AudioManager.play_sfx(...)` 호출 추가를 권장(Events 구독이 아니라 직접 호출 — `hitbox.is_heavy`가 시그널 페이로드에 없어 구독만으로는 티어를 구분할 수 없음, §12 참고).

---

## 3. 전투 — 피격/방어 (플레이어 관점)

| 이벤트 | 트리거(파일:함수) | 파일 | 볼륨(dB) | 피치 변주 | 재생 규칙 |
|---|---|---|---|---|---|
| 피격(일반 피해, 가드 아님) | `player.gd:_apply_full_hit()` | 풀: `NA/Sounds/Hit & Impact/Impact.wav`, `Impact2.wav`, `Impact3.wav` | -3 | 0.9–1.1× | 중첩 불필요(피격 무적 0.5s가 자연 쿨다운) |
| 가드 중 피격(칩데미지 통과) | `player.gd:_handle_guarded_hit()` | 풀: `NA/Sounds/Hit & Impact/Impact4.wav`, `Impact5.wav` | -6 | 0.95–1.05× | 중첩 없음(직전 소리 컷), 쿨다운 없음 |
| 저스트 가드 성공 | `player.gd:_handle_just_guard()` | **§10 미충족 — sfxr 필요.** 임시 대체: `NA/Sounds/Bonus/Bonus2.wav` | -2 | 1.0±0% | 중첩 1보이스 |
| 스태미나 고갈(구르기/가드 발동 실패) | `Events.player_stamina_insufficient` (roll.gd, state.gd, player.gd 3곳에서 emit) | **§10 미충족 — sfxr 필요.** 임시 대체: `NA/Sounds/Alert/Alert4.wav` | -6 | 1.0±0% | **디바운스 0.3초**(버튼 연타 시 소리 난사 방지) |

> 저스트 가드·스태미나 고갈은 "임시 대체" 파일로 즉시 재생 가능하지만, 기존 팩의 다른 용도(경고/UI 취소)와 의미가 겹쳐 정체성이 약하다 — §10에서 전용 sfxr 사운드를 정의한다.

---

## 4. 회피

| 이벤트 | 트리거(파일:함수) | 파일 | 볼륨(dB) | 피치 변주 | 재생 규칙 |
|---|---|---|---|---|---|
| 구르기 발동 | `player/states/roll.gd:enter()` (스태미나 소모 성공 직후) | `NA/Sounds/Whoosh & Slash/Whoosh2.wav` | -10 | 0.95–1.05× | 중첩 1보이스(연속 구르기 시 직전 소리 컷) |

---

## 5. 몬스터 — 슬라임 (M1 유일 구현 몬스터)

`game/scripts/entities/monster_base.gd`의 상태머신(`State.TELEGRAPH/ATTACK/HURT/DEAD`) 훅에 배선. 뿔토끼·버섯돌이는 M1 코드에 아직 없으므로 이번 문서 범위 밖 — 동일 훅 패턴(`_start_telegraph_flash`/`_fire_hitbox`/`_on_hurtbox_hurt`/`_play_death`)을 그대로 재사용할 수 있음을 참고용으로 남긴다.

| 이벤트 | 트리거(파일:함수) | 파일 | 볼륨(dB) | 피치 변주 | 재생 규칙 |
|---|---|---|---|---|---|
| 슬라임 예고(점멸 시작) | `monster_base.gd:_start_telegraph_flash()` | `NA/Sounds/Alert/Alert.wav` | -8 | 1.0±0%(예고는 매번 동일해야 학습 가능) | 중첩 4보이스(슬라임 여러 마리 동시 예고), 쿨다운 없음 |
| 슬라임 공격 실행 | `monster_base.gd:_fire_hitbox()` (`State.ATTACK` 진입) | `NA/Sounds/Elemental/Bubble2.wav` | -6 | 0.9–1.1× | 중첩 4보이스 |
| 슬라임 피격(생존) | `monster_base.gd:_on_hurtbox_hurt()`, `hp > 0` 분기(`State.HURT` 진입) | 풀: `NA/Sounds/Jump & Bounce/Bounce2.wav`, `Bounce3.wav` | -5 | 0.9–1.15× (개체별 통통 튀는 다양성) | 중첩 6보이스(전역 SFX 보이스 상한, `audio-spec.md` §3) |
| 슬라임 사망(터짐) | `monster_base.gd:_play_death()` (tween 시작과 동시, `queue_free` 전) | `NA/Sounds/Elemental/Bubble.wav` | -3 | 0.85–0.95× (평소보다 낮게 → "큰 거품이 터짐" 체감) | 중첩 4보이스, 쿨다운 없음 |

> **주의**: `_play_death()` 종료 시 노드가 `queue_free()`되므로, 자식 `AudioStreamPlayer2D`로 재생하면 소리가 끊긴다. `AudioManager.play_sfx(id, global_position)`가 몬스터 씬 트리 바깥(전역 SFX 풀)에 독립 재생 노드를 스폰해야 한다 — `audio-spec.md` §6 API 설계에 반영.

---

## 6. 플레이어 생사

| 이벤트 | 트리거 | 파일 | 볼륨(dB) | 피치 변주 | 재생 규칙 |
|---|---|---|---|---|---|
| 플레이어 사망 | `Events.player_died` (전역 구독 가능 — 페이로드 불필요, `player.gd:_die()`가 emit) | `NA/Jingles/GameOver1.wav` | -2 | 1.0±0% | 단일 보이스. **BGM 즉시 -12dB 덕킹**(사망 연출 1.0초, `DEATH_RESPAWN_DELAY_SEC`) 후 부활 시 원복 |
| 플레이어 부활 | `Events.player_respawned` (전역 구독, `player.gd:respawn()`이 emit) | `NA/Jingles/Success2.wav` | -4 | 1.0±0% | 단일 보이스, BGM 덕킹 해제와 동시 |

---

## 7. 월드 — 비석(워프/부활)

| 이벤트 | 트리거(파일:함수) | 파일 | 볼륨(dB) | 피치 변주 | 재생 규칙 |
|---|---|---|---|---|---|
| 비석 활성화 | `game/scripts/world/waystone.gd:_play_activation_feedback()` (색 변경 tween과 동시) | `NA/Sounds/Magic & Skill/Fx.wav` | -5 | 1.0±0% | 단일 보이스, 재활성화(재상호작용) 시에도 재생 허용 |

> `events.gd`에는 비석 전용 시그널이 없다 — `Waystone.activate()`가 유일한 호출부이므로 Events 확장 없이 `_play_activation_feedback()`에 직접 호출 추가로 충분하다(§12).

---

## 8. UI (선반영 — M1 시점 메뉴 시스템 미구현)

GDD 11장 UI(인벤토리·메뉴 커서 이동)는 M1 로드맵 범위 밖이라 `events.gd`에도 커서 이동/확인/취소를 쏘는 호출부가 아직 없다. 아래는 **자산만 선지정**해 두는 것 — 실제 배선은 UI 시스템 착수 시.

| 이벤트 | 파일 | 볼륨(dB) | 피치 변주 | 재생 규칙 |
|---|---|---|---|---|
| UI 커서 이동 | `NA/Sounds/Menu/Move1.wav` | -12 | 1.0±0% | 디바운스 0.05초(연타/연속 포커스 변경 시) |
| UI 확인 | `NA/Sounds/Menu/Accept1.wav` | -10 | 1.0±0% | 단일 보이스 |
| UI 취소 | `NA/Sounds/Menu/Cancel.wav` | -10 | 1.0±0% | 단일 보이스 |

---

## 9. BGM 후보

크로스페이드 규칙(지역 전환 1.5s, 전투 진입/이탈)은 `audio-spec.md` §2. 여기서는 후보곡만 확정.

| 용도 | 후보 | 근거(목가풍 판단) |
|---|---|---|
| 초원(하틀랜드, `region_id: greenfield_prototype`) 메인 BGM 후보 1 | `NA/Musics/31 - Sunny.ogg` | 밝은 톤, "시작의 땅" 튜토리얼 분위기에 가장 부합 — **1순위 추천** |
| 초원 BGM 후보 2 | `NA/Musics/33 - Calm Village.ogg` | 마을(민들레 마을) 장면 전환 시 자연스러운 톤 다운 |
| 초원 BGM 후보 3 | `NA/Musics/5 - Peaceful.ogg` | 필드 탐험 구간(전투 없이 이동) 대체 루프, 후보 1과 번갈아 재생해 반복 피로 완화 |
| 전투 진입 전환 BGM | `NA/Musics/17 - Fight.ogg` | 슬라임 어그로 시 크로스페이드 전환 대상. 대안: `34  - Fight.ogg`(파일명에 공백 2칸 — 원본 그대로, 동명 변주곡. 보스전 등 후속 확장용으로 남겨둠) |

> 최종 선곡(실제 청음 비교)은 audio-wrangler 청음 검토 없이 제목·팩 성격만으로 1차 필터링한 결과다 — godot-engineer/기획 재생 확인 후 순위 조정 가능.

---

## 10. 미충족 이벤트 — sfxr 파라미터 정의 (3건)

기존 CC0 팩에 "의미가 정확히 겹치지 않는" 3개 이벤트. 아래는 jsfxr 호환 파라미터 JSON(정규화 0~1 값, `wave_type`: 0=사각파 1=톱니파 2=사인파 3=노이즈)이며, **파일 생성은 다음 단계**(본 세션은 인라인 정의만, `tools/audio/sfxr/<이름>.json`으로 저장 예정).

### 10-1. `stamina_exhausted_deny` — 스태미나 고갈 전용 "안 돼" 신호
현재 임시 대체(Alert4.wav)는 슬라임 예고(Alert.wav류)와 같은 계열이라 "적이 나를 봤다"와 "내가 자원이 없다"가 청감상 혼동될 수 있다. 짧고 낮은 2음 하강 블립으로 명확히 분리.

```json
{
  "oldParams": true,
  "wave_type": 0,
  "p_env_attack": 0.0,
  "p_env_sustain": 0.05,
  "p_env_punch": 0.1,
  "p_env_decay": 0.15,
  "p_base_freq": 0.28,
  "p_freq_limit": 0.0,
  "p_freq_ramp": -0.35,
  "p_freq_dramp": 0.0,
  "p_duty": 0.4,
  "p_duty_ramp": 0.0,
  "p_repeat_speed": 0.0,
  "p_lpf_freq": 0.6,
  "p_lpf_ramp": 0.0,
  "p_lpf_resonance": 0.2,
  "p_hpf_freq": 0.0,
  "p_hpf_ramp": 0.0,
  "sound_vol": 0.4
}
```

### 10-2. `just_guard_parry_ting` — 저스트 가드 성공 전용 금속성 "쨍"
현재 임시 대체(Bonus2.wav)는 일반 보상 사운드라 GDD가 요구하는 "완벽 방어" 순간의 날카로운 강조가 약하다. 짧고 밝은 고음 핑(square + 짧은 파장 리버스 스윕)으로 구분.

```json
{
  "oldParams": true,
  "wave_type": 0,
  "p_env_attack": 0.0,
  "p_env_sustain": 0.08,
  "p_env_punch": 0.35,
  "p_env_decay": 0.25,
  "p_base_freq": 0.62,
  "p_freq_limit": 0.0,
  "p_freq_ramp": 0.15,
  "p_freq_dramp": 0.0,
  "p_duty": 0.5,
  "p_duty_ramp": 0.0,
  "p_repeat_speed": 0.0,
  "p_lpf_freq": 1.0,
  "p_lpf_ramp": 0.0,
  "p_lpf_resonance": 0.0,
  "p_hpf_freq": 0.1,
  "p_hpf_ramp": 0.0,
  "sound_vol": 0.45
}
```

### 10-3. `legendary_drop_sparkle` — 전설 등급 드랍 전용 반짝임 레이어 (M2 예고, `audio-spec.md` §4 연동)
GDD 10장 "전설 드랍 = 전용 효과음 + 빛기둥"의 "전용" 요건을 만족시키는 것이 목적. `NA/Jingles/Secret1.wav`(전설 드랍 베이스 팡파레, 기존 파일로 충분)에 위에 얹는 짧은 상승 아르페지오 스파클 레이어 — 사인파 기반, 다른 어떤 이벤트에도 재사용하지 않는 전설 전용 텍스처.

```json
{
  "oldParams": true,
  "wave_type": 2,
  "p_env_attack": 0.02,
  "p_env_sustain": 0.2,
  "p_env_punch": 0.2,
  "p_env_decay": 0.4,
  "p_base_freq": 0.45,
  "p_freq_limit": 0.0,
  "p_freq_ramp": 0.25,
  "p_freq_dramp": 0.05,
  "p_vib_strength": 0.15,
  "p_vib_speed": 0.4,
  "p_arp_mod": 0.3,
  "p_arp_speed": 0.6,
  "p_duty": 0.5,
  "p_duty_ramp": 0.0,
  "p_repeat_speed": 0.0,
  "p_lpf_freq": 1.0,
  "p_lpf_ramp": 0.0,
  "p_lpf_resonance": 0.0,
  "p_hpf_freq": 0.05,
  "p_hpf_ramp": 0.0,
  "sound_vol": 0.35
}
```

---

## 11. 확장 참고 — 등급별 드랍 사운드 (M2 예고)

`game/data/drop_tables.json`이 아직 없어(`combat-tuning-m1-addendum.md` §6) M1 구현 대상은 아니지만, `Events.item_dropped(item_id, world_position, rarity)`가 이미 `events.gd`에 선언돼 있으므로 사운드 자산만 미리 지정해 둔다. 등급 6종은 GDD 6.1 표(색상 포함) 그대로. `rarity` StringName 값(`common`/`uncommon`/`rare`/`epic`/`legendary`/`relic`)은 아직 `items.json`이 없어 game-designer 제안값 — M2 스키마 확정 시 재검토. 상세 차별화 규칙(빛기둥 등 시각 연동 포함)은 `audio-spec.md` §4.

| 등급(GDD 6.1) | `rarity` 제안값 | 파일 | 비고 |
|---|---|---|---|
| 일반(흰) | `common` | `NA/Sounds/Bonus/Coin.wav` | |
| 고급(초록) | `uncommon` | `NA/Sounds/Bonus/Coin2.wav` | 일반과 거의 동일 톤(파밍 스팸 방지, 미세 피치 차이만) |
| 희귀(파랑) | `rare` | `NA/Sounds/Bonus/Bonus.wav` | |
| 영웅(보라) | `epic` | `NA/Sounds/Bonus/Bonus3.wav` + `NA/Sounds/Bonus/Gold2.wav` 레이어 | |
| **전설(주황)** | `legendary` | `NA/Jingles/Secret1.wav` + **`legendary_drop_sparkle`(§10-3, 전용)** | 유일하게 "전용 효과음"을 갖는 등급 — GDD 10장 명시 요구사항 |
| 유물(붉은 금색) | `relic` | `NA/Jingles/Secret2.wav`(임시, 전설과 동일 계열) | GDD 10장은 유물 전용 사운드를 명시하지 않음 — 전설과 차별화할지는 결정 요청 대상(M2, 유물 콘텐츠 착수 시) |

---

## 12. `events.gd` 확장/직접 호출 요청 사항 (godot-engineer 전달)

M1 코드를 읽고 실제 훅 지점을 확인한 결과, 아래는 **Events 시그널 신규 추가가 필요 없는** 항목(직접 호출로 충분)과 **주의가 필요한** 항목을 구분한 목록이다. `game/`은 직접 수정하지 않으므로 아래는 요청 사항으로만 남긴다.

| 이벤트 | 권장 배선 방식 | 이유 |
|---|---|---|
| 타격 임팩트(§2) | `hit_feel.gd:apply()` 안에서 직접 호출 | `Events.hit_landed`에는 `hitbox.is_heavy`가 없어(§2 코드 주의 참고) 신호 구독만으로 강공격/일반을 구분할 수 없음 |
| 가드 중 피격(§3) | `player.gd:_handle_guarded_hit()` 안에서 직접 호출 | `Events.player_damaged`는 일반 피격과 가드 칩데미지를 구분하지 않고 동일 시그널로 emit됨(코드 확인 완료) — 구독만으로는 두 케이스를 가를 수 없음 |
| 저스트 가드 성공(§3) | `Events.just_guard_succeeded` 구독 가능 | 이 시그널은 페이로드(`defender`, `attacker`)만으로 충분 — 유일하게 안전하게 구독 가능한 전투 이벤트 |
| 스태미나 고갈(§3) | `Events.player_stamina_insufficient` 구독 | 페이로드(`action`)로 향후 roll/guard_hit별 사운드 분리 가능(현재는 동일 사운드) |
| 슬라임 예고/공격/피격/사망(§5) | `monster_base.gd`의 각 상태 진입 함수에서 직접 호출 | 몬스터 전용 이벤트라 전역 Events에 없음(의도된 설계 — 몬스터마다 다른 사운드 세트를 가지므로 전역 시그널화는 오히려 결합도만 늘림) |
| 플레이어 사망/부활(§6) | `Events.player_died` / `Events.player_respawned` 구독 | 페이로드 불필요, 안전하게 구독 가능 |
| 비석 활성화(§7) | `waystone.gd:_play_activation_feedback()` 안에서 직접 호출 | 전용 시그널 없음, 호출부가 유일해 신호 추가 실익 없음 |

**코드 주의 재확인(§2와 동일 항목, 반복 강조)**: `events.gd`의 `hit_landed(attacker, target, damage, is_critical)` 시그니처와 실제 emit(`hit_feel.gd`)이 넘기는 값(`is_advantage`, 원소 상성)이 이름과 다르다. 오디오 구현 시점에 게임 디자인팀 확인 없이 이름만 보고 "진짜 크리티컬"로 오해하지 않도록 이 문서와 결정 요청 목록에 남긴다.

---

## 13. 요약

- **파일로 매핑된 이벤트**: 19건 (§1~§8, UI 3건 포함 · sfxr 대기 2건 제외)
- **sfxr 필요(미충족) 이벤트**: 3건 (§10 — 저스트 가드 성공, 스태미나 고갈, 전설 드랍 전용 레이어) — 모두 임시 대체 파일 지정 완료, 즉시 플레이 가능
- **BGM 후보**: 4곡 (초원 목가풍 3 + 전투 전환 1)
- **godot-engineer 전달 사항**: §12 배선 권장표 7건, §2 코드 네이밍 불일치 1건
