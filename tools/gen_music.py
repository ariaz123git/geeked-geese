#!/usr/bin/env python3
"""
gen_music.py -- procedural ADAPTIVE MUSIC synthesis for "Geeked Geese"

Companion to gen_audio.py. Same rules: numpy + stdlib `wave` only, no sample
libraries, no downloads. Every note below is built from oscillators, filtered
noise, envelopes and FFT-domain filtering.

    "Soundtrack: Canadiana through a blown speaker. Fiddle, but wrong."

Writes 22.05kHz mono 16-bit PCM .wav STEMS into ../audio/, plus the matching
.wav.import files (PCM, forward-looping) so Godot doesn't QOA-compress the
seams we work so hard to make exact.

Why 22050 Hz: the entire aesthetic is a band-limited cassette played through a
dying speaker cone. Nothing in this score lives above ~7 kHz by design, so the
top half of a 44.1k spectrum would be storing silence at 2x the disk cost.

Why FFT filtering everywhere: an FFT applied to a buffer of exactly one loop
length treats that buffer as periodic. Every filter, every reverb, every EQ
move is therefore *circular* and preserves the loop seam bit-for-bit. The
recursive one-pole filters in gen_audio.py cannot do that (and are also a
Python for-loop, which on a 1M-sample buffer is not a plan).

Run:
    python3 gen_music.py

Prints: the stem table, the loop-seam report, a spectral analysis table
(band occupancy + centroid drift + RMS envelope variation over the loop), and
a per-zone full-layer-sum clip check.
"""

import math
import os
import wave

import numpy as np

# ============================================================================
# ---------------------------  GRID & TUNING  --------------------------------
# ============================================================================

SR = 22050                       # music sample rate (see docstring)
BPM = 84.0                       # one tempo for the entire score
BEAT = int(round(SR * 60.0 / BPM))   # 15750 samples EXACTLY at 22050/84
BAR = BEAT * 4                       # 63000
BARS = 16
LOOP_N = BAR * BARS                  # 1_008_000 samples = 45.714 s

assert SR * 60 % int(BPM) == 0, "pick a BPM that divides SR*60 exactly"

rng = np.random.default_rng(90210)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "audio"))
os.makedirs(OUT_DIR, exist_ok=True)


def midi_hz(m):
    """MIDI note -> Hz. A4 (69) = 440."""
    return 440.0 * (2.0 ** ((float(m) - 69.0) / 12.0))


def cents(hz, c):
    return hz * (2.0 ** (float(c) / 1200.0))


# Note-name sugar so the tune below reads like music instead of integers.
_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def N(name):
    """'F#4' -> midi number."""
    i = 1
    acc = 0
    if len(name) > 1 and name[1] in "#b":
        acc = 1 if name[1] == "#" else -1
        i = 2
    return 12 * (int(name[i:]) + 1) + _PC[name[0]] + acc


def at(bar, beat=0.0):
    """Bar (1-based) + beat (0-based float) -> sample index inside the loop."""
    return int(round((bar - 1) * BAR + beat * BEAT))


def beats(x):
    return int(round(x * BEAT))


# ============================================================================
# -------------------------  LOOP-SAFE PRIMITIVES  ---------------------------
# ============================================================================

def db_to_lin(db):
    return 10.0 ** (db / 20.0)


def lin_to_db(x):
    return 20.0 * math.log10(max(float(x), 1e-12))


def wrap_add(buf, sig, onset):
    """Add `sig` into the circular buffer `buf` starting at `onset`, wrapping
    around the end.

    THIS IS THE WHOLE TRICK. A note struck at bar 16 beat 4 whose tail runs
    two seconds long does not get truncated at the loop boundary -- its tail
    continues into bar 1 of the next pass. The loop point stops being an edit
    and becomes a bar line."""
    n = len(buf)
    sig = np.asarray(sig, dtype=np.float64)
    m = len(sig)
    if m == 0:
        return
    if m >= n:
        # Longer than the loop: fold it repeatedly. Rare but must not crash.
        k = int(math.ceil(m / n))
        pad = np.zeros(k * n)
        pad[:m] = sig
        buf += np.roll(pad.reshape(k, n).sum(axis=0), onset % n)
        return
    start = onset % n
    end = start + m
    if end <= n:
        buf[start:end] += sig
    else:
        head = n - start
        buf[start:] += sig[:head]
        buf[:end - n] += sig[head:]


def seam_null(x, n=4096):
    """Force the wrap discontinuity to EXACTLY zero, spreading the correction
    over 186 ms at each edge.

    gen_audio.py does this over 16 samples (`micro_declick`). Sixteen samples
    is fine for a noise-based SFX loop, but on a dark sustained pad a 16-sample
    correction is itself a ~1 kHz transient -- you fix the arithmetic and
    create the click. Spreading the same correction over 4096 samples puts its
    entire spectrum below about 5 Hz, which is not merely inaudible but below
    the range a speaker can reproduce. After this, every loop's edge jump is
    0.0 by construction and there is nothing left to argue about."""
    x = x.copy()
    n = min(n, len(x) // 4)
    if n <= 1:
        return x
    jump = float(x[0] - x[-1])
    taper = 0.5 * (1.0 + np.cos(np.linspace(0.0, np.pi, n)))   # 1 -> 0
    x[:n] -= (jump * 0.5) * taper
    x[-n:] += (jump * 0.5) * taper[::-1]
    return x


def periodic_noise(n, seed=None):
    """White noise that is EXACTLY periodic with period n, built by giving a
    flat magnitude spectrum uniformly random phase. Ordinary rng noise has a
    discontinuity at the seam; this does not, at any amplitude."""
    r = rng if seed is None else np.random.default_rng(seed)
    k = n // 2 + 1
    mag = np.ones(k)
    ph = r.uniform(0.0, 2 * np.pi, k)
    ph[0] = 0.0
    if n % 2 == 0:
        ph[-1] = 0.0
    spec = mag * np.exp(1j * ph)
    x = np.fft.irfft(spec, n)
    p = np.max(np.abs(x))
    return x / p if p > 0 else x


def _freqs(n, sr=SR):
    return np.fft.rfftfreq(n, d=1.0 / sr)


def snap_hz(f, n=LOOP_N, sr=SR):
    """Snap a frequency to the nearest one that completes a WHOLE number of
    cycles in `n` samples.

    Everything else in this file is circular by construction, but a free
    oscillator is not: 60 Hz over 45.714 s is 2742.857 cycles, so the mains
    hum arrives at the loop point 0.857 of a cycle out of phase with where it
    started -- a step, every single pass. The frequency grid here is
    sr/n = 0.0219 Hz, so snapping moves 60 Hz by at most 0.011 Hz. Inaudible,
    and it is the difference between a bed that loops and a bed that ticks."""
    k = max(round(float(f) * n / sr), 1)
    return k * sr / float(n)


def fft_shape(x, curve_fn, sr=SR):
    """Apply an arbitrary magnitude curve (function of a frequency array) in
    the FFT domain. Circular -> seam-preserving."""
    n = len(x)
    X = np.fft.rfft(x)
    return np.fft.irfft(X * curve_fn(_freqs(n, sr)), n)


def lowpass(x, fc, order=2, sr=SR):
    return fft_shape(x, lambda f: 1.0 / np.sqrt(1.0 + (np.maximum(f, 1e-6) / fc) ** (2 * order)), sr)


def highpass(x, fc, order=2, sr=SR):
    def c(f):
        r = (np.maximum(f, 1e-6) / fc) ** (2 * order)
        return np.sqrt(r / (1.0 + r))
    return fft_shape(x, c, sr)


def bandpass(x, lo, hi, order=2, sr=SR):
    return lowpass(highpass(x, lo, order, sr), hi, order, sr)


def peak_eq(x, fc, q, gain_db, sr=SR):
    """Resonant bell EQ. Used for instrument body resonances and for the
    single most important sound in this whole file: the 1.8 kHz honk of a
    cheap paper cone."""
    g = db_to_lin(gain_db) - 1.0

    def c(f):
        bw = fc / max(q, 0.05)
        return 1.0 + g / (1.0 + ((f - fc) / (bw * 0.5)) ** 2)
    return fft_shape(x, c, sr)


def tilt(x, pivot, db_per_oct, sr=SR):
    def c(f):
        o = np.log2(np.maximum(f, 20.0) / pivot)
        return db_to_lin(o * db_per_oct)
    return fft_shape(x, c, sr)


def circ_reverb(x, rt60, damp_hz=3000.0, predelay_ms=18.0, sr=SR, seed=7):
    """Reverb by circular convolution with an exponentially-decaying noise
    impulse response. Because the convolution is circular, the tail of the
    last chord wraps into the first -- a real room that does not reset at the
    loop point. This is the single biggest reason the cottage stems don't
    click."""
    n = len(x)
    ir_n = min(int(sr * rt60 * 1.15), n)
    r = np.random.default_rng(seed)
    ir = r.uniform(-1.0, 1.0, ir_n)
    tt = np.arange(ir_n) / float(sr)
    ir *= np.exp(-6.9078 * tt / max(rt60, 0.05))
    pd = int(sr * predelay_ms / 1000.0)
    ir[:pd] *= np.linspace(0.0, 1.0, pd) ** 3 if pd > 1 else 1.0
    ir = lowpass(ir, damp_hz, order=1, sr=sr)
    ir /= max(np.sqrt(np.sum(ir ** 2)), 1e-9)
    full = np.zeros(n)
    full[:ir_n] = ir
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(full), n)


def wow_flutter(x, wow_cycles=3, wow_ms=5.2, flutter_cycles=29, flutter_ms=0.55,
                scrape_cycles=181, scrape_ms=0.06):
    """Tape transport instability by resampling on periodic LFOs.

    Every LFO gets an INTEGER number of cycles across the loop, so the read
    pointer displacement is periodic with the loop and the seam survives.
    The cycle counts (3 / 29 / 181) are deliberately not multiples of 16
    bars: the pitch instability drifts against the bar grid all the way
    through the loop and never lands the same way twice inside one pass.
    That is an anti-repetition device disguised as a broken cassette."""
    n = len(x)
    t = np.arange(n, dtype=np.float64)
    ph = 2 * np.pi * t / n
    d = (wow_ms / 1000.0 * SR) * np.sin(wow_cycles * ph + 0.7)
    d += (wow_ms / 1000.0 * SR) * 0.45 * np.sin((wow_cycles * 2 + 1) * ph + 2.4)
    d += (flutter_ms / 1000.0 * SR) * np.sin(flutter_cycles * ph + 2.1)
    d += (scrape_ms / 1000.0 * SR) * np.sin(scrape_cycles * ph + 5.0)
    read = (t + d) % n
    i0 = np.floor(read).astype(np.int64)
    frac = read - i0
    i1 = (i0 + 1) % n
    return x[i0] * (1.0 - frac) + x[i1] * frac


