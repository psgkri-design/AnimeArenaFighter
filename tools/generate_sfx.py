#!/usr/bin/env python3
"""Generate small original procedural combat SFX for Anime Arena Fighter."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUT = Path("assets/generated_sfx")
OUT.mkdir(parents=True, exist_ok=True)

SPECS = {
    "swing": (0.16, 101),
    "impact": (0.22, 202),
    "dash": (0.24, 303),
    "energy": (0.30, 404),
    "parry": (0.28, 505),
    "ultimate": (0.55, 606),
}

def env(t, duration, attack=0.006, release=0.08):
    a = min(1.0, t / max(attack, 1e-5))
    r = min(1.0, (duration - t) / max(release, 1e-5))
    return max(0.0, min(a, r))

def synth(kind, duration, seed):
    rng = random.Random(seed)
    samples = []
    filtered_noise = 0.0
    phase = 0.0
    count = int(RATE * duration)
    for i in range(count):
        t = i / RATE
        x = t / duration
        white = rng.uniform(-1.0, 1.0)
        filtered_noise = filtered_noise * 0.72 + white * 0.28

        if kind == "swing":
            e = env(t, duration, 0.004, 0.055)
            freq = 980.0 - 620.0 * x
            value = filtered_noise * 0.62 + math.sin(2.0 * math.pi * freq * t) * 0.24
            value *= e * (1.0 - 0.35 * x)
        elif kind == "impact":
            e = math.exp(-15.0 * t)
            value = math.sin(2.0 * math.pi * 82.0 * t) * 0.74
            value += math.sin(2.0 * math.pi * 138.0 * t) * 0.28
            value += filtered_noise * 0.38
            value *= e
        elif kind == "dash":
            e = env(t, duration, 0.012, 0.10)
            freq = 320.0 + 180.0 * (1.0 - x)
            value = filtered_noise * 0.70 + math.sin(2.0 * math.pi * freq * t) * 0.18
            value *= e
        elif kind == "energy":
            e = env(t, duration, 0.018, 0.10)
            freq = 260.0 + 1200.0 * x * x
            phase += 2.0 * math.pi * freq / RATE
            value = math.sin(phase) * 0.58 + math.sin(phase * 0.5) * 0.20 + filtered_noise * 0.10
            value *= e
        elif kind == "parry":
            e = math.exp(-9.0 * t)
            value = math.sin(2.0 * math.pi * 1680.0 * t) * 0.62
            value += math.sin(2.0 * math.pi * 2470.0 * t) * 0.30
            value += filtered_noise * 0.16
            value *= e
        else:  # ultimate
            e = env(t, duration, 0.025, 0.16)
            rise = 220.0 + 820.0 * x
            phase += 2.0 * math.pi * rise / RATE
            value = math.sin(2.0 * math.pi * 64.0 * t) * 0.45
            value += math.sin(2.0 * math.pi * 96.0 * t) * 0.24
            value += math.sin(phase) * (0.18 + 0.30 * x)
            value += filtered_noise * 0.12
            value *= e

        samples.append(value)

    peak = max(max(abs(v) for v in samples), 1e-6)
    gain = 0.86 / peak
    return [max(-1.0, min(1.0, v * gain)) for v in samples]

def write_wav(path, samples):
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(v * 32767.0)) for v in samples)
        wav.writeframes(frames)

for cue, (duration, seed) in SPECS.items():
    write_wav(OUT / f"{cue}.wav", synth(cue, duration, seed))

print("Generated", len(SPECS), "original combat SFX in", OUT)
