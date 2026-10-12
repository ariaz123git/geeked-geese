#!/usr/bin/env python3
"""
gen_audio.py -- procedural SFX synthesis for "Geeked Geese"

Self-contained: numpy + stdlib `wave` only. No external audio libraries,
no sample libraries -- every sound below is built from oscillators,
filtered noise and envelopes.

Run:
    python3 gen_audio.py

Writes 44.1kHz mono 16-bit PCM .wav files into ../audio/ (relative to this
script), then prints a verification table (duration / peak dBFS / RMS dBFS)
and, for every *_loop file, a seam-discontinuity report.
"""

import math
import os
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(1234)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "audio"))
os.makedirs(OUT_DIR, exist_ok=True)


# ============================================================================
# ---------------------------  SYNTH TOOLKIT  -------------------------------
# ============================================================================

def db_to_lin(db):
    return 10.0 ** (db / 20.0)


def lin_to_db(x):
    x = max(float(x), 1e-12)
    return 20.0 * math.log10(x)


def t_axis(n, sr=SR):
    return np.arange(n) / float(sr)


def adsr(n, attack=0.01, decay=0.05, sustain=0.6, release=0.1, sr=SR):
    """Classic ADSR envelope, sample-accurate length `n`."""
    a = max(int(attack * sr), 0)
    d = max(int(decay * sr), 0)
    r = max(int(release * sr), 0)
    s = max(n - a - d - r, 0)
    parts = []
    if a > 0:
        parts.append(np.linspace(0.0, 1.0, a, endpoint=False))
    if d > 0:
        parts.append(np.linspace(1.0, sustain, d, endpoint=False))
    if s > 0:
        parts.append(np.full(s, sustain))
    if r > 0:
        parts.append(np.linspace(sustain, 0.0, r, endpoint=True))
    env = np.concatenate(parts) if parts else np.zeros(0)
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    elif len(env) > n:
        env = env[:n]
    return env


def exp_decay(n, tau, sr=SR, start=1.0):
    """Simple exponential decay envelope, tau in seconds."""
    tt = t_axis(n, sr)
    return start * np.exp(-tt / max(tau, 1e-6))


def one_pole_lowpass(x, cutoff_hz, sr=SR):
    """Constant-cutoff one-pole (6dB/oct) lowpass, recursive."""
    x = np.asarray(x, dtype=np.float64)
    if cutoff_hz <= 0:
        return np.zeros_like(x)
    if cutoff_hz >= sr / 2.0:
        return x.copy()
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / sr)
    y = np.empty_like(x)
    prev = 0.0
    xl = x  # numpy scalar indexing is fine at these lengths
    for i in range(len(xl)):
        prev += alpha * (xl[i] - prev)
        y[i] = prev
    return y


def one_pole_highpass(x, cutoff_hz, sr=SR):
    """Spectral complement of the one-pole lowpass -> one-pole highpass."""
    x = np.asarray(x, dtype=np.float64)
    return x - one_pole_lowpass(x, cutoff_hz, sr)


def bandpass_fft(x, low_hz, high_hz, sr=SR, trans=60.0):
    """Static (whole-buffer) bandpass via FFT masking with raised-cosine
    transition bands, to avoid brickwall ringing."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, d=1.0 / sr)
    lo_edge = np.clip((freqs - (low_hz - trans)) / trans, 0.0, 1.0)
    hi_edge = np.clip(((high_hz + trans) - freqs) / trans, 0.0, 1.0)
    mask = lo_edge * hi_edge
    return np.fft.irfft(X * mask, n)


def soft_clip(x, drive=1.5):
    """tanh soft saturation, normalised so drive doesn't collapse level."""
    d = max(drive, 1e-3)
    return np.tanh(x * d) / math.tanh(d)


def osc(freq_hz, n, sr=SR, shape="sine", phase0=0.0):
    """Fixed-frequency oscillator, `shape` in sine/saw/square/tri."""
    tt = t_axis(n, sr)
    ph = 2 * np.pi * freq_hz * tt + phase0
    return _shape_wave(ph, shape)


def osc_sweep(freq_array, sr=SR, shape="sine", phase0=0.0):
    """Oscillator driven by an instantaneous-frequency array (Hz per sample).
    Phase is the running integral of frequency -> click-free pitch sweeps."""
    freq_array = np.asarray(freq_array, dtype=np.float64)
    ph = 2 * np.pi * np.cumsum(freq_array) / sr + phase0
    return _shape_wave(ph, shape)


def _shape_wave(phase, shape):
    if shape == "sine":
        return np.sin(phase)
    elif shape == "saw":
        frac = (phase / (2 * np.pi)) % 1.0
        return 2.0 * frac - 1.0
    elif shape == "square":
        return np.sign(np.sin(phase))
    elif shape == "tri":
        frac = (phase / (2 * np.pi)) % 1.0
        return 2.0 * np.abs(2.0 * frac - 1.0) - 1.0
    else:
        raise ValueError("unknown shape " + shape)


def harmonic_stack(f0_array, n, k_harm=20, rolloff=1.15, sr=SR):
    """Additive sawtooth-ish harmonic stack driven by an f0 track. Rich,
    buzzy raw material for reedy/nasal vocal timbres."""
    f0_array = np.asarray(f0_array, dtype=np.float64)
    phase = 2 * np.pi * np.cumsum(f0_array) / sr
    k = np.arange(1, k_harm + 1)
    # zero out harmonics that would alias past Nyquist for the loudest part
    nyq_k = sr / 2.0 / max(np.max(f0_array), 1.0)
    weights = 1.0 / (k.astype(np.float64) ** rolloff)
    weights[k > nyq_k] *= 0.0
    harmonics = np.sin(np.outer(k, phase))
    return (weights[:, None] * harmonics).sum(axis=0)


def noise_burst(n, seed_shift=0):
    return rng.uniform(-1.0, 1.0, n)