def soft_clip(x, drive=1.6):
    d = max(drive, 1e-3)
    return np.tanh(x * d) / math.tanh(d)


def dropouts(n, count=3, depth_db=-2.6, width_s=0.35, seed=11):
    """A periodic gain envelope with a few shallow, smooth dips -- the crease
    in a tape that's been folded in a glovebox. Placed well inside the buffer
    so it can't touch the seam."""
    r = np.random.default_rng(seed)
    env = np.ones(n)
    w = int(width_s * SR)
    for _ in range(count):
        c = int(r.uniform(0.12, 0.88) * n)
        lo = max(c - w // 2, 0)
        hi = min(c + w // 2, n)
        m = hi - lo
        if m < 8:
            continue
        bump = 0.5 * (1.0 - np.cos(np.linspace(0, 2 * np.pi, m)))
        env[lo:hi] *= 1.0 + (db_to_lin(depth_db) - 1.0) * bump
    return env


def blown_speaker(x, cut=6200.0, drive=1.7, cone=4.0, hiss_db=-56.0,
                  wow=1.0, hp=90.0, seed=3):
    """The master chain. Everything the player hears goes through this.

    1. soft-clip (a small amp run slightly too hot)
    2. hard band-limit -- this is a speaker, not a monitor
    3. a resonant bump at 1.8 kHz: the honk of a paper cone with no surround
    4. a scoop at 380 Hz so the mids don't turn to porridge when layered
    5. wow & flutter by periodic resampling
    6. tape hiss + shallow dropouts
    """
    y = soft_clip(x, drive)
    y = highpass(y, hp, order=2)
    y = lowpass(y, cut, order=4)
    y = peak_eq(y, 1800.0, 1.1, cone)
    y = peak_eq(y, 380.0, 0.9, -2.2)
    if wow > 0.0:
        y = wow_flutter(y, wow_ms=5.2 * wow, flutter_ms=0.55 * wow,
                        scrape_ms=0.06 * wow)
    y = y * dropouts(len(y), count=3, depth_db=-2.6 * wow, seed=seed)
    hiss = periodic_noise(len(y), seed=seed * 977 + 1)
    hiss = tilt(hiss, 3000.0, 2.2)
    hiss = lowpass(hiss, 7200.0, order=2)
    hiss /= max(np.sqrt(np.mean(hiss ** 2)), 1e-9)
    y = y + hiss * db_to_lin(hiss_db)
    return y


# ============================================================================
# ------------------------------  ENVELOPES  ---------------------------------
# ============================================================================

def env_ar(n, attack_s, release_s, curve=2.0):
    a = max(int(attack_s * SR), 1)
    e = np.ones(n)
    a = min(a, n)
    e[:a] = np.linspace(0.0, 1.0, a) ** (1.0 / curve)
    tt = np.arange(n) / float(SR)
    e *= np.exp(-tt / max(release_s, 1e-4))
    return e * tail_out(n)


def tail_out(n, ms=6.0):
    """A raised-cosine ride to exactly zero over the last few milliseconds.

    An exponential decay truncated at the end of its buffer is still at 10-20%
    amplitude when the array stops, and that step is a click -- one per note,
    scattered through the stem. Six milliseconds is below the ear's temporal
    resolution for a level change and costs nothing musically."""
    k = min(int(ms * SR / 1000.0), n)
    e = np.ones(n)
    if k > 1:
        e[-k:] = 0.5 * (1.0 + np.cos(np.linspace(0.0, np.pi, k)))
    return e


def env_bow(n, attack_s=0.045, sustain_s=0.4, release_s=0.18):
    """Bowed articulation: soft attack, a body, then a release that isn't an
    exponential (a bow leaving the string stops rather than decays)."""
    a = min(max(int(attack_s * SR), 1), n)
    r = min(max(int(release_s * SR), 1), n - a if n > a else 1)
    s = max(n - a - r, 0)
    parts = [np.linspace(0.0, 1.0, a) ** 0.7]
    if s > 0:
        # Slight swell then settle -- a real bow is never a flat sustain.
        tt = np.linspace(0.0, 1.0, s)
        parts.append(1.0 + 0.12 * np.sin(np.pi * tt) - 0.10 * tt)
    if r > 0:
        parts.append(np.linspace(parts[-1][-1] if s > 0 else 1.0, 0.0, r) ** 1.4)
    e = np.concatenate(parts)
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n] * tail_out(n)


# ============================================================================
# -----------------------------  INSTRUMENTS  --------------------------------
# ============================================================================

def fiddle(hz, dur_s, level=1.0, detune_c=0.0, bright=1.0, bow=1.0,
           drift=1.0, vib=1.0, seed=None):
    """Detuned bowed string.

    Three sawtooth stacks at +/-6 and +/-11 cents (a real fiddle's own body
    resonances beat like this; two saws sound like a synth, three sound like
    rosin), a bandpassed bow-noise transient at the attack, a slow pitch drift
    that starts LATE (the intonation wobbles once the note has been held --
    which is exactly the thing an amateur does), and three body formants."""
    n = max(int(dur_s * SR), 64)
    r = rng if seed is None else np.random.default_rng(seed)
    f0 = cents(hz, detune_c)
    tt = np.arange(n) / float(SR)

    # Pitch track: late-onset vibrato + a slow sag. Both in cents.
    vib_on = np.clip((tt - 0.16) / 0.25, 0.0, 1.0)
    c_track = (18.0 * vib * vib_on * np.sin(2 * np.pi * 5.1 * tt + r.uniform(0, 6.28))
               - 9.0 * drift * np.clip((tt - 0.30) / 0.9, 0.0, 1.0)
               + 4.0 * drift * np.sin(2 * np.pi * 0.7 * tt + r.uniform(0, 6.28)))
    f_track = f0 * (2.0 ** (c_track / 1200.0))

    sig = np.zeros(n)
    for det, amp in ((-11.0, 0.55), (-6.0, 0.8), (0.0, 1.0), (6.0, 0.8), (11.0, 0.5)):
        ff = f_track * (2.0 ** (det / 1200.0))
        ph = 2 * np.pi * np.cumsum(ff) / SR + r.uniform(0, 6.28)
        frac = (ph / (2 * np.pi)) % 1.0
        sig += amp * (2.0 * frac - 1.0)
    sig /= 3.65

    # Bow-noise transient. Loud enough to hear the rosin; on the "wrong" notes
    # the caller pushes `bow` up and it becomes a scrape.
    bn = min(int(0.055 * SR), n)
    if bn > 16:
        noise = r.uniform(-1, 1, bn)
        noise = bandpass(noise, 1400.0, 5200.0, order=2)
        noise *= np.exp(-np.arange(bn) / (bn * 0.22))
        sig[:bn] += noise * 0.30 * bow

    sig *= env_bow(n, attack_s=0.040 / max(bow, 0.4), sustain_s=dur_s, release_s=0.16)

    # Body: an f-hole thump plus two upper formants. This is what makes it a
    # box with strings on it rather than a sawtooth.
    sig = peak_eq(sig, 290.0, 1.6, 5.0)
    sig = peak_eq(sig, 720.0, 2.2, 3.5)
    sig = peak_eq(sig, 1550.0 * bright, 2.0, 4.0)
    sig = highpass(sig, max(hz * 0.72, 150.0), order=2)
    sig = lowpass(sig, 4600.0 * bright, order=3)
    return sig * level


def upright_bass(hz, dur_s, level=1.0, seed=None):
    """Plucked upright. Fundamental + a little 2nd/3rd, a pitch blip at the
    attack (the string is pulled sharp before it settles), finger noise, and
    a wooden body thump an octave and a bit below."""
    n = max(int(dur_s * SR), 64)
    r = rng if seed is None else np.random.default_rng(seed)
    tt = np.arange(n) / float(SR)
    blip = 1.0 + 0.055 * np.exp(-tt / 0.030)
    f = hz * blip
    ph = 2 * np.pi * np.cumsum(f) / SR

    sig = np.sin(ph) * 1.0
    sig += 0.28 * np.sin(2 * ph) * np.exp(-tt / 0.25)
    sig += 0.11 * np.sin(3 * ph) * np.exp(-tt / 0.12)
    sig *= env_ar(n, 0.006, max(dur_s * 0.55, 0.35), curve=1.4)

    fn = min(int(0.03 * SR), n)
    if fn > 8:
        fnoise = r.uniform(-1, 1, fn)
        fnoise = bandpass(fnoise, 300.0, 1600.0, order=2)
        fnoise *= np.exp(-np.arange(fn) / (fn * 0.18))
        sig[:fn] += fnoise * 0.14

    body = np.sin(2 * np.pi * 78.0 * tt) * np.exp(-tt / 0.09) * 0.22
    sig += body
    sig = lowpass(sig, 1500.0, order=3)
    return sig * level


def brush(dur_s, level=1.0, swish=1.0, lo=260.0, hi=5200.0, seed=None):
    """Brushed snare. A swish is a SLOW attack -- that's the entire difference
    between a brush and a stick, and it's why this score can have a backbeat
    without ever sounding like a drum machine."""
    n = max(int(dur_s * SR), 64)
    r = rng if seed is None else np.random.default_rng(seed)
    noise = r.uniform(-1, 1, n)
    noise = bandpass(noise, lo, hi, order=2)
    a = min(int(0.030 * swish * SR), n - 1)
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a) ** 1.5
    e *= np.exp(-np.arange(n) / float(SR) / (0.11 * swish + 0.03))
    e *= tail_out(n, 3.0)
    sig = noise * e
    sig += np.sin(2 * np.pi * 186.0 * np.arange(n) / SR) * np.exp(-np.arange(n) / SR / 0.05) * 0.16
    return sig * level


def rim(dur_s=0.10, level=1.0, f=(430.0, 1290.0, 2380.0), seed=None):
    """Rimshot / dock knock / shopping-cart wheel. Modal, dry, over instantly."""
    n = max(int(dur_s * SR), 32)
    r = rng if seed is None else np.random.default_rng(seed)
    tt = np.arange(n) / float(SR)
    sig = np.zeros(n)
    for i, ff in enumerate(f):
        sig += (0.9 ** i) * np.sin(2 * np.pi * ff * tt + r.uniform(0, 6.28)) * np.exp(-tt / (0.045 / (i + 1)))
    sig *= tail_out(n, 2.0)
    cn = min(int(0.004 * SR), n)
    click = r.uniform(-1, 1, cn) * np.exp(-np.arange(cn) / (cn * 0.3))
    sig[:cn] += bandpass(click, 1800.0, 6000.0, order=1) * 0.5
    return sig * level


