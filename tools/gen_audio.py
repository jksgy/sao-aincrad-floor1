# -*- coding: utf-8 -*-
"""Aincrad Proto audio generator: 4 chiptune loop tracks + all SFX, 16-bit 22050Hz mono WAV."""
import math, os, random, struct, wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "project", "assets", "audio")
SR = 22050

NOTE = {}
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
for octv in range(1, 8):
    for i, n in enumerate(NAMES):
        midi = 12 * (octv + 1) + i
        NOTE[f"{n}{octv}"] = 440.0 * (2 ** ((midi - 69) / 12.0))

def env_adsr(n, a, d, s_level, r, total):
    out = [0.0] * n
    for i in range(n):
        t = i / total
        if t < a:
            v = t / a
        elif t < a + d:
            v = 1.0 - (1.0 - s_level) * (t - a) / d
        elif t < 1.0 - r:
            v = s_level
        else:
            v = s_level * max(0.0, (1.0 - t) / r)
        out[i] = v
    return out

def wave_note(freq, dur, kind="square", vib=0.0, duty=0.5, decay=1.0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        ph = t * freq + vib * math.sin(t * 5.0) * 0.01
        p = ph % 1.0
        if kind == "square":
            v = 1.0 if p < duty else -1.0
        elif kind == "triangle":
            v = 4.0 * abs(p - 0.5) - 1.0
        elif kind == "saw":
            v = 2.0 * p - 1.0
        else:  # sine
            v = math.sin(2 * math.pi * ph)
        env = (1.0 - t / (dur * decay)) if decay < 1.0 else 1.0
        env *= 1.0 if t < dur * 0.85 else (dur - t) / (dur * 0.15)
        out.append(v * env)
    return out

def noise_note(dur, cutoff=0.6, decay=1.0):
    n = int(SR * dur)
    rng = random.Random(42)
    lp = 0.0
    out = []
    for i in range(n):
        t = i / SR
        lp += cutoff * (rng.uniform(-1, 1) - lp)
        env = (1.0 - t / (dur * decay)) if decay < 1.0 else 1.0
        env *= 1.0 if t < dur * 0.8 else (dur - t) / (dur * 0.2)
        out.append(lp * 3.0 * env)
    return out

def mix_tracks(tracks, master=0.5):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    peak = max(1e-6, max(abs(v) for v in out))
    return [v / peak * master for v in out]

def save_wav(name, samples):
    os.makedirs(ROOT, exist_ok=True)
    p = os.path.join(ROOT, name)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32000)) for v in samples))
    print("wrote", p, f"{len(samples)/SR:.1f}s", flush=True)

def silence(dur):
    return [0.0] * int(SR * dur)

# ---------------- music ----------------
def track(bpm, bars, mel, bass, drum, lead="square", bass_kind="square", mel_oct=0, key=None):
    """mel/bass: list of per-beat entries: note name or None; drum: pattern string 'x' hit '.' rest."""
    spb = 60.0 / bpm
    mel_t, bass_t, dr_t = [], [], []
    for bar in range(bars):
        for i in range(4):
            m = mel[(bar * 4 + i) % len(mel)]
            b = bass[(bar * 4 + i) % len(bass)]
            if m:
                mel_t += wave_note(NOTE[m] * (2 ** mel_oct), spb * 0.95, lead, decay=0.9)
            else:
                mel_t += silence(spb)
            if b:
                bass_t += wave_note(NOTE[b] * 0.5, spb * 0.95, bass_kind, duty=0.35, decay=0.95)
            else:
                bass_t += silence(spb)
            # drums: 2 eighth per beat
            for j in range(2):
                ch = drum[(bar * 8 + i * 2 + j) % len(drum)]
                if ch == "x":
                    dr_t += noise_note(spb / 2 * 0.6, cutoff=0.7, decay=0.8)
                elif ch == "o":
                    dr_t += wave_note(150.0, spb / 2 * 0.8, "sine", decay=0.85)
                else:
                    dr_t += silence(spb / 2)
    return mix_tracks([mel_t, bass_t, dr_t], master=0.42)

