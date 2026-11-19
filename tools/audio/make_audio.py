"""Procedural SFX + music for the Taoist Wanderer demo (no third-party audio).

Music: Chinese pentatonic (宫商角徵羽) guqin-like plucks (Karplus-Strong with
pitch slides), low drones, wood block and temple bell. SFX: filtered noise
and modal synthesis. Output: 16-bit mono WAV, 22.05 kHz.

Usage: python -I tools/audio/make_audio.py game/assets/audio
"""
import os, sys, wave
import numpy as np

SR = 22050
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(3)


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.2, s=0.0, r=0.0, curve=4.0):
    total = n
    e = np.zeros(total)
    ai = max(1, int(a * SR))
    e[:ai] = np.linspace(0, 1, ai)
    rest = total - ai
    e[ai:] = s + (1 - s) * np.exp(-np.arange(rest) / max(1, d * SR) * curve / 4)
    return e


def lowpass(x, cut):
    # one-pole, cut in Hz (scalar or array)
    cut = np.broadcast_to(np.asarray(cut, float), x.shape)
    a = np.exp(-2 * np.pi * cut / SR)
    y = np.zeros_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = (1 - a[i]) * x[i] + a[i] * prev
        y[i] = prev
    return y


def lp_fast(x, cut):
    a = np.exp(-2 * np.pi * cut / SR)
    from scipy.signal import lfilter
    return lfilter([1 - a], [1, -a], x)


def hp_fast(x, cut):
    return x - lp_fast(x, cut)


def bp(x, lo, hi):
    return hp_fast(lp_fast(x, hi), lo)


def noise(d):
    return rng.standard_normal(int(SR * d))


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


# loudest-400ms RMS targets per category (dBFS); see tools/audio/audio_review.py
LOUD_TARGET = {"music": -16.0, "ambience": -22.0, "impact": -11.0, "ui": -16.0, "voice": -14.0, "foley": -18.0}


def category(name):
    if name.startswith("music"):
        return "music"
    if name.startswith("amb"):
        return "ambience"
    if name.startswith("ui_") or name in ("rest", "ending_chime", "barrier_up", "barrier_down", "stinger_boss", "stinger_victory"):
        return "ui"
    if name in ("growl", "husk_groan", "hiss", "gurgle", "elite_roar", "elite_die", "player_die", "spawn_rise"):
        return "voice"
    if name in ("step", "jump", "land", "swing_pre", "talisman_draw", "guard_up", "sac_swell", "elite_windup", "seal_charge", "beads_charge"):
        return "foley"
    return "impact"


def loudest_rms(x, win=0.4):
    n = int(win * SR)
    if len(x) <= n:
        return np.sqrt(np.mean(x * x)) + 1e-9
    c = np.convolve(x * x, np.ones(n) / n, mode="valid")
    return np.sqrt(c.max()) + 1e-9


def save(name, x, peak=0.9):
    """Loudness-normalize to the category target, soft-limit peaks to -1 dBFS.
    Loops (music_*/amb_*) get no edge fades so the seam stays continuous."""
    x = np.asarray(x, np.float64)
    x = x - x.mean()
    cat = category(name)
    x = x * (10 ** (LOUD_TARGET[cat] / 20.0) / loudest_rms(x))
    ceiling = 10 ** (-1.0 / 20.0)
    knee = ceiling * 0.8
    over = np.abs(x) > knee
    x[over] = np.sign(x[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(x[over]) - knee) / (ceiling - knee)))
    if cat not in ("music", "ambience"):
        f = min(len(x) // 10, 64)
        if f > 0:
            x[:f] *= np.linspace(0, 1, f)
            x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def sweep_noise(d, f0, f1, q=1.0):
    n = noise(d)
    out = np.zeros_like(n)
    k = len(n)
    seg = 256
    for i in range(0, k, seg):
        frac = i / k
        fc = f0 * (f1 / f0) ** frac
        out[i:i + seg] = bp(n[max(0, i - 512):i + seg], fc / (1 + q), fc * (1 + q))[-len(n[i:i + seg]):]
    return out


def thud(d, f0, f1):
    tt = t_(d)
    f = f0 * (f1 / f0) ** (tt / d)
    ph = np.cumsum(2 * np.pi * f / SR)
    return np.sin(ph) * env(len(tt), 0.002, d * 0.5)


def modal(d, freqs, decays, amps):
    tt = t_(d)
    x = np.zeros_like(tt)
    for f, dc, a in zip(freqs, decays, amps):
        x += a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / dc)
    return x


