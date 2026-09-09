#!/usr/bin/env python3
"""sfxr_synth.py — jsfxr/sfxr 호환 파라미터(JSON, "oldParams" 정규화 0~1 스키마)를
받아 44.1kHz 16bit mono WAV를 생성하는 순수 Python 포트.

용도: 《이슬란드 연대기》 자체 저작 SFX(docs/audio/sound-map-m1.md §10, §11).
      Ninja Adventure/Kenney 등 외부 CC0 팩에 의미가 정확히 겹치는 사운드가 없을 때
      사용 — 출력 WAV는 이 스크립트가 파라미터로부터 새로 합성한 것이므로 프로젝트
      자체 저작물이다(외부 샘플을 자르거나 재생하지 않음).

의존성: 표준 라이브러리만 사용(random, math, struct, wave, json, argparse).
        numpy는 이 환경에 없어(ModuleNotFoundError 확인) 의도적으로 배제 —
        생성 루프가 상태(엔벌로프·필터·비브라토)를 프레임마다 갱신해야 해서
        어차피 파이썬 루프이며, 사운드 길이가 짧아(<2초) 벡터화 이득이 적다.

재현성: JSON에 "seed"(정수) 키를 넣으면 그 시드로 로컬 random.Random을 만들어
        노이즈 파형·리시드가 필요한 지점에 사용한다 — 같은 JSON은 항상 같은 WAV를
        만든다(비결정적 요소 없음).

알고리즘 출처: DrPetter의 원조 sfxr 및 그 공개 포트(jsfxr/bfxr 계열)에 널리 쓰이는
        "oldParams" 필드 이름과 생성 순서(주파수 슬라이드→아르페지오→엔벌로프→
        LP/HP 필터→페이저→8배 오버샘플링)를 그대로 재현한 재구현이다. 외부
        코드를 복사하지 않고 알려진 신호 흐름만 참고해 이 프로젝트를 위해
        새로 작성했다.

사용법:
    python3 tools/audio/sfxr_synth.py tools/audio/sfxr/just_guard_parry_ting.json \
        game/assets/audio/sfx/just_guard_parry_ting.wav

    # sfxr/ 안의 모든 json을 한 번에 재생성(파일명.json -> 파일명.wav)
    python3 tools/audio/sfxr_synth.py --all tools/audio/sfxr game/assets/audio/sfx
"""

from __future__ import annotations

import argparse
import json
import math
import random
import struct
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 44100
OVERSAMPLING = 8  # 앨리어싱 완화(원조 sfxr과 동일하게 8배 슈퍼샘플 후 다운믹스)
MAX_SECONDS = 4.0  # 무한 루프 방지 안전장치(엔벌로프가 절대 안 끝나는 파라미터 실수 대비)
LIMITER_CEILING_DB = -1.0  # audio-spec.md §1 Master 버스 리미터(ceiling -1dB)와 동일 사상:
                            # 이 합성기도 출력 피크를 -1dBFS 밑으로 눌러 클리핑을 방지한다.

DEFAULTS = {
    "oldParams": True,
    "wave_type": 0,       # 0=square 1=sawtooth 2=sine 3=noise
    "p_env_attack": 0.0,
    "p_env_sustain": 0.3,
    "p_env_punch": 0.0,
    "p_env_decay": 0.4,
    "p_base_freq": 0.3,
    "p_freq_limit": 0.0,
    "p_freq_ramp": 0.0,
    "p_freq_dramp": 0.0,
    "p_vib_strength": 0.0,
    "p_vib_speed": 0.0,
    "p_arp_mod": 0.0,
    "p_arp_speed": 0.0,
    "p_duty": 0.0,
    "p_duty_ramp": 0.0,
    "p_repeat_speed": 0.0,
    "p_pha_offset": 0.0,
    "p_pha_ramp": 0.0,
    "p_lpf_freq": 1.0,
    "p_lpf_ramp": 0.0,
    "p_lpf_resonance": 0.0,
    "p_hpf_freq": 0.0,
    "p_hpf_ramp": 0.0,
    "sound_vol": 0.5,
    "seed": 0,
}


def _clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else (hi if v > hi else v)