def town_music():
    mel = ["E4", None, "G4", "A4", "B4", None, "A4", "G4", "E4", None, "D4", "E4", "G4", None, "E4", None,
           "C4", None, "E4", "G4", "A4", None, "G4", "E4", "D4", None, "C4", "D4", "E4", None, None, None]
    bass = ["C3", "C3", "G3", "C3", "A2", "A2", "E3", "A2", "F2", "F2", "C3", "F2", "G2", "G2", "D3", "G2"]
    drum = "x.o.x.o." * 2
    return track(100, 16, mel, bass, drum, lead="triangle", bass_kind="triangle")

def field_music():
    mel = ["A3", None, "C4", "D4", "E4", None, "D4", "C4", "A3", None, "G3", "A3", "C4", None, "A3", None,
           "G3", None, "A3", "C4", "D4", None, "E4", None, "G4", None, "E4", "D4", "C4", None, "D4", None]
    bass = ["A2", "A2", "E3", "A2", "F2", "F2", "C3", "F2", "G2", "G2", "D3", "G2", "A2", "A2", "E3", "A2"]
    drum = "x.x.o.x..x.o.x." * 2
    return track(112, 16, mel, bass, drum, lead="square", bass_kind="square")

def dungeon_music():
    mel = ["A2", None, None, "C3", None, "B2", None, "A2", None, "G2", None, None, "E2", None, None, None,
           "A2", None, None, "C3", None, "D3", None, "C3", None, "B2", None, "G2", None, "E2", None, None]
    bass = ["A1", None, "A1", None, "F1", None, "F1", None, "G1", None, "G1", None, "E1", None, "E1", None]
    drum = ".o..o..." * 2
    return track(84, 16, mel, bass, drum, lead="saw", bass_kind="triangle", mel_oct=0)

def boss_music():
    mel = ["E2", None, "E2", "E2", None, "F2", "F2", None, "E2", None, "D2", "D2", None, "E2", None, None,
           "E2", None, "E2", "E2", None, "F2", "F2", "G2", "A2", None, "G2", "F2", "E2", None, "D2", None]
    bass = ["E1", "E1", "E1", "E1", "F1", "F1", "F1", "F1", "D1", "D1", "D1", "D1", "E1", "E1", "B1", "B1"]
    drum = "xx.xx.x.xx.x.x." * 2
    return track(132, 16, mel, bass, drum, lead="saw", bass_kind="square")

# ---------------- sfx ----------------
def sfx_swing():
    return mix_tracks([noise_note(0.09, cutoff=0.9, decay=0.8), wave_note(900, 0.1, "saw", decay=0.7)], 0.5)

def sfx_hit():
    t = noise_note(0.06, cutoff=0.5, decay=0.7) + wave_note(140, 0.12, "sine", decay=0.75)
    return mix_tracks([t], 0.6)

def sfx_hurt():
    t = wave_note(300, 0.18, "square", decay=0.75)
    t2 = wave_note(220, 0.18, "square", decay=0.75)
    n = max(len(t), len(t2))
    for i in range(min(len(t), len(t2))):
        t[i] = t[i] * (1 - i / n) + t2[i] * (i / n)
    return mix_tracks([t], 0.55)

def sfx_die():
    return mix_tracks([noise_note(0.4, cutoff=0.4, decay=0.9), wave_note(180, 0.4, "saw", decay=0.8)], 0.5)

def sfx_dodge():
    t = noise_note(0.16, cutoff=0.9, decay=0.7)
    for i, v in enumerate(t):
        k = i / len(t)
        t[i] = v * (0.4 + k)
    return mix_tracks([t], 0.5)

def sfx_skill():
    t = noise_note(0.3, cutoff=0.95, decay=0.75)
    for i, v in enumerate(t):
        k = i / len(t)
        t[i] = v * (0.3 + k * 0.8)
    t2 = wave_note(1200, 0.22, "sine", decay=0.7)
    return mix_tracks([t, t2], 0.5)