def ks_pluck(freq, d, bright=0.5, slide=0.0):
    """Karplus-Strong with optional end-of-note pitch slide (guqin 吟猱)."""
    n = int(SR * d)
    period = SR / freq
    buf_len = int(period) + 2
    buf = rng.uniform(-1, 1, buf_len)
    buf = lp_fast(buf, 2000 + 4000 * bright)
    buf -= buf.mean()
    out = np.zeros(n)
    idx = 0.0
    hist = np.zeros(int(SR / (freq * 0.5)) + 4)
    # simple fractional-delay KS using resampling of the period
    y = np.zeros(n + buf_len)
    y[:buf_len] = buf
    p = period
    for i in range(buf_len, n + buf_len):
        tfrac = (i - buf_len) / n
        cur_p = period / (2 ** (slide * max(0, tfrac - 0.35) / 0.65 / 12))
        j = i - cur_p
        j0 = int(j)
        fr = j - j0
        s = (1 - fr) * y[j0] + fr * y[j0 + 1]
        s1 = (1 - fr) * y[j0 - 1] + fr * y[j0]
        y[i] = 0.4993 * (s + s1)
    out = y[buf_len:]
    # body resonance
    out = hp_fast(out + 0.3 * lp_fast(out, 400), 90)
    return out * env(n, 0.001, d * 1.2)


