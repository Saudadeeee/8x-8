# -*- coding: utf-8 -*-
"""Soan nhac nen cho 8x-8 — vong lap LIEN MACH, nhip cham.

    python tools/make_music.py

Vi sao khong dung rfxgen: rfxgen sinh SFX MOT NHAT, khong ghep duoc thanh vong
lap khong ro mach. O day soan NOT THAT (cao do, truong do, hoa am) roi tong hop
— khac han bo cu vi bo cu la chuoi bip khong co cau truc.

Thiet ke:
  - Am giai RE DORIAN (re mi fa sol la si do) — mau trung co, khong quá u ám
    như minor thuần, không quá tươi như major.
  - 66 BPM. Cham co chu dich: game nay muon nhip thu thanh thong tha kieu
    Bloons TD, nhac nhanh se doi lap voi cach choi.
  - Ba lop: DRONE bass giu goc + ARPEGGIO ram ri + GIAI DIEU thua thot.
  - Vong 32 nhip = 4 o nhac x 8 = ~29 giay. Diem noi lien mach: moi lop deu
    ket thuc dung o mut chu ky bien do nen khong co tieng "cop".
"""
import math
import os
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'audio', 'sfx', 'music_loop.wav')

SR = 44100
BPM = 66.0
BEAT = 60.0 / BPM
BARS = 8
BEATS_PER_BAR = 4
TOTAL_BEATS = BARS * BEATS_PER_BAR
TOTAL = int(SR * BEAT * TOTAL_BEATS)

# Re Dorian: D E F G A B C
SCALE = {'D': 0, 'E': 2, 'F': 3, 'G': 5, 'A': 7, 'B': 9, 'C': 10}


def hz(name, octave):
    """Ten not + quang tam -> tan so. D3 = 146.83 Hz."""
    semis = SCALE[name] + (octave - 3) * 12
    return 146.83 * (2.0 ** (semis / 12.0))


def env(i, n, attack, release):
    """Bao bien do ADSR rut gon, tinh theo ti le trong not."""
    a = max(1, int(n * attack))
    r = max(1, int(n * release))
    if i < a:
        return i / a
    if i > n - r:
        return max(0.0, (n - i) / r)
    return 1.0


def add_note(buf, start_beat, beats, freq, amp, wave_fn, attack=0.06, release=0.35):
    s = int(start_beat * BEAT * SR)
    n = int(beats * BEAT * SR)
    for i in range(n):
        idx = s + i
        if idx >= len(buf):
            # Vong lai dau — giu lien mach khi not tran qua cuoi vong
            idx -= len(buf)
        t = i / SR
        buf[idx] += wave_fn(2.0 * math.pi * freq * t) * amp * env(i, n, attack, release)


def w_sine(x):
    return math.sin(x)


def w_tri(x):
    x = x % (2 * math.pi)
    return 2.0 / math.pi * math.asin(math.sin(x))


def w_soft_square(x):
    """Vuong lam tron — dam hon sine nhung khong choi tai nhu vuong thuan."""
    s = math.sin(x)
    return math.tanh(s * 2.2) * 0.7


def main():
    buf = [0.0] * TOTAL

    # ── Lop 1: DRONE bass, giu goc Re suot 8 o, doi sang La o o 5-6 ──────────
    for bar in range(BARS):
        root = 'D' if bar < 4 or bar >= 6 else 'A'
        add_note(buf, bar * BEATS_PER_BAR, BEATS_PER_BAR, hz(root, 2),
                 0.26, w_tri, attack=0.25, release=0.3)

    # ── Lop 2: ARPEGGIO ram ri, 8 not moi o ─────────────────────────────────
    # Hop am theo o: Dm - Dm - F  - Dm - Am - Am - C  - Dm
    CHORDS = [('D', 'F', 'A'), ('D', 'F', 'A'), ('F', 'A', 'C'), ('D', 'F', 'A'),
              ('A', 'C', 'E'), ('A', 'C', 'E'), ('C', 'E', 'G'), ('D', 'F', 'A')]
    for bar, chord in enumerate(CHORDS):
        for step in range(8):
            note = chord[step % 3]
            octv = 3 if step < 4 else 4
            add_note(buf, bar * BEATS_PER_BAR + step * 0.5, 0.45,
                     hz(note, octv), 0.085, w_sine, attack=0.04, release=0.5)

    # ── Lop 3: GIAI DIEU thua, chi vao o 3-4 va 7-8 ─────────────────────────
    # (beat_offset, ten_not, quang_tam, so_phach)
    MELODY = [
        (8.0, 'A', 4, 1.5), (9.5, 'G', 4, 0.5), (10.0, 'F', 4, 1.0),
        (11.0, 'E', 4, 1.0), (12.0, 'D', 4, 2.0), (14.0, 'F', 4, 2.0),
        (24.0, 'C', 4, 1.5), (25.5, 'D', 4, 0.5), (26.0, 'E', 4, 1.0),
        (27.0, 'F', 4, 1.0), (28.0, 'E', 4, 2.0), (30.0, 'D', 4, 2.0),
    ]
    for b, name, octv, dur in MELODY:
        add_note(buf, b, dur, hz(name, octv), 0.13, w_soft_square,
                 attack=0.08, release=0.4)

    # ── Chuan hoa + fade cuc ngan hai dau de chac chan khong "cop" ──────────
    peak = max(abs(v) for v in buf) or 1.0
    gain = 0.62 / peak
    edge = int(SR * 0.004)
    out = []
    for i, v in enumerate(buf):
        g = gain
        if i < edge:
            g *= i / edge
        elif i > len(buf) - edge:
            g *= (len(buf) - i) / edge
        out.append(max(-32768, min(32767, int(v * g * 32767))))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    w = wave.open(OUT, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(struct.pack('<%dh' % len(out), *out))
    w.close()
    print('nhac nen: %s' % OUT)
    print('  %.1f giay | %d BPM | %d o nhac | Re Dorian' %
          (len(out) / SR, BPM, BARS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