def sfx_potion():
    t = wave_note(500, 0.07, "sine", decay=0.8) + silence(0.03) + wave_note(700, 0.09, "sine", decay=0.8)
    return mix_tracks([t], 0.5)

def sfx_pickup():
    t = wave_note(880, 0.06, "square", decay=0.8) + silence(0.02) + wave_note(1320, 0.1, "square", decay=0.8)
    return mix_tracks([t], 0.42)

def sfx_chest():
    t = noise_note(0.1, cutoff=0.3, decay=0.7) + silence(0.05) + wave_note(660, 0.12, "triangle", decay=0.8) + silence(0.05) + wave_note(880, 0.16, "triangle", decay=0.8)
    return mix_tracks([t], 0.5)

def sfx_lever():
    t = noise_note(0.08, cutoff=0.4, decay=0.8) + silence(0.06) + noise_note(0.1, cutoff=0.5, decay=0.8)
    t2 = wave_note(120, 0.2, "square", decay=0.7)
    return mix_tracks([t, t2], 0.55)

def sfx_levelup():
    notes = ["C4", "E4", "G4", "C5"]
    t = []
    for n in notes:
        t += wave_note(NOTE[n], 0.09, "square", decay=0.8) + silence(0.01)
    return mix_tracks([t], 0.45)

def sfx_confirm():
    return mix_tracks([wave_note(660, 0.06, "square", decay=0.8)], 0.35)

def sfx_cancel():
    return mix_tracks([wave_note(330, 0.08, "square", decay=0.8)], 0.35)

def sfx_roar():
    t = wave_note(110, 0.7, "saw", vib=0.4, decay=0.8) + noise_note(0.7, cutoff=0.25, decay=0.85)
    return mix_tracks([t], 0.6)

def sfx_victory():
    notes = [("C4", 0.14), ("E4", 0.14), ("G4", 0.14), ("C5", 0.4)]
    t = []
    for n, d in notes:
        t += wave_note(NOTE[n], d, "square", decay=0.9) + silence(0.02)
    t2 = [wave_note(NOTE["C3"], 0.5, "triangle", decay=0.95)[:0]][0] + wave_note(NOTE["G3"], 0.5, "triangle", decay=0.95)
    return mix_tracks([t, t2], 0.5)

def sfx_step():
    rng = random.Random()
    t = noise_note(0.05, cutoff=0.3, decay=0.7)
    for i in range(len(t)):
        t[i] *= 0.6
    return mix_tracks([t], 0.3)

def sfx_no_stamina():
    return mix_tracks([wave_note(200, 0.09, "square", decay=0.8) + silence(0.02) + wave_note(180, 0.09, "square", decay=0.8)], 0.4)

def sfx_unlock():
    return mix_tracks([wave_note(NOTE["A4"], 0.12, "square", decay=0.85) + silence(0.02) + wave_note(NOTE["D5"], 0.2, "square", decay=0.9)], 0.45)

def main():
    save_wav("music_town.wav", town_music())
    save_wav("music_field.wav", field_music())
    save_wav("music_dungeon.wav", dungeon_music())
    save_wav("music_boss.wav", boss_music())
    save_wav("swing.wav", sfx_swing())
    save_wav("hit.wav", sfx_hit())
    save_wav("hurt.wav", sfx_hurt())
    save_wav("die.wav", sfx_die())
    save_wav("dodge.wav", sfx_dodge())
    save_wav("skill.wav", sfx_skill())
    save_wav("potion.wav", sfx_potion())
    save_wav("pickup.wav", sfx_pickup())
    save_wav("chest.wav", sfx_chest())
    save_wav("lever.wav", sfx_lever())
    save_wav("levelup.wav", sfx_levelup())
    save_wav("confirm.wav", sfx_confirm())
    save_wav("cancel.wav", sfx_cancel())
    save_wav("roar.wav", sfx_roar())
    save_wav("victory.wav", sfx_victory())
    save_wav("step.wav", sfx_step())
    save_wav("no_stamina.wav", sfx_no_stamina())
    save_wav("unlock.wav", sfx_unlock())
    print("audio done")

if __name__ == "__main__":
    main()