# ------------------------------------------------------------------ SFX
def make_sfx():
    save("swing_pre", bp(noise(0.12), 800, 3000) * env(int(SR * 0.12), 0.01, 0.05), 0.4)
    sw = sweep_noise(0.22, 600, 3200, 0.6) * env(int(SR * 0.22), 0.03, 0.1)
    save("swing", sw, 0.8)
    save("step", bp(noise(0.08), 100, 900) * env(int(SR * 0.08), 0.002, 0.02), 0.5)
    save("jump", sweep_noise(0.18, 300, 1200, 0.8) * env(int(SR * 0.18), 0.01, 0.06), 0.5)
    save("land", (bp(noise(0.2), 60, 600) + 0.8 * thud(0.2, 120, 50)) * env(int(SR * 0.2), 0.002, 0.06), 0.7)
    save("dash", sweep_noise(0.3, 2400, 500, 0.8) * env(int(SR * 0.3), 0.01, 0.12), 0.7)
    save("guard_up", modal(0.25, [1800, 2700], [0.05, 0.03], [0.3, 0.2]) + bp(noise(0.25), 1000, 4000) * env(int(SR * 0.25), 0.002, 0.02), 0.5)
    clang = modal(0.6, [880, 1320, 2210, 3170, 4400], [0.25, 0.18, 0.12, 0.08, 0.05], [1, 0.7, 0.5, 0.35, 0.2])
    save("block", clang + 2 * bp(noise(0.6), 2000, 6000) * env(int(SR * 0.6), 0.001, 0.015), 0.8)
    ring = modal(1.2, [1047, 1568, 2093, 3136, 4186], [0.7, 0.5, 0.4, 0.25, 0.15], [1, 0.8, 0.6, 0.4, 0.3])
    save("parry", ring + 3 * bp(noise(1.2), 2500, 7000) * env(int(SR * 1.2), 0.001, 0.02) + 0.6 * thud(1.2, 200, 80), 0.9)
    hurt = (bp(noise(0.35), 150, 1500) + 1.2 * thud(0.35, 160, 60)) * env(int(SR * 0.35), 0.002, 0.12)
    save("player_hurt", hurt, 0.85)
    die = (bp(noise(1.6), 80, 800) * env(int(SR * 1.6), 0.01, 0.8) + thud(1.6, 110, 35) + 0.3 * modal(1.6, [220, 330], [0.8, 0.6], [1, 0.6]))
    save("player_die", die, 0.85)
    save("talisman_draw", bp(noise(0.18), 2000, 7000) * env(int(SR * 0.18), 0.01, 0.06), 0.4)
    fire = bp(noise(0.5), 500, 4000) * env(int(SR * 0.5), 0.005, 0.3)
    crack = np.zeros(int(SR * 0.5))
    for _ in range(18):
        i = rng.integers(0, len(crack) - 200)
        crack[i:i + 60] += rng.uniform(-1, 1, 60) * np.exp(-np.arange(60) / 10)
    save("talisman_fire", fire + 1.5 * crack + 0.3 * sweep_noise(0.5, 3000, 800, 0.5) * env(int(SR * 0.5), 0.01, 0.2), 0.75)
    save("talisman_hit", (bp(noise(0.4), 400, 5000) * env(int(SR * 0.4), 0.001, 0.1) + 0.5 * thud(0.4, 300, 90)), 0.8)
    pop = thud(0.15, 400, 900) * env(int(SR * 0.15), 0.001, 0.03)
    save("gourd_uncork", pop + 0.3 * bp(noise(0.15), 1000, 3000) * env(int(SR * 0.15), 0.001, 0.02), 0.6)
    gust = sweep_noise(0.9, 200, 1500, 1.0) * env(int(SR * 0.9), 0.08, 0.4) + 0.6 * thud(0.9, 90, 50)
    save("gourd_gust", gust, 0.85)
    tt = t_(0.5)
    shim = sum(np.sin(2 * np.pi * f * tt * (1 + 0.3 * tt)) * 0.2 for f in [523, 659, 784, 1047]) * env(len(tt), 0.3, 0.3)
    save("beads_charge", shim + 0.4 * bp(noise(0.5), 3000, 8000) * env(len(tt), 0.3, 0.2), 0.6)
    bell = modal(2.0, [262, 524, 698, 1047, 1400, 2093], [1.4, 1.0, 0.8, 0.6, 0.4, 0.3], [1, 0.6, 0.5, 0.4, 0.3, 0.25])
    save("beads_burst", bell + 1.2 * thud(2.0, 140, 45) + 0.6 * sweep_noise(2.0, 2500, 400, 0.8) * env(int(SR * 2.0), 0.01, 0.4), 0.9)
    flesh = (bp(noise(0.22), 200, 2500) * env(int(SR * 0.22), 0.001, 0.05) + 0.9 * thud(0.22, 180, 70))
    save("hit_flesh", flesh, 0.85)
    save("hit_heavy", flesh * 0.7 + 1.2 * thud(0.3, 120, 40)[:len(flesh)], 0.9)
    armor = modal(0.5, [310, 470, 930, 1400], [0.12, 0.1, 0.07, 0.05], [1, 0.8, 0.5, 0.3]) + bp(noise(0.5), 300, 3000) * env(int(SR * 0.5), 0.001, 0.03) + 0.8 * thud(0.5, 140, 60)
    save("hit_armor", armor, 0.85)
    edie = bp(noise(1.0), 100, 1200) * env(int(SR * 1.0), 0.01, 0.4) + 0.6 * thud(1.0, 90, 40)
    tt = t_(1.0)
    moan = np.sin(2 * np.pi * (110 - 40 * tt) * tt + 3 * np.sin(2 * np.pi * 6 * tt)) * env(len(tt), 0.05, 0.5)
    save("enemy_die", edie + 0.5 * moan, 0.8)

    def growl(d, f, rough=0.6, pitch_drop=0.3):
        tt = t_(d)
        ff = f * (1 - pitch_drop * tt / d)
        ph = np.cumsum(2 * np.pi * ff / SR)
        mod = 1 + rough * np.sin(2 * np.pi * 31 * tt) * rng.uniform(0.6, 1.0)
        x = np.sign(np.sin(ph)) * 0.5 + np.sin(ph * 2) * 0.3
        x = x * mod + 0.8 * bp(noise(d), f, f * 6)
        return lp_fast(x, 1400) * env(len(tt), 0.05, d * 0.5)
    save("growl", growl(0.7, 85), 0.7)
    save("husk_groan", growl(1.0, 60, 0.4, 0.1), 0.7)
    save("claw", sweep_noise(0.2, 1500, 4000, 0.5) * env(int(SR * 0.2), 0.005, 0.06), 0.6)
    save("hiss", bp(noise(0.6), 3000, 8000) * env(int(SR * 0.6), 0.05, 0.3), 0.6)
    save("pounce", sweep_noise(0.3, 800, 2500, 0.6) * env(int(SR * 0.3), 0.01, 0.1) + 0.3 * growl(0.3, 140), 0.7)
    cr = np.zeros(int(SR * 0.9))
    for _ in range(30):
        i = rng.integers(0, len(cr) - 300)
        cr[i:i + 200] += rng.uniform(-1, 1, 200) * np.exp(-np.arange(200) / 30) * rng.uniform(0.3, 1)
    save("seal_crack", bp(cr, 500, 6000) + 0.4 * thud(0.9, 70, 40), 0.8)
    tt = t_(0.55)
    rise = np.sin(2 * np.pi * np.cumsum(200 + 900 * (tt / 0.55) ** 2) / SR) * env(len(tt), 0.3, 0.3, 0.6)
    save("seal_charge", rise * 0.5 + bp(noise(0.55), 400, 3000) * (tt / 0.55), 0.7)
    save("seal_burst", bp(noise(1.0), 80, 3000) * env(int(SR * 1.0), 0.001, 0.25) + 1.4 * thud(1.0, 160, 35) + 0.5 * modal(1.0, [180, 270, 405], [0.5, 0.4, 0.3], [1, 0.6, 0.4]), 0.95)
    save("sleeve", sweep_noise(0.35, 300, 1200, 1.0) * env(int(SR * 0.35), 0.03, 0.12), 0.7)
    tt = t_(0.6)
    bub = sum(np.sin(2 * np.pi * rng.uniform(150, 400) * tt * (1 + tt)) * np.exp(-((tt - rng.uniform(0, 0.5)) / 0.03) ** 2) for _ in range(12))
    save("gurgle", bub + 0.3 * lp_fast(noise(0.6), 500) * env(len(tt), 0.05, 0.3), 0.6)
    tt = t_(0.9)
    swell = lowpass(noise(0.9), 300 + 900 * tt / 0.9) * (tt / 0.9) ** 1.5 + 0.4 * np.sin(2 * np.pi * (80 + 60 * tt) * tt) * (tt / 0.9)
    save("sac_swell", swell + 0.4 * bub[:len(swell)] if len(bub) >= len(swell) else swell, 0.7)
    save("spit", (bp(noise(0.35), 300, 3000) * env(int(SR * 0.35), 0.002, 0.08) + 0.6 * thud(0.35, 220, 90)), 0.8)
    save("splat", (bp(noise(0.5), 150, 2500) * env(int(SR * 0.5), 0.001, 0.12) + 0.4 * thud(0.5, 140, 60)), 0.8)
    save("elite_roar", growl(1.6, 55, 0.8, 0.25) + 0.5 * thud(1.6, 70, 40), 0.9)
    save("elite_windup", lp_fast(noise(0.8), 600) * env(int(SR * 0.8), 0.4, 0.3, 0.7) + 0.4 * modal(0.8, [140, 210], [0.6, 0.5], [1, 0.6]), 0.7)
    chop = bp(noise(1.2), 40, 2000) * env(int(SR * 1.2), 0.001, 0.25) + 1.8 * thud(1.2, 120, 28) + 0.5 * modal(1.2, [95, 160, 250], [0.6, 0.5, 0.3], [1, 0.6, 0.4])
    save("elite_chop", chop, 0.98)
    save("elite_sweep", sweep_noise(0.6, 250, 1800, 1.0) * env(int(SR * 0.6), 0.05, 0.2) + 0.6 * thud(0.6, 90, 50), 0.9)
    save("elite_step", lp_fast(noise(0.3), 300) * env(int(SR * 0.3), 0.002, 0.08) + thud(0.3, 70, 40), 0.8)
    save("armor_break", modal(1.0, [400, 620, 980, 1500], [0.4, 0.3, 0.25, 0.15], [1, 0.8, 0.6, 0.4]) + bp(noise(1.0), 1000, 6000) * env(int(SR * 1.0), 0.001, 0.05) + thud(1.0, 120, 40), 0.9)
    save("elite_die", growl(2.5, 50, 0.6, 0.5) + 1.5 * thud(2.5, 80, 25) + 0.4 * bp(noise(2.5), 60, 800) * env(int(SR * 2.5), 0.2, 1.5), 0.95)
    save("spawn_rise", lp_fast(noise(0.9), 400) * env(int(SR * 0.9), 0.4, 0.4) + 0.3 * growl(0.9, 70, 0.3, 0.1), 0.6)
    tt = t_(1.2)
    save("barrier_up", modal(1.2, [392, 587, 784], [0.8, 0.6, 0.4], [1, 0.7, 0.5]) + 0.5 * bp(noise(1.2), 2000, 6000) * env(len(tt), 0.2, 0.4), 0.7)
    save("barrier_down", modal(1.6, [523, 659, 784, 1047], [1.0, 0.8, 0.7, 0.5], [1, 0.8, 0.6, 0.5]), 0.7)
    save("rest", modal(2.5, [196, 294, 392, 587], [1.6, 1.3, 1.0, 0.8], [1, 0.6, 0.5, 0.3]) + 0.2 * lp_fast(noise(2.5), 800) * env(int(SR * 2.5), 0.5, 1.0), 0.7)
    save("ending_chime", modal(3.5, [262, 392, 524, 659, 784], [3.0, 2.5, 2.0, 1.6, 1.2], [1, 0.8, 0.6, 0.5, 0.4]), 0.8)
    save("ui_confirm", modal(0.6, [784, 1175], [0.3, 0.2], [1, 0.6]), 0.6)
    save("ui_move", modal(0.2, [1175], [0.06], [1]), 0.4)