def accordion(hz, dur_s, level=1.0, reeds=4, spread_c=9.0, wheeze=1.0,
              bright=1.0, seed=None):
    """Wheezing accordion / harmonium.

    Musette tuning is literally several reeds deliberately detuned against
    each other, so square waves at +/-spread cents is not an approximation --
    it is the instrument. On top: a bellows swell, a 4.6 Hz wobble (the arm),
    and a valve-air noise bed that swells WITH the note, which is the wheeze."""
    n = max(int(dur_s * SR), 64)
    r = rng if seed is None else np.random.default_rng(seed)
    tt = np.arange(n) / float(SR)
    sig = np.zeros(n)
    offs = np.linspace(-spread_c, spread_c, reeds)
    for i, o in enumerate(offs):
        f = cents(hz, o + r.uniform(-1.5, 1.5))
        ph = 2 * np.pi * f * tt + r.uniform(0, 6.28)
        # Slightly-asymmetric pulse, not a pure square: reeds aren't 50% duty.
        duty = 0.42 + 0.06 * i / max(reeds - 1, 1)
        sig += np.where(((ph / (2 * np.pi)) % 1.0) < duty, 1.0, -1.0)
    sig /= reeds

    bellows = env_ar(n, 0.16, max(dur_s * 0.9, 0.5), curve=1.8)
    bellows *= 1.0 + 0.09 * wheeze * np.sin(2 * np.pi * 4.6 * tt + r.uniform(0, 6.28))
    sig *= bellows

    air = r.uniform(-1, 1, n)
    air = bandpass(air, 900.0, 4200.0, order=2) * bellows * 0.085 * wheeze
    sig += air

    sig = peak_eq(sig, 520.0, 1.2, 3.0)
    # A 4 dB scoop right where the fiddle's fundamentals and body formant sit
    # (D4-D5 plus the 1.5 kHz box resonance). The reeds keep their bite below
    # it and their air above it; the tune gets a hole to sit in. This is the
    # difference between "accordion and fiddle" and "porridge".
    sig = peak_eq(sig, 1350.0, 1.0, -4.0)
    sig = lowpass(sig, 1900.0 * bright, order=3)
    sig = highpass(sig, max(hz * 0.85, 70.0), order=1)
    return sig * level


def bell(hz, dur_s, level=1.0, seed=None):
    """Glockenspiel-ish. Inharmonic partials, no sustain. Used sparingly --
    bells are the fastest way to make a score sound 'quirky', which is the
    one thing this score must never sound like."""
    n = max(int(dur_s * SR), 64)
    r = rng if seed is None else np.random.default_rng(seed)
    tt = np.arange(n) / float(SR)
    sig = np.zeros(n)
    for mult, amp, dec in ((1.0, 1.0, 0.9), (2.76, 0.42, 0.45), (5.40, 0.20, 0.22)):
        sig += amp * np.sin(2 * np.pi * hz * mult * tt + r.uniform(0, 6.28)) * np.exp(-tt / dec)
    sig *= env_ar(n, 0.002, dur_s, curve=1.0) * tail_out(n, 8.0)
    return sig * level


def mains_hum(n, hz=60.0, level=1.0):
    """A fluorescent ballast. 60 Hz sits between A#1 (58.27) and B1 (61.74) --
    it is a quarter-tone out of ANY key, which is why every big-box store
    sounds faintly nauseating. Here it is part of the harmony, permanently
    wrong, and it is the single most Canadian-strip-mall sound available."""
    hz = snap_hz(hz, n)
    tt = np.arange(n) / float(SR)
    sig = np.sin(2 * np.pi * hz * tt)
    sig += 0.40 * np.sin(2 * np.pi * hz * 2 * tt + 1.1)
    sig += 0.16 * np.sin(2 * np.pi * hz * 3 * tt + 2.3)
    sig += 0.07 * np.sin(2 * np.pi * hz * 6 * tt + 0.4)
    # Ballast buzz: a faint band of noise riding on the hum's rectified shape.
    buzz = periodic_noise(n, seed=4242)
    buzz = bandpass(buzz, 2000.0, 5000.0, order=2)
    sig += buzz * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * hz * tt))) * 0.09
    return sig * level


def mower(n, hz=54.0, level=1.0):
    """A two-stroke small engine three houses over. Buzzy harmonic stack with
    a slow governor hunt, tuned near A1 so it is technically in key. The
    lawnmower IS the suburban drone -- pretending otherwise would be a lie."""
    hz = snap_hz(hz, n)
    t = np.arange(n, dtype=np.float64)
    ph_lfo = 2 * np.pi * t / n
    # Governor hunting: integer LFO cycles and a snapped carrier, so the total
    # accumulated phase over the loop is an exact multiple of 2*pi.
    f = hz * (1.0 + 0.010 * np.sin(7 * ph_lfo) + 0.005 * np.sin(23 * ph_lfo + 1.0))
    ph = 2 * np.pi * np.cumsum(f) / SR
    sig = np.zeros(n)
    for k, a in ((1, 1.0), (2, 0.62), (3, 0.40), (4, 0.24), (5, 0.16), (7, 0.09)):
        sig += a * np.sin(k * ph + k * 0.7)
    sig /= 2.5
    # Exhaust chuff, amplitude-modulated by the firing cycle.
    chuff = periodic_noise(n, seed=808)
    chuff = bandpass(chuff, 300.0, 2600.0, order=2)
    sig += chuff * (0.5 + 0.5 * np.sin(ph)) * 0.22
    sig = lowpass(sig, 2400.0, order=2)
    return sig * level


def sub_drone(n, hz, level=1.0, beat_hz=0.14):
    """Two sines a hair apart so they beat slowly. Lake water at night.
    Both partials snapped to the loop's frequency grid, and their difference
    is therefore an exact number of beats per loop as well."""
    hz = snap_hz(hz, n)
    tt = np.arange(n) / float(SR)
    cyc = max(int(round(beat_hz * n / SR)), 1)
    f2 = snap_hz(hz + cyc * SR / float(n), n)
    return (np.sin(2 * np.pi * hz * tt) + np.sin(2 * np.pi * f2 * tt)) * 0.5 * level


# ============================================================================
# -----------------------------  THE MUSIC  ----------------------------------
# ============================================================================
#
# KEY: D mixolydian (D E F# G A B C).  The flat 7 is the whole identity --
# it is the mode of every fiddle tune ever played in a Legion hall, and it
# refuses to cadence. There is exactly ONE C# in the zone loops (bar 16 is an
# Asus4: no third at all), so the dominant never resolves. The MIGRATION set
# is where the C finally becomes C# and the V-I lands. Two zones of being
# denied a cadence is what makes forty-five seconds of flying feel like the
# only sincere thing in the game.
#
# 16 bars @ 84 BPM = 45.714 s. Structure inside the loop:
#   bars  1-8   A   the tune, stated then restated an octave up
#   bars  9-14  B   drops to B minor, and the melody GOES AWAY for two bars
#   bars 15-16  T   turnaround, unresolved, back to D
# That internal contrast is the fix for "a 30-second loop that feels like an
# 8-second one repeated": a listener who can hear the loop point can also
# hear that bars 9-14 are not bars 1-8.

# Bar -> (bass root midi, chord tone midis)
PROG = [
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),     # 1  D
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),     # 2  D
    (N("C2"), [N("C3"), N("E3"), N("G3"), N("C4")]),      # 3  C
    (N("G2"), [N("G2"), N("B2"), N("D3"), N("G3")]),      # 4  G
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),     # 5  D
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),     # 6  D
    (N("C2"), [N("C3"), N("E3"), N("G3"), N("C4")]),      # 7  C
    (N("G2"), [N("G2"), N("B2"), N("D3"), N("G3")]),      # 8  G
    (N("B1"), [N("B2"), N("D3"), N("F#3"), N("B3")]),     # 9  Bm
    (N("B1"), [N("B2"), N("D3"), N("F#3"), N("B3")]),     # 10 Bm
    (N("G2"), [N("G2"), N("B2"), N("D3"), N("G3")]),      # 11 G
    (N("A2"), [N("A2"), N("E3"), N("A3"), N("C#4")]),     # 12 A   <- lone C#
    (N("B1"), [N("B2"), N("D3"), N("F#3"), N("B3")]),     # 13 Bm
    (N("G2"), [N("G2"), N("B2"), N("D3"), N("G3")]),      # 14 G
    (N("C2"), [N("C3"), N("E3"), N("G3"), N("C4")]),      # 15 C
    (N("A2"), [N("A2"), N("D3"), N("E3"), N("A3")]),      # 16 Asus4 (no third)
]

# The tune. (bar, beat, note, beats_long, detune_cents, bow_scrape)
# The detune column is where "fiddle, but wrong" actually lives: four notes
# across 45 seconds are 16-30 cents flat. Not enough to read as a mistake in
# the file -- enough to read as a person.
TUNE = [
    (1, 0.0, "A4", 1.0, 0, 1.0), (1, 1.0, "F#4", 1.0, 0, 0.9), (1, 2.0, "D4", 2.0, 0, 0.8),
    (2, 0.0, "E4", 1.0, 0, 0.9), (2, 1.0, "F#4", 1.0, 0, 0.9), (2, 2.0, "A4", 1.0, 0, 1.0),
    (2, 3.0, "F#4", 1.0, 0, 0.9),
    (3, 0.0, "E4", 1.0, 0, 0.9), (3, 1.0, "C4", 1.0, -16, 1.2), (3, 2.0, "E4", 2.0, 0, 0.8),
    (4, 0.0, "D4", 1.0, 0, 0.9), (4, 1.0, "B3", 1.0, 0, 0.9), (4, 2.0, "G3", 2.0, 0, 0.8),
    (5, 0.0, "A4", 1.0, 0, 1.0), (5, 1.0, "F#4", 1.0, 0, 0.9), (5, 2.0, "D5", 2.0, -22, 1.6),
    (6, 0.25, "C5", 0.75, 0, 1.3), (6, 1.0, "A4", 1.0, 0, 0.9), (6, 2.0, "F#4", 1.0, 0, 0.9),
    (6, 3.0, "A4", 1.0, 0, 0.9),
    (7, 0.0, "G4", 1.0, 0, 0.9), (7, 1.0, "E4", 1.0, 0, 0.9), (7, 2.0, "C4", 2.0, 0, 0.8),
    (8, 0.0, "D4", 2.0, 0, 0.8), (8, 2.0, "A4", 2.0, -30, 1.1),
    # --- B: minor, sparse, and bars 12 is SILENT ---
    (9, 2.0, "F#4", 2.0, 0, 0.7),
    (10, 0.0, "D4", 1.0, 0, 0.8), (10, 1.0, "B3", 3.0, 0, 0.7),
    (11, 0.0, "G4", 1.0, 0, 0.9), (11, 1.0, "F#4", 1.0, 0, 0.9), (11, 2.0, "E4", 2.0, 0, 0.8),
    # bar 12: nothing. Two full bars of no melody, once every 45 seconds.
    (13, 0.0, "B4", 1.0, 0, 1.1), (13, 1.0, "A4", 1.0, 0, 1.0), (13, 2.0, "F#4", 1.0, 0, 0.9),
    (13, 3.0, "D4", 1.0, -18, 1.0),
    (14, 0.0, "G4", 2.0, 0, 0.8), (14, 2.0, "B4", 2.0, 0, 0.9),
    (15, 0.0, "C5", 1.0, 0, 1.0), (15, 1.0, "B4", 1.0, 0, 0.9), (15, 2.0, "A4", 2.0, 0, 0.8),
    (16, 0.0, "A4", 1.0, 0, 0.9), (16, 2.0, "E4", 2.0, 0, 0.7),
]

