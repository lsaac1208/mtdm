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


def _clip_hz(freq, lo=15.0, hi=None):
    upper = SR * 0.46 if hi is None else hi
    return np.clip(freq, lo, upper)


def sos_lp(sig, cut, order=2):
    from scipy.signal import butter, sosfilt
    sos = butter(order, float(_clip_hz(cut)) / (SR * 0.5), btype="low", output="sos")
    return sosfilt(sos, sig)


def sos_hp(sig, cut, order=2):
    from scipy.signal import butter, sosfilt
    sos = butter(order, float(_clip_hz(cut)) / (SR * 0.5), btype="high", output="sos")
    return sosfilt(sos, sig)


def sos_bp(sig, lo, hi, order=2):
    from scipy.signal import butter, sosfilt
    lo_hz = float(_clip_hz(lo, 15.0, SR * 0.44))
    hi_hz = float(_clip_hz(hi, lo_hz + 40.0, SR * 0.47))
    sos = butter(order, [lo_hz / (SR * 0.5), hi_hz / (SR * 0.5)], btype="band", output="sos")
    return sosfilt(sos, sig)


def svf_sweep(sig, freq, qval=2.5, mode="bp"):
    count = len(sig)
    freqs = _clip_hz(np.broadcast_to(np.asarray(freq, np.float64), (count,)), 20.0, SR * 0.45)
    qvals = np.broadcast_to(np.asarray(qval, np.float64), (count,))
    damp = 1.0 / np.maximum(qvals, 0.5)
    gain = np.tan(np.pi * freqs / SR)
    coef1 = 1.0 / (1.0 + gain * (gain + damp))
    coef2 = gain * coef1
    coef3 = gain * coef2
    out = np.zeros(count, np.float64)
    ic1 = 0.0
    ic2 = 0.0
    if mode == "bp":
        scale = np.sqrt(damp)
        for idx in range(count):
            v3 = sig[idx] - ic2
            v1 = coef1[idx] * ic1 + coef2[idx] * v3
            v2 = ic2 + coef2[idx] * ic1 + coef3[idx] * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[idx] = v1 * scale[idx]
    elif mode == "lp":
        for idx in range(count):
            v3 = sig[idx] - ic2
            v1 = coef1[idx] * ic1 + coef2[idx] * v3
            v2 = ic2 + coef2[idx] * ic1 + coef3[idx] * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[idx] = v2
    else:
        for idx in range(count):
            v3 = sig[idx] - ic2
            v1 = coef1[idx] * ic1 + coef2[idx] * v3
            v2 = ic2 + coef2[idx] * ic1 + coef3[idx] * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[idx] = sig[idx] - damp[idx] * v1 - v2
    return out


def soft_sat(sig, drive=1.5):
    return np.tanh(sig * drive) / np.tanh(drive)


def unit_peak(sig):
    peak = np.max(np.abs(sig))
    return sig / peak if peak > 1e-9 else sig


def ad_env(times, onset=0.0, attack=0.004, decay=0.06, power=1.0):
    delta = times - onset
    out = np.zeros_like(times)
    atk = max(attack, 1e-6)
    dec = max(decay, 1e-6)
    rising = (delta >= 0.0) & (delta < atk)
    falling = delta >= atk
    out[rising] = (delta[rising] / atk) ** power
    out[falling] = np.exp(-(delta[falling] - atk) / dec)
    return out


def punch_body(times, f_start, f_end, drop_tau, decay, onset=0.0, attack=0.003, drive=1.4):
    delta = np.maximum(0.0, times - onset)
    inst_freq = f_end + (f_start - f_end) * np.exp(-delta / max(drop_tau, 1e-6))
    phase = np.cumsum(2.0 * np.pi * inst_freq / SR)
    tone = soft_sat(np.sin(phase), drive)
    return tone * ad_env(times, onset, attack, decay)


def blade_ring(times, freqs, decays, amps, glide=0.0, glide_tau=0.06, onset=0.0, attack=0.003, mod_sig=None, mod_depth=0.0):
    delta = np.maximum(0.0, times - onset)
    glide_curve = 1.0 + glide * (1.0 - np.exp(-delta / max(glide_tau, 1e-6)))
    out = np.zeros_like(times)
    nyq_lim = SR * 0.47
    for freq, decay, amp in zip(freqs, decays, amps):
        inst = np.clip(freq * glide_curve, 20.0, nyq_lim)
        phase = np.cumsum(2.0 * np.pi * inst / SR)
        out += amp * np.sin(phase) * np.exp(-delta / max(decay, 1e-6))
    gate = np.where(times < onset, 0.0, np.minimum(1.0, delta / max(attack, 1e-6)))
    out *= gate
    if mod_sig is not None and mod_depth != 0.0:
        out *= 1.0 + mod_depth * mod_sig
    return out