# ------------------------------------------------------------------ music
PENTA = [0, 2, 4, 7, 9]  # gong shang jiao zhi yu


def note_freq(root, degree, octave=0):
    o, d = divmod(degree, 5)
    return root * 2 ** ((PENTA[d] + 12 * (o + octave)) / 12)


def drone(d, f, amp=0.3, breathe=0.1):
    tt = t_(d)
    x = sum(np.sin(2 * np.pi * f * h * tt + rng.uniform(0, 6)) / h for h in (1, 2, 3, 4))
    x = x * (1 + breathe * np.sin(2 * np.pi * tt / 7.0))
    x += 0.6 * lp_fast(noise(d), f * 2) * 3
    return lp_fast(x, f * 4) * amp


def music(name, root, dur, bpm, density, mood_low, seed, bells=False, wood=True):
    r = np.random.default_rng(seed)
    n = int(SR * dur)
    mix = np.zeros(n + SR * 4)
    mix[:n] += drone(dur, root / 2, 0.07)
    mix[:n] += drone(dur, root / 2 * 1.5, 0.025)
    beat = 60.0 / bpm
    t = 0.5
    deg = 5
    while t < dur - 3:
        if r.random() < density:
            step = r.choice([-2, -1, -1, 0, 1, 1, 2, 3])
            deg = int(np.clip(deg + step, mood_low, 12))
            f = note_freq(root, deg)
            ln = r.choice([1.5, 2.5, 3.5])
            p = ks_pluck(f, ln, bright=r.uniform(0.3, 0.7), slide=r.choice([0, 0, 0, 1, -1, 2]))
            i = int(t * SR)
            mix[i:i + len(p)] += p * r.uniform(0.8, 1.2)
            if r.random() < 0.25:  # octave harmonic 泛音
                h = ks_pluck(f * 2, 1.5, bright=0.9)
                mix[i + 40:i + 40 + len(h)] += h * 0.15
        t += beat * r.choice([1, 1, 1, 2, 2, 3])
    if wood:
        t = 0.0
        while t < dur - 1:
            if r.random() < 0.3:
                k = modal(0.15, [800, 1250], [0.03, 0.02], [1, 0.4]) * 0.18
                i = int(t * SR)
                mix[i:i + len(k)] += k
            t += beat * 2
    if bells:
        for tb in np.arange(2.0, dur - 4, 12.0):
            b = modal(4.0, [root, root * 2.76, root * 5.4, root * 8.9], [3.0, 2.0, 1.2, 0.8], [1, 0.5, 0.3, 0.2]) * 0.25
            i = int(tb * SR)
            mix[i:i + len(b)] += b
    # wrap the tail into the head so the loop is seamless
    tail = mix[n:]
    mix = mix[:n]
    mix[:len(tail)] += tail
    # gentle reverb-ish smear
    rev = np.zeros_like(mix)
    for dly, g in [(0.083, 0.3), (0.131, 0.22), (0.197, 0.16), (0.271, 0.1)]:
        k = int(dly * SR)
        rev[k:] += mix[:-k] * g
        rev[:k] += mix[-k:] * g
    save(name, loop_fix(hp_fast(lp_fast(mix + rev, 5000), 40), 0.05), 0.7)


