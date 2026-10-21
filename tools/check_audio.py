"""Sanity-checks generated audio: peak/RMS levels, DC offset and loop seam smoothness."""
import glob
import os
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
for path in sorted(glob.glob(os.path.join(ROOT, "assets", "audio", "*.wav"))):
    with wave.open(path) as w:
        ch, sr, n = w.getnchannels(), w.getframerate(), w.getnframes()
        data = np.frombuffer(w.readframes(n), dtype="<i2").astype(np.float32) / 32768.0
    if ch == 2:
        data = data.reshape(-1, 2)
    mono = data.mean(axis=1) if ch == 2 else data
    peak = np.max(np.abs(data))
    rms = float(np.sqrt(np.mean(mono ** 2)))
    note = ""
    if os.path.basename(path).startswith("music"):
        seam = float(np.max(np.abs(data[0] - data[-1])))
        note = f" dur={n / sr:.1f}s seam_jump={seam:.4f}"
    print(f"{os.path.basename(path):16s} sr={sr} ch={ch} peak={peak:.2f} rms={rms:.3f} dc={float(mono.mean()):+.4f}{note}")
