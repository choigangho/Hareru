#!/usr/bin/env python3
"""Day 1 sounds made from code (no samples, no API): effects, rain, wind, machine hum, music.

    python3 Tools/audio/synth_sounds.py            # writes Game/audio/{sfx,amb,music}/*.wav

Loops are filtered in the frequency domain (circular), so they wrap without a seam.
Everything is mono 16-bit; ambience and music at 22050 Hz, effects at 44100 Hz.
Change a recipe here and run again — the game picks up the new files on import.
"""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parents[2] / "Game" / "audio"
rng = np.random.default_rng(2094)


def save(rel, x, sr, peak=0.7):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    p = OUT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(p), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print(f"{rel}  {len(x) / sr:.2f}s")


def t_axis(sec, sr):
    return np.arange(int(sec * sr)) / sr


def shape(x, sr, lo=None, hi=None, tilt=0.0):
    """Circular FFT filter: band-pass lo..hi (soft edges) and a spectral tilt (dB/octave)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / sr)
    X = np.fft.rfft(x)
    g = np.ones_like(f)
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi:
        g *= 1 / (1 + (f / hi) ** 4)
    if tilt:
        g *= (np.maximum(f, 20) / 1000.0) ** (tilt / 6.02)
    return np.fft.irfft(X * g, n)


def env(n, attack, decay, sr):
    t = np.arange(n) / sr
    e = np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-np.maximum(0, t - attack) / decay)
    return e


def noise(n):
    return rng.standard_normal(n)


def periodic_lfo(n, sr, cycles, phase=0.0):
    """LFO that completes whole cycles over the loop (so the loop wraps)."""
    return np.sin(2 * np.pi * cycles * np.arange(n) / n + phase)


# ── ambience (loops) ─────────────────────────────────────────────────────────

def rain(sec=24.0, sr=22050, heavy=False):
    n = int(sec * sr)
    bed = shape(noise(n), sr, lo=300, hi=5200 if heavy else 3800, tilt=-2.0)
    bed *= 0.75 + 0.15 * periodic_lfo(n, sr, 3) + 0.08 * periodic_lfo(n, sr, 7, 1.0)
    drops = np.zeros(n)
    k = int(sec * (220 if heavy else 140))
    for pos in rng.integers(0, n, k):
        ln = int(sr * rng.uniform(0.004, 0.02))
        d = noise(ln) * env(ln, 0.0005, rng.uniform(0.002, 0.008), sr) * rng.uniform(0.3, 1.0)
        idx = (pos + np.arange(ln)) % n
        drops[idx] += d
    drops = shape(drops, sr, lo=1200, hi=7000)
    # a few fat drops on the window sill
    sill = np.zeros(n)
    for pos in rng.integers(0, n, int(sec * 3)):
        ln = int(sr * 0.06)
        tt = np.arange(ln) / sr
        f0 = rng.uniform(700, 1300)
        d = np.sin(2 * np.pi * f0 * tt * (1 - 0.35 * tt / tt[-1])) * env(ln, 0.001, 0.015, sr)
        sill[(pos + np.arange(ln)) % n] += d * rng.uniform(0.2, 0.5)
    return 1.0 * bed / np.std(bed) + 0.9 * drops / (np.std(drops) + 1e-9) * 0.35 + sill * 0.6


def wind(sec=30.0, sr=22050):
    n = int(sec * sr)
    x = noise(n)
    # several slow gusts: band-passed noise whose loudness and brightness follow periodic LFOs
    low = shape(x, sr, lo=60, hi=420, tilt=-3.0)
    mid = shape(noise(n), sr, lo=300, hi=1400, tilt=-1.5)
    gust = 0.55 + 0.3 * periodic_lfo(n, sr, 2) + 0.15 * periodic_lfo(n, sr, 5, 2.0)
    whistle = 0.3 + 0.7 * np.clip(periodic_lfo(n, sr, 3, 0.7), 0, 1) ** 2
    y = low / np.std(low) * gust + mid / np.std(mid) * whistle * gust * 0.45
    return y


def hum(sec=8.0, sr=22050):
    """Reader machine: mains hum + a small fan. Whole cycles so it loops."""
    n = int(sec * sr)
    t = np.arange(n) / sr
    h = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(60, 1.0), (120, 0.5), (180, 0.25), (240, 0.12)])
    fan = shape(noise(n), sr, lo=150, hi=1800, tilt=-3.0)
    fan *= 1 + 0.15 * periodic_lfo(n, sr, 40)
    return h * 0.35 + fan / np.std(fan) * 0.5


# ── effects ──────────────────────────────────────────────────────────────────

SR = 44100


def tick_soft():           # dialog typing (phosphor terminal tick)
    n = int(SR * 0.025)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 1900 * t) * env(n, 0.0008, 0.006, SR) + 0.3 * shape(noise(n), SR, lo=2500) * env(n, 0.0002, 0.002, SR)


def tick_key():            # intro CRT typewriter key
    n = int(SR * 0.07)
    t = np.arange(n) / SR
    click = shape(noise(n), SR, lo=1500, hi=9000) * env(n, 0.0003, 0.004, SR)
    body = np.sin(2 * np.pi * 420 * t) * env(n, 0.001, 0.02, SR) * 0.5
    return click + body


def door_creak():
    sec = 1.3
    n = int(SR * sec)
    t = np.arange(n) / SR
    f = 95 + 60 * np.sin(2 * np.pi * 0.9 * t) + 25 * np.sin(2 * np.pi * 3.7 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    stick = (rng.random(n) < 0.03) * 1.0          # stick-slip grain
    grain = shape(stick, SR, lo=400, hi=3000)
    y = shape(saw, SR, lo=300, hi=2500) * (0.6 + 0.4 * grain / (np.max(np.abs(grain)) + 1e-9))
    return y * env(n, 0.08, 0.6, SR)


def door_close():
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * 70 * t) * env(n, 0.002, 0.09, SR)
    knock = shape(noise(n), SR, lo=200, hi=1800) * env(n, 0.001, 0.03, SR) * 0.6
    latch = np.zeros(n)
    i = int(SR * 0.09)
    ln = int(SR * 0.02)
    latch[i:i + ln] = shape(noise(ln), SR, lo=2500, hi=9000) * env(ln, 0.0002, 0.004, SR)
    return thud + knock + latch * 0.5


def drip():                # bucket '똑'
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    f = 1500 * np.exp(-t * 9) + 650
    ph = 2 * np.pi * np.cumsum(f) / SR
    plink = np.sin(ph) * env(n, 0.001, 0.05, SR)
    ring = np.sin(2 * np.pi * 820 * t) * env(n, 0.01, 0.12, SR) * 0.25
    return plink + ring


def flip():                # ledger number flap 찰칵
    n = int(SR * 0.18)
    y = np.zeros(n)
    for off, a in [(0.0, 1.0), (0.045, 0.7)]:
        i = int(off * SR)
        ln = int(SR * 0.03)
        y[i:i + ln] += shape(noise(ln), SR, lo=1800, hi=8000) * env(ln, 0.0002, 0.005, SR) * a
    return y


def tap():                 # finger tap on the ledger 톡
    n = int(SR * 0.15)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 310 * t) * env(n, 0.001, 0.025, SR) + 0.3 * shape(noise(n), SR, lo=800, hi=4000) * env(n, 0.0005, 0.006, SR)


def stamp():
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * 110 * t * (1 - 0.3 * t)) * env(n, 0.002, 0.06, SR)
    slap = shape(noise(n), SR, lo=500, hi=5000) * env(n, 0.0005, 0.012, SR) * 0.7
    return thump + slap


def paper_feed():          # rollers pull the sheet in
    n = int(SR * 0.5)
    t = np.arange(n) / SR
    motor = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(140, 1.0), (280, 0.5), (420, 0.2)])
    rustle = shape(noise(n), SR, lo=1500, hi=7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t))
    e = np.minimum(1, t / 0.04) * np.minimum(1, (t[-1] - t) / 0.08)
    return (motor * 0.25 + rustle * 0.35) * e


def scan_pass():           # one sweep of the scan bar
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    f = 380 + 260 * t / t[-1]
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) * 0.25 + np.sin(2 * ph) * 0.08
    air = shape(noise(n), SR, lo=2000, hi=6000) * 0.12
    e = np.sin(np.pi * t / t[-1]) ** 1.5
    return (tone + air) * e


def lever():
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    clack = shape(noise(n), SR, lo=1500, hi=8000) * env(n, 0.0003, 0.006, SR)
    spring = np.sin(2 * np.pi * 880 * t) * env(n, 0.001, 0.05, SR) * 0.35
    thud = np.sin(2 * np.pi * 150 * t) * env(n, 0.001, 0.03, SR) * 0.6
    return clack + spring + thud


def receipt_print():       # dot-matrix line feed
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    pulses = (np.sin(2 * np.pi * 55 * t) > 0.6) * 1.0
    buzz = shape(pulses * noise(n), SR, lo=1200, hi=6000)
    head = np.sin(2 * np.pi * 1450 * t) * pulses * 0.15
    e = np.minimum(1, t / 0.02) * np.minimum(1, (t[-1] - t) / 0.05)
    return (buzz + head) * e


def blip():                # keycap / choice
    n = int(SR * 0.08)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 1180 * t) * env(n, 0.001, 0.02, SR) + 0.4 * np.sin(2 * np.pi * 2360 * t) * env(n, 0.001, 0.01, SR)


def patch():               # D1-312 the ceiling is patched: thunk, then quiet
    n = int(SR * 0.5)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 90 * t) * env(n, 0.003, 0.1, SR) + shape(noise(n), SR, lo=300, hi=2500) * env(n, 0.001, 0.04, SR) * 0.5


# ── music ────────────────────────────────────────────────────────────────────

def note_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lab_theme(sr=22050):
    """Slow warm loop for the lab: pad chords + soft electric piano, 72 bpm, 8 bars."""
    bpm = 72
    beat = 60 / bpm
    chords = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]  # Fmaj7 Em7 Dm7 Cmaj7
    bars = 8
    sec = bars * 4 * beat
    n = int(sec * sr)
    t = np.arange(n) / sr
    pad = np.zeros(n)
    keys = np.zeros(n)
    for b in range(bars):
        ch = chords[b % 4]
        s0 = int(b * 4 * beat * sr)
        ln = int(4 * beat * sr)
        tt = np.arange(ln + int(0.8 * sr)) / sr
        e = np.minimum(1, tt / 0.9) * np.minimum(1, np.maximum(0, (4 * beat + 0.8 - tt)) / 0.8)
        for m in ch:
            for det in (-0.08, 0.08):
                f = note_hz(m - 12) * 2 ** (det / 12)
                tone = np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)
                idx = (s0 + np.arange(len(tt))) % n
                pad[idx] += tone * e * 0.12
        # electric piano: broken chord on beats 1, 2.5, 3, 4
        for k, (bt, m) in enumerate(zip([0, 1.5, 2, 3], [ch[0] + 12, ch[2] + 12, ch[3] + 12, ch[1] + 24])):
            st = s0 + int(bt * beat * sr)
            ln2 = int(1.6 * sr)
            tt2 = np.arange(ln2) / sr
            f = note_hz(m)
            ep = (np.sin(2 * np.pi * f * tt2) + 0.25 * np.sin(2 * np.pi * 2 * f * tt2) * np.exp(-tt2 * 6)) * env(ln2, 0.004, 0.55, sr)
            keys[(st + np.arange(ln2)) % n] += ep * (0.32 if k == 0 else 0.22)
    pad = shape(pad, sr, hi=1800)
    hiss = shape(noise(n), sr, lo=3000, hi=8000) * 0.004
    wow = 1 + 0.002 * periodic_lfo(n, sr, 16)
    return (pad + keys) * wow + hiss


def main():
    save("amb/rain_inside.wav", shape(rain(), 22050, hi=2600), 22050, 0.6)    # through the window
    save("amb/rain_outside.wav", rain(heavy=True), 22050, 0.7)
    save("amb/wind.wav", wind(), 22050, 0.6)
    save("amb/hum.wav", hum(), 22050, 0.5)
    for name, fn in [("tick_soft", tick_soft), ("tick_key", tick_key), ("door_creak", door_creak),
                     ("door_close", door_close), ("drip", drip), ("flip", flip), ("tap", tap),
                     ("stamp", stamp), ("paper_feed", paper_feed), ("scan_pass", scan_pass),
                     ("lever", lever), ("receipt_print", receipt_print), ("blip", blip), ("patch", patch)]:
        save(f"sfx/{name}.wav", fn(), SR, 0.8)
    save("music/lab_theme.wav", lab_theme(), 22050, 0.6)


if __name__ == "__main__":
    main()