def ambience():
    d = 30.0
    n = noise(d)
    tt = t_(d)
    cut = 300 + 250 * (np.sin(2 * np.pi * tt / 9.0) + 1) + 120 * np.sin(2 * np.pi * tt / 3.3)
    x = np.zeros_like(n)
    seg = 512
    for i in range(0, len(n), seg):
        x[i:i + seg] = bp(n[max(0, i - 2048):i + seg], cut[i] * 0.5, cut[i] * 1.6)[-len(n[i:i + seg]):]
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * tt / 10.0)   # 30 s / 10 s: periodic over the loop
    save("amb_wind", loop_fix(x), 0.5)


def wind_bed(d, seed, lo=0.5, hi=1.6, base=300):
    r = np.random.default_rng(seed)
    n = r.standard_normal(int(SR * d))
    tt = t_(d)
    cut = base + base * 0.8 * (np.sin(2 * np.pi * tt / 9.0) + 1) / 2
    x = np.zeros_like(n)
    seg = 512
    for i in range(0, len(n), seg):
        x[i:i + seg] = bp(n[max(0, i - 2048):i + seg], cut[i] * lo, cut[i] * hi)[-len(n[i:i + seg]):]
    return x * (0.6 + 0.4 * np.sin(2 * np.pi * tt / 11.0))


