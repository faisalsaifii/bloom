"""Synthesises every Bloom sound effect and both music loops. Run: python tools/gen_audio.py
Everything is generated from scratch (no samples), so the audio is 100% original."""
import os
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(7)


def t_of(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env_ad(n, a=0.005, d=None, sr=SR, curve=3.0):
    """Fast attack, exponential-ish decay envelope over n samples."""
    t = np.arange(n) / sr
    dur = n / sr
    d = d or dur
    atk = np.minimum(1.0, t / max(a, 1e-4))
    dec = np.exp(-curve * t / d)
    e = atk * dec
    # fade tail to zero to avoid clicks
    fade = min(n, int(0.004 * sr))
    e[-fade:] *= np.linspace(1, 0, fade)
    return e


def sine(freq, dur, phase=0.0):
    t = t_of(dur)
    f = np.asarray(freq)
    if f.ndim == 0:
        return np.sin(2 * np.pi * f * t + phase)
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def sweep(f0, f1, dur, exp=True):
    n = int(dur * SR)
    if exp:
        f = f0 * (f1 / f0) ** (np.arange(n) / n)
    else:
        f = np.linspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def lowpass(x, cutoff, sr=SR):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / sr)
    spec *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


def highpass(x, cutoff, sr=SR):
    return x - lowpass(x, cutoff, sr)


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def reverb(x, wet=0.25, sr=SR):
    """Cheap multi-tap feedback comb 'reverb' - good enough for glow-y tails."""
    out = x.copy()
    for delay, g in ((0.029, 0.5), (0.037, 0.42), (0.053, 0.36), (0.071, 0.3), (0.097, 0.24)):
        d = int(delay * sr)
        tap = np.zeros_like(x)
        tap[d:] = x[:-d] * g
        out += tap * wet
    return out