def load_params(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    p = dict(DEFAULTS)
    p.update(raw)
    return p


def synthesize(p: dict) -> list[float]:
    """파라미터 dict -> -1.0..1.0 범위 float 샘플 리스트(모노, 44.1kHz)."""
    rng = random.Random(int(p.get("seed", 0)))

    wave_type = int(p["wave_type"])

    # --- 주파수 슬라이드 ---
    period0 = 100.0 / (p["p_base_freq"] ** 2 + 0.001)
    maxperiod = 100.0 / (p["p_freq_limit"] ** 2 + 0.001)
    slide0 = 1.0 - (p["p_freq_ramp"] ** 3) * 0.01
    dslide0 = -(p["p_freq_dramp"] ** 3) * 0.000001

    fperiod = period0
    fslide = slide0
    fdslide = dslide0

    # --- 듀티(사각파 폭) 슬라이드 ---
    square_duty = 0.5 - p["p_duty"] * 0.5
    square_slide = -p["p_duty_ramp"] * 0.00005

    # --- 아르페지오 ---
    if p["p_arp_mod"] >= 0.0:
        arp_mod = 1.0 - (p["p_arp_mod"] ** 2) * 0.9
    else:
        arp_mod = 1.0 + (p["p_arp_mod"] ** 2) * 10.0
    arp_limit0 = 0 if p["p_arp_speed"] == 1.0 else int((1.0 - p["p_arp_speed"]) ** 2 * 20000 + 32)
    arp_time = 0
    arp_limit = arp_limit0

    # --- 비브라토 ---
    vib_speed = (p["p_vib_speed"] ** 2) * 0.01
    vib_amp = p["p_vib_strength"] * 0.5
    vib_phase = 0.0

    # --- 볼륨 엔벌로프 (0=attack 1=sustain(+punch) 2=decay) ---
    env_length = [
        int(p["p_env_attack"] ** 2 * 100000),
        int(p["p_env_sustain"] ** 2 * 100000),
        int(p["p_env_decay"] ** 2 * 100000),
    ]
    env_length = [max(l, 1) for l in env_length]
    env_punch = p["p_env_punch"]
    env_stage = 0
    env_time = 0

    # --- 로우패스/하이패스 필터 ---
    fltw0 = (p["p_lpf_freq"] ** 3) * 0.1
    fltw_d = 1.0 + p["p_lpf_ramp"] * 0.0001
    fltdmp = 5.0 / (1.0 + (p["p_lpf_resonance"] ** 2) * 20.0) * (0.01 + fltw0)
    fltdmp = min(fltdmp, 0.8)
    lpf_on = p["p_lpf_freq"] != 1.0
    fltw = fltw0
    fltp = 0.0
    fltdp = 0.0

    flthp = (p["p_hpf_freq"] ** 2) * 0.1
    flthp_d = 1.0 + p["p_hpf_ramp"] * 0.0003
    fltphp = 0.0
    fltpp = 0.0  # 직전 fltp 값(하이패스는 fltp의 '변화량'을 누설 적분한다 — 원신호를
                 # 그대로 누적하면 DC 게인이 1/flthp까지 치솟아 폭주하므로 반드시 차분해야 함

    # --- 페이저(짧은 딜레이 라인 콤) ---
    fphase = (p["p_pha_offset"] ** 2) * 1020.0
    if p["p_pha_offset"] < 0.0:
        fphase = -fphase
    fdphase = (p["p_pha_ramp"] ** 2) * 1.0
    if p["p_pha_ramp"] < 0.0:
        fdphase = -fdphase
    iphase = abs(int(fphase))
    phaser_buffer = [0.0] * 1024
    ipp = 0

    # --- 리피트(재트리거) ---
    rep_limit = 0 if p["p_repeat_speed"] == 0.0 else int((1.0 - p["p_repeat_speed"]) ** 2 * 20000 + 32)
    rep_time = 0

    # --- 파형 위상/노이즈 버퍼 ---
    phase = 0
    noise_buffer = [rng.uniform(-1.0, 1.0) for _ in range(32)]

    sound_vol = p["sound_vol"]

    out: list[float] = []
    max_samples = int(SAMPLE_RATE * MAX_SECONDS)

    while len(out) < max_samples:
        # 리피트: 주기적으로 엔벌로프·주파수 슬라이드를 초기값으로 되돌려
        # 짧게 재트리거되는 "뽁뽁"류 다중 펄스를 만든다.
        rep_time += 1
        if rep_limit != 0 and rep_time >= rep_limit:
            rep_time = 0
            fperiod = period0
            fslide = slide0
            fdslide = dslide0
            env_stage = 0
            env_time = 0
            arp_time = 0
            arp_limit = arp_limit0

        # 아르페지오: 한 번(또는 리피트마다 한 번) 주파수를 점프시킨다.
        arp_time += 1
        if arp_limit != 0 and arp_time >= arp_limit:
            arp_limit = 0
            fperiod *= arp_mod

        # 주파수 슬라이드 적용
        fslide += fdslide
        fperiod *= fslide
        if fperiod > maxperiod:
            fperiod = maxperiod
            if p["p_freq_limit"] > 0.0:
                break  # 주파수 하한 컷오프로 사운드 종료(로우 사이렌 등)

        rfperiod = fperiod
        if vib_amp > 0.0:
            vib_phase += vib_speed
            rfperiod = fperiod * (1.0 + math.sin(vib_phase) * vib_amp)

        iperiod = int(rfperiod)
        if iperiod < OVERSAMPLING:
            iperiod = OVERSAMPLING

        # 듀티 슬라이드
        square_duty = _clamp(square_duty + square_slide, 0.0, 0.5)

        # 볼륨 엔벌로프 갱신
        env_time += 1
        if env_time > env_length[env_stage]:
            env_time = 0
            env_stage += 1
            if env_stage == 3:
                break
        if env_stage == 0:
            env_vol = env_time / env_length[0]
        elif env_stage == 1:
            env_vol = 1.0 + (1.0 - env_time / env_length[1]) * 2.0 * env_punch
        else:
            env_vol = 1.0 - env_time / env_length[2]

        # 페이저 위상
        fphase += fdphase
        iphase = int(_clamp(abs(int(fphase)), 0, 1023))

        if flthp_d != 0.0:
            flthp = _clamp(flthp * flthp_d, 0.00001, 0.1)

        ssample = 0.0
        for _ in range(OVERSAMPLING):
            sample = 0.0
            phase += 1
            if phase >= iperiod:
                phase %= iperiod
                if wave_type == 3:
                    noise_buffer = [rng.uniform(-1.0, 1.0) for _ in range(32)]

            fp = phase / iperiod
            if wave_type == 0:  # square
                sample = 0.5 if fp < square_duty else -0.5
            elif wave_type == 1:  # sawtooth
                sample = 1.0 - fp * 2.0
            elif wave_type == 2:  # sine
                sample = math.sin(fp * 2.0 * math.pi)
            else:  # noise
                sample = noise_buffer[int(phase * 32 / iperiod) % 32]

            # 로우패스(1차 IIR + 댐핑 — 원조 sfxr과 동일한 "슬루 리미터"형 LPF)
            fltw = _clamp(fltw * fltw_d, 0.0, 0.1)
            if lpf_on:
                fltdp += (sample - fltp) * fltw
                fltdp -= fltdp * fltdmp
                fltp += fltdp
            else:
                fltp = sample
                fltdp = 0.0

            # 하이패스(1차 차분기 + 누설 적분 = 안정적인 HPF). fltp를 그대로 누적하면
            # DC 게인이 1/flthp까지 치솟아 폭주하므로 반드시 fltp의 변화량(차분)만 적분한다.
            fltphp += fltp - fltpp
            fltpp = fltp
            fltphp -= fltphp * flthp
            hp_sample = fltphp if p["p_hpf_freq"] > 0.0 else fltp

            # 페이저(짧은 순환 버퍼 딜레이 콤)
            phaser_buffer[ipp & 1023] = hp_sample
            hp_sample += phaser_buffer[(ipp - iphase + 1024) & 1023]
            ipp = (ipp + 1) & 1023

            ssample += hp_sample

        ssample = (ssample / OVERSAMPLING) * env_vol * sound_vol
        out.append(ssample)

    return out


def _apply_ceiling(samples: list[float], ceiling_db: float = LIMITER_CEILING_DB) -> list[float]:
    """audio-spec.md §1 Master 리미터(ceiling -1dB)와 같은 사상의 안전 리미터.
    피크가 천장을 넘을 때만 전체를 다운스케일한다(조용한 사운드를 억지로 키우지 않음)."""
    if not samples:
        return samples
    peak = max(abs(s) for s in samples)
    if peak <= 0.0:
        return samples
    ceiling_lin = 10 ** (ceiling_db / 20.0)
    if peak > ceiling_lin:
        gain = ceiling_lin / peak
        return [s * gain for s in samples]
    return samples


def write_wav(path: Path, samples: list[float], sample_rate: int = SAMPLE_RATE) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    samples = _apply_ceiling(samples)
    frames = bytearray()
    for s in samples:
        s = _clamp(s, -1.0, 1.0)
        frames += struct.pack("<h", int(s * 32767))
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16bit
        wf.setframerate(sample_rate)
        wf.writeframes(bytes(frames))


def render_one(json_path: Path, wav_path: Path) -> tuple[int, float, float]:
    params = load_params(json_path)
    samples = _apply_ceiling(synthesize(params))
    write_wav(wav_path, samples)
    duration = len(samples) / SAMPLE_RATE
    peak = max((abs(s) for s in samples), default=0.0)
    return len(samples), duration, peak


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src", help="sfxr 파라미터 JSON 파일 또는 (--all 사용 시) JSON이 든 디렉터리")
    ap.add_argument("dst", help="출력 WAV 파일 또는 (--all 사용 시) 출력 디렉터리")
    ap.add_argument("--all", action="store_true", help="src 디렉터리의 모든 *.json을 dst 디렉터리에 동명 .wav로 일괄 생성")
    args = ap.parse_args()

    if args.all:
        src_dir = Path(args.src)
        dst_dir = Path(args.dst)
        json_files = sorted(src_dir.glob("*.json"))
        if not json_files:
            print(f"[sfxr_synth] 경고: {src_dir}에 json이 없습니다.", file=sys.stderr)
        for jf in json_files:
            wav_path = dst_dir / (jf.stem + ".wav")
            n, dur, peak = render_one(jf, wav_path)
            peak_db = 20 * math.log10(peak) if peak > 0 else float("-inf")
            print(f"{jf.name} -> {wav_path} ({n} samples, {dur:.3f}s, peak {peak_db:.2f} dBFS)")
    else:
        jf = Path(args.src)
        wav_path = Path(args.dst)
        n, dur, peak = render_one(jf, wav_path)
        peak_db = 20 * math.log10(peak) if peak > 0 else float("-inf")
        print(f"{jf.name} -> {wav_path} ({n} samples, {dur:.3f}s, peak {peak_db:.2f} dBFS)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