def loop_fix(x, fade_s=2.0):
    k = int(fade_s * SR)
    y = x[:-k].copy()
    y[:k] = y[:k] * np.linspace(0, 1, k) + x[-k:] * np.linspace(1, 0, k)
    return y


def crow():
    tt = t_(0.35)
    f = 900 - 300 * tt / 0.35
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 + bp(noise(0.35), 700, 2500)
    return lp_fast(x, 2500) * env(len(tt), 0.01, 0.12)


def ambience_beds():
    d = 32.0
    r = np.random.default_rng(91)
    # village: wind + distant crows
    v = wind_bed(d, 1) * 0.8
    for tc in np.arange(3.0, d - 3, 7.5):
        for k in range(r.integers(1, 3)):
            c = crow() * 0.25
            i = int((tc + k * 0.45) * SR)
            v[i:i + len(c)] += c
    save("amb_village", loop_fix(v), 0.5)
    # lowland: bubbling taint + low drone
    l = wind_bed(d, 2, base=180) * 0.4 + 0.3 * lp_fast(noise(d), 90)
    for _ in range(140):
        tb = r.uniform(0, d - 0.3)
        f = r.uniform(180, 520)
        tt = t_(0.12)
        b = np.sin(2 * np.pi * f * tt * (1 + 3 * tt)) * np.exp(-tt / 0.03) * r.uniform(0.2, 0.6)
        i = int(tb * SR)
        l[i:i + len(b)] += b
    save("amb_lowland", loop_fix(l), 0.5)
    # temple: wind + sparse wind chimes
    te = wind_bed(d, 3, base=380) * 0.6
    for tc in np.arange(1.5, d - 4, 4.3):
        for k in range(r.integers(2, 5)):
            f = r.choice([1568, 1760, 2093, 2349, 2637])
            ch = modal(2.5, [f, f * 2.76], [1.2, 0.6], [1, 0.3]) * 0.08
            i = int((tc + k * r.uniform(0.1, 0.3)) * SR)
            te[i:i + len(ch)] += ch
    save("amb_temple", loop_fix(te), 0.5)
    # burial: low howling wind + distant groans
    bu = wind_bed(d, 4, lo=0.7, hi=1.3, base=220) * 1.0
    for tc in np.arange(5.0, d - 4, 9.0):
        tt = t_(2.0)
        g = np.sin(2 * np.pi * (75 - 15 * tt) * tt + 2 * np.sin(2 * np.pi * 4 * tt)) * env(len(tt), 0.4, 1.0) * 0.12
        i = int(tc * SR)
        bu[i:i + len(g)] += lp_fast(g, 400)
    save("amb_burial", loop_fix(bu), 0.5)