def save_mono(name, x, peak=0.85):
    x = norm(x, peak)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def save_stereo(name, l, r, sr, peak=0.8):
    m = max(np.max(np.abs(l)), np.max(np.abs(r))) or 1
    l, r = l / m * peak, r / m * peak
    pcm = np.empty(len(l) * 2, dtype="<i2")
    pcm[0::2] = (np.clip(l, -1, 1) * 32767).astype("<i2")
    pcm[1::2] = (np.clip(r, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def pad(x, n):
    out = np.zeros(n)
    out[: min(n, len(x))] = x[:n]
    return out


def mix(parts, total):
    out = np.zeros(int(total * SR))
    for start, x in parts:
        s = int(start * SR)
        e = min(len(out), s + len(x))
        if s < len(out):
            out[s:e] += x[: e - s]
    return out


# ---------------------------------------------------------------- SFX
def pluck(freq, dur, bright=1.0, vol=1.0):
    t = t_of(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.35 * bright * np.sin(2 * np.pi * freq * 2 * t) + 0.12 * bright * np.sin(2 * np.pi * freq * 3.01 * t)
    return x * env_ad(len(t), 0.003, dur * 0.45, curve=4) * vol


def make_sfx():
    # jump: bubbly upward chirp
    n = 0.2
    j = sweep(300, 760, n) * env_ad(int(n * SR), 0.004, 0.12, curve=3)
    j += 0.3 * sweep(600, 1520, n) * env_ad(int(n * SR), 0.004, 0.08, curve=3)
    save_mono("jump", j, 0.7)

    # land: soft thump
    n = 0.16
    th = sweep(150, 55, n) * env_ad(int(n * SR), 0.002, 0.07, curve=3)
    th += 0.25 * lowpass(noise(n), 900) * env_ad(int(n * SR), 0.001, 0.03)
    save_mono("land", th, 0.6)

    # coin: bright two-note ping, 6 rising pitches (pentatonic) for combo feel
    scale = [76, 79, 81, 84, 86, 88]
    for i, m in enumerate(scale):
        a = pluck(midi(m), 0.34, 1.2)
        b = pluck(midi(m + 7), 0.34, 1.0) * 0.8
        x = mix([(0, a), (0.055, b)], 0.4)
        x = reverb(x, 0.2)
        save_mono(f"coin_{i}", x, 0.65)

    # death: crunchy downward sweep + noise burst
    n = 0.7
    d = sweep(520, 38, n) * env_ad(int(n * SR), 0.002, 0.35, curve=3)
    nz = lowpass(noise(n), 3000) * env_ad(int(n * SR), 0.001, 0.12, curve=4)
    save_mono("death", d * 0.8 + nz * 0.7, 0.8)

    # win: ascending arpeggio with shimmer
    notes = [72, 76, 79, 84, 88, 91]
    parts = [(i * 0.09, pluck(midi(m), 1.1, 1.3)) for i, m in enumerate(notes)]
    parts.append((0.5, pluck(midi(84), 1.4, 1.0) * 0.7 + pluck(midi(91), 1.4, 1.0) * 0.6 + pluck(midi(96), 1.4, 1.0) * 0.5))
    save_mono("win", reverb(mix(parts, 2.2), 0.35), 0.8)

    # stars 1..3
    for i, m in enumerate([79, 84, 91]):
        save_mono(f"star_{i}", reverb(pluck(midi(m), 0.9, 1.4) + 0.5 * pluck(midi(m + 12), 0.9, 1.0), 0.35), 0.7)

    # UI
    n = 0.07
    save_mono("ui_click", (sine(1180, n) + 0.4 * sine(1770, n)) * env_ad(int(n * SR), 0.001, 0.03, curve=4), 0.5)
    n = 0.05
    save_mono("ui_hover", sine(820, n) * env_ad(int(n * SR), 0.002, 0.025, curve=4), 0.25)
    n = 0.14
    save_mono("ui_back", sweep(760, 420, n) * env_ad(int(n * SR), 0.002, 0.08, curve=3), 0.5)
    n = 0.2
    save_mono("ui_locked", (np.sign(sine(130, n)) * 0.5 + sine(97, n)) * env_ad(int(n * SR), 0.002, 0.1, curve=3), 0.45)
    save_mono("ui_toggle", pluck(midi(84), 0.18, 1.0), 0.5)

    # buy / unlock: sparkly cascade
    parts = [(i * 0.07, pluck(midi(m), 0.9, 1.4)) for i, m in enumerate([76, 83, 88, 95, 100])]
    save_mono("buy", reverb(mix(parts, 1.6), 0.4), 0.8)

    # whoosh for transitions
    n = 0.4
    nz = noise(n)
    nz = highpass(lowpass(nz, 2500), 300)
    env = np.sin(np.linspace(0, np.pi, len(nz))) ** 2
    save_mono("whoosh", nz * env, 0.35)

    # crumble
    n = 0.35
    cr = lowpass(noise(n), 1800) * env_ad(int(n * SR), 0.002, 0.2, curve=3)
    cr *= 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t_of(n)))
    save_mono("crumble", cr, 0.5)

    # bounce spring
    n = 0.25
    save_mono("bounce", sweep(220, 900, n) * env_ad(int(n * SR), 0.003, 0.15, curve=3), 0.6)


# ---------------------------------------------------------------- Music
def music(name, bpm, bars, chords, bass_roots, drums, arp_pattern, seed, sr_out=32000, melody=None):
    spb = 60.0 / bpm
    bar = spb * 4
    total = bar * bars
    n = int(total * SR)
    tail = int(2.5 * SR)
    L = np.zeros(n + tail)
    R = np.zeros(n + tail)
    r = np.random.default_rng(seed)

    chord_bars = bars // len(chords)

    def add(x, start, pan=0.0, vol=1.0):
        s = int(start * SR)
        e = min(len(L), s + len(x))
        if e <= s:
            return
        x = x[: e - s] * vol
        L[s:e] += x * (1 - max(0, pan))
        R[s:e] += x * (1 + min(0, pan))

    for ci, chord in enumerate(chords):
        start = ci * chord_bars * bar
        dur = chord_bars * bar + 1.2
        # warm detuned pad: stacked sines w/ gentle harmonic roll-off, slow swell
        for note in chord:
            f = midi(note)
            t = t_of(dur)
            sig = np.zeros_like(t)
            for det, ph in ((-0.07, 0.0), (0.0, 1.3), (0.07, 2.4)):
                ff = f * 2 ** (det / 12)
                sig += np.sin(2 * np.pi * ff * t + ph) + 0.28 * np.sin(2 * np.pi * ff * 2 * t + ph) + 0.1 * np.sin(2 * np.pi * ff * 3 * t + ph)
            swell = np.minimum(1, t / 1.6) * np.minimum(1, (dur - t) / 1.2)
            slow = 0.85 + 0.15 * np.sin(2 * np.pi * (0.11 + r.random() * 0.05) * t + r.random() * 6)
            add(sig * swell * slow, start, pan=r.uniform(-0.5, 0.5), vol=0.05)
        # sub bass
        root = bass_roots[ci]
        for b in range(chord_bars * 2):
            t0 = start + b * 2 * spb
            f = midi(root)
            t = t_of(2 * spb * 0.98)
            sub = np.sin(2 * np.pi * f * t) * env_ad(len(t), 0.02, 2 * spb * 0.8, curve=2.0)
            add(sub, t0, vol=0.32)

    # arpeggio sparkles (stereo ping-pong echo)
    steps = int(bars * 16)
    for s in range(steps):
        ci = min(len(chords) - 1, s // (16 * chord_bars))
        pat = arp_pattern[s % len(arp_pattern)]
        if pat is None:
            continue
        chord = chords[ci]
        note = chord[pat % len(chord)] + 12 * (1 + pat // len(chord))
        t0 = s * spb / 4
        p = pluck(midi(note), 0.9, 1.1)
        side = -0.6 if (s % 2) else 0.6
        add(p, t0, pan=side, vol=0.075)
        add(p, t0 + spb * 0.75, pan=-side, vol=0.035)
        add(p, t0 + spb * 1.5, pan=side * 0.5, vol=0.016)

    if melody:
        for (step, note, ln) in melody:
            t0 = step * spb / 4
            t = t_of(ln * spb / 4 + 0.4)
            m = (np.sin(2 * np.pi * midi(note) * t) + 0.2 * np.sin(2 * np.pi * midi(note) * 2 * t))
            m *= env_ad(len(t), 0.03, ln * spb / 4 * 0.9, curve=2.5)
            add(m, t0, pan=0.2, vol=0.07)
            add(m, t0 + spb * 0.75, pan=-0.4, vol=0.03)

    if drums:
        for b in range(bars * 4):
            t0 = b * spb
            if b % 2 == 0:  # soft kick on 1 & 3
                k = sweep(130, 42, 0.28) * env_ad(int(0.28 * SR), 0.002, 0.12, curve=3)
                add(k, t0, vol=0.45)
            if b % 2 == 1:  # airy clap-ish snare
                nz = highpass(lowpass(noise(0.2), 6000), 900) * env_ad(int(0.2 * SR), 0.002, 0.07, curve=4)
                add(nz, t0, vol=0.12)
        for s in range(bars * 16):
            if s % 2 == 1:
                hat = highpass(noise(0.05), 7000) * env_ad(int(0.05 * SR), 0.001, 0.02, curve=4)
                add(hat, s * spb / 4, pan=0.3, vol=0.05 if s % 4 == 3 else 0.03)

    # fold the reverb/echo tail back onto the start => perfectly seamless loop
    Ls, Rs = L[:n].copy(), R[:n].copy()
    Ls[:tail] += L[n:]
    Rs[:tail] += R[n:]
    # decimate to sr_out with simple averaging resample
    idx = np.linspace(0, n - 1, int(n * sr_out / SR)).astype(int)
    Ls, Rs = lowpass(Ls, sr_out * 0.45)[idx], lowpass(Rs, sr_out * 0.45)[idx]
    save_stereo(name, Ls, Rs, sr_out)


def make_music():
    # Menu: dreamy and slow. Am9 - Fmaj7 - Cmaj7 - G6/9
    chords = [[57, 60, 64, 67, 71], [53, 57, 60, 64, 67], [48, 55, 59, 64, 67], [55, 59, 62, 64, 69]]
    music("music_menu", 72, 8, chords, [33, 29, 36, 31], False,
          [0, None, 2, None, 4, None, 2, None, 1, None, 3, None, 5, None, 3, None], 1,
          melody=[(0, 81, 6), (8, 79, 6), (32, 77, 6), (40, 79, 6), (64, 76, 8), (80, 74, 4), (96, 79, 6), (104, 81, 8)])
    # Game: brighter, with a gentle beat. Dm9 - Bbmaj7 - Fmaj7 - C6
    chords = [[50, 57, 60, 64, 69], [58, 62, 65, 69, 72], [53, 57, 60, 64, 69], [48, 55, 60, 64, 69]]
    music("music_game", 104, 8, chords, [38, 34, 41, 36], True,
          [0, 2, 4, 2, 1, 3, 5, 3, 0, 2, 4, 6, 5, 3, 2, 1], 2,
          melody=[(0, 86, 4), (4, 84, 2), (6, 81, 6), (16, 79, 4), (20, 81, 4), (32, 84, 6), (40, 86, 4), (48, 81, 4), (64, 88, 4), (68, 86, 4), (72, 84, 6), (96, 81, 8)])


if __name__ == "__main__":
    make_sfx()
    make_music()
    print("audio generated in", OUT)