# The migration tune: the same melody in half-time, in tune, with the bar-16
# Asus4 replaced by a real A7 -> D. This is the only place the score means it.
#
# The fourth column is DYNAMIC, and it is doing structural work. Bars 1-8 are
# played at roughly half strength with a slower bow; the flight starts small.
# Bar 8 is a full bar of rest -- the only silence in the melody -- and then
# bars 9-16 are the same tune committed to. A loop that gets louder and then
# resets is the classic loop-fatigue trap, so the reset happens at the ONE
# point where it reads as a breath instead of a rewind: after the rest.
TUNE_MIG = [
    (1, 0.0, "A4", 2.0, 0.55), (1, 2.0, "F#4", 2.0, 0.55),
    (2, 0.0, "D4", 4.0, 0.60),
    (3, 0.0, "E4", 2.0, 0.60), (3, 2.0, "G4", 2.0, 0.62),
    (4, 0.0, "F#4", 4.0, 0.66),
    (5, 0.0, "A4", 2.0, 0.72), (5, 2.0, "D5", 2.0, 0.78),
    (6, 0.0, "C5", 4.0, 0.78),
    (7, 0.0, "B4", 2.0, 0.80), (7, 2.0, "A4", 2.0, 0.74),
    # bar 8: rest. One whole bar of no melody, at the exact midpoint.
    (9, 0.0, "F#4", 2.0, 0.95), (9, 2.0, "E4", 2.0, 0.95),
    (10, 0.0, "D4", 4.0, 1.00),
    (11, 0.0, "G4", 2.0, 1.00), (11, 2.0, "B4", 2.0, 1.00),
    (12, 0.0, "C#5", 4.0, 1.00),                    # the leading tone, at last
    (13, 0.0, "D5", 4.0, 1.05),                     # ...and it resolves
    (14, 0.0, "B4", 2.0, 1.00), (14, 2.0, "G4", 2.0, 0.95),
    (15, 0.0, "A4", 4.0, 0.90),
    (16, 0.0, "A4", 2.0, 0.80), (16, 2.0, "C#5", 2.0, 0.86),  # V, leaning home
]

PROG_MIG = [
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),
    (N("A1"), [N("A2"), N("C#3"), N("E3"), N("A3")]),
    (N("A1"), [N("A2"), N("C#3"), N("E3"), N("A3")]),
    (N("B1"), [N("B2"), N("D3"), N("F#3"), N("B3")]),
    (N("B1"), [N("B2"), N("D3"), N("F#3"), N("B3")]),
    (N("G2"), [N("G2"), N("B2"), N("D3"), N("G3")]),
    (N("G2"), [N("G2"), N("B2"), N("D3"), N("G3")]),
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),
    (N("G2"), [N("G2"), N("B2"), N("D3"), N("G3")]),
    (N("A1"), [N("A2"), N("C#3"), N("E3"), N("G3")]),   # A7
    (N("D2"), [N("D3"), N("F#3"), N("A3"), N("D4")]),   # I. Landed.
    (N("G2"), [N("G2"), N("B2"), N("D3"), N("G3")]),
    (N("A1"), [N("A2"), N("C#3"), N("E3"), N("A3")]),
    (N("A1"), [N("A2"), N("C#3"), N("E3"), N("G3")]),
]


def blank():
    return np.zeros(LOOP_N)


# ------------------------------------------------------------------ layers

def pad_layer(prog, level=0.10, reeds=4, spread=9.0, wheeze=1.0, bright=1.0,
              octave=0, seed=100, hold=1.0):
    """Sustained accordion/harmonium chords, one per bar, each ringing a
    little past the bar line so the harmony overlaps instead of switching."""
    buf = blank()
    for i, (_root, tones) in enumerate(prog):
        dur = (BAR / SR) * hold
        for j, m in enumerate(tones):
            v = level * (1.0 - 0.13 * j)
            buf_sig = accordion(midi_hz(m + 12 * octave), dur, level=v,
                                reeds=reeds, spread_c=spread, wheeze=wheeze,
                                bright=bright, seed=seed + i * 17 + j)
            wrap_add(buf, buf_sig, at(i + 1))
    return buf


def bass_layer(prog, pattern, level=0.42, seed=200, octave=0):
    """pattern: list of (beat, scale_step) per bar. step 0 = root, 7 = fifth,
    12 = octave, -5 = fifth below."""
    buf = blank()
    for i, (root, _tones) in enumerate(prog):
        for k, (b, step, ln) in enumerate(pattern):
            m = root + step + 12 * octave
            wrap_add(buf, upright_bass(midi_hz(m), ln * BEAT / SR, level=level,
                                       seed=seed + i * 31 + k), at(i + 1, b))
    return buf


def tune_layer(tune, level=0.30, octave=0, bright=1.0, seed=300,
               interval=0, late=0.0, drift=1.0, vib=1.0):
    buf = blank()
    for k, ev in enumerate(tune):
        bar, beat, name, ln, det, bw = ev
        m = N(name) + 12 * octave + interval
        wrap_add(buf, fiddle(midi_hz(m), ln * BEAT / SR, level=level,
                             detune_c=det, bright=bright, bow=bw, drift=drift,
                             vib=vib, seed=seed + k * 13),
                 at(bar, beat + late))
    return buf


# ============================================================================
# -------------------------------  STEMS  ------------------------------------
# ============================================================================

STEMS = {}   # name -> (array, is_loop)
META = {}    # name -> dict


def add_stem(name, arr, zone, role, is_loop=True, note=""):
    arr = np.asarray(arr, dtype=np.float64)
    if is_loop:
        arr = seam_null(arr)
    STEMS[name] = (arr, is_loop)
    META[name] = {"zone": zone, "role": role, "note": note}


# ------------------------------------------------- ZONE 1: STRIP MALL
# Flat, plodding, fluorescent. The bass never walks. The brush never lifts.
# Nothing in this arrangement wants to be anywhere.

def build_strip_mall():
    # BASE ---------------------------------------------------------------
    base = pad_layer(PROG, level=0.085, reeds=4, spread=10.0, wheeze=1.0,
                     bright=0.85, seed=1000, hold=1.05)
    base += mains_hum(LOOP_N, 60.0, 0.055)
    base = lowpass(base, 1900.0, order=2)
    base = blown_speaker(base, cut=5200.0, drive=1.5, cone=3.0, hiss_db=-58.0, seed=3)

    # RHYTHM -------------------------------------------------------------
    # Bass on 1 and 3 only. That is the sound of a man who is being paid.
    rhythm = bass_layer(PROG, [(0.0, 0, 1.9), (2.0, 0, 1.9)], level=0.40, seed=1100)
    for i in range(BARS):
        # Top rolled off to 3.6 kHz: the backbeat brush must sit UNDER the
        # hi layer's shakers, or turning intensity up just makes it louder
        # instead of making it busier.
        wrap_add(rhythm, brush(0.44, level=0.19, swish=1.15, hi=3600.0,
                               seed=1200 + i * 3), at(i + 1, 1.0))
        wrap_add(rhythm, brush(0.44, level=0.18, swish=1.15, hi=3600.0,
                               seed=1201 + i * 3), at(i + 1, 3.0))
        # One rim tick per bar, on the "and" of 3: a cart with a bad wheel.
        # It vanishes for bars 9-12, because the B section is where the joke
        # stops. Four bars an ostinato is absent is four bars it gets back.
        if not (8 <= i < 12):
            wrap_add(rhythm, rim(0.10, level=0.085, seed=1300 + i), at(i + 1, 2.5))
    rhythm = peak_eq(rhythm, 600.0, 0.8, -4.0)   # carve room for the pad
    rhythm = blown_speaker(rhythm, cut=6000.0, drive=1.6, cone=3.5, hiss_db=-62.0, seed=5)

    # LEAD ---------------------------------------------------------------
    # Played 40 ms behind the beat, all the way through. Not swing -- drag.
    lead = tune_layer(TUNE, level=0.26, bright=0.92, seed=1400,
                      late=0.038 * SR / BEAT, drift=1.2, vib=0.9)
    lead = highpass(lead, 220.0, order=2)
    lead = blown_speaker(lead, cut=4800.0, drive=1.8, cone=4.5, hiss_db=-64.0, seed=7)

    # HI (intensity) -----------------------------------------------------
    hi = blank()
    for i in range(BARS):
        for e in range(8):
            wrap_add(hi, brush(0.16, level=0.080 if e % 2 else 0.108, swish=0.55,
                               lo=900.0, hi=7000.0, seed=1500 + i * 8 + e),
                     at(i + 1, e * 0.5))
        for s in range(16):
            wrap_add(hi, brush(0.055, level=0.044, swish=0.3, lo=2600.0, hi=8000.0,
                               seed=1700 + i * 16 + s), at(i + 1, s * 0.25))
    # A fifth above the tune, only in the second half: the loop grows.
    hi += tune_layer([e for e in TUNE if e[0] >= 5], level=0.15, interval=7,
                     bright=1.15, seed=1900, late=0.038 * SR / BEAT, vib=1.3)
    hi = highpass(hi, 800.0, order=2)
    hi = blown_speaker(hi, cut=7000.0, drive=1.4, cone=2.0, hiss_db=-66.0, seed=9)

    return {"base": base, "rhythm": rhythm, "lead": lead, "hi": hi}


# ------------------------------------------------- ZONE 2: SUBURBIA
# Warmer, brighter, and there is a mower going somewhere. The bass finally
# moves. Sprinklers are the hi-hat.