def taiko(d=0.9, f=62.0, hard=1.0):
    tt = t_(d)
    body = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.6 * np.exp(-tt * 30))) / SR) * np.exp(-tt / 0.28)
    skin = bp(noise(d), 120, 900) * np.exp(-tt / 0.04) * 0.6 * hard
    return (body + skin) * env(len(tt), 0.001, d)


def gong(d=4.0, f=110.0):
    return modal(d, [f, f * 1.47, f * 2.09, f * 2.56, f * 3.31, f * 4.2], [3.0, 2.4, 1.8, 1.4, 1.0, 0.7],
                 [1, 0.7, 0.55, 0.4, 0.3, 0.2]) + 0.3 * bp(noise(d), 800, 5000) * env(int(SR * d), 0.01, 0.6)


def bowed(f, d, amp=1.0):
    tt = t_(d)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * tt)
    ph = np.cumsum(2 * np.pi * f * vib / SR)
    saw = sum(np.sin(ph * h) / h for h in range(1, 9))
    return lp_fast(saw, f * 6) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / d - np.pi / 2)) ** 1.2 * amp


def boss_music(name, dur=40.0, bpm=96, root=82.4, intensity=1.0, seed=21):
    """Boss battle: taiko pattern, bowed drone, driving low guqin ostinato,
    dissonant stabs and gong swells. intensity>1 = phase-2 variant."""
    r = np.random.default_rng(seed)
    n = int(SR * dur)
    mix = np.zeros(n + SR * 5)
    beat = 60.0 / bpm
    bars = int(dur / (beat * 4))
    # drone: root + fifth, swelling per 4 bars
    for b in range(0, bars, 4):
        i = int(b * 4 * beat * SR)
        seg = bowed(root, beat * 16, 0.5) + bowed(root * 1.5, beat * 16, 0.25) + bowed(root * 2.0 * 2 ** (1 / 12), beat * 16, 0.08 * intensity)
        mix[i:i + len(seg)] += seg * 0.35
    # taiko: ka-don pattern, doubled in phase 2
    pat = [1.0, 0, 0, 0.5, 1.0, 0, 0.6, 0] if intensity <= 1.0 else [1.0, 0.4, 0.5, 0.6, 1.0, 0.4, 0.8, 0.6]
    for b in range(bars):
        for k, a in enumerate(pat):
            if a <= 0:
                continue
            i = int((b * 4 + k * 0.5) * beat * SR)
            dr = taiko(0.8, 58.0 if k % 4 == 0 else 74.0, a) * a
            mix[i:i + len(dr)] += dr * 0.9
    # ostinato: low pentatonic plucks on 8ths, minor-ish (yu mode)
    scale = [0, 3, 5, 7, 10]
    for b in range(bars):
        for k in range(8):
            if r.random() < (0.55 if intensity <= 1.0 else 0.85):
                deg = scale[int(r.integers(0, 3)) if k % 2 == 0 else int(r.integers(1, 5))]
                f = root * 2 * 2 ** (deg / 12)
                p = ks_pluck(f, 0.6, bright=0.6) * 0.5
                i = int((b * 4 + k * 0.5) * beat * SR)
                mix[i:i + len(p)] += p
    # dissonant stab + gong every 8 bars
    for b in range(0, bars, 8):
        i = int(b * 4 * beat * SR)
        g = gong(4.0, root * 1.33) * 0.35
        mix[i:i + len(g)] += g
        st = sum(ks_pluck(root * 4 * 2 ** (s / 12), 1.2, 0.8) for s in (0, 1, 6)) * 0.25 * intensity
        j = i + int(beat * 14 * SR)
        mix[j:j + len(st)] += st
    tail = mix[n:]
    mix = mix[:n]
    mix[:len(tail)] += tail
    rev = np.zeros_like(mix)
    for dly, gg in [(0.07, 0.25), (0.13, 0.18), (0.21, 0.12)]:
        k = int(dly * SR)
        rev[k:] += mix[:-k] * gg
        rev[:k] += mix[-k:] * gg
    save(name, loop_fix(hp_fast(lp_fast(mix + rev, 6000), 35), 0.05))