def stft_sweep(x, cutoff_track, sr=SR, mode="lowpass", bandwidth=1200.0,
               frame_size=1024, hop=256):
    """Time-varying spectral filter via overlap-add STFT masking.
    cutoff_track: array (len == len(x)) of the desired cutoff/center freq
    per output sample. mode: 'lowpass' or 'bandpass'."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    cutoff_track = np.asarray(cutoff_track, dtype=np.float64)
    pad = frame_size
    xp = np.concatenate([np.zeros(pad), x, np.zeros(pad)])
    win = np.hanning(frame_size)
    out = np.zeros(len(xp))
    wsum = np.zeros(len(xp))
    freqs = np.fft.rfftfreq(frame_size, d=1.0 / sr)
    pos = 0
    while pos + frame_size <= len(xp):
        seg = xp[pos:pos + frame_size] * win
        center_sample = pos + frame_size // 2 - pad
        center_sample = min(max(center_sample, 0), n - 1)
        fc = max(float(cutoff_track[center_sample]), 20.0)
        X = np.fft.rfft(seg)
        if mode == "lowpass":
            mask = 1.0 / (1.0 + (freqs / fc) ** 4)
        else:  # bandpass
            half = bandwidth / 2.0
            low = max(fc - half, 1.0)
            high = fc + half
            trans = max(bandwidth * 0.3, 30.0)
            mask = (np.clip((freqs - (low - trans)) / trans, 0, 1) *
                    np.clip(((high + trans) - freqs) / trans, 0, 1))
        Y = X * mask
        seg_out = np.fft.irfft(Y, frame_size)
        out[pos:pos + frame_size] += seg_out * win
        wsum[pos:pos + frame_size] += win ** 2
        pos += hop
    wsum[wsum < 1e-6] = 1e-6
    out = out / wsum
    return out[pad:pad + n]


def mix_into(buf, sig, onset):
    """Add `sig` into `buf` starting at sample `onset`, clipping to bounds."""
    n = len(buf)
    seg = sig
    start = onset
    if start < 0:
        seg = seg[-start:]
        start = 0
    end = min(start + len(seg), n)
    if end <= start:
        return
    buf[start:end] += seg[:end - start]


def modal_burst(n, freqs, amps, decays, sr=SR, noise_amp=0.0,
                 noise_band=(1000, 6000), noise_dur_ms=8):
    """Sum of decaying inharmonic sinusoids (modal synthesis) -> good for
    metallic/wooden/dull impact bodies, plus an optional noise transient."""
    tt = t_axis(n, sr)
    sig = np.zeros(n)
    for f, a, dec in zip(freqs, amps, decays):
        ph = rng.uniform(0, 2 * np.pi)
        sig += a * np.sin(2 * np.pi * f * tt + ph) * np.exp(-tt / dec)
    if noise_amp > 0:
        dur_n = min(int(sr * noise_dur_ms / 1000.0), n)
        if dur_n > 4:
            noise = noise_burst(dur_n)
            noise = bandpass_fft(noise, noise_band[0], noise_band[1], sr=sr)
            env = np.exp(-np.arange(dur_n) / (dur_n * 0.25 + 1))
            sig[:dur_n] += noise * env * noise_amp
    return sig


def transient_click(dur_n, band=(1500, 6000), sr=SR, decay_frac=0.3):
    noise = noise_burst(dur_n)
    filt = bandpass_fft(noise, band[0], band[1], sr=sr)
    env = np.exp(-np.arange(dur_n) / (dur_n * decay_frac + 1))
    return filt * env


def apply_fade(x, fade_in_ms=4.0, fade_out_ms=8.0, sr=SR):
    x = x.copy()
    n = len(x)
    fi = min(int(sr * fade_in_ms / 1000.0), n // 2)
    fo = min(int(sr * fade_out_ms / 1000.0), n // 2)
    if fi > 0:
        x[:fi] *= np.linspace(0.0, 1.0, fi)
    if fo > 0:
        x[-fo:] *= np.linspace(1.0, 0.0, fo)
    return x


def normalize_peak(x, target_dbfs=-3.0):
    peak = np.max(np.abs(x))
    if peak < 1e-9:
        return x
    target_lin = db_to_lin(target_dbfs)
    return x * (target_lin / peak)


def micro_declick(x, n=16):
    """Force the exact wrap-around jump (x[0]-x[-1]) to zero by nudging a
    handful of samples at each edge with a raised-cosine taper. `n` samples
    (well under a millisecond) is inaudible as an added event but guarantees
    a click-free loop regardless of what the stochastic content happens to
    do right at the boundary."""
    x = x.copy()
    n = min(n, len(x) // 2)
    if n <= 0:
        return x
    jump = x[0] - x[-1]
    taper = 0.5 * (1.0 + np.cos(np.linspace(0.0, np.pi, n)))  # 1 -> 0
    x[-n:] += (jump * 0.5) * taper[::-1]
    x[:n] -= (jump * 0.5) * taper
    return x


def seamless_loop(gen_func, loop_seconds, xfade_ms=40.0, sr=SR, **kwargs):
    """Generate `loop_seconds` of seamless audio from a continuous generator
    `gen_func(n, sr=sr, **kwargs)` by synthesising a little extra tail and
    equal-power crossfading that continuation into the loop's start, then
    guaranteeing an exact-zero sample-level wrap discontinuity."""
    xfade_n = int(sr * xfade_ms / 1000.0)
    loop_n = int(sr * loop_seconds)
    total_n = loop_n + xfade_n
    x = gen_func(total_n, sr=sr, **kwargs)
    head = x[:loop_n].copy()
    tail = x[loop_n:loop_n + xfade_n]
    tt = np.linspace(0.0, np.pi / 2.0, xfade_n)
    fade_in = np.sin(tt)
    fade_out = np.cos(tt)
    head[:xfade_n] = head[:xfade_n] * fade_in + tail * fade_out
    head = micro_declick(head, n=16)
    return head


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1.0, 1.0)
    data = (x * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


# ---- .import sidecars, for the ambience beds only --------------------------
#
# CLAUDE.md says never hand-write a `.import`. `tools/gen_music.py` is the one
# sanctioned exception and this is the second, for the same reason and for one
# more that gen_music.py got wrong.
#
#   compress/mode=0 is PCM. Godot's wav default is 2 = QOA, which is lossy and
#   resets its predictor per frame. On a loop whose wrap we have made
#   sample-exact that is a coin flip on an audible tick every time round.
#   Measured on the shipped assets: swim_loop.wav is 176,400 bytes of PCM that
#   imports to a 35,720-byte QOA blob.
#
#   edit/loop_mode=2 is FORWARD. The importer's enum is
#   "Detect From WAV, Disabled, Forward, Ping-Pong, Backward", so 0 means
#   "detect" (and our wavs carry no smpl chunk, so: off) and 1 means DISABLED.
#   gen_music.py writes 1 believing it to be forward; verified by loading
#   mus_mall_base.wav in a booted project, which reports loop_mode=0. The music
#   only loops because music.gd::_stream() forces LOOP_FORWARD at runtime.
#   `Sfx._configure_loop_if_needed()` now does the same for these beds, so this
#   file and that one are belt and braces rather than a single point of failure.
#
# No [remap] path/uid is written: NEVER invent a uid. Godot fills both in on
# `--import` and honours the [params] block we set here.
IMPORT_TMPL = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://audio/{name}.wav"

[params]

force/8_bit=false
force/mono=true
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""


def write_import(path, name):
    with open(path, "w") as f:
        f.write(IMPORT_TMPL.format(name=name))


# ============================================================================
# ------------------------  SOUND DEFINITIONS  ------------------------------
# ============================================================================

REGISTRY = []  # (name, np.float64 array, is_loop bool)


def add_sound(name, arr, is_loop=False, fade_in_ms=4.0, fade_out_ms=8.0,
              target_dbfs=-3.0):
    arr = np.asarray(arr, dtype=np.float64)
    if is_loop:
        # NEVER fade a loop -- that would break the seam we just built.
        arr = normalize_peak(arr, target_dbfs)
    else:
        arr = apply_fade(arr, fade_in_ms, fade_out_ms)
        arr = normalize_peak(arr, target_dbfs)
    REGISTRY.append((name, arr, is_loop))


# ---- shared goose vocal identity ------------------------------------------
GOOSE_F1 = (950.0, 1350.0)     # formant 1 band (spec: ~1.0-1.3kHz)
GOOSE_F2 = (2200.0, 2700.0)    # formant 2 band (spec: ~2.4kHz center)


def make_honk(n, f_start, f_peak, f_end, k_harm=22, rolloff=1.1,
              drive=1.4, noise_amt=0.18, growl_hz=0.0, growl_depth=0.0,
              attack_frac=0.10, sag_k=3.0, sr=SR):
    tt = t_axis(n, sr)
    attack_n = max(int(n * attack_frac), 8)
    remain_n = n - attack_n
    rise = f_start + (f_peak - f_start) * (1 - np.exp(-4.0 * np.linspace(0, 1, attack_n)))
    sag = f_end + (f_peak - f_end) * np.exp(-sag_k * np.linspace(0, 1, remain_n))
    f0 = np.concatenate([rise, sag])
    # tiny buzzy wobble -- reedy/kazoo-like character
    f0 = f0 * (1.0 + 0.012 * np.sin(2 * np.pi * 32.0 * tt))

    raw = harmonic_stack(f0, n, k_harm=k_harm, rolloff=rolloff, sr=sr)
    f1 = bandpass_fft(raw, *GOOSE_F1, sr=sr)
    f2 = bandpass_fft(raw, *GOOSE_F2, sr=sr)
    body = raw * 0.25 + f1 * 1.0 + f2 * 0.55

    amp = adsr(n, attack=0.006, decay=0.05, sustain=0.72, release=0.10, sr=sr)
    if growl_depth > 0:
        amp = amp * (1.0 + growl_depth * np.sin(2 * np.pi * growl_hz * tt))
        amp = np.clip(amp, 0, None)

    sig = body * amp
    sig = soft_clip(sig, drive=drive)

    # breath noise gated to the attack only
    breath_n = min(int(0.05 * sr), n)
    breath = noise_burst(breath_n)
    breath = bandpass_fft(breath, 1800, 5000, sr=sr)
    breath *= np.exp(-np.arange(breath_n) / (breath_n * 0.35 + 1))
    sig[:breath_n] += breath * noise_amt

    return sig


def gen_honks():
    add_sound("honk_a", make_honk(int(0.40 * SR), 340, 520, 380,
                                   drive=1.35, noise_amt=0.16))
    add_sound("honk_b", make_honk(int(0.36 * SR), 310, 495, 355,
                                   drive=1.5, noise_amt=0.20, k_harm=20,
                                   rolloff=1.2, sag_k=3.6))
    add_sound("honk_c", make_honk(int(0.44 * SR), 365, 545, 405,
                                   drive=1.3, noise_amt=0.14, k_harm=24,
                                   rolloff=1.05, sag_k=2.5))
    add_sound("honk_angry", make_honk(int(0.56 * SR), 255, 430, 300,
                                       drive=2.4, noise_amt=0.30, k_harm=24,
                                       rolloff=1.0, growl_hz=27.0,
                                       growl_depth=0.35, sag_k=1.8,
                                       attack_frac=0.09))


def gen_hiss():
    n = int(0.7 * SR)
    tt = t_axis(n)
    noise = noise_burst(n)
    # amplitude rises then falls
    amp = np.sin(np.pi * np.clip(tt / 0.7, 0, 1)) ** 0.8
    # center frequency sweeps up then back down -- "threatening" arc
    center = 2400 + 2600 * np.sin(np.pi * np.clip(tt / 0.7, 0, 1))
    sig = stft_sweep(noise, center, mode="bandpass", bandwidth=1800)
    sig *= amp
    sig = soft_clip(sig, drive=1.2)
    add_sound("hiss", sig)


def gen_goose_grumble():
    n = int(0.5 * SR)
    buf = np.zeros(n)
    tpos = 0.02
    while tpos < 0.46:
        grain_dur = rng.uniform(0.04, 0.075)
        gn = int(grain_dur * SR)
        f_start = rng.uniform(150, 200)
        f_end = f_start * rng.uniform(0.75, 0.95)
        f0 = np.linspace(f_start, f_end, gn)
        raw = harmonic_stack(f0, gn, k_harm=14, rolloff=1.4)
        body = bandpass_fft(raw, 500, 950) * 0.9 + raw * 0.2
        env = adsr(gn, attack=0.008, decay=0.02, sustain=0.5, release=0.03)
        grain = soft_clip(body * env, drive=1.3) * rng.uniform(0.6, 1.0)
        mix_into(buf, grain, int(tpos * SR))
        tpos += grain_dur + rng.uniform(0.01, 0.035)
    # continuous low breathy chirr underneath
    breath = noise_burst(n)
    breath = bandpass_fft(breath, 300, 700)
    breath *= 0.12 * (0.6 + 0.4 * np.sin(2 * np.pi * 6 * t_axis(n)))
    buf += breath
    add_sound("goose_grumble", buf)


def gen_flaps():
    for i, (seed_amp, dur, thump_f) in enumerate([
        (1.0, 0.18, 70), (0.95, 0.17, 65), (1.05, 0.19, 75)
    ], start=1):
        n = int(dur * SR)
        noise = noise_burst(n)
        cutoff = 3200 * np.exp(-np.arange(n) / (n * 0.22)) + 120
        whoomp = stft_sweep(noise, cutoff, mode="lowpass")
        thump = osc(thump_f, n, shape="sine") * exp_decay(n, 0.05)
        sig = whoomp * 0.8 * seed_amp + thump * 0.6
        sig = soft_clip(sig, drive=1.1)
        add_sound(f"flap_{i}", sig)


def gen_waddles():
    for i in range(1, 3):
        n = int(0.08 * SR)
        noise = noise_burst(n)
        cutoff = np.full(n, 1400.0 + i * 150)
        sig = stft_sweep(noise, cutoff, mode="lowpass", frame_size=256, hop=64)
        sig *= exp_decay(n, 0.018)
        click = transient_click(min(n, int(0.02 * SR)), band=(600, 2200), decay_frac=0.2)
        sig[:len(click)] += click * 0.5
        add_sound(f"waddle_{i}", sig)


def gen_splash_in():
    n = int(0.5 * SR)
    tt = t_axis(n)
    noise = noise_burst(n)
    cutoff = 9000 * np.exp(-tt / 0.12) + 350
    bright = stft_sweep(noise, cutoff, mode="lowpass")
    bright *= exp_decay(n, 0.10)
    # low gurgle tail: low-passed noise with slow random amplitude wobble
    gnoise = noise_burst(n)
    gurgle = one_pole_lowpass(gnoise, 500)
    wobble = 0.5 + 0.5 * np.sin(2 * np.pi * 7 * tt + 0.4 * np.sin(2 * np.pi * 2.3 * tt))
    gurgle *= wobble
    gurgle_env = 1.0 - np.exp(-tt / 0.06)
    gurgle *= gurgle_env * np.exp(-tt / 0.35)
    sig = bright * 0.9 + gurgle * 0.6
    add_sound("splash_in", sig)


def gen_splash_small():
    n = int(0.25 * SR)
    tt = t_axis(n)
    noise = noise_burst(n)
    cutoff = 6000 * np.exp(-tt / 0.05) + 400
    sig = stft_sweep(noise, cutoff, mode="lowpass")
    sig *= exp_decay(n, 0.09)
    plip = osc_sweep(np.linspace(900, 350, n), shape="sine") * exp_decay(n, 0.04)
    sig += plip * 0.25
    add_sound("splash_small", sig)


def _swim_raw(n, sr=SR):
    tt = t_axis(n, sr)
    base = noise_burst(n)
    lap_lfo = 0.55 + 0.45 * np.sin(2 * np.pi * 1.5 * tt)  # 3 cycles / 2.0s
    body = one_pole_lowpass(base * 0.7, 650) * lap_lfo
    sparkle = noise_burst(n)
    sparkle = one_pole_highpass(sparkle, 1600)
    sparkle *= (0.5 + 0.5 * np.sin(2 * np.pi * 3.5 * tt + 1.0))  # 7 cyc / 2.0s
    return body * 0.85 + sparkle * 0.22


def gen_swim_loop():
    sig = seamless_loop(_swim_raw, 2.0, xfade_ms=60.0)
    add_sound("swim_loop", sig, is_loop=True)


def _wind_raw(n, sr=SR):
    tt = t_axis(n, sr)
    noise = noise_burst(n)
    low_band = one_pole_lowpass(one_pole_highpass(noise, 250), 1100)
    mid_noise = noise_burst(n)
    mid_band = one_pole_lowpass(one_pole_highpass(mid_noise, 900), 2600)
    hi_noise = noise_burst(n)
    hi_band = one_pole_highpass(hi_noise, 2200)
    w1 = 0.5 + 0.5 * np.sin(2 * np.pi * 0.25 * tt)          # 1 cycle / 4.0s
    w2 = 0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * tt + 1.1)     # 2 cycles / 4.0s
    sig = low_band * (0.55 + 0.30 * w1) + mid_band * (0.25 + 0.25 * w2) + hi_band * 0.12
    amp_mod = 0.75 + 0.25 * np.sin(2 * np.pi * 0.25 * tt + 2.2)  # 1 cycle / 4.0s
    return sig * amp_mod * 0.7


def gen_wind_loop():
    sig = seamless_loop(_wind_raw, 4.0, xfade_ms=80.0)
    add_sound("wind_loop", sig, is_loop=True)


def gen_crash_cart():
    n = int(0.6 * SR)
    buf = np.zeros(n)
    hits = [(0.0, 1.0), (0.09, 0.68), (0.20, 0.5), (0.34, 0.32)]
    base_freqs = [920, 1460, 2150, 3100, 4250]
    base_amps = [0.9, 0.7, 0.5, 0.35, 0.22]
    base_decays = [0.28, 0.22, 0.18, 0.13, 0.09]
    for onset_t, amp_scale in hits:
        onset = int(onset_t * SR)
        freqs = [f * rng.uniform(0.985, 1.015) for f in base_freqs]
        hit_n = n - onset
        hit = modal_burst(hit_n, freqs, [a * amp_scale for a in base_amps],
                           base_decays, noise_amp=0.5 * amp_scale,
                           noise_band=(2000, 7000), noise_dur_ms=6)
        mix_into(buf, hit, onset)
    add_sound("crash_cart", soft_clip(buf, drive=1.2))


def gen_crash_light():
    n = int(0.25 * SR)
    hit1 = modal_burst(n, [520, 880, 1320], [0.9, 0.5, 0.3],
                        [0.10, 0.08, 0.06], noise_amp=0.5,
                        noise_band=(800, 3500), noise_dur_ms=5)
    buf = hit1.copy()
    hit2 = modal_burst(n, [610, 990], [0.4, 0.22], [0.07, 0.05],
                        noise_amp=0.25, noise_band=(800, 3000), noise_dur_ms=4)
    mix_into(buf, hit2, int(0.09 * SR))
    add_sound("crash_light", buf)


def gen_crash_heavy():
    n = int(0.5 * SR)
    body = modal_burst(n, [72, 118, 175, 230], [1.0, 0.55, 0.35, 0.2],
                        [0.30, 0.24, 0.16, 0.10], noise_amp=0.4,
                        noise_band=(80, 900), noise_dur_ms=20)
    sub = osc(52, n, shape="sine") * exp_decay(n, 0.09)
    sig = body * 0.85 + sub * 0.5
    add_sound("crash_heavy", soft_clip(sig, drive=1.15))


def gen_smash():
    n = int(0.7 * SR)
    buf = np.zeros(n)
    # sharp initial transient
    trans = transient_click(int(0.03 * SR), band=(2500, 9000), decay_frac=0.12)
    mix_into(buf, trans * 1.2, 0)
    trans_low = modal_burst(int(0.08 * SR), [600, 1500], [0.5, 0.3], [0.04, 0.03])
    mix_into(buf, trans_low, 0)
    # scatter of debris ticks, decreasing density/amplitude over time
    tpos = 0.02
    while tpos < 0.65:
        amp = max(0.5 * (1.0 - tpos / 0.65), 0.05)
        dur_n = int(rng.uniform(0.006, 0.02) * SR)
        band_lo = rng.uniform(1500, 4500)
        band_hi = band_lo + rng.uniform(800, 2500)
        tick = transient_click(dur_n, band=(band_lo, band_hi), decay_frac=0.3)
        mix_into(buf, tick * amp, int(tpos * SR))
        tpos += rng.uniform(0.012, 0.05) * (1.0 + tpos)
    add_sound("smash", buf)


def gen_thud_land():
    n = int(0.3 * SR)
    thump = osc(68, n, shape="sine") * exp_decay(n, 0.045)
    thump2 = osc(112, n, shape="sine") * exp_decay(n, 0.03) * 0.4
    noise = noise_burst(int(0.05 * SR))
    flump = bandpass_fft(noise, 200, 1800)
    flump *= exp_decay(len(flump), 0.02)
    sig = thump + thump2
    sig[:len(flump)] += flump * 0.5
    add_sound("thud_land", soft_clip(sig, drive=1.2))


def gen_tumble():
    n = int(1.0 * SR)
    tt = t_axis(n)
    bed_noise = noise_burst(n)
    bed = one_pole_lowpass(bed_noise, 900)
    bed_env = (0.6 + 0.4 * np.sin(2 * np.pi * 5.0 * tt)) * np.exp(-tt / 1.4)
    buf = bed * bed_env * 0.35
    tpos = 0.0
    interval = 0.02
    while tpos < 0.95:
        density_progress = tpos / 0.95
        amp = (1.0 - 0.6 * density_progress) * rng.uniform(0.5, 1.0)
        dur_n = int(rng.uniform(0.01, 0.028) * SR)
        f_lo = rng.uniform(400, 2200)
        f_hi = f_lo + rng.uniform(400, 1800)
        grain = transient_click(dur_n, band=(f_lo, f_hi), decay_frac=0.35)
        mix_into(buf, grain * amp * 0.7, int(tpos * SR))
        interval = rng.uniform(0.015, 0.05) * (1.0 + density_progress * 1.5)
        tpos += interval
    add_sound("tumble", soft_clip(buf, drive=1.15))


def gen_meow():
    n = int(0.5 * SR)
    frac = np.linspace(0, 1, n)
    f0 = 430 + 220 * np.sin(np.pi * np.clip(frac / 0.7, 0, 1)) - 120 * np.clip((frac - 0.55) / 0.45, 0, 1)
    f0 = np.clip(f0, 200, 750)
    raw = harmonic_stack(f0, n, k_harm=12, rolloff=1.4)
    f1 = bandpass_fft(raw, 600, 850)
    f2 = bandpass_fft(raw, 1650, 1950)
    body = raw * 0.3 + f1 * 0.9 + f2 * 0.55
    amp = adsr(n, attack=0.03, decay=0.08, sustain=0.65, release=0.22)
    sig = soft_clip(body * amp, drive=1.15)
    breath_n = min(int(0.06 * SR), n)
    breath = bandpass_fft(noise_burst(breath_n), 1200, 3500)
    breath *= np.exp(-np.arange(breath_n) / (breath_n * 0.4 + 1))
    sig[:breath_n] += breath * 0.12
    add_sound("meow", sig)


def gen_meow_frenzy():
    n = int(0.8 * SR)
    tt = t_axis(n)
    frac = tt / 0.8
    f0 = 380 + 380 * np.sin(2 * np.pi * 1.4 * frac) * np.exp(-0.3 * frac) + 60 * np.sin(2 * np.pi * 9 * tt)
    f0 = np.clip(f0, 220, 950)
    raw = harmonic_stack(f0, n, k_harm=16, rolloff=1.1)
    f1 = bandpass_fft(raw, 600, 900)
    f2 = bandpass_fft(raw, 1700, 2100)
    body = raw * 0.35 + f1 * 0.85 + f2 * 0.7
    amp = adsr(n, attack=0.015, decay=0.05, sustain=0.75, release=0.18)
    amp *= (1.0 + 0.25 * np.sin(2 * np.pi * 18 * tt))
    amp = np.clip(amp, 0, None)
    sig = soft_clip(body * amp, drive=1.9)
    noise = bandpass_fft(noise_burst(n), 1500, 4500) * 0.1
    sig += noise * exp_decay(n, 0.5)
    add_sound("meow_frenzy", sig)


def _yelp(n, f_start, f_peak, f_low, formants, drive):
    frac = np.linspace(0, 1, n)
    rise_n = max(int(n * 0.18), 4)
    fall_n = n - rise_n
    rise = f_start + (f_peak - f_start) * (1 - np.exp(-5 * np.linspace(0, 1, rise_n)))
    fall = f_peak + (f_low - f_peak) * (1 - np.exp(-4 * np.linspace(0, 1, fall_n)))
    f0 = np.concatenate([rise, fall])
    raw = harmonic_stack(f0, n, k_harm=10, rolloff=1.5)
    f1 = bandpass_fft(raw, *formants[0])
    f2 = bandpass_fft(raw, *formants[1])
    body = raw * 0.3 + f1 * 0.8 + f2 * 0.45
    amp = adsr(n, attack=0.012, decay=0.06, sustain=0.5, release=0.14)
    sig = soft_clip(body * amp, drive=drive)
    breath_n = min(int(0.03 * SR), n)
    breath = bandpass_fft(noise_burst(breath_n), 800, 2500)
    breath *= np.exp(-np.arange(breath_n) / (breath_n * 0.3 + 1))
    sig[:breath_n] += breath * 0.15
    return sig


def gen_human_yelps():
    n = int(0.35 * SR)
    add_sound("human_yelp_1", _yelp(n, 260, 520, 200, ((500, 750), (1000, 1350)), 1.3))
    add_sound("human_yelp_2", _yelp(n, 300, 600, 230, ((520, 780), (1100, 1450)), 1.5))


def _pluck(n, carrier, mod_ratio=3.0, index0=3.5, tau=0.06, sr=SR):
    tt = t_axis(n, sr)
    idx = index0 * np.exp(-tt / (tau * 1.4))
    modf = carrier * mod_ratio
    sig = np.sin(2 * np.pi * carrier * tt + idx * np.sin(2 * np.pi * modf * tt))
    sig *= np.exp(-tt / tau)
    return sig


def gen_score_blips():
    n = int(0.12 * SR)
    base = _pluck(n, 1050.0)
    add_sound("score_blip", base)
    hi = _pluck(n, 1050.0 * 1.5)  # perfect fifth up
    add_sound("score_blip_hi", hi)


def _charge_raw(n, sr=SR):
    tt = t_axis(n, sr)
    f0 = 172.0
    d1 = osc(f0, n, shape="saw")
    d2 = osc(f0 * 1.012, n, shape="saw")
    drone = (d1 + d2) * 0.5
    tremolo = 0.55 + 0.45 * np.sin(2 * np.pi * 8.0 * tt)  # 8 cycles / 1.0s
    sig = drone * tremolo
    hiss = one_pole_highpass(noise_burst(n), 3500) * 0.08
    sig = soft_clip(sig * 0.9 + hiss, drive=1.6)
    return sig


def gen_dose_charge_loop():
    sig = seamless_loop(_charge_raw, 1.0, xfade_ms=30.0)
    add_sound("dose_charge_loop", sig, is_loop=True)


def gen_dose_commit_good():
    n = int(0.4 * SR)
    tt = t_axis(n)
    root = 220.0
    chord_ratios = [1.0, 1.25, 1.5, 2.0]  # major triad + octave, warm
    sig = np.zeros(n)
    for r in chord_ratios:
        f = root * r
        detune = f * 0.004
        sig += 0.5 * (osc(f - detune, n, shape="sine") + osc(f + detune, n, shape="sine"))
    sig = one_pole_lowpass(sig, 3200)
    amp = adsr(n, attack=0.008, decay=0.09, sustain=0.55, release=0.22)
    sig = soft_clip(sig * amp, drive=1.1)
    add_sound("dose_commit_good", sig)


def gen_dose_commit_bad():
    n = int(0.5 * SR)
    tt = t_axis(n)
    f1 = 220.0
    f2 = 233.0  # dissonant minor-second-ish detune -> beating/sour
    wobble = 1.0 + 0.05 * np.sin(2 * np.pi * 5.5 * tt)
    pitch_drop = np.exp(-tt / 0.5)  # instantaneous freq array, sags downward
    sig = (osc_sweep(f1 * wobble * pitch_drop, shape="saw") * 0.5 +
           osc_sweep(f2 / wobble * pitch_drop, shape="saw") * 0.5)
    amp = adsr(n, attack=0.01, decay=0.1, sustain=0.55, release=0.25)
    sig = soft_clip(sig * amp, drive=1.7)
    add_sound("dose_commit_bad", sig)


def gen_unlock():
    n = int(0.7 * SR)
    note1_n = int(0.28 * SR)
    note2_n = n - note1_n
    note1 = _pluck(note1_n, 660.0, mod_ratio=2.0, index0=2.0, tau=0.22)
    note2 = _pluck(note2_n, 880.0, mod_ratio=2.0, index0=2.2, tau=0.42)
    sig = np.zeros(n)
    sig[:note1_n] += note1 * 0.8
    mix_into(sig, note2 * 0.9, int(0.22 * SR))
    # simple short echo/tail via one delayed decayed copy (cheap reverb feel)
    delay_n = int(0.06 * SR)
    echo = np.zeros(n)
    mix_into(echo, sig[:n - delay_n] * 0.25, delay_n)
    sig = sig + echo
    add_sound("unlock", sig)


def gen_blackout():
    n = int(1.2 * SR)
    tt = t_axis(n)
    whoosh_n = int(0.85 * SR)
    noise = noise_burst(whoosh_n)
    center = 6000 * np.exp(-np.arange(whoosh_n) / (whoosh_n * 0.35)) + 100
    whoosh = stft_sweep(noise, center, mode="lowpass")
    whoosh_amp = np.sin(np.pi * np.clip(np.arange(whoosh_n) / whoosh_n, 0, 1)) ** 0.6
    whoosh *= whoosh_amp
    buf = np.zeros(n)
    buf[:whoosh_n] += whoosh * 0.9
    thump = osc(58, n, shape="sine") * exp_decay(n, 0.35)
    thump_env = np.zeros(n)
    thump_start = int(0.78 * SR)
    thump_env[thump_start:] = 1.0
    buf += thump * 0.7 * (np.arange(n) >= thump_start)
    add_sound("blackout", soft_clip(buf, drive=1.15))


def gen_heartbeat():
    n = int(0.9 * SR)
    buf = np.zeros(n)

    def lub(dur_n):
        tt = t_axis(dur_n)
        return (osc(55, dur_n, shape="sine") * np.exp(-tt / 0.09) +
                bandpass_fft(noise_burst(dur_n), 40, 300) * np.exp(-tt / 0.02) * 0.4)

    b1 = lub(int(0.16 * SR))
    b2 = lub(int(0.14 * SR)) * 0.75
    mix_into(buf, b1, int(0.02 * SR))
    mix_into(buf, b2, int(0.36 * SR))
    add_sound("heartbeat", soft_clip(buf, drive=1.1))


def gen_fx_wobble():
    n = int(0.9 * SR)
    tt = t_axis(n)
    base = 260.0
    depth = 0.18 * np.clip(tt / 0.3, 0, 1)
    lfo = np.sin(2 * np.pi * 3.2 * tt + 0.6 * np.sin(2 * np.pi * 0.7 * tt))
    f0 = base * (1.0 + depth * lfo)
    sig = osc_sweep(f0, shape="saw") * 0.6 + osc_sweep(f0 * 1.5, shape="sine") * 0.3
    sig = one_pole_lowpass(sig, 2200)
    amp = adsr(n, attack=0.05, decay=0.05, sustain=0.8, release=0.25)
    add_sound("fx_wobble", soft_clip(sig * amp, drive=1.2))


def gen_fx_jitter():
    n = int(0.8 * SR)
    tt = t_axis(n)
    buzz = osc(150, n, shape="saw") * 0.6 + osc(151.5, n, shape="square") * 0.25
    gate_rate = 24.0
    gate_phase = 2 * np.pi * gate_rate * tt + 0.6 * np.sin(2 * np.pi * 13 * tt)
    jitter = 0.5 * (np.random.default_rng(7).uniform(-1, 1, n))
    jitter = one_pole_lowpass(jitter, 40)
    gate = (np.sign(np.sin(gate_phase + jitter * 2.0)) * 0.5 + 0.5)
    gate = one_pole_lowpass(gate, 900)  # soften hard edges just slightly
    amp = adsr(n, attack=0.02, decay=0.03, sustain=0.85, release=0.2)
    sig = soft_clip(buzz * gate * amp, drive=1.6)
    add_sound("fx_jitter", sig)


def gen_fx_slowmo():
    n = int(1.4 * SR)
    tt = t_axis(n)
    f0 = 900 * np.exp(-tt / 0.35) + 40
    sig = osc_sweep(f0, shape="sine") * 0.7 + osc_sweep(f0 * 0.5, shape="sine") * 0.3
    amp = np.clip(1.0 - np.exp(-tt / 0.05), 0, 1) * np.exp(-np.clip((tt - 1.1), 0, None) / 0.2)
    sig = one_pole_lowpass(sig, 1400)
    add_sound("fx_slowmo", soft_clip(sig * amp, drive=1.15))


def gen_fx_trip():
    n = int(2.0 * SR)
    tt = t_axis(n)
    base = 330.0
    detunes = [1.0, 1.006, 0.992, 1.014, 0.985]
    sig = np.zeros(n)
    for d in detunes:
        sig += osc(base * d, n, shape="sine") * 0.2
    shimmer = 0.7 + 0.3 * np.sin(2 * np.pi * 0.35 * tt)
    sig *= shimmer
    amp = adsr(n, attack=0.15, decay=0.1, sustain=0.75, release=0.6)
    add_sound("fx_trip", sig * amp)


def gen_fx_warp():
    n = int(1.5 * SR)
    tt = t_axis(n)
    base = 240.0
    wave_rate = 1.3
    pitch_lfo = np.sin(2 * np.pi * wave_rate * tt)
    f0 = base * (1.0 + 0.22 * pitch_lfo)
    amp_lfo = 0.55 + 0.45 * np.sin(2 * np.pi * wave_rate * tt - 0.3)
    sig = osc_sweep(f0, shape="sine") * 0.7 + osc_sweep(f0 * 2.0, shape="sine") * 0.2
    env = adsr(n, attack=0.08, decay=0.05, sustain=0.85, release=0.3)
    add_sound("fx_warp", soft_clip(sig * amp_lfo * env, drive=1.1))


def _amb_raw(n, sr=SR):
    tt = t_axis(n, sr)
    rumble_noise = noise_burst(n)
    rumble = one_pole_lowpass(rumble_noise, 220)
    rumble_mod = 0.75 + 0.25 * np.sin(2 * np.pi * (1.0 / 6.0) * tt)  # 1 cyc / 6s
    rumble *= rumble_mod

    wind_noise = noise_burst(n)
    wind = one_pole_highpass(wind_noise, 3000)
    wind *= 0.06 + 0.03 * np.sin(2 * np.pi * (2.0 / 6.0) * tt + 0.8)  # 2 cyc / 6s

    sig = rumble * 0.5 + wind

    # faint distant bird chirps, placed well away from the loop edges
    for chirp_t in (1.3, 3.6, 4.9):
        cn = int(0.09 * SR)
        start = int(chirp_t * sr)
        if start + cn >= n:
            continue
        f0 = np.linspace(1900, 2500, cn)
        chirp = harmonic_stack(f0, cn, k_harm=6, rolloff=1.6)
        chirp = bandpass_fft(chirp, 1500, 3200)
        chirp *= np.exp(-np.arange(cn) / (cn * 0.3 + 1))
        mix_into(sig, chirp * 0.045, start)

    return sig


def gen_amb_parking_lot():
    sig = seamless_loop(_amb_raw, 6.0, xfade_ms=120.0)
    add_sound("amb_parking_lot", sig, is_loop=True)


# ============================================================================
# ---------------------  ZONE AMBIENCE BEDS  ---------------------------------
# ============================================================================
#
# One bed per PLACE. Every leg used to run `amb_parking_lot`, so a cottage lake
# at night, a dawn marsh and a truck stop in the rain all sounded like a strip
# mall. `scripts/core/sfx.gd::set_ambience()` now picks the bed from the ZONE
# ID -- not the leg number, because leg numbers move and zone ids do not.
#
# The parking lot bed above is kept as-is: it is the right sound for leg 1
# (the retention pond behind the plaza) and leg 2 (the lot itself).
#
# ---------------------------------------------------------------------------
# HOW EACH BED IS GUARANTEED TO LOOP WITHOUT A SEAM
# ---------------------------------------------------------------------------
# Four mechanisms, and all four are load-bearing. A bed with an audible seam
# every eight seconds is worse than one wrong bed, because you cannot stop
# hearing it.
#
#   1. CONTINUOUS CONTENT IS PHASE-LOCKED TO THE LOOP. Every oscillator and
#      every LFO runs at `cycles / LOOP_SECONDS` for a WHOLE number of cycles,
#      so its phase at the wrap is exactly its phase at zero. A 118 Hz mower
#      over a 12.000 s loop is 1416 whole cycles. `_whole_cycles()` asserts it
#      rather than trusting the arithmetic, and `_lfo()` takes a cycle COUNT
#      instead of a frequency so it cannot be got wrong at all.
#   2. THE WRAP IS CROSSFADED. `seamless_loop()` synthesises `xfade_ms` of
#      extra tail and equal-power crossfades it into the head. That is also
#      what disposes of every filter's startup transient, and what carries a
#      short event that straddles the wrap over to the other side.
#   3. THE SAMPLE-LEVEL JUMP IS FORCED TO ZERO by `micro_declick()` inside
#      `seamless_loop()`. The seam table at the bottom of this file prints the
#      residual edge jump per loop and marks anything above 3x the local
#      slope as CHECK.
#   4. LONG DISCRETE EVENTS ARE FENCED. A loon wail still ringing at the wrap
#      gets truncated -- a chop once per loop that the edge-jump number cannot
#      see, because the jump is still exactly zero. `_amb_place()` REFUSES an
#      event that does not fit wholly inside the loop with clearance at both
#      ends, and RAISES rather than clipping, so a mis-scheduled call is a
#      build failure instead of a defect you have to hear to find.
#
# Two kinds of content deliberately skip rule 4:
#   * PERIODIC TRAINS (sprinkler impacts, diesel firing pulses) -- they are
#     meant to cross the seam and do it safely because their tick count
#     divides the loop exactly. `_amb_train()`.
#   * DENSE SHORT SCATTER (rain on metal, papery corn ticks) -- each event is
#     shorter than the crossfade, so rule 2 carries it across intact, and
#     there are hundreds of them so no single one is a landmark you could
#     learn. Fencing these would leave an audible hole at the top of the loop.
#
# ---------------------------------------------------------------------------
# NOBODY HAS HEARD ANY OF THIS.
# ---------------------------------------------------------------------------
# The only objective evidence these beds work is the seam table this file
# prints. Whether a bed sounds like the place it is named after is a judgement
# no generator can make; it needs a listener.

AMB_XFADE_MS = 140.0    ## crossfade at the wrap, every bed
AMB_GUARD_S = 0.30      ## dead zone at the top of the loop for landmark events


def _lp(x, hi_hz, sr=SR, trans=60.0):
    """Vectorised lowpass. `one_pole_lowpass` is a Python for-loop over every
    sample: fine for a 0.2 s impact, not fine for a 16 s bed."""
    return bandpass_fft(x, 0.0, hi_hz, sr=sr, trans=trans)


def _hp(x, lo_hz, sr=SR, trans=60.0):
    return bandpass_fft(x, lo_hz, sr * 0.5, sr=sr, trans=trans)


def _whole_cycles(freq_hz, loop_s, what):
    """Assert that `freq_hz` completes a whole number of cycles in `loop_s`,
    i.e. that this oscillator's phase is continuous across the wrap before the
    crossfade touches it. Returns the frequency so it reads as a cast."""
    cyc = float(freq_hz) * float(loop_s)
    if abs(cyc - round(cyc)) > 1e-9:
        raise ValueError(
            "%s: %.6f Hz is %.6f cycles per %.3f s loop, not a whole number -- "
            "the wrap would be a pitch discontinuity" % (what, freq_hz, cyc, loop_s))
    return float(freq_hz)


def _lfo(tt, cycles, loop_s, phase=0.0, lo=0.0, hi=1.0):
    """A modulator that CANNOT break the loop: it takes a whole cycle COUNT,
    not a frequency, so `cycles / loop_s` is continuous at the wrap by
    construction. Output is mapped into [lo, hi]."""
    if int(cycles) != cycles:
        raise ValueError("_lfo needs a whole cycle count, got %r" % (cycles,))
    u = 0.5 + 0.5 * np.sin(2 * np.pi * (float(cycles) / float(loop_s)) * tt + phase)
    return lo + (hi - lo) * u


def _amb_place(buf, sig, t_start, sr, loop_s, guard=AMB_GUARD_S):
    """Mix a LANDMARK event -- a loon wail, a blackbird song, a dog two streets
    over -- into a bed at an absolute time, and refuse if it does not fit.

    Refuse, not clip. An event whose tail is cut off at the wrap is an audible
    chop once per loop, and the seam report cannot see it: `micro_declick`
    still drives the edge jump to exactly zero. The only way to catch it is to
    make the schedule itself a failure, here, at generation time."""
    n_loop = int(round(loop_s * sr))
    start = int(round(t_start * sr))
    end = start + len(sig)
    if start < int(round(guard * sr)) or end > n_loop:
        raise ValueError(
            "ambience event at %.3f s is %.3f s long and does not fit a %.3f s "
            "loop with a %.2f s head guard (it would end at %.3f s) -- "
            "reschedule it" % (t_start, len(sig) / float(sr), loop_s, guard,
                               end / float(sr)))
    mix_into(buf, sig, start)


def _amb_train(buf, sr, loop_s, count, make_tick, level_fn=None):
    """A PERIODIC event train that is allowed to cross the wrap, because
    `count` ticks fit `loop_s` exactly: tick 0 of the next pass lands exactly
    where tick `count` of this one would have. Sprinkler impacts and diesel
    firing pulses are this. A loon is not."""
    n = len(buf)
    spacing = float(loop_s) / float(count)
    k = 0
    while k * spacing * sr < n:
        t = k * spacing
        amp = 1.0 if level_fn is None else float(level_fn(t % loop_s))
        if amp > 1e-4:
            mix_into(buf, make_tick(k) * amp, int(round(t * sr)))
        k += 1


def _amb_scatter(buf, sr, loop_s, count, make_event, gain_lo, gain_hi):
    """DENSE SHORT scatter across the whole buffer, tail included. Every event
    must be shorter than the crossfade so rule 2 carries a straddling one over
    intact; `make_event` is asserted against that."""
    n = len(buf)
    xfade_n = int(sr * AMB_XFADE_MS / 1000.0)
    total_s = n / float(sr)
    for _ in range(count):
        ev = make_event()
        if len(ev) > xfade_n:
            raise ValueError(
                "scattered event is %d samples, longer than the %d-sample "
                "crossfade -- it would be chopped at the wrap. Use "
                "_amb_place() instead." % (len(ev), xfade_n))
        mix_into(buf, ev * float(rng.uniform(gain_lo, gain_hi)),
                 int(rng.uniform(0.0, total_s) * sr))
    _ = loop_s  # kept in the signature so call sites read symmetrically


def _slow_env(n, sr, lo_hz=0.5, hi_hz=9.0):
    """A slow, irregular 0..1 fluctuation -- what makes a rustle read as wind
    moving through a thing rather than as a noise generator at a fixed level."""
    e = np.abs(bandpass_fft(noise_burst(n), lo_hz, hi_hz, sr=sr, trans=3.0))
    peak = float(np.max(e))
    if peak < 1e-12:
        return np.zeros(n)
    return e / peak


# ---------------------------------------------------------------------------
# LEG 3 -- SUBURBIA, GOLDEN HOUR
# distant mower, a dog two streets over, sprinklers, cicadas
# ---------------------------------------------------------------------------

AMB_SUBURBIA_S = 12.0


def _dog_bark(sr, f_hi=430.0, level=1.0):
    """One bark, from two streets away: no high end survives the distance, and
    what comes back is mostly the slap off the house opposite."""
    n = int(0.16 * sr)
    f0 = np.linspace(f_hi, f_hi * 0.55, n)
    raw = harmonic_stack(f0, n, k_harm=10, rolloff=1.35, sr=sr)
    body = bandpass_fft(raw, 180.0, 1300.0, sr=sr)
    env = adsr(n, attack=0.008, decay=0.05, sustain=0.35, release=0.09, sr=sr)
    bark = soft_clip(body * env, drive=1.4)
    out = np.zeros(n + int(0.36 * sr))
    out[:n] += bark
    mix_into(out, _lp(bark, 900.0, sr=sr) * 0.24, int(0.11 * sr))
    mix_into(out, _lp(bark, 600.0, sr=sr) * 0.10, int(0.21 * sr))
    return out * level


def _amb_suburbia_raw(n, sr=SR):
    L = AMB_SUBURBIA_S
    tt = t_axis(n, sr)

    # warm evening air
    sig = _lp(noise_burst(n), 620.0, sr=sr) * _lfo(tt, 1, L, 0.0, 0.34, 0.52)

    # a mower, three gardens over. 118 Hz x 12 s = 1416 whole cycles.
    f_eng = _whole_cycles(118.0, L, "suburbia mower")
    engine = (osc(f_eng, n, sr=sr, shape="saw") * 0.70
              + osc(f_eng * 2.0, n, sr=sr, shape="saw") * 0.22)
    engine *= _lfo(tt, 3, L, 0.4, 0.70, 1.0)                 # engine load
    engine = bandpass_fft(engine, 70.0, 820.0, sr=sr)
    blade = bandpass_fft(noise_burst(n), 500.0, 2400.0, sr=sr)
    blade *= _lfo(tt, int(f_eng * L), L, 0.0, 0.45, 1.0)     # locked to the engine
    sig += engine * 0.17 + blade * 0.055

    # cicadas: a 48 Hz shimmer (576 whole cycles) under a slow swell
    cic = bandpass_fft(noise_burst(n), 3600.0, 6800.0, sr=sr)
    cic *= _lfo(tt, int(48.0 * L), L, 0.0, 0.35, 1.0)
    cic *= _lfo(tt, 2, L, 1.2, 0.30, 0.78)
    sig += cic * 0.20

    # an impact sprinkler: 60 impacts a loop, sweeping across three times
    def _spr_tick(_k):
        d = int(0.030 * sr)
        t = transient_click(d, band=(1100.0, 4200.0), sr=sr, decay_frac=0.22)
        return t + _lp(t, 1400.0, sr=sr) * 0.55

    def _spr_level(t_in_loop):
        u = 0.5 + 0.5 * math.sin(2 * math.pi * (3.0 / L) * t_in_loop - 1.4)
        return 0.10 + 0.42 * (u ** 2)

    _amb_train(sig, sr, L, 60, _spr_tick, _spr_level)

    # the dog. Two bouts, both well clear of the wrap.
    for t, f, lv in ((2.15, 430.0, 0.55), (2.61, 405.0, 0.44), (3.04, 448.0, 0.33),
                     (8.40, 418.0, 0.40), (8.82, 396.0, 0.29)):
        _amb_place(sig, _dog_bark(sr, f, lv), t, sr, L)

    return sig


# ---------------------------------------------------------------------------
# LEG 4 -- COTTAGE COUNTRY, NIGHT
# loons, water lapping, wind in pines, a far outboard
# ---------------------------------------------------------------------------

AMB_LAKE_S = 14.0


def _loon_wail(sr, f_a=640.0, f_b=880.0, f_c=760.0, dur=1.9, level=1.0, far=0.0):
    """The wail: one long slurred vowel with a slow vibrato, and then the lake
    hands it back to you twice."""
    n = int(dur * sr)
    frac = np.linspace(0.0, 1.0, n)
    f0 = np.interp(frac, [0.0, 0.22, 0.58, 1.0], [f_a, f_b, f_b * 0.98, f_c])
    f0 = f0 * (1.0 + 0.012 * np.sin(2 * np.pi * 6.0 * t_axis(n, sr)))
    tone = (osc_sweep(f0, sr=sr, shape="sine") * 0.80
            + osc_sweep(f0 * 2.0, sr=sr, shape="sine") * 0.22
            + osc_sweep(f0 * 3.0, sr=sr, shape="sine") * 0.07)
    call = tone * adsr(n, attack=0.09, decay=0.25, sustain=0.85, release=0.55, sr=sr)
    if far > 0.0:
        call = _lp(call, 1600.0 - 800.0 * far, sr=sr)
    out = np.zeros(n + int(0.90 * sr))
    out[:n] += call
    mix_into(out, _lp(call, 1100.0, sr=sr) * 0.30, int(0.26 * sr))
    mix_into(out, _lp(call, 800.0, sr=sr) * 0.14, int(0.52 * sr))
    return out * level


def _loon_tremolo(sr, f0_hz=760.0, pulses=9, level=0.5):
    """The laugh. Same bird, entirely different mood, and the reason people
    describe a lake at night as unsettling rather than as peaceful."""
    per = 0.105
    n = int(pulses * per * sr)
    ttl = t_axis(n, sr)
    f0 = f0_hz * (1.0 + 0.05 * np.sin(2 * np.pi * (1.0 / (pulses * per)) * ttl))
    tone = (osc_sweep(f0, sr=sr, shape="sine") * 0.8
            + osc_sweep(f0 * 2.0, sr=sr, shape="sine") * 0.25)
    gate = np.clip(0.5 + 0.62 * np.sin(2 * np.pi * (1.0 / per) * ttl), 0.0, 1.0) ** 1.6
    call = _lp(tone * gate, 2200.0, sr=sr)
    call *= np.clip(ttl / 0.08, 0, 1) * np.exp(-np.clip(ttl - (n / sr) * 0.55, 0, None) / 0.22)
    out = np.zeros(n + int(0.45 * sr))
    out[:n] += call
    mix_into(out, _lp(call, 900.0, sr=sr) * 0.26, int(0.22 * sr))
    return out * level


def _amb_lake_night_raw(n, sr=SR):
    L = AMB_LAKE_S
    tt = t_axis(n, sr)

    # water against granite
    water = _lp(noise_burst(n), 900.0, sr=sr)
    water *= _lfo(tt, 7, L, 0.0, 0.35, 1.0) * _lfo(tt, 2, L, 0.9, 0.60, 1.0)
    sig = water * 0.62

    # ripple round the dock cribs
    ripple = bandpass_fft(noise_burst(n), 1200.0, 3800.0, sr=sr)
    ripple *= _lfo(tt, 21, L, 1.7, 0.15, 0.65)
    sig += ripple * 0.085

    # wind in the pines -- a hush, not a whistle
    pine = bandpass_fft(noise_burst(n), 620.0, 4200.0, sr=sr)
    pine *= _lfo(tt, 1, L, 0.0, 0.22, 0.70) + _lfo(tt, 3, L, 2.1, 0.0, 0.22)
    sig += pine * 0.34

    # an outboard, a long way up the lake. 84 Hz x 14 s = 1176 whole cycles.
    f_out = _whole_cycles(84.0, L, "cottage outboard")
    outb = (osc(f_out, n, sr=sr, shape="saw") * 0.60
            + osc(f_out * 1.5, n, sr=sr, shape="saw") * 0.25)
    outb = bandpass_fft(outb, 45.0, 340.0, sr=sr)
    sig += outb * _lfo(tt, 2, L, 0.7, 0.25, 0.80) * 0.09

    # the loons: one near, one answering from the far shore, one tremolo
    _amb_place(sig, _loon_wail(sr, 620.0, 900.0, 780.0, 2.00, 0.62), 2.30, sr, L)
    _amb_place(sig, _loon_wail(sr, 600.0, 845.0, 725.0, 1.50, 0.20, far=0.85), 8.10, sr, L)
    _amb_place(sig, _loon_tremolo(sr, 780.0, 9, 0.16), 11.05, sr, L)
    return sig


# ---------------------------------------------------------------------------
# LEG 5 -- THE STOPOVER, DAWN MARSH
# red-winged blackbirds, wind in cattails, water, and A LOT of geese
# ---------------------------------------------------------------------------
#
# The geese are the point. CAMPAIGN_SPEC has forty of them standing around on
# the impoundment not reacting to you, and the bed has to make the other three
# hundred that are out of frame exist. It does it two ways: a continuous
# low-voiced murmur, and thirty-odd individual honks scattered far enough back
# that none of them is a foreground event.

AMB_MARSH_S = 16.0


def _blackbird(sr, pitch=1.0, level=1.0, far=0.0):
    """Red-winged blackbird: 'conk-la-REEEEE'. Two short introductory notes and
    then the buzzy up-sweeping trill, which is the single most identifying
    sound a North American marsh makes in April."""
    seg = []
    for f, d in ((1560.0, 0.055), (1990.0, 0.070)):
        nn = int(d * sr)
        note = harmonic_stack(np.full(nn, f * pitch), nn, k_harm=6, rolloff=1.5, sr=sr)
        note *= adsr(nn, attack=0.005, decay=0.02, sustain=0.55, release=0.02, sr=sr)
        seg.append(note)
        seg.append(np.zeros(int(0.030 * sr)))
    tn = int(0.60 * sr)
    ttl = t_axis(tn, sr)
    tf = (2300.0 + 900.0 * np.clip(ttl / 0.35, 0, 1)) * pitch
    trill = (osc_sweep(tf, sr=sr, shape="saw") * 0.65
             + osc_sweep(tf * 0.5, sr=sr, shape="sine") * 0.30)
    trill *= 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * 92.0 * ttl))
    trill *= np.clip(ttl / 0.05, 0, 1) * np.exp(-np.clip(ttl - 0.36, 0, None) / 0.16)
    seg.append(trill)
    call = bandpass_fft(np.concatenate(seg), 900.0, 6200.0 - 2600.0 * far, sr=sr)
    out = np.zeros(len(call) + int(0.45 * sr))
    out[:len(call)] += call
    mix_into(out, _lp(call, 3000.0, sr=sr) * (0.10 + 0.24 * far), int(0.17 * sr))
    return out * level


def _far_honk(sr, f_lo, level, muffle):
    """One goose, over there. `make_honk` gives it the same throat as the
    player's honk -- it is the same species -- and the distance is a lowpass
    and a slap back off the water, not a volume knob."""
    n = int(rng.uniform(0.24, 0.40) * sr)
    h = make_honk(n, f_lo, f_lo * 1.55, f_lo * 1.12, k_harm=14, rolloff=1.25,
                  drive=1.2, noise_amt=0.05, sr=sr)
    h = bandpass_fft(h, 160.0, 2600.0 - 1500.0 * muffle, sr=sr)
    out = np.zeros(n + int(0.30 * sr))
    out[:n] += h
    mix_into(out, _lp(h, 1200.0, sr=sr) * 0.20 * muffle, int(0.13 * sr))
    return out * level


def _amb_marsh_dawn_raw(n, sr=SR):
    L = AMB_MARSH_S
    tt = t_axis(n, sr)

    # shallow water over a drowned marsh -- flatter and brighter than the lake
    water = _lp(noise_burst(n), 1100.0, sr=sr)
    water *= _lfo(tt, 8, L, 0.0, 0.35, 1.0) * _lfo(tt, 3, L, 1.4, 0.55, 1.0)
    sig = water * 0.40

    # cattails: dry, papery, and the only thing above 4 kHz in the mix
    cat = bandpass_fft(noise_burst(n), 1700.0, 7200.0, sr=sr)
    cat *= _lfo(tt, 2, L, 0.0, 0.16, 0.62) + _lfo(tt, 5, L, 2.4, 0.0, 0.20)
    cat *= 0.30 + 0.70 * _slow_env(n, sr, 0.4, 6.0)
    sig += cat * 0.26

    # the far side of the impoundment: several hundred geese, none of them near
    murmur = bandpass_fft(noise_burst(n), 300.0, 1500.0, sr=sr)
    murmur *= 0.25 + 0.75 * _slow_env(n, sr, 0.8, 14.0)
    murmur *= _lfo(tt, 3, L, 0.9, 0.55, 1.0)
    sig += murmur * 0.24

    # thirty-four individual birds. Onsets on a jittered grid, clamped clear of
    # the wrap: a honk is ~0.7 s with its slap-back, far longer than the
    # crossfade, so these are fenced landmarks and not scatter.
    count = 34
    span = L - AMB_GUARD_S - 0.90
    for i in range(count):
        t = AMB_GUARD_S + 0.05 + span * (i + float(rng.uniform(-0.40, 0.40))) / float(count)
        t = float(np.clip(t, AMB_GUARD_S + 0.02, AMB_GUARD_S + span))
        muffle = float(rng.uniform(0.35, 1.0))
        ev = _far_honk(sr, float(rng.uniform(300.0, 470.0)),
                       0.34 * (1.0 - 0.62 * muffle), muffle)
        _amb_place(sig, ev, t, sr, L)

    # the blackbirds, one per cattail stand
    _amb_place(sig, _blackbird(sr, 1.00, 0.30, 0.10), 1.90, sr, L)
    _amb_place(sig, _blackbird(sr, 0.94, 0.17, 0.55), 7.35, sr, L)
    _amb_place(sig, _blackbird(sr, 1.06, 0.24, 0.30), 12.60, sr, L)
    return sig


# ---------------------------------------------------------------------------
# LEG 6 -- THE CUT CORN, HARD MIDDAY
# dry rustle of standing corn, wind over stubble, a distant combine
# ---------------------------------------------------------------------------

AMB_CORN_S = 12.0


def _amb_corn_raw(n, sr=SR):
    L = AMB_CORN_S
    tt = t_axis(n, sr)

    # standing corn. Dry paper, not leaves: the band starts at 1.8 kHz.
    rustle = bandpass_fft(noise_burst(n), 1800.0, 8200.0, sr=sr)
    rustle *= 0.18 + 0.82 * _slow_env(n, sr, 0.6, 11.0)
    rustle *= _lfo(tt, 2, L, 0.0, 0.35, 1.0)
    sig = rustle * 0.34

    # wind over cut stubble -- nothing tall left to break it
    stubble = bandpass_fft(noise_burst(n), 160.0, 2400.0, sr=sr)
    stubble *= _lfo(tt, 1, L, 0.0, 0.30, 0.85) + _lfo(tt, 3, L, 1.9, 0.0, 0.20)
    sig += stubble * 0.42

    # a combine, somewhere up the field. 46 Hz x 12 s = 552 whole cycles;
    # 312 Hz x 12 s = 3744.
    f_d = _whole_cycles(46.0, L, "corn combine diesel")
    diesel = (osc(f_d, n, sr=sr, shape="saw") * 0.65
              + osc(f_d * 2.0, n, sr=sr, shape="square") * 0.20)
    diesel = bandpass_fft(diesel, 35.0, 380.0, sr=sr)
    f_t = _whole_cycles(312.0, L, "corn thresher")
    thresh = (osc(f_t, n, sr=sr, shape="tri") * 0.35
              + osc(f_t * 2.0, n, sr=sr, shape="sine") * 0.12)
    thresh = bandpass_fft(thresh, 240.0, 760.0, sr=sr)
    sig += (diesel * 0.30 + thresh * 0.055) * _lfo(tt, 2, L, 0.6, 0.55, 1.0)

    # heat haze, right at the top
    sig += _hp(noise_burst(n), 6200.0, sr=sr) * _lfo(tt, 4, L, 0.3, 0.25, 0.70) * 0.05

    # papery ticks: 190 of them, each a few milliseconds, so the crossfade
    # carries whichever ones straddle the wrap
    def _tick():
        d = int(float(rng.uniform(0.004, 0.013)) * sr)
        lo = float(rng.uniform(2200.0, 5200.0))
        return transient_click(d, band=(lo, lo + float(rng.uniform(900.0, 2600.0))),
                               sr=sr, decay_frac=0.30)

    _amb_scatter(sig, sr, L, 190, _tick, 0.02, 0.09)
    return sig


# ---------------------------------------------------------------------------
# LEG 7 -- THE TRUCK STOP, 3 A.M., RAIN
# rain on metal, an idling diesel, the interstate a long way off
# ---------------------------------------------------------------------------
#
# This is the leanest zone in the game and its bed does the work the mix does
# not: MUSIC_NOTES puts the truck stop's music floor at 0.16, the lowest in the
# run, precisely so that at rest you hear the rain.

AMB_TRUCK_S = 12.0


def _amb_truckstop_raw(n, sr=SR):
    L = AMB_TRUCK_S
    tt = t_axis(n, sr)

    # rain: a wide band, with the low half a separate layer so it does not
    # sound like a hiss generator
    rain = bandpass_fft(noise_burst(n), 400.0, 9500.0, sr=sr)
    rain *= _lfo(tt, 2, L, 0.0, 0.55, 1.0)
    sig = rain * 0.32 + bandpass_fft(noise_burst(n), 120.0, 900.0, sr=sr) * 0.25

    # the interstate, a long way off, never arriving
    road = _lp(noise_burst(n), 1100.0, sr=sr)
    road *= _lfo(tt, 1, L, 0.0, 0.45, 0.90) * _lfo(tt, 3, L, 2.2, 0.70, 1.0)
    sig += road * 0.30

    # a rig idling two rows over. 12 firings a second (144 whole cycles),
    # on a 58 Hz body (696).
    f_body = _whole_cycles(58.0, L, "truck stop diesel body")
    body = (osc(f_body, n, sr=sr, shape="saw") * 0.50
            + osc(_whole_cycles(29.0, L, "truck stop diesel sub"), n, sr=sr,
                  shape="sine") * 0.50)
    body = bandpass_fft(body, 30.0, 260.0, sr=sr)
    fire = _lfo(tt, int(12.0 * L), L, 0.0, 0.30, 1.0) ** 2
    sig += body * fire * 0.30
    sig += bandpass_fft(noise_burst(n), 900.0, 3400.0, sr=sr) * fire * 0.05

    # rain ON METAL -- awnings, trailer roofs, the pump canopy. Twelve ping
    # timbres, 540 hits, none of them long enough to be chopped at the wrap.
    pings = []
    for _ in range(12):
        d = int(float(rng.uniform(0.006, 0.016)) * sr)
        f = float(rng.uniform(2400.0, 6200.0))
        pings.append(modal_burst(d, [f, f * 1.87, f * 2.61], [0.9, 0.45, 0.22],
                                 [0.0025, 0.0018, 0.0012], sr=sr, noise_amp=0.40,
                                 noise_band=(3000.0, 9000.0), noise_dur_ms=2))

    def _ping():
        return pings[int(rng.integers(0, len(pings)))]

    _amb_scatter(sig, sr, L, 540, _ping, 0.03, 0.16)
    return sig


# ---------------------------------------------------------------------------
# LEG 8 -- THE 18TH GREEN, FIRST LIGHT
# sprinklers, palm fronds, cicadas. Warm and slow.
# ---------------------------------------------------------------------------
#
# The arrival deliberately rhymes with suburbia -- same sprinkler, same
# cicadas, 2,000 km south and no longer anybody's problem.

AMB_GREEN_S = 14.0


def _amb_green_raw(n, sr=SR):
    L = AMB_GREEN_S
    tt = t_axis(n, sr)

    sig = _lp(noise_burst(n), 480.0, sr=sr) * _lfo(tt, 1, L, 0.0, 0.30, 0.48)

    # palm fronds: broader and slower than corn, with real mid in it
    fronds = bandpass_fft(noise_burst(n), 900.0, 5200.0, sr=sr)
    fronds *= 0.20 + 0.80 * _slow_env(n, sr, 0.3, 5.0)
    fronds *= _lfo(tt, 2, L, 0.5, 0.25, 0.85)
    sig += fronds * 0.24

    # cicadas: 42 Hz shimmer, 588 whole cycles, warmer band than suburbia's
    cic = bandpass_fft(noise_burst(n), 3200.0, 6400.0, sr=sr)
    cic *= _lfo(tt, int(42.0 * L), L, 0.0, 0.30, 1.0)
    cic *= _lfo(tt, 2, L, 2.6, 0.35, 0.85)
    sig += cic * 0.22

    # fairway sprinklers: 63 impacts a loop, four sweeps
    def _spr_tick(_k):
        d = int(0.034 * sr)
        t = transient_click(d, band=(900.0, 3600.0), sr=sr, decay_frac=0.26)
        return t + _lp(t, 1200.0, sr=sr) * 0.60

    def _spr_level(t_in_loop):
        u = 0.5 + 0.5 * math.sin(2 * math.pi * (4.0 / L) * t_in_loop - 0.9)
        return 0.08 + 0.34 * (u ** 2)

    _amb_train(sig, sr, L, 63, _spr_tick, _spr_level)

    # a dry frond rattle, sparse
    def _rattle():
        d = int(float(rng.uniform(0.005, 0.018)) * sr)
        lo = float(rng.uniform(700.0, 2400.0))
        return transient_click(d, band=(lo, lo + float(rng.uniform(600.0, 2000.0))),
                               sr=sr, decay_frac=0.34)

    _amb_scatter(sig, sr, L, 70, _rattle, 0.02, 0.07)
    return sig


# ---------------------------------------------------------------------------

## Beds that ship a hand-written PCM .import. See write_import() above.
AMBIENCE_LOOPS = []


def _add_bed(name, raw_fn, seconds):
    sig = seamless_loop(raw_fn, seconds, xfade_ms=AMB_XFADE_MS)
    add_sound(name, sig, is_loop=True)
    AMBIENCE_LOOPS.append(name)


def gen_amb_beds():
    """Order matters only in that it must stay at the END of build_all() --
    every generator draws from the one module-level `rng`, so inserting a new
    one anywhere earlier silently re-renders every sound after it."""
    _add_bed("amb_suburbia_loop", _amb_suburbia_raw, AMB_SUBURBIA_S)
    _add_bed("amb_lake_night_loop", _amb_lake_night_raw, AMB_LAKE_S)
    _add_bed("amb_marsh_dawn_loop", _amb_marsh_dawn_raw, AMB_MARSH_S)
    _add_bed("amb_corn_loop", _amb_corn_raw, AMB_CORN_S)
    _add_bed("amb_truckstop_loop", _amb_truckstop_raw, AMB_TRUCK_S)
    _add_bed("amb_green_loop", _amb_green_raw, AMB_GREEN_S)


# ============================================================================
# ------------------------------  MAIN  --------------------------------------
# ============================================================================

def build_all():
    gen_honks()
    gen_hiss()
    gen_goose_grumble()
    gen_flaps()
    gen_waddles()
    gen_splash_in()
    gen_splash_small()
    gen_swim_loop()
    gen_wind_loop()
    gen_crash_cart()
    gen_crash_light()
    gen_crash_heavy()
    gen_smash()
    gen_thud_land()
    gen_tumble()
    gen_meow()
    gen_meow_frenzy()
    gen_human_yelps()
    gen_score_blips()
    gen_dose_charge_loop()
    gen_dose_commit_good()
    gen_dose_commit_bad()
    gen_unlock()
    gen_blackout()
    gen_heartbeat()
    gen_fx_wobble()
    gen_fx_jitter()
    gen_fx_slowmo()
    gen_fx_trip()
    gen_fx_warp()
    gen_amb_parking_lot()
    # NEW GENERATORS GO HERE, AT THE END, AND NOWHERE ELSE. Every sound in this
    # file draws from the single seeded `rng` at the top; inserting a call
    # earlier shifts that stream and silently re-renders every sound after the
    # insertion point. Appending here leaves the existing 40 byte-identical.
    gen_amb_beds()


def report_and_write():
    print("=" * 92)
    print(f"{'file':<24}{'dur(s)':>9}{'peak(dBFS)':>13}{'RMS(dBFS)':>12}{'notes':>20}")
    print("-" * 92)
    loop_rows = []
    for name, arr, is_loop in REGISTRY:
        path = os.path.join(OUT_DIR, name + ".wav")
        write_wav(path, arr)
        if name in AMBIENCE_LOOPS:
            write_import(path + ".import", name)
        dur = len(arr) / SR
        peak = np.max(np.abs(arr))
        rms = np.sqrt(np.mean(arr.astype(np.float64) ** 2))
        peak_db = lin_to_db(peak)
        rms_db = lin_to_db(rms)
        note = "LOOP" if is_loop else ""
        print(f"{name+'.wav':<24}{dur:9.3f}{peak_db:13.2f}{rms_db:12.2f}{note:>20}")
        if is_loop:
            loop_rows.append((name, arr))
    print("=" * 92)

    print()
    print("Loop seam verification (discontinuity at wrap point last->first sample)")
    print("=" * 92)
    hdr = f"{'file':<24}{'edge jump':>12}{'edge jump(dB rel pk)':>22}{'mean|d| start':>16}{'mean|d| end':>14}{'verdict':>10}"
    print(hdr)
    print("-" * 92)
    for name, arr in loop_rows:
        peak = np.max(np.abs(arr))
        edge_jump = float(arr[0] - arr[-1])
        edge_jump_db = lin_to_db(abs(edge_jump) / peak) if peak > 0 else float("-inf")
        k = 64
        start_d = np.mean(np.abs(np.diff(arr[:k + 1])))
        end_d = np.mean(np.abs(np.diff(arr[-(k + 1):])))
        typical_d = (start_d + end_d) / 2.0
        ok = abs(edge_jump) <= max(typical_d * 3.0, 1e-6)
        verdict = "OK" if ok else "CHECK"
        print(f"{name+'.wav':<24}{edge_jump:12.6f}{edge_jump_db:22.2f}{start_d:16.6f}{end_d:14.6f}{verdict:>10}")
    print("=" * 92)

    if AMBIENCE_LOOPS:
        print()
        print("Ambience beds: PCM .import sidecars written (compress/mode=0, "
              "edit/loop_mode=2 = FORWARD)")
        print("-" * 92)
        for name in AMBIENCE_LOOPS:
            print("  audio/%s.wav.import" % name)
        print("Run `godot --headless --path . --import` before these are usable.")


if __name__ == "__main__":
    build_all()
    report_and_write()