def build_suburbia():
    base = pad_layer(PROG, level=0.080, reeds=5, spread=7.0, wheeze=0.75,
                     bright=1.25, seed=2000, hold=1.1)
    base += mower(LOOP_N, 54.0, 0.085)
    base = tilt(base, 500.0, 0.7)
    base = lowpass(base, 2300.0, order=2)
    base = blown_speaker(base, cut=6000.0, drive=1.5, cone=3.0, hiss_db=-58.0, seed=13)

    # Bass actually walks: root, fifth-below, root, sixth. Suburbia has a
    # little more going on than the parking lot, and only a little.
    rhythm = bass_layer(PROG, [(0.0, 0, 1.0), (1.5, -5, 0.6), (2.0, 0, 1.0), (3.0, 7, 0.9)],
                        level=0.36, seed=2100)
    for i in range(BARS):
        wrap_add(rhythm, brush(0.42, level=0.19, swish=1.0, hi=3800.0,
                               seed=2200 + i * 4), at(i + 1, 1.0))
        wrap_add(rhythm, brush(0.42, level=0.18, swish=1.0, hi=3800.0,
                               seed=2201 + i * 4), at(i + 1, 3.0))
        wrap_add(rhythm, brush(0.13, level=0.065, swish=0.5, hi=3800.0,
                               seed=2202 + i * 4), at(i + 1, 3.66))
    # Sprinkler: a tick every 3 eighths against a 4/4 bar. It phases through
    # the bar over 3 bars and comes back -- free variation, zero notes.
    step = 0
    while step * 1.5 < BARS * 4:
        wrap_add(rhythm, rim(0.07, level=0.045, f=(1100.0, 2600.0, 4300.0),
                             seed=2400 + step), at(1, step * 1.5))
        step += 1
    rhythm = peak_eq(rhythm, 620.0, 0.8, -3.5)
    rhythm = blown_speaker(rhythm, cut=6600.0, drive=1.5, cone=3.0, hiss_db=-62.0, seed=15)

    lead = tune_layer(TUNE, level=0.25, bright=1.18, seed=2500,
                      late=0.012 * SR / BEAT, drift=0.85, vib=1.15)
    # Grace notes: a scoop into every downbeat of the A section. Ornament, not
    # a different tune.
    for k, ev in enumerate(TUNE):
        bar, beat, name, ln, det, bw = ev
        if beat == 0.0 and ln >= 1.0 and bar <= 8:
            wrap_add(lead, fiddle(midi_hz(N(name) - 2), 0.11, level=0.13,
                                  bright=1.2, bow=1.2, seed=2600 + k),
                     at(bar, beat) - int(0.10 * SR))
    lead = highpass(lead, 230.0, order=2)
    lead = blown_speaker(lead, cut=5600.0, drive=1.7, cone=4.0, hiss_db=-64.0, seed=17)

    hi = blank()
    for i in range(BARS):
        for e in range(8):
            wrap_add(hi, brush(0.14, level=0.072 if e % 2 else 0.100, swish=0.5,
                               lo=1100.0, hi=7500.0, seed=2700 + i * 8 + e),
                     at(i + 1, e * 0.5))
        wrap_add(hi, rim(0.09, level=0.075, f=(760.0, 1900.0, 3400.0), seed=2800 + i), at(i + 1, 1.0))
        wrap_add(hi, rim(0.09, level=0.075, f=(760.0, 1900.0, 3400.0), seed=2801 + i), at(i + 1, 3.0))
    # Bells on chord tones, bars 5-8 and 13-16 only.
    for i, (_root, tones) in enumerate(PROG):
        if not (4 <= i < 8 or 12 <= i < 16):
            continue
        for j, m in enumerate(tones[1:3]):
            wrap_add(hi, bell(midi_hz(m + 24), 0.9, level=0.045, seed=2900 + i * 5 + j),
                     at(i + 1, j * 2.0))
    hi += tune_layer([e for e in TUNE if e[0] >= 5], level=0.14, interval=7,
                     bright=1.3, seed=3000, vib=1.4)
    hi = highpass(hi, 850.0, order=2)
    hi = blown_speaker(hi, cut=7400.0, drive=1.3, cone=2.0, hiss_db=-66.0, seed=19)

    return {"base": base, "rhythm": rhythm, "lead": lead, "hi": hi}


# ------------------------------------------------- ZONE 3: COTTAGE, NIGHT
# Sparse, reverberant, lonely. Mostly bass and a fiddle a long way off across
# the water. The tape damage backs off here -- at night you notice the room,
# not the speaker.

def build_cottage():
    base = pad_layer(PROG, level=0.055, reeds=3, spread=5.0, wheeze=0.45,
                     bright=0.65, octave=-1, seed=4000, hold=1.6)
    base = lowpass(base, 1150.0, order=3)
    base = circ_reverb(base, rt60=3.4, damp_hz=1800.0, predelay_ms=42.0, seed=41) * 2.1 + base * 0.55
    base += sub_drone(LOOP_N, midi_hz(N("D1")), 0.075, beat_hz=0.13)
    base = lowpass(base, 1400.0, order=2)
    base = blown_speaker(base, cut=4200.0, drive=1.25, cone=1.5, hiss_db=-60.0,
                         wow=0.55, hp=32.0, seed=23)

    # Half-time. One note a bar, and in the B section not even that.
    rhythm = blank()
    for i, (root, _tones) in enumerate(PROG):
        if 8 <= i < 12 and i % 2 == 1:
            continue                       # the lake goes quiet for a while
        wrap_add(rhythm, upright_bass(midi_hz(root), 3.1, level=0.48, seed=4100 + i),
                 at(i + 1, 0.0))
        if i % 4 == 3:
            # A dock board, once every four bars, wet.
            k = rim(0.14, level=0.10, f=(240.0, 690.0, 1420.0), seed=4200 + i)
            k = np.concatenate([k, np.zeros(int(1.8 * SR))])
            k = circ_reverb(k, rt60=2.4, damp_hz=2200.0, seed=43) * 1.4 + k * 0.6
            wrap_add(rhythm, k, at(i + 1, 2.0))
    rhythm = lowpass(rhythm, 2600.0, order=2)
    rhythm = blown_speaker(rhythm, cut=5000.0, drive=1.3, cone=1.5, hiss_db=-64.0,
                           wow=0.6, hp=28.0, seed=25)

    # A fiddle across the water: only the phrase heads, heavily damped and wet.
    frag = [e for e in TUNE if e[0] in (1, 2, 9, 10, 13, 14)]
    lead = tune_layer(frag, level=0.22, bright=0.55, seed=4300, drift=1.5, vib=0.6)
    lead = lowpass(lead, 2100.0, order=3)
    lead = circ_reverb(lead, rt60=4.2, damp_hz=1400.0, predelay_ms=95.0, seed=45) * 2.6 + lead * 0.30
    lead = highpass(lead, 180.0, order=2)
    lead = blown_speaker(lead, cut=3400.0, drive=1.2, cone=1.0, hiss_db=-66.0,
                         wow=0.7, hp=150.0, seed=27)

    # HI: the fiddle walks up the dock towards you, and a bowed swell arrives.
    # The fiddle walks up the dock: quiet in the A section, close by the B.
    hi = tune_layer([e for e in TUNE if 3 <= e[0] <= 8], level=0.085, bright=0.8,
                    seed=4390, drift=1.1, vib=0.8)
    hi += tune_layer([e for e in TUNE if e[0] >= 9], level=0.20, bright=1.0,
                     seed=4400, drift=0.9, vib=1.0)
    hi = circ_reverb(hi, rt60=1.9, damp_hz=3000.0, seed=47) * 0.9 + hi * 0.85
    for i, (_root, tones) in enumerate(PROG):
        if i % 2:
            continue
        sw = np.zeros(int(2.9 * SR))
        for j, m in enumerate(tones[:3]):
            wrap_add(sw, fiddle(midi_hz(m + 12), 2.8, level=0.085 * (1.0 - 0.2 * j),
                                bright=0.8, bow=0.35, vib=0.5, seed=4500 + i * 4 + j), 0)
        sw *= np.clip(np.linspace(0.0, 2.4, len(sw)), 0.0, 1.0)
        wrap_add(hi, sw, at(i + 1, 1.0))
    hi = highpass(hi, 300.0, order=2)
    hi = blown_speaker(hi, cut=5400.0, drive=1.3, cone=2.0, hiss_db=-66.0,
                       wow=0.6, hp=200.0, seed=29)

    return {"base": base, "rhythm": rhythm, "lead": lead, "hi": hi}


# ------------------------------------------------- MIGRATION
# The one part of the game that is not a joke, so this is the one cue that is
# not damaged. Less wow, less clipping, wider band, and the cadence lands.