def mixl(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def stingers():
    save("stinger_boss", mixl(taiko(1.5, 50.0, 1.4), gong(3.0, 98.0) * 0.6, bowed(98.0, 3.0, 0.3)))
    tt = t_(3.0)
    up = sum(ks_pluck(f, 3.0, 0.7) * a for f, a in [(392, 1.0), (523, 0.8), (659, 0.7), (784, 0.6)])
    save("stinger_victory", mixl(up, modal(3.0, [523, 784, 1047], [2.0, 1.6, 1.2], [0.5, 0.4, 0.3])))


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[2] == "beds":
        ambience_beds()
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[2] == "boss":
        boss_music("music_boss")
        boss_music("music_boss2", bpm=112, intensity=1.4, seed=22)
        stingers()
        sys.exit(0)
    ambience_beds()
    make_sfx()
    ambience()
    music("music_title", 196.0, 48.0, 54, 0.75, 2, 11, bells=True, wood=False)
    music("music_wander", 220.0, 48.0, 66, 0.8, 3, 12)
    music("music_taint", 185.0, 48.0, 60, 0.7, 0, 13, wood=True)
    music("music_temple", 174.6, 48.0, 58, 0.75, 1, 14, bells=True)
    boss_music("music_boss")
    boss_music("music_boss2", bpm=112, intensity=1.4, seed=22)
    stingers()
    print("audio done")