def micro_bursts(times, stamps, decays, amps, rng_local, lo=1200.0, hi=5500.0):
    raw = np.zeros_like(times)
    for stamp, decay, amp in zip(stamps, decays, amps):
        raw += amp * rng_local.standard_normal(len(times)) * ad_env(times, stamp, 0.0012, decay)
    return sos_bp(raw, lo, hi, order=2)


def make_combat_sfx():
    rng_c = np.random.default_rng(108)

    times = t_(0.20)
    cut_freq = np.exp(np.interp(times, [0.0, 0.034, 0.068, 0.125, 0.200], np.log([2100.0, 720.0, 1550.0, 4350.0, 3300.0])))
    wind_cut = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), cut_freq, np.linspace(2.4, 3.8, len(times)), "bp") * ad_env(times, 0.003, 0.044, 0.048, 1.5))
    edge_freq = np.exp(np.interp(times, [0.0, 0.042, 0.115, 0.200], np.log([2600.0, 1850.0, 5800.0, 4600.0])))
    edge = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), edge_freq, 3.6, "bp") * ad_env(times, 0.018, 0.032, 0.038, 1.4))
    air_tip = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 3600.0, 8200.0, 2) * ad_env(times, 0.024, 0.024, 0.030, 1.4))
    wind_body = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 520.0, 3600.0, 2) * ad_env(times, 0.005, 0.038, 0.044, 1.3))
    sheen_mod = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 1600.0, 5800.0, 2))
    sheen = unit_peak(blade_ring(times, [2920.0, 3580.0, 4340.0, 5180.0], [0.046, 0.034, 0.024, 0.017], [0.90, 0.74, 0.58, 0.42], glide=0.10, glide_tau=0.052, onset=0.024, attack=0.007, mod_sig=sheen_mod, mod_depth=0.55))
    save("swing", sos_hp(1.00 * wind_cut + 0.72 * edge + 0.36 * air_tip + 0.38 * wind_body + 0.34 * sheen, 180.0, 2), 0.85)

    times = t_(0.30)
    cleave_freq = np.exp(np.interp(times, [0.0, 0.052, 0.135, 0.225, 0.300], np.log([1950.0, 1280.0, 460.0, 230.0, 175.0])))
    cleave = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), cleave_freq, np.linspace(2.6, 1.8, len(times)), "bp") * ad_env(times, 0.006, 0.068, 0.082, 1.6))
    wind_low = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 75.0, 380.0, 2) * ad_env(times, 0.012, 0.065, 0.088, 1.4))
    air_boom = unit_peak(punch_body(times, 124.0, 42.0, 0.052, 0.095, onset=0.036, attack=0.030, drive=1.3))
    hi_freq = np.exp(np.interp(times, [0.0, 0.075, 0.210, 0.300], np.log([3600.0, 2300.0, 740.0, 460.0])))
    hi_edge = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), hi_freq, 2.8, "bp") * ad_env(times, 0.010, 0.055, 0.058, 1.4))
    dark_mod = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 1000.0, 4000.0, 2))
    dark_sheen = unit_peak(blade_ring(times, [1960.0, 2690.0, 3580.0], [0.060, 0.042, 0.028], [0.75, 0.56, 0.38], glide=-0.10, glide_tau=0.068, onset=0.038, attack=0.012, mod_sig=dark_mod, mod_depth=0.55))
    save("swing_heavy", sos_hp(1.15 * cleave + 0.78 * wind_low + 0.36 * air_boom + 0.72 * hi_edge + 0.28 * dark_sheen, 35.0, 2), 0.90)

    times = t_(0.27)
    rip_snap = unit_peak(soft_sat(sos_bp(rng_c.standard_normal(len(times)), 2200.0, 8600.0, 2) * ad_env(times, 0.002, 0.0025, 0.009), 1.9))
    jet_freq = np.exp(np.interp(times, [0.0, 0.022, 0.095, 0.210, 0.270], np.log([6600.0, 4600.0, 2050.0, 1280.0, 960.0])))
    lance_jet = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), jet_freq, 3.6, "bp") * ad_env(times, 0.004, 0.014, 0.066, 1.2))
    qi_freq = np.exp(np.interp(times, [0.0, 0.032, 0.105, 0.230], np.log([1900.0, 3100.0, 5200.0, 4400.0])))
    qi_whistle = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), qi_freq, 5.0, "bp") * ad_env(times, 0.005, 0.015, 0.062, 1.2))
    thrust_kick = unit_peak(punch_body(times, 215.0, 72.0, 0.016, 0.036, onset=0.001, attack=0.0028, drive=1.4))
    bronze_ring = unit_peak(blade_ring(times, [1318.0, 1340.0, 2245.0, 3190.0, 4430.0, 5920.0], [0.160, 0.150, 0.112, 0.080, 0.054, 0.034], [0.55, 0.45, 0.68, 0.56, 0.42, 0.28], glide=0.03, glide_tau=0.048, onset=0.008, attack=0.006))
    save("swing_thrust", sos_hp(0.95 * rip_snap + 1.00 * lance_jet + 0.68 * qi_whistle + 0.34 * thrust_kick + 0.52 * bronze_ring, 65.0, 2), 0.90)

    times = t_(0.32)
    cracks = unit_peak(soft_sat(micro_bursts(times, [0.0025, 0.006, 0.011, 0.018, 0.027], [0.005, 0.0065, 0.0085, 0.010, 0.014], [1.0, 0.88, 0.74, 0.58, 0.42], rng_c, 900.0, 6400.0), 2.1))
    grit = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 480.0, 4200.0, 2) * ad_env(times, 0.002, 0.003, 0.042))
    stone_modes = unit_peak(blade_ring(times, [210.0, 365.0, 620.0, 980.0, 1560.0], [0.055, 0.040, 0.028, 0.019, 0.013], [0.80, 0.68, 0.54, 0.40, 0.28], glide=-0.04, glide_tau=0.025, onset=0.002, attack=0.0025))
    sub_thud = unit_peak(punch_body(times, 138.0, 38.0, 0.026, 0.082, onset=0.001, attack=0.003, drive=1.55))
    rubble = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 95.0, 420.0, 2) * ad_env(times, 0.004, 0.008, 0.085))
    save("ground_slam", sos_hp(1.32 * cracks + 0.84 * grit + 0.56 * stone_modes + 0.64 * sub_thud + 0.58 * rubble, 32.0, 2), 0.90)

    times = t_(0.18)
    bite_snap = unit_peak(soft_sat(sos_bp(rng_c.standard_normal(len(times)), 1250.0, 4800.0, 2) * ad_env(times, 0.002, 0.0025, 0.0085), 2.2))
    wet_freq = np.exp(np.interp(times, [0.0, 0.012, 0.052, 0.130], np.log([4700.0, 3200.0, 1400.0, 980.0])))
    wet_shear = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), wet_freq, 2.5, "bp") * ad_env(times, 0.0025, 0.003, 0.028))
    micro_bite = unit_peak(micro_bursts(times, [0.0025, 0.007, 0.0125], [0.0045, 0.0055, 0.0065], [1.0, 0.70, 0.42], rng_c, 1450.0, 5800.0))
    chest = unit_peak(punch_body(times, 160.0, 55.0, 0.019, 0.044, onset=0.0025, attack=0.003, drive=1.65))
    steel_slice = unit_peak(blade_ring(times, [2950.0, 3980.0, 5150.0], [0.036, 0.026, 0.018], [0.82, 0.66, 0.48], glide=-0.06, glide_tau=0.028, onset=0.0025, attack=0.0025))
    save("hit_flesh", sos_hp(1.38 * bite_snap + 0.98 * wet_shear + 0.88 * micro_bite + 0.46 * chest + 0.52 * steel_slice, 42.0, 2), 0.90)

    times = t_(0.27)
    tear_crack = unit_peak(soft_sat(sos_bp(rng_c.standard_normal(len(times)), 1400.0, 6400.0, 2) * ad_env(times, 0.002, 0.0025, 0.012), 2.3))
    tear_freq = np.exp(np.interp(times, [0.0, 0.018, 0.072, 0.175], np.log([5200.0, 3300.0, 1100.0, 680.0])))
    tear_rip = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), tear_freq, 2.4, "bp") * ad_env(times, 0.003, 0.004, 0.048))
    tear_pulses = unit_peak(soft_sat(micro_bursts(times, [0.0025, 0.008, 0.015, 0.0235], [0.005, 0.0065, 0.0085, 0.010], [1.0, 0.84, 0.66, 0.46], rng_c, 1350.0, 6200.0), 1.9))
    sub_punch = unit_peak(punch_body(times, 140.0, 38.0, 0.028, 0.078, onset=0.003, attack=0.003, drive=1.75))
    sword_ring = unit_peak(blade_ring(times, [1480.0, 2380.0, 3420.0, 4780.0], [0.120, 0.088, 0.060, 0.038], [0.82, 0.70, 0.55, 0.40], glide=-0.03, glide_tau=0.048, onset=0.003, attack=0.003))
    save("hit_heavy", sos_hp(1.28 * tear_crack + 0.96 * tear_rip + 0.98 * tear_pulses + 0.64 * sub_punch + 0.56 * sword_ring, 30.0, 2), 0.90)

    times = t_(0.38)
    spark_noise = unit_peak(soft_sat(sos_bp(rng_c.standard_normal(len(times)), 2800.0, 9000.0, 2) * ad_env(times, 0.002, 0.002, 0.014), 2.1))
    spark_crackle = unit_peak(micro_bursts(times, [0.0025, 0.007, 0.0135, 0.021], [0.0035, 0.0045, 0.0055, 0.006], [1.0, 0.74, 0.50, 0.30], rng_c, 3200.0, 9200.0))
    spark_pings = unit_peak(blade_ring(times, [5280.0, 6820.0, 8250.0], [0.030, 0.020, 0.014], [0.90, 0.78, 0.62], onset=0.002, attack=0.0018))
    iron_raw = unit_peak(blade_ring(times, [515.0, 815.0, 1340.0, 2045.0, 2980.0, 4120.0, 5450.0], [0.180, 0.150, 0.120, 0.092, 0.066, 0.046, 0.030], [0.65, 0.75, 0.88, 0.82, 0.72, 0.56, 0.40], onset=0.002, attack=0.002))
    iron_bite = unit_peak(soft_sat(iron_raw, 2.4) * ad_env(times, 0.002, 0.002, 0.026))
    iron_thud = unit_peak(punch_body(times, 185.0, 68.0, 0.015, 0.036, onset=0.001, attack=0.0025, drive=1.45))
    save("hit_armor", sos_hp(1.15 * spark_noise + 0.95 * spark_crackle + 0.80 * spark_pings + 0.78 * iron_raw + 0.65 * iron_bite + 0.40 * iron_thud, 55.0, 2), 0.90)

    times = t_(0.23)
    wind_freq = np.exp(np.interp(times, [0.0, 0.020, 0.080, 0.160, 0.230], np.log([4200.0, 2600.0, 1100.0, 540.0, 390.0])))
    wind_step = unit_peak(svf_sweep(rng_c.standard_normal(len(times)), wind_freq, np.linspace(2.6, 1.8, len(times)), "bp") * ad_env(times, 0.002, 0.014, 0.062, 1.2))
    air_rush = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 1800.0, 7400.0, 2) * ad_env(times, 0.003, 0.014, 0.048))
    air_tail = unit_peak(sos_bp(rng_c.standard_normal(len(times)), 420.0, 3200.0, 2) * ad_env(times, 0.004, 0.018, 0.065))
    step_pop = unit_peak(punch_body(times, 195.0, 72.0, 0.013, 0.024, onset=0.002, attack=0.0028, drive=1.2))
    cloth_snap = unit_peak(micro_bursts(times, [0.012, 0.030], [0.009, 0.013], [1.0, 0.68], rng_c, 1300.0, 5600.0))
    save("dash", sos_hp(1.00 * wind_step + 0.55 * air_rush + 0.42 * air_tail + 0.28 * step_pop + 0.72 * cloth_snap, 65.0, 2), 0.80)


# ------------------------------------------------------------------ SFX
def make_sfx():
    save("swing_pre", bp(noise(0.12), 800, 3000) * env(int(SR * 0.12), 0.01, 0.05), 0.4)
    save("step", bp(noise(0.08), 100, 900) * env(int(SR * 0.08), 0.002, 0.02), 0.5)
    save("jump", sweep_noise(0.18, 300, 1200, 0.8) * env(int(SR * 0.18), 0.01, 0.06), 0.5)
    save("land", (bp(noise(0.2), 60, 600) + 0.8 * thud(0.2, 120, 50)) * env(int(SR * 0.2), 0.002, 0.06), 0.7)
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
    make_combat_sfx()


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
    if len(sys.argv) > 2 and sys.argv[2] == "sfx":
        make_sfx()
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[2] == "combat":
        make_combat_sfx()
        sys.exit(0)
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