def build_migration():
    base = pad_layer(PROG_MIG, level=0.075, reeds=5, spread=4.0, wheeze=0.30,
                     bright=1.15, seed=5000, hold=1.5)
    # A second pad an octave up, entering only in the back half: the sky opens.
    up = pad_layer(PROG_MIG[8:] + PROG_MIG[:8], level=0.030, reeds=4, spread=3.0,
                   wheeze=0.2, bright=1.4, octave=1, seed=5050, hold=1.4)
    base += np.roll(up, at(9))
    base += sub_drone(LOOP_N, midi_hz(N("D1")), 0.070, beat_hz=0.09)
    base = circ_reverb(base, rt60=2.6, damp_hz=4000.0, predelay_ms=30.0, seed=51) * 1.1 + base * 0.9
    base = lowpass(base, 3200.0, order=2)
    base = blown_speaker(base, cut=8000.0, drive=1.2, cone=1.0, hiss_db=-62.0,
                         wow=0.35, hp=34.0, seed=31)

    # PULSE: 84 BPM felt as 168 -- the same grid, twice the motion. Nothing
    # about the tempo changed; the birds just started flying.
    #
    # Four different bass figures across the sixteen bars, not one repeated.
    # Bars 1-2 are quarters (taking off), 3-8 are eighths, 9-12 invert the
    # figure so the octave lands on the offbeat, 13-16 open back out. Plus a
    # sixteenth-note fill at the end of bars 8 and 16. Without this the pulse
    # measured a 2.4 dB dynamic range over 45 seconds, which is the exact
    # definition of "an 8-second loop played six times".
    FIG_A = [(0.0, 0), (1.0, 7), (2.0, 0), (3.0, 7)]
    FIG_B = [(e * 0.5, [0, 7, 12, 7, 0, 7, 12, 7][e]) for e in range(8)]
    FIG_C = [(e * 0.5, [0, 12, 7, 12, 0, 12, 7, 12][e]) for e in range(8)]
    FIG_D = [(e * 0.5, [0, 7, 12, 19, 12, 7, 12, 7][e]) for e in range(8)]
    pulse = blank()
    for i, (root, tones) in enumerate(PROG_MIG):
        if i < 2:
            fig, base_lv = FIG_A, 0.30
        elif i < 8:
            fig, base_lv = FIG_B, 0.26
        elif i < 12:
            fig, base_lv = FIG_C, 0.28
        else:
            fig, base_lv = FIG_D, 0.30
        for k, (b, step) in enumerate(fig):
            lvl = base_lv * (1.0 if b == float(int(b)) else 0.72)
            wrap_add(pulse, upright_bass(midi_hz(root + step), 0.42, level=lvl,
                                         seed=5100 + i * 8 + k), at(i + 1, b))
        wrap_add(pulse, brush(0.40, level=0.11 + 0.04 * (i >= 8), swish=0.85,
                              seed=5200 + i * 3), at(i + 1, 1.0))
        wrap_add(pulse, brush(0.40, level=0.11 + 0.04 * (i >= 8), swish=0.85,
                              seed=5201 + i * 3), at(i + 1, 3.0))
        if i >= 8:
            wrap_add(pulse, brush(0.16, level=0.055, swish=0.4, lo=900.0,
                                  seed=5202 + i * 3), at(i + 1, 2.5))
        if i % 4 == 0:
            wrap_add(pulse, bell(midi_hz(tones[0] + 12), 0.7, level=0.034,
                                 seed=5300 + i), at(i + 1, 0.0))
        if i in (7, 15):
            for f in range(4):
                wrap_add(pulse, brush(0.10, level=0.06 + 0.02 * f, swish=0.35,
                                      lo=600.0, hi=7000.0, seed=5350 + i * 4 + f),
                         at(i + 1, 3.0 + f * 0.25))
    pulse = peak_eq(pulse, 640.0, 0.8, -3.0)
    pulse = blown_speaker(pulse, cut=7600.0, drive=1.3, cone=1.5, hiss_db=-64.0,
                          wow=0.35, hp=44.0, seed=33)

    # LEAD: long bows, in tune, no scrape. The tune, finally played properly.
    lead = blank()
    for k, (bar, beat, name, ln, dyn) in enumerate(TUNE_MIG):
        wrap_add(lead, fiddle(midi_hz(N(name)), ln * BEAT / SR, level=0.26 * dyn,
                              detune_c=0, bright=0.85 + 0.30 * dyn,
                              bow=0.32 + 0.22 * dyn, drift=0.35,
                              vib=0.8 + 0.5 * dyn, seed=5400 + k * 7), at(bar, beat))
    lead = circ_reverb(lead, rt60=1.7, damp_hz=3800.0, predelay_ms=26.0, seed=53) * 0.8 + lead * 0.95
    lead = highpass(lead, 210.0, order=2)
    lead = blown_speaker(lead, cut=7000.0, drive=1.4, cone=2.0, hiss_db=-66.0,
                         wow=0.35, hp=190.0, seed=35)

    # HI: an octave-up counter-line plus a flock texture -- twelve detuned
    # voices on the chord, which at this density stops being a chord and
    # becomes weather.
    hi = blank()
    for k, (bar, beat, name, ln, dyn) in enumerate(TUNE_MIG):
        # Present from bar 3, but a whisper until the back half, so pushing
        # intensity to 1.0 during the first pass still does something.
        if bar < 3:
            continue
        lv = 0.055 if bar < 9 else 0.11
        wrap_add(hi, fiddle(midi_hz(N(name) + 12), ln * BEAT / SR, level=lv * dyn,
                            bright=1.25, bow=0.4, drift=0.3, vib=1.3,
                            seed=5500 + k * 7), at(bar, beat))
    for i, (_root, tones) in enumerate(PROG_MIG):
        if i % 4:
            continue
        flock = np.zeros(int(4.2 * SR))
        for j in range(12):
            m = tones[j % len(tones)] + 12 * (j // 4)
            wrap_add(flock, fiddle(cents(midi_hz(m), rng.uniform(-14, 14)), 4.0,
                                   level=0.022, bright=0.9, bow=0.25, vib=0.7,
                                   seed=5600 + i * 12 + j), 0)
        flock *= np.clip(np.linspace(0.0, 1.9, len(flock)), 0.0, 1.0) * \
            np.clip(np.linspace(1.6, 0.0, len(flock)), 0.0, 1.0)
        wrap_add(hi, flock, at(i + 1, 0.0))
    hi = circ_reverb(hi, rt60=2.2, damp_hz=4200.0, seed=55) * 1.0 + hi * 0.8
    hi = highpass(hi, 520.0, order=2)
    hi = blown_speaker(hi, cut=8200.0, drive=1.2, cone=1.5, hiss_db=-68.0,
                       wow=0.3, hp=460.0, seed=37)

    return {"base": base, "pulse": pulse, "lead": lead, "hi": hi}


# ============================================================================
# ------------------------------  STINGERS  ----------------------------------
# ============================================================================
# Rules I gave myself, from the research: a stinger is IN KEY and IN TEMPO
# with the bed (84 BPM, D mixolydian) so it lands like the band did it, not
# like a notification. None of them are "funny". The score is the straight man
# -- if it winks, the geese stop being funny, because the joke is that the
# world is treating this completely normally.

def sting_objective():
    """Objective complete. Three notes, up, landing on D. Confident, brief,
    over before you've finished reading the toast."""
    n = int(1.35 * SR)
    out = np.zeros(n)
    for k, (name, b, lv) in enumerate([("F#4", 0.0, 0.30), ("A4", 0.25, 0.30), ("D5", 0.5, 0.34)]):
        wrap_add(out, fiddle(midi_hz(N(name)), 0.75, level=lv, bright=1.15,
                             bow=0.7, vib=1.0, seed=6000 + k), int(b * BEAT))
    for j, m in enumerate([N("D3"), N("F#3"), N("A3")]):
        wrap_add(out, accordion(midi_hz(m), 0.95, level=0.075, reeds=4,
                                bright=1.1, seed=6010 + j), int(0.5 * BEAT))
    wrap_add(out, upright_bass(midi_hz(N("D2")), 0.8, level=0.34, seed=6020), int(0.5 * BEAT))
    return blown_speaker(out, cut=6800.0, drive=1.5, cone=3.0, hiss_db=-70.0, wow=0.5, seed=61)


def sting_hidden():
    """Hidden objective found. Sweet, high, and slightly out of tune -- the
    private one. Bells plus a fiddle note that bends up into place and then
    keeps going a little too far."""
    n = int(1.9 * SR)
    out = np.zeros(n)
    for k, (m, b, lv) in enumerate([(N("A5"), 0.0, 0.20), (N("D6"), 0.18, 0.16),
                                    (N("F#6"), 0.36, 0.11)]):
        wrap_add(out, bell(midi_hz(m), 1.5, level=lv, seed=6100 + k), int(b * BEAT))
    bend = fiddle(midi_hz(N("B4")), 1.1, level=0.20, detune_c=-45, bright=1.2,
                  bow=0.6, drift=0.0, vib=0.8, seed=6110)
    # Force the bend by resampling on a rising ramp: -45c up to +14c.
    idx = np.arange(len(bend))
    ramp = np.cumsum(2.0 ** (np.linspace(-45, 14, len(bend)) / 1200.0) *
                     (2.0 ** (45 / 1200.0)))
    ramp = np.clip(ramp, 0, len(bend) - 2)
    i0 = ramp.astype(np.int64)
    bend = bend[i0] * (1 - (ramp - i0)) + bend[i0 + 1] * (ramp - i0)
    wrap_add(out, bend * np.hanning(len(bend)) ** 0.4, int(0.20 * BEAT))
    wrap_add(out, accordion(midi_hz(N("D3")), 1.4, level=0.06, reeds=3,
                            bright=0.9, seed=6120), 0)
    out = circ_reverb(out, rt60=1.4, damp_hz=4000.0, seed=63) * 0.7 + out * 0.9
    return blown_speaker(out, cut=8000.0, drive=1.3, cone=2.0, hiss_db=-70.0, wow=0.6, seed=65)


def sting_leg_pass():
    """Leg passed. A real cadence -- A7 to D, the resolution the zone loops
    spend forty-five seconds refusing. It's the migration harmony arriving
    early, which is exactly what passing a leg means."""
    n = int(2.6 * SR)
    out = np.zeros(n)
    for j, m in enumerate([N("A2"), N("C#3"), N("E3"), N("G3")]):
        wrap_add(out, accordion(midi_hz(m), 0.85, level=0.085, reeds=4,
                                spread_c=6.0, bright=1.05, seed=6200 + j), 0)
    for j, m in enumerate([N("D3"), N("F#3"), N("A3"), N("D4")]):
        wrap_add(out, accordion(midi_hz(m), 1.7, level=0.090, reeds=5,
                                spread_c=5.0, bright=1.1, seed=6210 + j), int(0.9 * BEAT))
    wrap_add(out, upright_bass(midi_hz(N("A1")), 1.0, level=0.34, seed=6220), 0)
    wrap_add(out, upright_bass(midi_hz(N("D2")), 1.7, level=0.40, seed=6221), int(0.9 * BEAT))
    wrap_add(out, fiddle(midi_hz(N("C#5")), 0.85, level=0.20, bright=1.1, bow=0.6, seed=6230), 0)
    wrap_add(out, fiddle(midi_hz(N("D5")), 1.5, level=0.24, bright=1.1, bow=0.5,
                         vib=1.2, seed=6231), int(0.9 * BEAT))
    wrap_add(out, brush(0.5, level=0.11, swish=1.0, seed=6240), int(0.9 * BEAT))
    out = circ_reverb(out, rt60=1.5, damp_hz=3600.0, seed=67) * 0.6 + out * 0.95
    return blown_speaker(out, cut=7200.0, drive=1.5, cone=2.5, hiss_db=-70.0, wow=0.5, seed=69)


def sting_leg_fail():
    """Leg failed. The SAME cadence, except the tape sags a semitone under it
    and the D never arrives -- it lands on a bare A and stops. No wah-wah, no
    trombone. The music is not making fun of you; it just ran out."""
    n = int(2.9 * SR)
    out = np.zeros(n)
    for j, m in enumerate([N("A2"), N("C#3"), N("E3"), N("G3")]):
        wrap_add(out, accordion(midi_hz(m), 0.9, level=0.085, reeds=4,
                                spread_c=8.0, bright=0.9, seed=6300 + j), 0)
    for j, m in enumerate([N("A2"), N("D3"), N("E3")]):
        wrap_add(out, accordion(midi_hz(m), 1.9, level=0.080, reeds=4,
                                spread_c=12.0, wheeze=1.4, bright=0.75, seed=6310 + j),
                 int(0.9 * BEAT))
    wrap_add(out, upright_bass(midi_hz(N("A1")), 2.0, level=0.36, seed=6320), 0)
    wrap_add(out, fiddle(midi_hz(N("C#5")), 0.9, level=0.19, bright=0.95, bow=0.7, seed=6330), 0)
    wrap_add(out, fiddle(midi_hz(N("A4")), 1.6, level=0.19, detune_c=-24, bright=0.85,
                         bow=0.9, drift=2.2, seed=6331), int(0.9 * BEAT))
    # Tape sag: the second half slows and drops. Built as a read-pointer ramp.
    t = np.arange(n, dtype=np.float64)
    k = np.clip((t - 0.9 * BEAT) / (1.6 * SR), 0.0, 1.0)
    rate = 1.0 - 0.058 * k ** 1.6
    read = np.clip(np.cumsum(rate), 0, n - 2)
    i0 = read.astype(np.int64)
    out = out[i0] * (1 - (read - i0)) + out[i0 + 1] * (read - i0)
    return blown_speaker(out, cut=5200.0, drive=1.8, cone=4.0, hiss_db=-66.0, wow=1.6, seed=71)


def sting_blackout():
    """Blackout. A tape stop: everything pitches down to a stop over 400 ms,
    the reel flaps twice against the head, one dead thud, then hiss. This is
    the loudest structural event in the score and it is three seconds long."""
    n = int(2.4 * SR)
    out = np.zeros(n)
    for j, m in enumerate([N("D3"), N("F#3"), N("A3"), N("C4")]):
        wrap_add(out, accordion(midi_hz(m), 1.0, level=0.10, reeds=4, spread_c=10.0,
                                wheeze=1.2, seed=6400 + j), 0)
    wrap_add(out, fiddle(midi_hz(N("D5")), 0.9, level=0.22, bright=1.0, bow=1.1, seed=6410), 0)
    wrap_add(out, upright_bass(midi_hz(N("D2")), 1.2, level=0.40, seed=6420), 0)
    # Tape stop.
    t = np.arange(n, dtype=np.float64)
    stop_at = int(0.30 * SR)
    span = int(0.42 * SR)
    rate = np.ones(n)
    seg = np.clip((t - stop_at) / span, 0.0, 1.0)
    rate = np.maximum(1.0 - seg ** 0.7, 0.0)
    read = np.clip(np.cumsum(rate), 0, n - 2)
    i0 = read.astype(np.int64)
    out = out[i0] * (1 - (read - i0)) + out[i0 + 1] * (read - i0)
    out *= np.clip(1.0 - (t - stop_at - span) / (0.25 * SR), 0.0, 1.0)
    # Reel flap x2, then the thud.
    for j, off in enumerate((0.80, 0.93)):
        f = rim(0.07, level=0.16, f=(90.0, 210.0, 470.0), seed=6430 + j)
        wrap_add(out, f, int(off * SR))
    thud = np.sin(2 * np.pi * np.cumsum(np.linspace(64.0, 31.0, int(0.5 * SR))) / SR)
    thud *= np.exp(-np.arange(int(0.5 * SR)) / (0.10 * SR)) * 0.45
    wrap_add(out, thud, int(1.02 * SR))
    tail = periodic_noise(n, seed=6440)
    tail = tilt(bandpass(tail, 400.0, 6000.0, order=1), 3000.0, 1.5)
    tail /= max(np.sqrt(np.mean(tail ** 2)), 1e-9)
    out += tail * db_to_lin(-40.0) * np.clip((t - 1.0 * SR) / (0.3 * SR), 0.0, 1.0) * \
        np.clip(1.0 - (t - 1.5 * SR) / (0.9 * SR), 0.0, 1.0)
    return blown_speaker(out, cut=5000.0, drive=2.0, cone=4.0, hiss_db=-58.0, wow=1.2, hp=40.0, seed=73)


def sting_wake():
    """Blackout ends. The transport spools back up: hiss rises, pitch climbs
    from a third down back to unity, one accordion chord swells in. The other
    half of the blackout gag, and the reason the blackout is memorable rather
    than merely loud."""
    n = int(2.2 * SR)
    out = np.zeros(n)
    for j, m in enumerate([N("D3"), N("A3"), N("D4")]):
        wrap_add(out, accordion(midi_hz(m), 2.0, level=0.085, reeds=4, spread_c=9.0,
                                wheeze=1.0, bright=0.9, seed=6500 + j), int(0.15 * SR))
    wrap_add(out, upright_bass(midi_hz(N("D2")), 1.6, level=0.30, seed=6510), int(0.15 * SR))
    t = np.arange(n, dtype=np.float64)
    rate = np.clip(0.62 + 0.38 * (t / (1.1 * SR)) ** 0.8, 0.0, 1.0)
    read = np.clip(np.cumsum(rate), 0, n - 2)
    i0 = read.astype(np.int64)
    out = out[i0] * (1 - (read - i0)) + out[i0 + 1] * (read - i0)
    out *= np.clip(t / (0.25 * SR), 0.0, 1.0)
    hs = periodic_noise(n, seed=6520)
    hs = tilt(bandpass(hs, 800.0, 7000.0, order=1), 3000.0, 2.0)
    hs /= max(np.sqrt(np.mean(hs ** 2)), 1e-9)
    out += hs * db_to_lin(-38.0) * np.clip(1.0 - t / (0.9 * SR), 0.0, 1.0)
    return blown_speaker(out, cut=6000.0, drive=1.5, cone=3.0, hiss_db=-62.0, wow=0.9, seed=75)


# ============================================================================
# --------------------------------  BUILD  -----------------------------------
# ============================================================================

# Layer gains at intensity == 1.0, matching music.gd's mix curve, so the sum
# measured below is the real worst case the player can hear.
FULL_MIX = {"base": 1.0, "rhythm": 1.0, "pulse": 1.0, "lead": 1.0, "hi": 1.0}


def balance_zone(layers, headroom_db=-3.0):
    """Normalise a whole zone by ONE common factor so the fully-layered sum
    peaks at `headroom_db`.

    Per-stem normalisation would be actively wrong here: it would make the
    hi-hat layer as loud as the bass and destroy the arrangement. The mix
    balance is composed, not measured. What gets measured is only whether the
    sum clips."""
    mix = np.zeros(LOOP_N)
    for k, v in layers.items():
        mix += v * FULL_MIX.get(k, 1.0)
    peak = float(np.max(np.abs(mix)))
    k = db_to_lin(headroom_db) / max(peak, 1e-9)
    return {name: v * k for name, v in layers.items()}, float(np.max(np.abs(mix * k)))


ZONE_MIX_PEAK = {}


def build_all():
    print("synthesising ... (this takes a minute; it is a lot of FFT)")

    jobs = [
        ("strip_mall", "mus_mall", build_strip_mall),
        ("suburbia", "mus_burb", build_suburbia),
        ("cottage", "mus_lake", build_cottage),
        ("migration", "mus_mig", build_migration),
    ]
    for zone, prefix, fn in jobs:
        print("  ", zone, "...", flush=True)
        layers = fn()
        layers, pk = balance_zone(layers)
        ZONE_MIX_PEAK[zone] = pk
        for role, arr in layers.items():
            add_stem("%s_%s" % (prefix, role), arr, zone, role)

    print("   stingers ...", flush=True)
    for name, fn in [("mus_sting_objective", sting_objective),
                     ("mus_sting_hidden", sting_hidden),
                     ("mus_sting_leg_pass", sting_leg_pass),
                     ("mus_sting_leg_fail", sting_leg_fail),
                     ("mus_sting_blackout", sting_blackout),
                     ("mus_sting_wake", sting_wake)]:
        arr = fn()
        # One-shots DO get faded and peak-normalised -- they have no seam to
        # protect and they must all land at a predictable level.
        f = min(int(0.004 * SR), len(arr) // 2)
        arr[:f] *= np.linspace(0, 1, f)
        arr[-int(0.03 * SR):] *= np.linspace(1, 0, int(0.03 * SR))
        arr *= db_to_lin(-6.0) / max(np.max(np.abs(arr)), 1e-9)
        add_stem(name, arr, "sting", "sting", is_loop=False)


# ============================================================================
# ------------------------------  ANALYSIS  ----------------------------------
# ============================================================================

BANDS = [(20, 60), (60, 150), (150, 350), (350, 700), (700, 1400),
         (1400, 2800), (2800, 5600), (5600, 11025)]
BAND_LABELS = ["sub", "bass", "lomid", "mid", "upmid", "pres", "bril", "air"]


def a_weight(f):
    """IEC 61672 A-weighting curve. Raw energy-per-band says the bass owns
    everything, which is true and useless -- the ear is ~20 dB more sensitive
    at 3 kHz than at 80 Hz. A-weighted band shares are what the player
    actually hears fighting for the same space."""
    f = np.maximum(f, 1e-3)
    f2 = f ** 2
    num = (12194.0 ** 2) * f2 ** 2
    den = ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2))
           * (f2 + 12194.0 ** 2))
    return num / den * 1.2589254


