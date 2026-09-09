# 자체 저작 SFX 합성기 (`sfxr_synth.py`)

`docs/audio/sound-map-m1.md` §10·§11 기준 — 기존 CC0 팩(Ninja Adventure, Kenney)에 의미가 정확히 겹치는 사운드가 없는 이벤트를 위해, jsfxr/sfxr 호환 파라미터(JSON)로부터 WAV를 직접 합성한다. **출력 WAV는 파라미터로부터 새로 만든 파형이므로 프로젝트 자체 저작물**이다(외부 샘플 편집이 아님) — `docs/art/LICENSES.md` "자체 제작 SFX" 행 참고.

## 요구사항
표준 라이브러리만 사용(`random`/`math`/`struct`/`wave`/`json`/`argparse`). numpy는 허용되나 이 스크립트는 쓰지 않는다(합성 루프가 프레임마다 엔벌로프·필터 상태를 갱신해야 해서 벡터화 이득이 적고, 사운드가 짧아 순수 파이썬 루프로도 충분히 빠르다).

## 사용법

단일 파일:
```bash
python3 tools/audio/sfxr_synth.py tools/audio/sfxr/just_guard_parry_ting.json \
    game/assets/audio/sfx/just_guard_parry_ting.wav
```

`tools/audio/sfxr/*.json` 전체를 `game/assets/audio/sfx/`에 동명 `.wav`로 일괄 재생성(파라미터를 고쳤을 때 이 명령 하나로 전부 다시 만든다):
```bash
python3 tools/audio/sfxr_synth.py --all tools/audio/sfxr game/assets/audio/sfx
```

출력은 항상 **44.1kHz 16bit mono WAV**이며, 각 JSON의 `"seed"` 정수 값으로 결정적으로 재현된다(같은 JSON → 항상 같은 WAV 바이트).

## 파라미터 스키마 (`oldParams` 정규화 0~1)
jsfxr/sfxr와 동일한 필드명을 쓴다 — `wave_type`(0=square 1=sawtooth 2=sine 3=noise), `p_env_attack/sustain/punch/decay`, `p_base_freq`, `p_freq_limit/ramp/dramp`, `p_vib_strength/speed`, `p_arp_mod/speed`, `p_duty/duty_ramp`, `p_repeat_speed`, `p_pha_offset/ramp`, `p_lpf_freq/ramp/resonance`, `p_hpf_freq/ramp`, `sound_vol`. 생략한 키는 `DEFAULTS`(무음에 가까운 안전값)로 채워진다. `_comment`는 스크립트가 무시하는 문서용 키.

**리피트(`p_repeat_speed`) 주의**: 0이 아니면 주기적으로 엔벌로프·주파수를 초기화해 재트리거한다("뽁뽁" 다중 펄스에 유용) — 단, 엔벌로프 총 길이(attack+sustain+decay 샘플 수)가 리피트 주기보다 **짧아야** 정상 종료한다. 더 길면 사운드가 끝나기 직전 매번 리셋되어 사실상 무한 재생된다(안전장치로 `MAX_SECONDS=4.0`에서 강제 종료하지만, 의도한 소리가 아니게 된다) — 새 파라미터를 추가할 때 `--all` 실행 후 길이가 기대보다 훨씬 길면(수 초) 이 상호작용을 의심할 것.

## 출력 안전장치 — 소프트 리미터
`docs/audio/audio-spec.md` §1의 Master 버스 리미터(ceiling -1dB)와 같은 사상으로, 합성된 샘플의 피크가 -1dBFS를 넘으면 전체를 다운스케일해 절대 클리핑되지 않게 한다(조용한 소리를 억지로 키우지는 않음 — 피크가 이미 -1dBFS 밑이면 그대로 둔다).

## 현재 파라미터 목록 (`tools/audio/sfxr/*.json` → `game/assets/audio/sfx/*.wav`)

| 파일 | 용도 | 근거 |
|---|---|---|
| `just_guard_parry_ting.json` | 저스트 가드 성공 "쨍" | sound-map-m1.md §10-2 |
| `stamina_exhausted_deny.json` | 스태미나 고갈 "안 돼" | sound-map-m1.md §10-1 |
| `legendary_drop_sparkle.json` | 전설 드랍 전용 반짝임 레이어(다른 이벤트 재사용 금지) | sound-map-m1.md §10-3, audio-spec.md §4 규칙 3 |
| `drop_common.json` ~ `drop_relic.json` | 등급별 드랍 "뽁뽁" 6종(등급이 오를수록 음 높이·길이·비브라토 증가) | sound-map-m1.md §11, audio-spec.md §4 |
| `drop_epic_layer.json` | 영웅 등급 2번째 레이어(사인 트윙클) | audio-spec.md §4 원칙 2 |
| `goblin_whistle.json` | 고블린 정찰 호루라기(M2-3 몬스터 확장 예고, M1 코드에 훅 없음) | M2-3 선반영 |
| `blacksmith_enhance_success.json` | 대장간 강화 성공(모루 타격+밝은 2음 상승) | sound-map-m1.md §13, `blacksmith_menu.gd:788` |
| `blacksmith_enhance_fail.json` | 대장간 강화 실패(둔탁+하강, 페널티 최소화 톤) | sound-map-m1.md §13, `blacksmith_menu.gd:791` |
| `blacksmith_refine_roll.json` | 대장간 재련 굴림(구슬 굴림/찰칵) | sound-map-m1.md §13, `blacksmith_menu.gd:814` |
| `blacksmith_salvage_complete.json` | 대장간 분해 완료(노이즈 파쇄음) | sound-map-m1.md §13, `blacksmith_menu.gd:913` |
| `blacksmith_craft_complete.json` | 대장간 제작 완료(사인파 완성 팡파레) | sound-map-m1.md §13, `blacksmith_menu.gd:936` |
| `mailbox_claim_chime.json` | 우편함 수령(짧은 종이/벨) — 선반영, `mailbox_popup.gd` 미배선 | sound-map-m1.md §13 |

## 재생성 검증
생성 직후 길이·피크·무음 여부를 확인하려면(표준 라이브러리 `wave` 모듈만 사용):
```bash
python3 - <<'PY'
import wave, struct, math, glob, os
for f in sorted(glob.glob("game/assets/audio/sfx/*.wav")):
    with wave.open(f, 'rb') as wf:
        n, sr = wf.getnframes(), wf.getframerate()
        samples = struct.unpack('<%dh' % n, wf.readframes(n))
    peak = (max(abs(s) for s in samples) / 32768.0) if samples else 0.0
    peak_db = 20*math.log10(peak) if peak > 0 else float('-inf')
    print(f"{os.path.basename(f):32} {n/sr:7.3f}s  {peak_db:7.2f} dBFS")
PY
```
