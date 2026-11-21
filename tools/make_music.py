#!/usr/bin/env python3
"""Renders the plaza's background loop to App/Passby/Resources/theme.wav.

An original 16-bar tune at 96 bpm: soft electric-piano chords, a bossa-style bass,
a shaker and a vibraphone-like melody. Every note's tail wraps round the end, so the
file loops without a seam. Run it again after changing anything here.
"""
import os
import wave

import numpy as np

RATE = 32_000
BPM = 96
BEAT = 60 / BPM
BARS = 16
TOTAL = int(round(BARS * 4 * BEAT * RATE))
out = np.zeros(TOTAL)
rng = np.random.default_rng(7)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add(samples, beat):
    """Mixes a sound in at a beat, wrapping past the end back to the start."""
    start = int(round(beat * BEAT * RATE))
    idx = (start + np.arange(len(samples))) % TOTAL
    np.add.at(out, idx, samples)


def envelope(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(t / attack, 1) * np.exp(-t / decay)


def piano(midi, beats, gain):
    n = int((beats * BEAT + 0.9) * RATE)
    t = np.arange(n) / RATE
    f = hz(midi)
    tone = np.sin(2 * np.pi * f * t) + 0.32 * np.sin(2 * np.pi * 2 * f * t) + 0.1 * np.sin(2 * np.pi * 3 * f * t)
    tone *= 1 + 0.06 * np.sin(2 * np.pi * 4.5 * t)
    return gain * tone * envelope(n, 0.008, 0.25 + beats * BEAT * 0.9)


def bass(midi, beats, gain):
    n = int((beats * BEAT + 0.25) * RATE)
    t = np.arange(n) / RATE
    f = hz(midi)
    tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
    return gain * tone * envelope(n, 0.006, 0.2 + beats * BEAT * 0.7)


def vibes(midi, beats, gain):
    n = int((beats * BEAT + 0.8) * RATE)
    t = np.arange(n) / RATE
    f = hz(midi) * (1 + 0.003 * np.sin(2 * np.pi * 5.5 * t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) + 0.18 * np.sin(4 * phase) * np.exp(-t / 0.12)
    return gain * tone * envelope(n, 0.006, 0.22 + beats * BEAT * 0.75)


def shaker(gain):
    n = int(0.05 * RATE)
    noise = rng.standard_normal(n)
    noise = np.diff(noise, prepend=0)          # crude high-pass
    return gain * noise * envelope(n, 0.002, 0.014)


# Chords as rootless voicings, two bars each, played twice through.
CHORDS = [
    ([52, 55, 59, 62], 36, 43),   # C major 9
    ([55, 59, 60, 64], 33, 40),   # A minor 9
    ([53, 57, 60, 64], 38, 45),   # D minor 9
    ([53, 57, 59, 64], 31, 38),   # G 13
]
COMP = [0, 1.5, 2.5, 4.5, 6, 7.5]            # where the chord lands across two bars
BASS = [(0, 1.5, "root"), (1.5, 0.5, "root"), (2, 1.5, "fifth"), (3.5, 0.5, "fifth")]

for section in range(2):
    for c, (notes, root, fifth) in enumerate(CHORDS):
        base = section * 32 + c * 8
        for hit in COMP:
            for m in notes:
                add(piano(m, 1.0, 0.085), base + hit)
        for bar in range(2):
            for at, length, which in BASS:
                add(bass(root if which == "root" else fifth, length, 0.34), base + bar * 4 + at)

for eighth in range(BARS * 8):
    add(shaker(0.05 if eighth % 2 else 0.028), eighth / 2)

# The tune: (beat, midi note, length in beats).
MELODY = [
    (0, 76, 1), (1, 79, .5), (1.5, 81, 1), (3, 79, .5), (3.5, 76, 1.5), (5.5, 74, .5), (6, 76, 1), (7, 72, 1),
    (8, 81, 1), (9, 79, .5), (9.5, 76, 1), (11, 72, .5), (11.5, 74, 1.5), (13.5, 72, .5), (14, 69, 2),
    (16, 77, 1), (17, 81, .5), (17.5, 79, 1), (19, 77, .5), (19.5, 74, 1.5), (21.5, 76, .5), (22, 77, 1), (23, 81, 1),
    (24, 79, 1.5), (25.5, 77, .5), (26, 76, .5), (26.5, 74, 1.5), (28.5, 71, .5), (29, 74, 1), (30, 67, 2),
    (32, 84, .5), (32.5, 83, .5), (33, 79, 1), (34, 76, .5), (34.5, 79, 1.5), (36.5, 81, .5), (37, 79, .5), (37.5, 76, .5), (38, 74, 1), (39, 72, 1),
    (40, 76, 1), (41, 81, 1), (42, 84, 1.5), (43.5, 83, .5), (44, 81, 2), (46.5, 79, .5), (47, 76, 1),
    (48, 77, .5), (48.5, 79, .5), (49, 81, 1), (50, 86, 1.5), (51.5, 84, .5), (52, 81, 1.5), (53.5, 77, .5), (54, 76, 1), (55, 74, 1),
    (56, 83, 1), (57, 81, .5), (57.5, 79, 1), (59, 77, .5), (59.5, 74, 1.5), (61.5, 76, .5), (62, 74, .5), (62.5, 71, .5), (63, 67, 1),
]
for at, midi, length in MELODY:
    add(vibes(midi, length, 0.2), at)

# A little room: two quiet echoes an eighth note apart. Rolling wraps, so the loop stays seamless.
echo = int(round(BEAT / 2 * RATE))
out = out + 0.16 * np.roll(out, echo) + 0.07 * np.roll(out, 2 * echo)

out *= 0.708 / np.max(np.abs(out))            # peak at -3 dBFS
path = os.path.join(os.path.dirname(__file__), "..", "App", "Passby", "Resources", "theme.wav")
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes((out * 32767).astype("<i2").tobytes())

seam = abs(out[0] - out[-1])
print(f"{TOTAL / RATE:.1f} s, peak {np.max(np.abs(out)):.3f}, rms {np.sqrt(np.mean(out ** 2)):.3f}, seam step {seam:.4f}")