def band_energy(x, weighted=False):
    X = np.abs(np.fft.rfft(x)) ** 2
    f = _freqs(len(x))
    if weighted:
        X = X * a_weight(f) ** 2
    tot = float(np.sum(X)) + 1e-30
    return [100.0 * float(np.sum(X[(f >= lo) & (f < hi)])) / tot for lo, hi in BANDS]


def seam_click(arr, win=384, trials=800):
    """Is the wrap discontinuity audible?

    Not "is there a step" -- there is always some step, at some magnitude.
    The question is whether the step's own broadband energy is buried under
    the music that is playing at that instant, because that is the only thing
    that decides whether a human hears a tick.

    So: take the ACTUAL wrapped window (tail followed by head, Hann-windowed,
    centred exactly on the seam) and measure its energy above 3.5 kHz. Then
    synthesise the ideal click that a step of exactly this magnitude produces,
    window it identically, and measure ITS energy above 3.5 kHz. The ratio is
    the masking margin in dB.

      margin >= 12 dB  ->  the step contributes < 6% of the HF energy already
                           present. Inaudible.
      margin ~=  0 dB  ->  the step IS the high frequency content. A tick.

    Also reported: where the seam window's HF energy falls in the
    distribution of 800 random windows from the same file. A real click is a
    global outlier (100.0); ordinary bright content is not."""
    n = len(arr)
    w = np.hanning(2 * win)
    fq = np.fft.rfftfreq(2 * win, d=1.0 / SR)
    hi = fq > 3500.0

    def hf(seg):
        X = np.abs(np.fft.rfft(seg * w)) ** 2
        return float(np.sum(X[hi])) + 1e-30

    natural = hf(np.concatenate([arr[-win:], arr[:win]]))
    jump = float(arr[0] - arr[-1])
    step = np.concatenate([np.zeros(win), np.full(win, jump)])
    margin = 10.0 * math.log10(natural / hf(step)) if jump != 0.0 else 99.0
    r = np.random.default_rng(5)
    vals = np.array([hf(arr[i:i + 2 * win])
                     for i in r.integers(0, n - 2 * win, trials)])
    pct = 100.0 * float(np.mean(vals < natural))
    return margin, pct


