# SPDX-FileCopyrightText: 2026 NooniOS
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Genera los sonidos propios del widget (sintetizados aquí, sin material de
# terceros). Uso: python3 tools/make_sounds.py
# Salida: package/contents/sounds/*.wav (44,1 kHz, 16 bits, mono)
import math, os, random, struct, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "package", "contents", "sounds")
rnd = random.Random(7)   # siempre igual

def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(name, "%.2f s" % (len(samples) / RATE), "pico %.2f" % peak)

def env(i, attack, decay):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / decay)

def highpass(xs, k=0.92):
    out, prev_x, prev_y = [], 0.0, 0.0
    for x in xs:
        y = k * (prev_y + x - prev_x)
        out.append(y); prev_x, prev_y = x, y
    return out

def lowpass(xs, k=0.15):
    out, y = [], 0.0
    for x in xs:
        y += k * (x - y); out.append(y)
    return out

def click(n, tone, decay, level, noise=0.6):
    burst = highpass([rnd.uniform(-1, 1) for _ in range(n)])
    return [level * env(i, 0.0005, decay) * (noise * burst[i] + (1 - noise) * math.sin(2 * math.pi * tone * i / RATE)) for i in range(n)]

def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]

def delay(xs, seconds):
    return [0.0] * int(seconds * RATE) + xs

# Pasar de un juego a otro: un clic corto y suave.
write("pasar.wav", click(int(0.045 * RATE), 3200, 0.006, 0.35, noise=0.55))

# Abrir la caja: el cierre de plástico que salta y un golpe grave.
thunk = [0.45 * env(i, 0.001, 0.035) * math.sin(2 * math.pi * 140 * i / RATE) for i in range(int(0.16 * RATE))]
write("abrir.wav", mix(click(int(0.05 * RATE), 2400, 0.008, 0.5), delay(thunk, 0.012)))

# Cerrar la caja: al revés (golpe y luego el clic), algo más grave.
thunk2 = [0.5 * env(i, 0.001, 0.03) * math.sin(2 * math.pi * 120 * i / RATE) for i in range(int(0.14 * RATE))]
write("cerrar.wav", mix(thunk2, delay(click(int(0.05 * RATE), 2000, 0.007, 0.45), 0.03)))

# Jugar: dos notas que suben (mi y si), suaves.
def note(freq, start, length, level):
    return delay([level * env(i, 0.004, 0.09) * (math.sin(2 * math.pi * freq * i / RATE) + 0.25 * math.sin(4 * math.pi * freq * i / RATE)) for i in range(int(length * RATE))], start)
write("jugar.wav", mix(note(659.25, 0, 0.32, 0.4), note(987.77, 0.09, 0.4, 0.4)))

# Disco girando: zumbido de lector en bucle (2 s, empalma sin corte).
L = 2 * RATE
noise = lowpass([rnd.uniform(-1, 1) for _ in range(L + RATE // 10)], 0.08)
fade = RATE // 10
loop_noise = [noise[i] if i >= fade else noise[i] * (i / fade) + noise[L + i] * (1 - i / fade) for i in range(L)]
spin = []
for i in range(L):
    t = i / RATE
    wob = 1 + 0.25 * math.sin(2 * math.pi * 1.5 * t)          # 3 vueltas del vaivén en 2 s
    hum = 0.10 * math.sin(2 * math.pi * 95 * t) + 0.05 * math.sin(2 * math.pi * 190 * t)
    whine = 0.05 * wob * math.sin(2 * math.pi * 850 * t)       # 1700 ciclos exactos en 2 s
    spin.append(hum + whine + 0.6 * loop_noise[i])
write("disco.wav", spin)