def seam_tick(arr, hp_hz=6000.0, blk=64):
    """The decisive test: play the loop twice and look for the tick.

    Concatenate the stem with itself -- which is literally what the game does
    -- highpass the result at 6 kHz, and take a short-time peak envelope. A
    click is a broadband impulse, so it survives a 6 kHz highpass while music
    largely does not. Then ask: is the block containing the seam an outlier
    against every other block in the doubled signal?

    Returned in dB relative to the 99.9th percentile of all other blocks. A
    real click lands at +10 to +40 dB. Anything at or below 0 dB means the
    seam is not even in the top 0.1% of transients the stem already
    contains -- there is nothing there to hear."""
    n = len(arr)
    dbl = np.concatenate([arr, arr])
    hp = highpass(dbl, hp_hz, order=6)
    k = (2 * n) // blk
    env = np.max(np.abs(hp[:k * blk].reshape(k, blk)), axis=1)
    seam_blk = n // blk
    guard = 3
    idx = np.arange(k)
    near = (np.abs(idx - seam_blk) <= guard) | (idx <= guard) | (idx >= k - guard)
    peak_at_seam = float(np.max(env[near]))
    ref = float(np.percentile(env[~near], 99.9)) + 1e-12
    return 20.0 * math.log10(peak_at_seam / ref)


def frames(x, win_s=2.0):
    w = int(win_s * SR)
    k = len(x) // w
    if k < 1:
        return x[None, :]
    return x[:k * w].reshape(k, w)


def centroid_track(x, win_s=2.0, floor_db=-55.0):
    """Spectral centroid per frame, but only for frames that are actually
    audible. A silent frame has the centroid of the dither, which is ~5.5 kHz
    and completely meaningless -- reporting it makes every sparse stem look
    like it has enormous brightness range when it just has rests."""
    out = []
    ref = float(np.sqrt(np.mean(x ** 2))) + 1e-30
    for fr in frames(x, win_s):
        if lin_to_db(float(np.sqrt(np.mean(fr ** 2))) / ref) < floor_db + 40.0:
            continue
        X = np.abs(np.fft.rfft(fr))
        f = _freqs(len(fr))
        s = float(np.sum(X)) + 1e-30
        out.append(float(np.sum(f * X)) / s)
    return np.array(out) if out else np.array([0.0])


def rms_track(x, win_s=1.0):
    return np.sqrt(np.mean(frames(x, win_s) ** 2, axis=1) + 1e-30)


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1.0, 1.0)
    data = (x * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


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
edit/loop_mode={loop}
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""


def write_import(path, name, is_loop):
    """Ship the .import alongside the wav.

    compress/mode=0 is PCM. Godot's default for wav is QOA, which is lossy and
    resets its predictor every frame -- on a loop whose seam we have made
    sample-exact, that is a coin flip on an audible click every 45 seconds.
    Not worth the disk saving. loop_mode=1 is LOOP_FORWARD.

    No [remap] path/uid: Godot fills those in on --import and honours the
    [params] we set here."""
    with open(path, "w") as f:
        f.write(IMPORT_TMPL.format(name=name, loop=1 if is_loop else 0))


def report_and_write():
    print()
    print("=" * 112)
    print("STEMS  (%.1f BPM, D mixolydian, %d bars, %.3f s loop, %d Hz mono PCM)"
          % (BPM, BARS, LOOP_N / SR, SR))
    print("=" * 112)
    hdr = (f"{'file':<26}{'zone':<12}{'role':<8}{'dur(s)':>8}{'peak dB':>9}"
           f"{'RMS dB':>8}{'centroid':>10}{'band':>26}")
    print(hdr)
    print("-" * 112)
    loop_rows = []
    for name in sorted(STEMS):
        arr, is_loop = STEMS[name]
        m = META[name]
        path = os.path.join(OUT_DIR, name + ".wav")
        write_wav(path, arr)
        write_import(path + ".import", name, is_loop)
        peak = float(np.max(np.abs(arr)))
        rms = float(np.sqrt(np.mean(arr ** 2)))
        be = band_energy(arr)
        top = sorted(range(len(be)), key=lambda i: -be[i])[:2]
        bandstr = " ".join("%s %.0f%%" % (BAND_LABELS[i], be[i]) for i in top)
        cen = float(np.mean(centroid_track(arr)))
        print(f"{name:<26}{m['zone']:<12}{m['role']:<8}{len(arr)/SR:8.3f}"
              f"{lin_to_db(peak):9.2f}{lin_to_db(rms):8.2f}{cen:10.0f}{bandstr:>26}")
        if is_loop:
            loop_rows.append((name, arr))
    print("=" * 112)

    # ---- seam --------------------------------------------------------------
    print()
    print("LOOP SEAM  (wrap discontinuity, last sample -> first sample)")
    print("=" * 112)
    print(f"{'file':<26}{'edge jump':>13}{'dB rel pk':>11}{'slope ratio':>13}"
          f"{'mask margin':>13}{'tick dB':>10}{'verdict':>10}")
    print("-" * 112)
    worst_r = 0.0
    worst_hf = 999.0
    worst_tick = -999.0
    bad = []
    for name, arr in loop_rows:
        peak = float(np.max(np.abs(arr)))
        jump = float(arr[0] - arr[-1])
        jdb = lin_to_db(abs(jump) / peak) if peak > 0 and jump != 0.0 else -999.0
        k = 256
        typ = float(np.mean(np.abs(np.diff(arr[:k + 1]))) +
                    np.mean(np.abs(np.diff(arr[-(k + 1):])))) / 2.0
        ratio = abs(jump) / max(typ, 1e-12)
        hf_db, _pct = seam_click(arr)
        tick = seam_tick(arr)
        # Three conditions. The first two are structural (no waveform step,
        # step energy buried); the third is the empirical one -- play it twice
        # and listen for the tick with a highpass instead of an ear.
        # Two conditions. The edge jump is nulled by construction, so the
        # slope test should read 0.00; the tick test is the empirical proof
        # that playing the file twice produces no impulse.
        ok = ratio <= 3.0 and tick <= 0.0
        if not ok:
            bad.append(name)
        worst_r = max(worst_r, ratio)
        worst_hf = min(worst_hf, hf_db)
        worst_tick = max(worst_tick, tick)
        jstr = "exact 0" if jump == 0.0 else "%.7f" % jump
        dstr = "  --" if jump == 0.0 else "%.2f" % jdb
        mstr = "  --" if jump == 0.0 else "%.2f" % hf_db
        print(f"{name:<26}{jstr:>13}{dstr:>11}{ratio:13.2f}"
              f"{mstr:>13}{tick:10.2f}{'OK' if ok else 'CHECK':>10}")
    print("-" * 112)
    print("worst seam/local-slope ratio  : %.2f    (<= 3.0  = no waveform step)" % worst_r)
    print("worst doubled-loop tick       : %+.2f dB vs the stem's own 99.9th "
          "pct transient (<= 0 dB = nothing to hear)" % worst_tick)
    if bad:
        print("!! CHECK: " + ", ".join(bad))
    else:
        print("ALL LOOPS SEAMLESS.")
    print("=" * 112)

    # ---- band separation ---------------------------------------------------
    print()
    print("SPECTRAL OCCUPANCY, A-WEIGHTED  (%% of PERCEIVED energy per band)")
    print("Layers of the same zone must peak in different columns or they mud.")
    print("=" * 112)
    print(f"{'file':<26}" + "".join(f"{l:>9}" for l in BAND_LABELS) + f"{'peak band':>12}")
    print("-" * 112)
    zone_bands = {}
    for name in sorted(STEMS):
        arr, _ = STEMS[name]
        be = band_energy(arr, weighted=True)
        top = int(np.argmax(be))
        zone_bands.setdefault(META[name]["zone"], []).append((name, top, be[top]))
        print(f"{name:<26}" + "".join(f"{v:9.1f}" for v in be)
              + f"{BAND_LABELS[top]:>12}")
    print("-" * 112)
    for zone in ("strip_mall", "suburbia", "cottage", "migration"):
        rows = zone_bands.get(zone, [])
        tops = [t for _n, t, _v in rows]
        clash = len(tops) - len(set(tops))
        note = "clean" if clash == 0 else "%d layers share a peak band" % (clash + 1)
        print("  %-12s peak bands: %-34s %s"
              % (zone, ", ".join("%s=%s" % (n.split("_")[-1], BAND_LABELS[t])
                                 for n, t, _v in rows), note))
    print("=" * 112)

    # ---- variation over the loop ------------------------------------------
    print()
    print("VARIATION ACROSS THE LOOP  (does a 45 s stem actually go anywhere?)")
    print("=" * 112)
    print(f"{'file':<26}{'RMS dB min':>12}{'med':>8}{'max':>8}{'range':>8}"
          f"{'cen min':>10}{'cen max':>10}{'A vs B dB':>11}")
    print("-" * 112)
    for name, arr in loop_rows:
        r = rms_track(arr, 1.0)
        c = centroid_track(arr, 2.0)
        h = len(arr) // 2
        a = lin_to_db(float(np.sqrt(np.mean(arr[:h] ** 2))))
        b = lin_to_db(float(np.sqrt(np.mean(arr[h:] ** 2))))
        rr = lin_to_db(float(np.max(r))) - lin_to_db(float(np.min(r)))
        print(f"{name:<26}{lin_to_db(float(np.min(r))):12.1f}"
              f"{lin_to_db(float(np.median(r))):8.1f}"
              f"{lin_to_db(float(np.max(r))):8.1f}{rr:8.1f}"
              f"{float(np.min(c)):10.0f}{float(np.max(c)):10.0f}{b - a:11.2f}")
    print("=" * 112)

    # ---- clip check --------------------------------------------------------
    print()
    print("FULL-LAYER SUM  (all layers of a zone at intensity 1.0)")
    print("=" * 112)
    for zone in ("strip_mall", "suburbia", "cottage", "migration"):
        names = [n for n in STEMS if META[n]["zone"] == zone]
        mix = np.zeros(LOOP_N)
        for n in names:
            mix += STEMS[n][0]
        pk = float(np.max(np.abs(mix)))
        rms = float(np.sqrt(np.mean(mix ** 2)))
        clipped = int(np.sum(np.abs(mix) >= 0.999))
        print("  %-12s layers=%d  peak %6.2f dBFS  RMS %6.2f dBFS  "
              "clipped samples: %d" % (zone, len(names), lin_to_db(pk),
                                       lin_to_db(rms), clipped))
    print()
    for name in sorted(STEMS):
        arr, _ = STEMS[name]
        c = int(np.sum(np.abs(arr) >= 0.999))
        if c:
            print("  !! %s clips %d samples" % (name, c))
    print("=" * 112)
    print()
    total = sum(len(a) * 2 for a, _ in STEMS.values())
    print("wrote %d files to %s  (%.1f MB PCM)" % (len(STEMS) * 2, OUT_DIR,
                                                   total / 1e6))


if __name__ == "__main__":
    build_all()
    report_and_write()
