"""Procedural SFX + music for the Taoist Wanderer demo (no third-party audio).

Music: Chinese pentatonic (宫商角徵羽) guqin-like plucks (Karplus-Strong with
pitch slides), stereo drones, wood block and temple bell. SFX: filtered noise
and modal synthesis. Output: 44.1 kHz 16-bit WAV (stereo for music, ambience,
and spatial/atmospheric effects; crisp mono for punchy combat/UI/foley).

Usage: python3 tools/audio/make_audio.py [game/assets/audio] [sfx|combat|beds|boss]
"""
import os, sys, wave
import numpy as np

try:
    from scipy.signal import butter as _sp_butter, lfilter as _sp_lfilter, sosfilt as _sp_sosfilt
except Exception:
    _sp_butter = None
    _sp_lfilter = None
    _sp_sosfilt = None

SR = 44100
SUBCOMMANDS = ("sfx", "combat", "beds", "boss")
if len(sys.argv) > 1 and sys.argv[1] not in SUBCOMMANDS:
    OUT = sys.argv[1]
else:
    OUT = os.path.join("game", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(3)


def _n(d):
    return max(1, int(round(SR * d)))


def t_(d):
    return np.arange(_n(d), dtype=np.float64) / SR


def env(n, a=0.005, d=0.2, s=0.0, r=0.0, curve=4.0):
    total = int(n)
    e = np.zeros(total, dtype=np.float64)
    ai = max(1, min(total, int(round(a * SR))))
    e[:ai] = np.linspace(0.0, 1.0, ai)
    rest = total - ai
    if rest > 0:
        e[ai:] = s + (1.0 - s) * np.exp(-np.arange(rest) / max(1.0, d * SR) * curve / 4.0)
    return e


def _fft_pow2(n):
    return 1 << int(np.ceil(np.log2(max(int(n), 16))))


def lowpass(x, cut):
    cut_arr = np.broadcast_to(np.asarray(cut, float), x.shape)
    a = np.exp(-2.0 * np.pi * np.clip(cut_arr, 5.0, SR * 0.49) / SR)
    y = np.zeros_like(x, dtype=np.float64)
    prev = 0.0
    for idx in range(len(x)):
        prev = (1.0 - a[idx]) * x[idx] + a[idx] * prev
        y[idx] = prev
    return y


def lp_fast(x, cut):
    sig = np.asarray(x, dtype=np.float64)
    if sig.shape[0] == 0:
        return sig
    fc = float(np.clip(cut, 5.0, SR * 0.49))
    a = float(np.exp(-2.0 * np.pi * fc / SR))
    if _sp_lfilter is not None:
        return _sp_lfilter([1.0 - a], [1.0, -a], sig, axis=0)
    decay = min(max(256, int(np.ceil(np.log(1e-5) / np.log(min(max(a, 1e-6), 0.99995))))), max(sig.shape[0], SR * 2))
    m = _fft_pow2(sig.shape[0] + decay)
    w = 2.0 * np.pi * np.fft.rfftfreq(m)
    h = (1.0 - a) / (1.0 - a * np.exp(-1j * w))
    if sig.ndim == 2:
        h = h[:, None]
    return np.fft.irfft(np.fft.rfft(sig, n=m, axis=0) * h, n=m, axis=0)[:sig.shape[0]]


def hp_fast(x, cut):
    return np.asarray(x, dtype=np.float64) - lp_fast(x, cut)


def lp_circ(x, cut):
    sig = np.asarray(x, dtype=np.float64)
    n = sig.shape[0]
    if n == 0:
        return sig
    fc = float(np.clip(cut, 5.0, SR * 0.49))
    a = float(np.exp(-2.0 * np.pi * fc / SR))
    w = 2.0 * np.pi * np.fft.rfftfreq(n)
    h = (1.0 - a) / (1.0 - a * np.exp(-1j * w))
    if sig.ndim == 2:
        h = h[:, None]
    return np.fft.irfft(np.fft.rfft(sig, axis=0) * h, n=n, axis=0)


def hp_circ(x, cut):
    return np.asarray(x, dtype=np.float64) - lp_circ(x, cut)


def bp(x, lo, hi):
    return hp_fast(lp_fast(x, hi), lo)


def bp_circ(x, lo, hi):
    return hp_circ(lp_circ(x, hi), lo)


def noise(d, rng_local=None):
    gen = rng if rng_local is None else rng_local
    return gen.standard_normal(_n(d))


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


# loudest-400ms RMS targets per category (dBFS); see tools/audio/audio_review.py
LOUD_TARGET = {
    "music": -16.0,
    "ambience": -22.0,
    "impact": -11.0,
    "ui": -16.5,
    "chime": -17.0,
    "voice": -14.0,
    "foley": -18.0,
}


def category(name):
    if name.startswith("music"):
        return "music"
    if name.startswith("amb"):
        return "ambience"
    if name in ("wisp_pickup", "whisper_chime", "ending_chime", "rest", "barrier_up", "barrier_down"):
        return "chime"
    if name.startswith("ui_") or name in ("stinger_boss", "stinger_victory"):
        return "ui"
    if name in ("growl", "husk_groan", "hiss", "gurgle", "elite_roar", "elite_die", "player_die", "spawn_rise"):
        return "voice"
    if name in (
        "step", "jump", "land", "swing_pre", "talisman_draw", "guard_up",
        "sac_swell", "elite_windup", "seal_charge", "beads_charge", "hearth_ignite",
    ):
        return "foley"
    return "impact"


def loudest_rms(x, win=0.4):
    arr = np.asarray(x, dtype=np.float64)
    pwr = np.mean(arr * arr, axis=1) if arr.ndim == 2 else arr * arr
    n = int(round(win * SR))
    if len(pwr) <= n:
        return np.sqrt(np.mean(pwr)) + 1e-9
    c = np.convolve(pwr, np.ones(n) / n, mode="valid")
    return np.sqrt(c.max()) + 1e-9


def pan_stereo(mono, pan=0.0):
    sig = np.asarray(mono, dtype=np.float64)
    theta = (float(np.clip(pan, -1.0, 1.0)) + 1.0) * (np.pi * 0.25)
    return np.column_stack((sig * np.cos(theta), sig * np.sin(theta)))


def add_at(buf, start_idx, sig, wrap=False):
    arr = np.asarray(sig, dtype=np.float64)
    if arr.shape[0] == 0:
        return
    if buf.ndim == 2 and arr.ndim == 1:
        arr = np.column_stack((arr, arr)) * 0.70710678
    n_buf = buf.shape[0]
    n_sig = arr.shape[0]
    if wrap:
        start = int(start_idx) % n_buf
        first = min(n_sig, n_buf - start)
        buf[start:start + first] += arr[:first]
        rem = n_sig - first
        pos = first
        while rem > 0:
            chunk = min(rem, n_buf)
            buf[:chunk] += arr[pos:pos + chunk]
            pos += chunk
            rem -= chunk
    else:
        start = int(start_idx)
        if start >= n_buf or start + n_sig <= 0:
            return
        src0 = max(0, -start)
        dst0 = max(0, start)
        count = min(n_sig - src0, n_buf - dst0)
        if count > 0:
            buf[dst0:dst0 + count] += arr[src0:src0 + count]


def anchor_low_end(st, cut=150.0, circular=False):
    mid = 0.5 * (st[:, 0] + st[:, 1])
    side = 0.5 * (st[:, 0] - st[:, 1])
    side_hi = hp_circ(side, cut) if circular else hp_fast(side, cut)
    return np.column_stack((mid + side_hi, mid - side_hi))


def stereo_reverb_circular(st, taps_l, taps_r, damp_hz=3600.0, wet=0.36, cross=0.28):
    rev_l = np.zeros(st.shape[0], dtype=np.float64)
    rev_r = np.zeros(st.shape[0], dtype=np.float64)
    src_l = st[:, 0]
    src_r = st[:, 1]
    for dly, gain in taps_l:
        shift = int(round(dly * SR))
        rev_l += np.roll(src_l * (1.0 - cross) + src_r * cross, shift) * gain
    for dly, gain in taps_r:
        shift = int(round(dly * SR))
        rev_r += np.roll(src_r * (1.0 - cross) + src_l * cross, shift) * gain
    wet_st = lp_circ(np.column_stack((rev_l, rev_r)), damp_hz)
    return anchor_low_end(st + wet * wet_st, 150.0, circular=True)


def stereo_reverb_oneshot(st, taps_l=None, taps_r=None, damp_hz=4200.0, wet=0.28, cross=0.26):
    if taps_l is None:
        taps_l = [(0.017, 0.42), (0.037, 0.30), (0.067, 0.20), (0.109, 0.13)]
    if taps_r is None:
        taps_r = [(0.023, 0.42), (0.043, 0.30), (0.079, 0.20), (0.127, 0.13)]
    n = st.shape[0]
    rev_l = np.zeros(n, dtype=np.float64)
    rev_r = np.zeros(n, dtype=np.float64)
    src_l = st[:, 0]
    src_r = st[:, 1]
    for dly, gain in taps_l:
        k = int(round(dly * SR))
        if 0 < k < n:
            rev_l[k:] += (src_l[:-k] * (1.0 - cross) + src_r[:-k] * cross) * gain
    for dly, gain in taps_r:
        k = int(round(dly * SR))
        if 0 < k < n:
            rev_r[k:] += (src_r[:-k] * (1.0 - cross) + src_l[:-k] * cross) * gain
    wet_st = lp_fast(np.column_stack((rev_l, rev_r)), damp_hz)
    return anchor_low_end(st + wet * wet_st, 160.0, circular=False)


def stereo_bloom(mono, width=0.34, damp_hz=4600.0, taps=(0.013, 0.029, 0.053)):
    """Mono-compatible stereo early-reflection bloom: summing L+R cancels the side cleanly."""
    sig = np.asarray(mono, dtype=np.float64)
    n = len(sig)
    side = np.zeros(n, dtype=np.float64)
    signs = (1.0, -0.72, 0.48)
    for dly, sgn in zip(taps, signs):
        k = int(round(dly * SR))
        if 0 < k < n:
            side[k:] += sig[:-k] * sgn
    side = hp_fast(lp_fast(side, damp_hz), 180.0) * width
    return np.column_stack((sig + side, sig - side))


def save(name, x, peak=0.9, target_db=None):
    """Loudness-normalize to the category target, soft-limit peaks to -1 dBFS.
    Supports mono (N,) and stereo (N, 2) at 44.1 kHz. Loops get no edge fades."""
    arr = np.asarray(x, dtype=np.float64).copy()
    is_stereo = arr.ndim == 2 and arr.shape[1] == 2
    if is_stereo:
        arr -= arr.mean(axis=0, keepdims=True)
    else:
        arr = arr.reshape(-1)
        arr -= arr.mean()
    cat = category(name)
    tgt = LOUD_TARGET[cat] if target_db is None else float(target_db)
    arr *= 10.0 ** (tgt / 20.0) / loudest_rms(arr)
    ceiling = 10.0 ** (-1.0 / 20.0)
    knee = ceiling * 0.8
    if is_stereo:
        mag = np.max(np.abs(arr), axis=1)
        over = mag > knee
        if np.any(over):
            limited = knee + (ceiling - knee) * np.tanh((mag[over] - knee) / (ceiling - knee))
            arr[over] *= (limited / mag[over])[:, None]
    else:
        over = np.abs(arr) > knee
        if np.any(over):
            arr[over] = np.sign(arr[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(arr[over]) - knee) / (ceiling - knee)))
    if cat not in ("music", "ambience"):
        fin = min(len(arr) // 10, int(round(0.0015 * SR)))
        fout = min(len(arr) // 8, int(round(0.005 * SR)))
        if fin > 0:
            w_in = np.linspace(0.0, 1.0, fin)
            arr[:fin] *= w_in[:, None] if is_stereo else w_in
        if fout > 0:
            w_out = np.linspace(1.0, 0.0, fout)
            arr[-fout:] *= w_out[:, None] if is_stereo else w_out
    data = np.round(np.clip(arr, -1.0, 1.0) * 32767.0).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2 if is_stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def sweep_noise(d, f0, f1, q=1.0):
    n = noise(d)
    out = np.zeros_like(n)
    k = len(n)
    seg = int(round(0.012 * SR))
    pad = int(round(0.025 * SR))
    for i in range(0, k, seg):
        frac = i / max(k, 1)
        fc = f0 * (f1 / f0) ** frac
        sl = n[max(0, i - pad):i + seg]
        out[i:i + seg] = bp(sl, fc / (1.0 + q), fc * (1.0 + q))[-len(n[i:i + seg]):]
    return out


def thud(d, f0, f1):
    tt = t_(d)
    f = f0 * (f1 / f0) ** (tt / max(d, 1e-6))
    ph = np.cumsum(2.0 * np.pi * f / SR)
    return np.sin(ph) * env(len(tt), 0.002, d * 0.5)


def modal(d, freqs, decays, amps):
    tt = t_(d)
    x = np.zeros_like(tt)
    for f, dc, a in zip(freqs, decays, amps):
        if f < SR * 0.48:
            x += a * np.sin(2.0 * np.pi * f * tt) * np.exp(-tt / max(dc, 1e-6))
    return x


def modal_stereo(d, freqs, decays, amps, spread=0.35, detune_hz=1.6, onset=0.0, attack=0.003):
    tt = t_(d)
    delta = np.maximum(0.0, tt - onset)
    gate = np.where(tt < onset, 0.0, np.minimum(1.0, delta / max(attack, 1e-6)))
    left = np.zeros_like(tt)
    right = np.zeros_like(tt)
    for idx, (f, dc, a) in enumerate(zip(freqs, decays, amps)):
        if f >= SR * 0.47:
            continue
        if idx == 0:
            pan = 0.0
        else:
            pan = spread * (-1.0 if idx % 2 == 1 else 1.0) * min(1.0, 0.42 + 0.14 * idx)
        theta = (pan + 1.0) * (np.pi * 0.25)
        df = detune_hz * (0.35 + 0.18 * idx)
        dec = np.exp(-delta / max(dc, 1e-6))
        left += a * np.cos(theta) * np.sin(2.0 * np.pi * (f + 0.5 * df) * delta) * dec
        right += a * np.sin(theta) * np.sin(2.0 * np.pi * (f - 0.5 * df) * delta) * dec
    return np.column_stack((left * gate, right * gate))


def ks_pluck(freq, d, bright=0.5, slide=0.0, rng_local=None):
    """Vectorized fractional-delay Karplus-Strong with guqin 吟猱 pitch slide at 44.1 kHz."""
    gen = rng if rng_local is None else rng_local
    n = _n(d)
    period = SR / float(freq)
    min_period = period / (2.0 ** (max(slide, 0.0) / 12.0))
    buf_len = int(np.ceil(max(period, period / (2.0 ** (min(slide, 0.0) / 12.0))))) + 4
    buf = gen.uniform(-1.0, 1.0, buf_len)
    buf = lp_fast(buf, 1800.0 + 4200.0 * bright)
    buf -= buf.mean()
    y = np.zeros(n + buf_len, dtype=np.float64)
    y[:buf_len] = buf
    smooth = 0.28 - 0.14 * float(np.clip(bright, 0.0, 1.0))
    decay_p = 0.9965 + 0.0022 * float(np.clip(bright, 0.0, 1.0))
    chunk_max = max(1, int(np.floor(min_period)) - 3)
    pos = buf_len
    total = n + buf_len
    while pos < total:
        end = min(total, pos + chunk_max)
        idxs = np.arange(pos, end, dtype=np.float64)
        if slide != 0.0:
            tfrac = (idxs - buf_len) / max(n, 1)
            cur_p = period / (2.0 ** (slide * np.maximum(0.0, tfrac - 0.35) / 0.65 / 12.0))
        else:
            cur_p = period
        j = idxs - cur_p
        j0 = np.floor(j).astype(np.int64)
        fr = j - j0
        s0 = (1.0 - fr) * y[j0] + fr * y[j0 + 1]
        sm1 = (1.0 - fr) * y[j0 - 1] + fr * y[j0]
        sp1 = (1.0 - fr) * y[j0 + 1] + fr * y[j0 + 2]
        y[pos:end] = decay_p * ((1.0 - 2.0 * smooth) * s0 + smooth * (sm1 + sp1))
        pos = end
    out = y[buf_len:]
    out = hp_fast(out + 0.28 * lp_fast(out, 420.0), 85.0)
    return out * env(n, 0.0015, d * 1.15)


def _clip_hz(freq, lo=15.0, hi=None):
    upper = SR * 0.46 if hi is None else hi
    return np.clip(freq, lo, upper)


def _butter_fft(sig, cut, order=2, btype="low"):
    arr = np.asarray(sig, dtype=np.float64)
    n = arr.shape[0]
    if n == 0:
        return arr
    k = np.arange(1, order + 1, dtype=np.float64)
    proto = np.exp(1j * np.pi * (2.0 * k + order - 1.0) / (2.0 * order))
    if btype in ("low", "high"):
        wc = np.tan(np.pi * float(_clip_hz(cut)) / SR)
        sp = wc * proto
        zp = (1.0 + sp) / (1.0 - sp)
        r_max = float(np.max(np.abs(zp)))
        decay = min(max(256, int(np.ceil(np.log(1e-5) / np.log(min(max(r_max, 1e-6), 0.99995))))), max(n, SR * 2))
        m = _fft_pow2(n + decay)
        w = 2.0 * np.pi * np.fft.rfftfreq(m)
        zinv = np.exp(-1j * w)
        den = np.prod(1.0 - zp[:, None] * zinv[None, :], axis=0)
        if btype == "low":
            gain = float(np.real(np.prod(1.0 - zp) / (2.0 ** order)))
            h = gain * ((1.0 + zinv) ** order) / den
        else:
            gain = float(np.real(np.prod(1.0 + zp) / (2.0 ** order)))
            h = gain * ((1.0 - zinv) ** order) / den
    else:
        lo_hz, hi_hz = cut
        w1 = np.tan(np.pi * lo_hz / SR)
        w2 = np.tan(np.pi * hi_hz / SR)
        bw = w2 - w1
        w0_sq = w1 * w2
        half = 0.5 * bw * proto
        root = np.sqrt(half * half - w0_sq)
        sp = np.concatenate((half + root, half - root))
        zp = (1.0 + sp) / (1.0 - sp)
        r_max = float(np.max(np.abs(zp)))
        decay = min(max(256, int(np.ceil(np.log(1e-5) / np.log(min(max(r_max, 1e-6), 0.99995))))), max(n, SR * 2))
        m = _fft_pow2(n + decay)
        w = 2.0 * np.pi * np.fft.rfftfreq(m)
        zinv = np.exp(-1j * w)
        den = np.prod(1.0 - zp[:, None] * zinv[None, :], axis=0)
        w_center = 2.0 * np.arctan(np.sqrt(w0_sq))
        zinv_c = np.exp(-1j * w_center)
        gain = float(np.abs(np.prod(1.0 - zp * zinv_c) / ((1.0 - zinv_c * zinv_c) ** order)))
        h = gain * ((1.0 - zinv * zinv) ** order) / den
    if arr.ndim == 2:
        h = h[:, None]
    return np.fft.irfft(np.fft.rfft(arr, n=m, axis=0) * h, n=m, axis=0)[:n]


def sos_lp(sig, cut, order=2):
    fc = float(_clip_hz(cut))
    if _sp_butter is not None:
        sos = _sp_butter(order, fc / (SR * 0.5), btype="low", output="sos")
        return _sp_sosfilt(sos, sig, axis=0)
    return _butter_fft(sig, fc, order=order, btype="low")


def sos_hp(sig, cut, order=2):
    fc = float(_clip_hz(cut))
    if _sp_butter is not None:
        sos = _sp_butter(order, fc / (SR * 0.5), btype="high", output="sos")
        return _sp_sosfilt(sos, sig, axis=0)
    return _butter_fft(sig, fc, order=order, btype="high")


def sos_bp(sig, lo, hi, order=2):
    lo_hz = float(_clip_hz(lo, 15.0, SR * 0.44))
    hi_hz = float(_clip_hz(hi, lo_hz + 40.0, SR * 0.47))
    if _sp_butter is not None:
        sos = _sp_butter(order, [lo_hz / (SR * 0.5), hi_hz / (SR * 0.5)], btype="band", output="sos")
        return _sp_sosfilt(sos, sig, axis=0)
    return _butter_fft(sig, (lo_hz, hi_hz), order=order, btype="band")


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
def make_v04_sfx():
    """10 new v0.4.0 SFX in the dark ink-wash Taoist xianxia palette."""
    rng_v = np.random.default_rng(404)

    # 1. pot_break — crisp ceramic/earthenware urn shatter + dusty rubble settle (stereo)
    times = t_(0.48)
    n_pot = len(times)
    pot_st = np.zeros((n_pot, 2), dtype=np.float64)
    snap = unit_peak(soft_sat(sos_bp(rng_v.standard_normal(n_pot), 1800.0, 8800.0, 2) * ad_env(times, 0.001, 0.0018, 0.011), 2.0))
    cavity = unit_peak(punch_body(times, 275.0, 118.0, 0.018, 0.036, onset=0.001, attack=0.002, drive=1.35))
    clay_ring = unit_peak(blade_ring(times, [740.0, 1290.0, 2140.0, 3380.0], [0.048, 0.038, 0.028, 0.020], [0.70, 0.85, 0.72, 0.50], glide=-0.03, glide_tau=0.03, onset=0.001, attack=0.002))
    pot_st += pan_stereo(1.15 * snap + 0.52 * cavity + 0.58 * clay_ring, 0.0)
    shard_specs = [
        (0.008, 2450.0, 0.038, -0.42, 0.78),
        (0.019, 3620.0, 0.032, 0.48, 0.72),
        (0.033, 1890.0, 0.046, -0.28, 0.65),
        (0.052, 4780.0, 0.026, 0.58, 0.58),
        (0.074, 2980.0, 0.034, -0.54, 0.48),
        (0.105, 5420.0, 0.022, 0.35, 0.38),
        (0.142, 2260.0, 0.030, -0.22, 0.30),
        (0.188, 3910.0, 0.024, 0.44, 0.22),
    ]
    for onset_s, freq_s, dec_s, pan_s, amp_s in shard_specs:
        clink = blade_ring(times, [freq_s, freq_s * 1.63, freq_s * 2.41], [dec_s, dec_s * 0.7, dec_s * 0.45], [1.0, 0.58, 0.32], onset=onset_s, attack=0.0012)
        pot_st += pan_stereo(unit_peak(clink) * amp_s * 0.44, pan_s)
    dust_l = sos_bp(rng_v.standard_normal(n_pot), 340.0, 2800.0, 2) * ad_env(times, 0.030, 0.025, 0.135)
    dust_r = sos_bp(rng_v.standard_normal(n_pot), 340.0, 2800.0, 2) * ad_env(times, 0.034, 0.028, 0.140)
    grit_l = micro_bursts(times, [0.022, 0.058, 0.112, 0.175, 0.245], [0.006, 0.008, 0.009, 0.010, 0.012], [0.7, 0.55, 0.4, 0.28, 0.18], rng_v, 1100.0, 5800.0)
    grit_r = micro_bursts(times, [0.029, 0.071, 0.130, 0.198, 0.268], [0.006, 0.008, 0.009, 0.010, 0.012], [0.7, 0.52, 0.38, 0.26, 0.16], rng_v, 1100.0, 5800.0)
    pot_st += np.column_stack((unit_peak(dust_l) * 0.32 + unit_peak(grit_l) * 0.36, unit_peak(dust_r) * 0.32 + unit_peak(grit_r) * 0.36))
    save("pot_break", anchor_low_end(sos_hp(stereo_reverb_oneshot(pot_st, damp_hz=5200.0, wet=0.18), 55.0, 2), 160.0), 0.90)

    # 2. wood_break — splintering dry weathered timber crate crack + rattle (stereo)
    times = t_(0.46)
    n_wd = len(times)
    wd_st = np.zeros((n_wd, 2), dtype=np.float64)
    crack_main = unit_peak(soft_sat(micro_bursts(times, [0.0015, 0.0065, 0.014, 0.024, 0.039], [0.004, 0.0055, 0.0065, 0.0075, 0.009], [1.0, 0.88, 0.72, 0.54, 0.38], rng_v, 680.0, 4800.0), 2.1))
    box_thump = unit_peak(punch_body(times, 195.0, 68.0, 0.020, 0.052, onset=0.001, attack=0.0025, drive=1.55))
    timber_modes = unit_peak(blade_ring(times, [185.0, 335.0, 560.0, 890.0, 1420.0], [0.052, 0.042, 0.030, 0.022, 0.015], [0.85, 0.78, 0.64, 0.45, 0.30], glide=-0.05, glide_tau=0.03, onset=0.002, attack=0.002))
    wd_st += pan_stereo(1.18 * crack_main + 0.62 * box_thump + 0.68 * timber_modes, 0.0)
    splinters = [
        (0.018, -0.45, 0.65, 950.0, 5200.0, 0.011),
        (0.044, 0.48, 0.58, 820.0, 4600.0, 0.014),
        (0.072, -0.35, 0.46, 1100.0, 5400.0, 0.012),
        (0.115, 0.38, 0.42, 650.0, 3800.0, 0.016),
    ]
    for onset_s, pan_s, amp_s, lo_s, hi_s, dec_s in splinters:
        sp = unit_peak(soft_sat(sos_bp(rng_v.standard_normal(n_wd), lo_s, hi_s, 2) * ad_env(times, onset_s, 0.0012, dec_s), 1.8))
        wd_st += pan_stereo(sp * amp_s * 0.52, pan_s)
    rattle_planks = [
        (0.095, [440.0, 745.0, 1180.0], -0.42, 0.44),
        (0.165, [390.0, 680.0, 1050.0], 0.46, 0.34),
        (0.240, [480.0, 810.0, 1290.0], -0.26, 0.24),
        (0.315, [425.0, 720.0, 1120.0], 0.30, 0.16),
    ]
    for onset_s, fqs, pan_s, amp_s in rattle_planks:
        plank = unit_peak(blade_ring(times, fqs, [0.028, 0.020, 0.013], [1.0, 0.65, 0.35], onset=onset_s, attack=0.0015))
        tap = unit_peak(sos_bp(rng_v.standard_normal(n_wd), 500.0, 3000.0, 2) * ad_env(times, onset_s, 0.001, 0.009))
        wd_st += pan_stereo((0.72 * plank + 0.48 * tap) * amp_s, pan_s)
    save("wood_break", anchor_low_end(sos_hp(stereo_reverb_oneshot(wd_st, damp_hz=3800.0, wet=0.16), 45.0, 2), 160.0), 0.90)

    # 3. brazier_clang — resonant cast-bronze brazier strike + hot ember hiss (stereo)
    times = t_(0.95)
    n_br = len(times)
    strike = unit_peak(soft_sat(sos_bp(rng_v.standard_normal(n_br), 2000.0, 10200.0, 2) * ad_env(times, 0.001, 0.0015, 0.013), 2.1))
    iron_weight = unit_peak(punch_body(times, 215.0, 76.0, 0.022, 0.058, onset=0.001, attack=0.002, drive=1.6))
    bronze_ring = modal_stereo(
        0.95,
        [286.0, 498.0, 796.0, 1188.0, 1745.0, 2540.0, 3710.0, 5240.0],
        [0.44, 0.38, 0.32, 0.25, 0.19, 0.14, 0.095, 0.06],
        [0.85, 0.92, 0.88, 0.76, 0.62, 0.48, 0.32, 0.20],
        spread=0.42, detune_hz=2.8, onset=0.002, attack=0.002,
    )
    bronze_ring /= np.max(np.abs(bronze_ring)) + 1e-9
    hiss_l = sos_bp(rng_v.standard_normal(n_br), 2600.0, 11200.0, 2) * ad_env(times, 0.014, 0.032, 0.245)
    hiss_r = sos_bp(rng_v.standard_normal(n_br), 2600.0, 11200.0, 2) * ad_env(times, 0.018, 0.036, 0.255)
    embers_l = micro_bursts(times, [0.025, 0.068, 0.135, 0.215, 0.320, 0.450], [0.004, 0.005, 0.005, 0.006, 0.006, 0.007], [0.9, 0.72, 0.56, 0.42, 0.30, 0.20], rng_v, 3400.0, 10800.0)
    embers_r = micro_bursts(times, [0.038, 0.092, 0.162, 0.265, 0.380, 0.510], [0.004, 0.005, 0.005, 0.006, 0.006, 0.007], [0.85, 0.68, 0.50, 0.38, 0.26, 0.18], rng_v, 3400.0, 10800.0)
    ember_st = np.column_stack((unit_peak(hiss_l) * 0.42 + unit_peak(embers_l) * 0.34, unit_peak(hiss_r) * 0.42 + unit_peak(embers_r) * 0.34))
    brazier_st = pan_stereo(0.95 * strike + 0.54 * iron_weight, 0.0) + 0.96 * bronze_ring + ember_st
    save("brazier_clang", anchor_low_end(sos_hp(stereo_reverb_oneshot(brazier_st, damp_hz=5600.0, wet=0.26), 45.0, 2), 160.0), 0.90)

    # 4. wisp_pickup — airy jade/dao spirit wisp absorption shimmer (pentatonic harmonic chime, stereo)
    times = t_(0.78)
    n_wp = len(times)
    wisp_st = np.zeros((n_wp, 2), dtype=np.float64)
    pull_freq = np.exp(np.interp(times, [0.0, 0.09, 0.24, 0.55], np.log([1150.0, 2400.0, 4600.0, 3400.0])))
    pull_l = unit_peak(svf_sweep(rng_v.standard_normal(n_wp), pull_freq, 3.2, "bp") * ad_env(times, 0.004, 0.045, 0.155, 1.3))
    pull_r = unit_peak(svf_sweep(rng_v.standard_normal(n_wp), pull_freq * 1.03, 3.2, "bp") * ad_env(times, 0.006, 0.048, 0.160, 1.3))
    wisp_st += np.column_stack((pull_l, pull_r)) * 0.30
    jade_notes = [
        (0.010, 587.33, -0.34, 0.72, 0.30),
        (0.058, 880.00, 0.28, 0.85, 0.28),
        (0.118, 1174.66, -0.16, 0.92, 0.26),
        (0.180, 1318.51, 0.24, 0.70, 0.24),
    ]
    for onset_s, f_j, pan_s, amp_s, dec_s in jade_notes:
        ch = modal_stereo(0.78, [f_j, f_j * 2.0, f_j * 2.756], [dec_s, dec_s * 0.72, dec_s * 0.42], [1.0, 0.34, 0.16], spread=0.22, detune_hz=1.4, onset=onset_s, attack=0.006)
        theta = (pan_s + 1.0) * (np.pi * 0.25)
        wisp_st += np.column_stack((ch[:, 0] * np.cos(theta), ch[:, 1] * np.sin(theta))) * amp_s
    sparkle_l = sos_bp(rng_v.standard_normal(n_wp), 4200.0, 10500.0, 2) * ad_env(times, 0.08, 0.05, 0.18)
    sparkle_r = sos_bp(rng_v.standard_normal(n_wp), 4200.0, 10500.0, 2) * ad_env(times, 0.09, 0.05, 0.18)
    wisp_st += np.column_stack((unit_peak(sparkle_l), unit_peak(sparkle_r))) * 0.16
    save("wisp_pickup", anchor_low_end(sos_hp(stereo_reverb_oneshot(wisp_st, damp_hz=6400.0, wet=0.30), 140.0, 2), 180.0), 0.85, target_db=-16.5)

    # 5. hearth_ignite — deep ceremonial whoosh + warm hearth flame flare + faint brass bell ring (stereo)
    times = t_(1.35)
    n_hi = len(times)
    whoosh_freq = np.exp(np.interp(times, [0.0, 0.11, 0.26, 0.62, 1.25], np.log([190.0, 880.0, 560.0, 310.0, 210.0])))
    whoosh_c = unit_peak(svf_sweep(rng_v.standard_normal(n_hi), whoosh_freq, 1.9, "bp") * ad_env(times, 0.008, 0.095, 0.32, 1.4))
    ignite_boom = unit_peak(punch_body(times, 118.0, 40.0, 0.055, 0.165, onset=0.045, attack=0.022, drive=1.55))
    flame_l = unit_peak(sos_bp(rng_v.standard_normal(n_hi), 240.0, 2700.0, 2) * ad_env(times, 0.075, 0.085, 0.38, 1.3))
    flame_r = unit_peak(sos_bp(rng_v.standard_normal(n_hi), 240.0, 2700.0, 2) * ad_env(times, 0.082, 0.090, 0.39, 1.3))
    crackle_l = unit_peak(micro_bursts(times, [0.11, 0.19, 0.29, 0.42, 0.58, 0.76], [0.005, 0.006, 0.005, 0.007, 0.006, 0.008], [0.85, 0.72, 0.62, 0.50, 0.36, 0.24], rng_v, 1800.0, 7600.0))
    crackle_r = unit_peak(micro_bursts(times, [0.14, 0.23, 0.34, 0.48, 0.64, 0.84], [0.005, 0.006, 0.006, 0.007, 0.007, 0.008], [0.80, 0.68, 0.55, 0.45, 0.32, 0.22], rng_v, 1800.0, 7600.0))
    brass_bell = modal_stereo(
        1.35,
        [293.66, 587.33, 880.00, 1468.3, 2110.0],
        [0.72, 0.56, 0.44, 0.30, 0.20],
        [0.70, 0.55, 0.38, 0.22, 0.12],
        spread=0.38, detune_hz=1.8, onset=0.115, attack=0.045,
    )
    brass_bell /= np.max(np.abs(brass_bell)) + 1e-9
    hearth_st = (
        pan_stereo(0.95 * whoosh_c + 0.68 * ignite_boom, 0.0)
        + np.column_stack((0.58 * flame_l + 0.28 * crackle_l, 0.58 * flame_r + 0.28 * crackle_r))
        + 0.34 * brass_bell
    )
    save("hearth_ignite", anchor_low_end(sos_hp(stereo_reverb_oneshot(hearth_st, damp_hz=4400.0, wet=0.28), 34.0, 2), 150.0), 0.88, target_db=-15.5)

    # 6. ui_hover — subtle dry bamboo/scroll paper brush tick (mono, gentle, low fatigue)
    times = t_(0.085)
    brush_freq = np.exp(np.interp(times, [0.0, 0.03, 0.085], np.log([1750.0, 1280.0, 820.0])))
    paper_brush = unit_peak(svf_sweep(rng_v.standard_normal(len(times)), brush_freq, 1.8, "bp") * ad_env(times, 0.002, 0.006, 0.020, 1.2))
    bamboo_tick = unit_peak(blade_ring(times, [860.0, 1420.0], [0.016, 0.010], [0.80, 0.38], onset=0.003, attack=0.004))
    save("ui_hover", sos_hp(0.72 * paper_brush + 0.48 * bamboo_tick, 240.0, 2), 0.50, target_db=-21.5)

    # 7. ui_click — crisp lacquered woodblock / seal-clack confirm (mono)
    times = t_(0.145)
    clack_imp = unit_peak(soft_sat(sos_bp(rng_v.standard_normal(len(times)), 1100.0, 4800.0, 2) * ad_env(times, 0.001, 0.0015, 0.008), 1.6))
    wood_block = unit_peak(blade_ring(times, [690.0, 1165.0, 1920.0, 2940.0], [0.032, 0.022, 0.014, 0.009], [1.0, 0.72, 0.40, 0.18], onset=0.001, attack=0.0015))
    lacquer_body = unit_peak(punch_body(times, 235.0, 138.0, 0.010, 0.020, onset=0.001, attack=0.0018, drive=1.25))
    save("ui_click", sos_hp(0.68 * clack_imp + 1.00 * wood_block + 0.44 * lacquer_body, 110.0, 2), 0.72, target_db=-16.0)

    # 8. ui_back — muted low wooden tap / scroll-close dismiss (mono)
    times = t_(0.175)
    low_tap = unit_peak(blade_ring(times, [405.0, 645.0, 1020.0], [0.036, 0.024, 0.014], [1.0, 0.56, 0.24], glide=-0.05, glide_tau=0.025, onset=0.002, attack=0.0025))
    wood_thump = unit_peak(punch_body(times, 168.0, 92.0, 0.014, 0.032, onset=0.001, attack=0.003, drive=1.2))
    scroll_freq = np.exp(np.interp(times, [0.0, 0.045, 0.140], np.log([1950.0, 1050.0, 560.0])))
    scroll_close = unit_peak(svf_sweep(rng_v.standard_normal(len(times)), scroll_freq, 1.7, "bp") * ad_env(times, 0.012, 0.018, 0.045, 1.2))
    save("ui_back", sos_hp(0.86 * low_tap + 0.58 * wood_thump + 0.52 * scroll_close, 75.0, 2), 0.65, target_db=-18.0)

    # 9. seal_stamp — weighty vermilion stone seal thump + brief paper resonance (stereo)
    times = t_(0.58)
    n_ss = len(times)
    stone_thump = unit_peak(punch_body(times, 148.0, 42.0, 0.026, 0.095, onset=0.002, attack=0.0025, drive=1.75))
    stone_crack = unit_peak(soft_sat(sos_bp(rng_v.standard_normal(n_ss), 580.0, 3400.0, 2) * ad_env(times, 0.0015, 0.002, 0.014), 2.0))
    jade_stone = unit_peak(blade_ring(times, [332.0, 578.0, 945.0, 1510.0], [0.052, 0.038, 0.026, 0.016], [0.92, 0.72, 0.48, 0.28], glide=-0.03, glide_tau=0.028, onset=0.002, attack=0.002))
    paper_slap_l = unit_peak(sos_bp(rng_v.standard_normal(n_ss), 1300.0, 5400.0, 2) * ad_env(times, 0.005, 0.004, 0.034))
    paper_slap_r = unit_peak(sos_bp(rng_v.standard_normal(n_ss), 1300.0, 5400.0, 2) * ad_env(times, 0.006, 0.004, 0.036))
    desk_res = modal_stereo(0.58, [126.0, 238.0, 392.0], [0.16, 0.11, 0.075], [0.75, 0.48, 0.28], spread=0.28, detune_hz=1.2, onset=0.004, attack=0.004)
    desk_res /= np.max(np.abs(desk_res)) + 1e-9
    seal_st = (
        pan_stereo(1.12 * stone_thump + 0.85 * stone_crack + 0.72 * jade_stone, 0.0)
        + np.column_stack((0.36 * paper_slap_l, 0.36 * paper_slap_r))
        + 0.42 * desk_res
    )
    save("seal_stamp", anchor_low_end(sos_hp(stereo_reverb_oneshot(seal_st, damp_hz=3200.0, wet=0.22), 30.0, 2), 145.0), 0.90, target_db=-11.5)

    # 10. whisper_chime — soft distant bronze wind-chime + airy breath swell (stereo)
    times = t_(1.55)
    n_wc = len(times)
    wc_st = np.zeros((n_wc, 2), dtype=np.float64)
    br_freq_l = np.exp(np.interp(times, [0.0, 0.45, 1.05, 1.55], np.log([560.0, 1380.0, 920.0, 580.0])))
    br_freq_r = np.exp(np.interp(times, [0.0, 0.52, 1.12, 1.55], np.log([620.0, 1260.0, 1020.0, 610.0])))
    breath_env = np.sin(np.pi * np.clip(times / 1.50, 0.0, 1.0)) ** 1.45
    breath_l = unit_peak(svf_sweep(rng_v.standard_normal(n_wc), br_freq_l, 2.4, "bp") * breath_env)
    breath_r = unit_peak(svf_sweep(rng_v.standard_normal(n_wc), br_freq_r, 2.4, "bp") * breath_env)
    wc_st += np.column_stack((breath_l, breath_r)) * 0.34
    chime_hits = [
        (0.11, 659.25, -0.36, 0.62, 0.68),
        (0.32, 987.77, 0.38, 0.68, 0.62),
        (0.56, 1318.51, -0.04, 0.56, 0.55),
    ]
    for onset_s, f_c, pan_s, amp_s, dec_s in chime_hits:
        ch = modal_stereo(1.55, [f_c, f_c * 2.01, f_c * 2.756], [dec_s, dec_s * 0.65, dec_s * 0.40], [1.0, 0.32, 0.22], spread=0.26, detune_hz=1.6, onset=onset_s, attack=0.022)
        theta = (pan_s + 1.0) * (np.pi * 0.25)
        wc_st += np.column_stack((ch[:, 0] * np.cos(theta), ch[:, 1] * np.sin(theta))) * amp_s
    wc_st = lp_fast(wc_st, 5200.0)
    save("whisper_chime", anchor_low_end(sos_hp(stereo_reverb_oneshot(wc_st, damp_hz=4400.0, wet=0.38), 120.0, 2), 180.0), 0.78, target_db=-19.0)


# ------------------------------------------------------------------ SFX
def make_sfx():
    save("swing_pre", bp(noise(0.12), 800, 3000) * env(_n(0.12), 0.01, 0.05), 0.4)
    save("step", bp(noise(0.08), 100, 900) * env(_n(0.08), 0.002, 0.02), 0.5)
    save("jump", sweep_noise(0.18, 300, 1200, 0.8) * env(_n(0.18), 0.01, 0.06), 0.5)
    save("land", (bp(noise(0.2), 60, 600) + 0.8 * thud(0.2, 120, 50)) * env(_n(0.2), 0.002, 0.06), 0.7)
    save("guard_up", modal(0.25, [1800, 2700], [0.05, 0.03], [0.3, 0.2]) + bp(noise(0.25), 1000, 4000) * env(_n(0.25), 0.002, 0.02), 0.5)
    clang = modal(0.6, [880, 1320, 2210, 3170, 4400], [0.25, 0.18, 0.12, 0.08, 0.05], [1, 0.7, 0.5, 0.35, 0.2])
    save("block", clang + 2 * bp(noise(0.6), 2000, 6000) * env(_n(0.6), 0.001, 0.015), 0.8)
    parry_ring = modal_stereo(1.2, [1047, 1568, 2093, 3136, 4186], [0.7, 0.5, 0.4, 0.25, 0.15], [1, 0.8, 0.6, 0.4, 0.3], spread=0.40, detune_hz=2.4)
    parry_hit = pan_stereo(3.0 * bp(noise(1.2), 2500, 7500) * env(_n(1.2), 0.001, 0.02) + 0.6 * thud(1.2, 200, 80), 0.0)
    save("parry", stereo_reverb_oneshot(parry_ring + parry_hit, damp_hz=5800.0, wet=0.22), 0.9)
    hurt = (bp(noise(0.35), 150, 1500) + 1.2 * thud(0.35, 160, 60)) * env(_n(0.35), 0.002, 0.12)
    save("player_hurt", hurt, 0.85)
    die = (bp(noise(1.6), 80, 800) * env(_n(1.6), 0.01, 0.8) + thud(1.6, 110, 35) + 0.3 * modal(1.6, [220, 330], [0.8, 0.6], [1, 0.6]))
    save("player_die", die, 0.85)
    save("talisman_draw", bp(noise(0.18), 2000, 7000) * env(_n(0.18), 0.01, 0.06), 0.4)
    fire = bp(noise(0.5), 500, 4000) * env(_n(0.5), 0.005, 0.3)
    crack = np.zeros(_n(0.5))
    ck_len = int(round(0.0027 * SR))
    ck_tau = 0.00045 * SR
    for _ in range(18):
        i = rng.integers(0, len(crack) - ck_len - 16)
        crack[i:i + ck_len] += rng.uniform(-1, 1, ck_len) * np.exp(-np.arange(ck_len) / ck_tau)
    save("talisman_fire", fire + 1.5 * crack + 0.3 * sweep_noise(0.5, 3000, 800, 0.5) * env(_n(0.5), 0.01, 0.2), 0.75)
    save("talisman_hit", (bp(noise(0.4), 400, 5000) * env(_n(0.4), 0.001, 0.1) + 0.5 * thud(0.4, 300, 90)), 0.8)
    pop = thud(0.15, 400, 900) * env(_n(0.15), 0.001, 0.03)
    save("gourd_uncork", pop + 0.3 * bp(noise(0.15), 1000, 3000) * env(_n(0.15), 0.001, 0.02), 0.6)
    gust = sweep_noise(0.9, 200, 1500, 1.0) * env(_n(0.9), 0.08, 0.4) + 0.6 * thud(0.9, 90, 50)
    save("gourd_gust", stereo_bloom(gust, width=0.38, damp_hz=3600.0), 0.85)
    tt = t_(0.5)
    shim = sum(np.sin(2 * np.pi * f * tt * (1 + 0.3 * tt)) * 0.2 for f in [523, 659, 784, 1047]) * env(len(tt), 0.3, 0.3)
    save("beads_charge", shim + 0.4 * bp(noise(0.5), 3000, 8000) * env(len(tt), 0.3, 0.2), 0.6)
    bell_st = modal_stereo(1.9, [262, 524, 698, 1047, 1400, 2093], [1.3, 0.95, 0.75, 0.58, 0.40, 0.30], [1, 0.6, 0.5, 0.4, 0.3, 0.25], spread=0.45, detune_hz=2.0)
    beads_core = pan_stereo(1.2 * thud(1.9, 140, 45) + 0.6 * sweep_noise(1.9, 2500, 400, 0.8) * env(_n(1.9), 0.01, 0.4), 0.0)
    save("beads_burst", stereo_reverb_oneshot(bell_st + beads_core, damp_hz=5000.0, wet=0.28), 0.9)
    edie = bp(noise(1.0), 100, 1200) * env(_n(1.0), 0.01, 0.4) + 0.6 * thud(1.0, 90, 40)
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
    save("claw", sweep_noise(0.2, 1500, 4000, 0.5) * env(_n(0.2), 0.005, 0.06), 0.6)
    save("hiss", bp(noise(0.6), 3000, 8000) * env(_n(0.6), 0.05, 0.3), 0.6)
    save("pounce", sweep_noise(0.3, 800, 2500, 0.6) * env(_n(0.3), 0.01, 0.1) + 0.3 * growl(0.3, 140), 0.7)
    cr = np.zeros(_n(0.9))
    cr_len = int(round(0.009 * SR))
    cr_tau = 0.00136 * SR
    for _ in range(30):
        i = rng.integers(0, len(cr) - cr_len - 16)
        cr[i:i + cr_len] += rng.uniform(-1, 1, cr_len) * np.exp(-np.arange(cr_len) / cr_tau) * rng.uniform(0.3, 1)
    save("seal_crack", bp(cr, 500, 6000) + 0.4 * thud(0.9, 70, 40), 0.8)
    tt = t_(0.55)
    rise = np.sin(2 * np.pi * np.cumsum(200 + 900 * (tt / 0.55) ** 2) / SR) * env(len(tt), 0.3, 0.3, 0.6)
    save("seal_charge", rise * 0.5 + bp(noise(0.55), 400, 3000) * (tt / 0.55), 0.7)
    sb_mono = bp(noise(1.0), 80, 3000) * env(_n(1.0), 0.001, 0.25) + 1.4 * thud(1.0, 160, 35) + 0.5 * modal(1.0, [180, 270, 405], [0.5, 0.4, 0.3], [1, 0.6, 0.4])
    save("seal_burst", stereo_reverb_oneshot(stereo_bloom(sb_mono, width=0.32), damp_hz=4200.0, wet=0.22), 0.95)
    save("sleeve", sweep_noise(0.35, 300, 1200, 1.0) * env(_n(0.35), 0.03, 0.12), 0.7)
    tt = t_(0.6)
    bub = sum(np.sin(2 * np.pi * rng.uniform(150, 400) * tt * (1 + tt)) * np.exp(-((tt - rng.uniform(0, 0.5)) / 0.03) ** 2) for _ in range(12))
    save("gurgle", bub + 0.3 * lp_fast(noise(0.6), 500) * env(len(tt), 0.05, 0.3), 0.6)
    tt = t_(0.9)
    swell = lowpass(noise(0.9), 300 + 900 * tt / 0.9) * (tt / 0.9) ** 1.5 + 0.4 * np.sin(2 * np.pi * (80 + 60 * tt) * tt) * (tt / 0.9)
    save("sac_swell", swell + 0.4 * bub[:len(swell)] if len(bub) >= len(swell) else swell, 0.7)
    save("spit", (bp(noise(0.35), 300, 3000) * env(_n(0.35), 0.002, 0.08) + 0.6 * thud(0.35, 220, 90)), 0.8)
    save("splat", (bp(noise(0.5), 150, 2500) * env(_n(0.5), 0.001, 0.12) + 0.4 * thud(0.5, 140, 60)), 0.8)
    save("elite_roar", growl(1.6, 55, 0.8, 0.25) + 0.5 * thud(1.6, 70, 40), 0.9)
    save("elite_windup", lp_fast(noise(0.8), 600) * env(_n(0.8), 0.4, 0.3, 0.7) + 0.4 * modal(0.8, [140, 210], [0.6, 0.5], [1, 0.6]), 0.7)
    chop = bp(noise(1.2), 40, 2000) * env(_n(1.2), 0.001, 0.25) + 1.8 * thud(1.2, 120, 28) + 0.5 * modal(1.2, [95, 160, 250], [0.6, 0.5, 0.3], [1, 0.6, 0.4])
    save("elite_chop", chop, 0.98)
    save("elite_sweep", sweep_noise(0.6, 250, 1800, 1.0) * env(_n(0.6), 0.05, 0.2) + 0.6 * thud(0.6, 90, 50), 0.9)
    save("elite_step", lp_fast(noise(0.3), 300) * env(_n(0.3), 0.002, 0.08) + thud(0.3, 70, 40), 0.8)
    ab_ring = modal_stereo(1.0, [400, 620, 980, 1500], [0.4, 0.3, 0.25, 0.15], [1, 0.8, 0.6, 0.4], spread=0.42, detune_hz=2.5)
    ab_core = pan_stereo(bp(noise(1.0), 1000, 6500) * env(_n(1.0), 0.001, 0.05) + thud(1.0, 120, 40), 0.0)
    save("armor_break", stereo_reverb_oneshot(ab_ring + ab_core, damp_hz=5000.0, wet=0.22), 0.9)
    save("elite_die", growl(2.5, 50, 0.6, 0.5) + 1.5 * thud(2.5, 80, 25) + 0.4 * bp(noise(2.5), 60, 800) * env(_n(2.5), 0.2, 1.5), 0.95)
    sr_mono = lp_fast(noise(0.9), 400) * env(_n(0.9), 0.4, 0.4) + 0.3 * growl(0.9, 70, 0.3, 0.1)
    save("spawn_rise", stereo_bloom(sr_mono, width=0.35, damp_hz=2400.0), 0.6)
    tt = t_(1.2)
    bu_st = modal_stereo(1.2, [392, 587, 784], [0.8, 0.6, 0.4], [1, 0.7, 0.5], spread=0.40, detune_hz=1.8) + stereo_bloom(0.5 * bp(noise(1.2), 2000, 6500) * env(len(tt), 0.2, 0.4), width=0.42)
    save("barrier_up", stereo_reverb_oneshot(bu_st, damp_hz=5400.0, wet=0.30), 0.7)
    bd_st = modal_stereo(1.5, [523, 659, 784, 1047], [0.95, 0.78, 0.68, 0.48], [1, 0.8, 0.6, 0.5], spread=0.44, detune_hz=1.6)
    save("barrier_down", stereo_reverb_oneshot(bd_st, damp_hz=5600.0, wet=0.32), 0.7)
    rest_st = modal_stereo(2.0, [196, 294, 392, 587], [1.35, 1.1, 0.9, 0.7], [1, 0.6, 0.5, 0.3], spread=0.38, detune_hz=1.2) + stereo_bloom(0.2 * lp_fast(noise(2.0), 800) * env(_n(2.0), 0.4, 0.85), width=0.35, damp_hz=2600.0)
    save("rest", stereo_reverb_oneshot(rest_st, damp_hz=4400.0, wet=0.35), 0.7)
    ec_st = modal_stereo(2.6, [262, 392, 524, 659, 784], [2.2, 1.85, 1.5, 1.2, 0.95], [1, 0.8, 0.6, 0.5, 0.4], spread=0.46, detune_hz=1.4)
    save("ending_chime", stereo_reverb_oneshot(ec_st, damp_hz=4800.0, wet=0.38), 0.8)
    save("ui_confirm", modal(0.6, [784, 1175], [0.3, 0.2], [1, 0.6]), 0.6)
    save("ui_move", modal(0.2, [1175], [0.06], [1]), 0.4)
    make_combat_sfx()
    make_v04_sfx()


# ------------------------------------------------------------------ music
PENTA = [0, 2, 4, 7, 9]  # gong shang jiao zhi yu


def note_freq(root, degree, octave=0):
    o, d = divmod(degree, 5)
    return root * 2 ** ((PENTA[d] + 12 * (o + octave)) / 12)


def drone_stereo(d, f, amp=0.3, breathe=0.12, seed=7):
    """Strictly periodic stereo harmonic drone with mono-compatible low end."""
    r = np.random.default_rng(seed)
    tt = t_(d)
    n = len(tt)
    cyc_base = max(1, int(round(f * d)))
    f_per = cyc_base / d
    xl = np.zeros(n, dtype=np.float64)
    xr = np.zeros(n, dtype=np.float64)
    for h in (1, 2, 3, 4):
        ph = r.uniform(0.0, 2.0 * np.pi)
        w = 2.0 * np.pi * f_per * h * tt
        if h == 1:
            tone = np.sin(w + ph)
            xl += tone
            xr += tone
        else:
            shift = 0.26 * h
            xl += np.sin(w + ph + shift) / h
            xr += np.sin(w + ph - shift) / h
    b_l = 1.0 + breathe * np.sin(2.0 * np.pi * tt / d)
    b_r = 1.0 + breathe * np.sin(2.0 * np.pi * tt / d + 0.65)
    nl = lp_circ(r.standard_normal(n), f * 2.2) * 2.2
    nr = lp_circ(r.standard_normal(n), f * 2.2) * 2.2
    nc = lp_circ(r.standard_normal(n), f * 1.8) * 2.2
    st = np.column_stack((xl * b_l + 0.36 * nc + 0.34 * nl, xr * b_r + 0.36 * nc + 0.34 * nr))
    return anchor_low_end(lp_circ(st, f * 4.2) * amp, 150.0, circular=True)


def music(name, root, dur, bpm, density, mood_low, seed, bells=False, wood=True):
    r = np.random.default_rng(seed)
    n = _n(dur)
    mix = np.zeros((n, 2), dtype=np.float64)
    mix += drone_stereo(dur, root * 0.5, 0.075, seed=seed + 100)
    mix += drone_stereo(dur, root * 0.75, 0.028, seed=seed + 200)
    beat = 60.0 / bpm
    t = 0.0
    deg = mood_low + 2
    harm_off = int(round(0.002 * SR))
    while t < dur - beat * 0.45:
        if r.random() < density:
            step = r.choice([-2, -1, -1, 0, 1, 1, 2, 3])
            deg = int(np.clip(deg + step, mood_low, 12))
            f = note_freq(root, deg)
            ln = float(r.choice([1.6, 2.4, 3.2]))
            p = ks_pluck(f, ln, bright=float(r.uniform(0.32, 0.72)), slide=float(r.choice([0, 0, 0, 1, -1, 2])), rng_local=r)
            pan = float(r.uniform(-0.48, 0.48))
            i = int(round(t * SR))
            add_at(mix, i, pan_stereo(p * float(r.uniform(0.82, 1.18)), pan), wrap=True)
            if r.random() < 0.28:  # octave harmonic 泛音 panned gently opposite
                h = ks_pluck(f * 2.0, 1.5, bright=0.88, rng_local=r)
                add_at(mix, i + harm_off, pan_stereo(h * 0.18, float(np.clip(-pan * 1.25, -0.68, 0.68))), wrap=True)
        t += beat * float(r.choice([1, 1, 2, 2, 3]))
    if wood:
        t = 0.0
        while t < dur - beat * 0.5:
            if r.random() < 0.32:
                k = modal(0.15, [800, 1250], [0.03, 0.02], [1, 0.4]) * 0.18
                add_at(mix, int(round(t * SR)), pan_stereo(k, float(r.uniform(0.24, 0.44))), wrap=True)
            t += beat * 2.0
    if bells:
        bell_step = max(6.5, dur * 0.5)
        for tb in np.arange(1.8, dur - 1.5, bell_step):
            b = modal_stereo(3.6, [root, root * 2.76, root * 5.4, root * 8.9], [2.6, 1.8, 1.1, 0.7], [1, 0.5, 0.3, 0.2], spread=0.44, detune_hz=1.4) * 0.24
            add_at(mix, int(round(tb * SR)), b, wrap=True)
    taps_l = [(0.053, 0.30), (0.109, 0.22), (0.181, 0.16), (0.269, 0.11)]
    taps_r = [(0.079, 0.30), (0.149, 0.22), (0.227, 0.16), (0.313, 0.11)]
    wet = stereo_reverb_circular(mix, taps_l, taps_r, damp_hz=4400.0, wet=0.46, cross=0.38)
    save(name, anchor_low_end(hp_circ(lp_circ(wet, 6800.0), 38.0), 150.0, circular=True), 0.72)


def loop_fix(x, fade_s=1.5):
    """Equal-power seamless crossfade splice for 1D or 2D (N, 2) buffers."""
    arr = np.asarray(x, dtype=np.float64)
    k = max(1, int(round(fade_s * SR)))
    y = arr[:-k].copy()
    ang = 0.5 * np.pi * np.linspace(0.0, 1.0, k)
    w_in = np.sin(ang)
    w_out = np.cos(ang)
    if arr.ndim == 2:
        y[:k] = y[:k] * w_in[:, None] + arr[-k:] * w_out[:, None]
    else:
        y[:k] = y[:k] * w_in + arr[-k:] * w_out
    return y


def _wind_mono(d_total, d_loop, rng_local, lo=0.5, hi=1.6, base=300.0, phase=0.0):
    n = _n(d_total)
    raw = rng_local.standard_normal(n)
    tt = np.arange(n, dtype=np.float64) / SR
    lfo1 = np.sin(2.0 * np.pi * tt / d_loop + phase)
    lfo2 = np.sin(2.0 * np.pi * 2.0 * tt / d_loop + phase * 1.7 + 0.8)
    cut = base + base * (0.48 * (lfo1 + 1.0) * 0.5 + 0.26 * (lfo2 + 1.0) * 0.5)
    x = np.zeros(n, dtype=np.float64)
    seg = int(round(0.025 * SR))
    pad = int(round(0.095 * SR))
    for i in range(0, n, seg):
        sl = raw[max(0, i - pad):i + seg]
        y_seg = hp_fast(lp_fast(lp_fast(sl, cut[i] * hi), cut[i] * hi), cut[i] * lo)
        x[i:i + seg] = y_seg[-len(raw[i:i + seg]):]
    amp_mod = 0.76 + 0.20 * np.sin(2.0 * np.pi * tt / d_loop + phase * 0.5) + 0.08 * np.sin(2.0 * np.pi * 2.0 * tt / d_loop + phase)
    return x * amp_mod


def wind_bed_stereo(d, seed, lo=0.5, hi=1.6, base=300.0, width=0.55, fade_s=1.5):
    """Seamless stereo wind bed with periodic drift and mono-compatible low end."""
    r = np.random.default_rng(seed)
    d_total = d + fade_s
    center = _wind_mono(d_total, d, r, lo=lo, hi=hi, base=base, phase=0.0)
    side_l = _wind_mono(d_total, d, r, lo=lo * 1.05, hi=hi * 1.10, base=base * 1.08, phase=0.45)
    side_r = _wind_mono(d_total, d, r, lo=lo * 1.05, hi=hi * 1.10, base=base * 1.08, phase=2.15)
    w = float(np.clip(width, 0.0, 0.85))
    c = np.sqrt(max(0.0, 1.0 - w * w))
    st = np.column_stack((c * center + w * side_l, c * center + w * side_r))
    st = loop_fix(st, fade_s=fade_s)
    st = lp_circ(lp_circ(hp_circ(st, 35.0), 3400.0), 3400.0)
    return anchor_low_end(st, 150.0, circular=True)


def ambience():
    d = 6.0
    bed = wind_bed_stereo(d, seed=71, lo=0.45, hi=1.65, base=310.0, width=0.58)
    airy = wind_bed_stereo(d, seed=72, lo=0.65, hi=1.55, base=760.0, width=0.68) * 0.22
    taps_l = [(0.053, 0.20), (0.119, 0.13)]
    taps_r = [(0.067, 0.20), (0.137, 0.13)]
    out = lp_circ(stereo_reverb_circular(bed + airy, taps_l, taps_r, damp_hz=3000.0, wet=0.25), 3400.0)
    save("amb_wind", out, 0.5)


def crow(rng_local):
    tt = t_(0.35)
    f = 900.0 - 300.0 * tt / 0.35
    x = np.sign(np.sin(2.0 * np.pi * np.cumsum(f) / SR)) * 0.4 + bp(noise(0.35, rng_local), 700, 2500)
    return lp_fast(x, 2600.0) * env(len(tt), 0.01, 0.12)


def ambience_beds():
    r = np.random.default_rng(91)
    taps_l = [(0.061, 0.22), (0.137, 0.14)]
    taps_r = [(0.073, 0.22), (0.157, 0.14)]

    # village: stereo mountain wind + distant panned crows
    d_v = 6.0
    v = wind_bed_stereo(d_v, 1, base=300.0, width=0.56) * 0.85
    for tc, pan_c in [(1.4, -0.55), (4.2, 0.52)]:
        for k in range(int(r.integers(1, 3))):
            c = crow(r) * 0.22
            add_at(v, int(round((tc + k * 0.44) * SR)), pan_stereo(c, pan_c + 0.08 * k), wrap=True)
    save("amb_village", lp_circ(stereo_reverb_circular(v, taps_l, taps_r, damp_hz=3400.0, wet=0.28), 3800.0), 0.5)

    # lowland: bubbling taint scattered in stereo + low miasma rumble
    d_l = 6.0
    n_l = _n(d_l)
    rumble = lp_circ(r.standard_normal(n_l), 95.0) * 0.32
    l = wind_bed_stereo(d_l, 2, base=185.0, width=0.52) * 0.45 + pan_stereo(rumble, 0.0)
    for _ in range(30):
        tb = float(r.uniform(0.0, d_l))
        f = float(r.uniform(180.0, 520.0))
        tt = t_(0.12)
        b = np.sin(2.0 * np.pi * f * tt * (1.0 + 3.0 * tt)) * np.exp(-tt / 0.03) * float(r.uniform(0.22, 0.58))
        add_at(l, int(round(tb * SR)), pan_stereo(b, float(r.uniform(-0.72, 0.72))), wrap=True)
    save("amb_lowland", lp_circ(stereo_reverb_circular(l, taps_l, taps_r, damp_hz=2800.0, wet=0.26), 3200.0), 0.5)

    # temple: stereo breeze + sparse bronze wind-chimes across eaves
    d_t = 6.0
    te = wind_bed_stereo(d_t, 3, base=370.0, width=0.60) * 0.65
    for tc, base_pan in [(0.8, -0.50), (3.6, 0.48)]:
        for k in range(int(r.integers(2, 4))):
            f = float(r.choice([1568, 1760, 2093, 2349, 2637]))
            ch = modal_stereo(2.2, [f, f * 2.76], [1.1, 0.55], [1.0, 0.3], spread=0.30, detune_hz=1.4) * 0.075
            pan_k = float(np.clip(base_pan + r.uniform(-0.22, 0.22), -0.75, 0.75))
            theta = (pan_k + 1.0) * (np.pi * 0.25)
            ch_p = np.column_stack((ch[:, 0] * np.cos(theta), ch[:, 1] * np.sin(theta)))
            add_at(te, int(round((tc + k * float(r.uniform(0.14, 0.30))) * SR)), ch_p, wrap=True)
    save("amb_temple", lp_circ(stereo_reverb_circular(te, taps_l, taps_r, damp_hz=4600.0, wet=0.34), 5600.0), 0.5)

    # burial: hollow howling stereo wind + distant spectral groans
    d_b = 6.0
    bu = wind_bed_stereo(d_b, 4, lo=0.68, hi=1.32, base=220.0, width=0.62) * 1.0
    for tc, pan_g in [(1.5, -0.44), (4.3, 0.46)]:
        tt = t_(1.8)
        g = np.sin(2.0 * np.pi * (75.0 - 15.0 * tt) * tt + 2.0 * np.sin(2.0 * np.pi * 4.0 * tt)) * env(len(tt), 0.35, 0.9) * 0.12
        add_at(bu, int(round(tc * SR)), pan_stereo(lp_fast(g, 420.0), pan_g), wrap=True)
    save("amb_burial", lp_circ(stereo_reverb_circular(bu, taps_l, taps_r, damp_hz=2600.0, wet=0.32), 2800.0), 0.5)


def taiko(d=0.9, f=62.0, hard=1.0, rng_local=None):
    tt = t_(d)
    body = np.sin(2.0 * np.pi * np.cumsum(f * (1.0 + 0.6 * np.exp(-tt * 30.0))) / SR) * np.exp(-tt / 0.28)
    skin = bp(noise(d, rng_local), 120, 950) * np.exp(-tt / 0.04) * 0.6 * hard
    return (body + skin) * env(len(tt), 0.001, d)


def gong_stereo(d=3.5, f=110.0, rng_local=None):
    ring = modal_stereo(
        d,
        [f, f * 1.47, f * 2.09, f * 2.56, f * 3.31, f * 4.2],
        [2.6, 2.1, 1.6, 1.25, 0.9, 0.65],
        [1.0, 0.7, 0.55, 0.4, 0.3, 0.2],
        spread=0.46, detune_hz=2.2,
    )
    wash_l = bp(noise(d, rng_local), 800, 5600) * env(_n(d), 0.01, 0.55) * 0.26
    wash_r = bp(noise(d, rng_local), 800, 5600) * env(_n(d), 0.01, 0.55) * 0.26
    return ring + np.column_stack((wash_l, wash_r))


def bowed_stereo(f, d, amp=1.0):
    tt = t_(d)
    vib_l = 1.0 + 0.004 * np.sin(2.0 * np.pi * 5.1 * tt)
    vib_r = 1.0 + 0.004 * np.sin(2.0 * np.pi * 5.3 * tt + 1.2)
    ph_l = np.cumsum(2.0 * np.pi * f * 1.0018 * vib_l / SR)
    ph_r = np.cumsum(2.0 * np.pi * f * 0.9982 * vib_r / SR)
    saw_l = sum(np.sin(ph_l * h) / h for h in range(1, 9))
    saw_r = sum(np.sin(ph_r * h) / h for h in range(1, 9))
    sw = (0.5 + 0.5 * np.sin(2.0 * np.pi * tt / d - np.pi / 2.0)) ** 1.2 * amp
    st = np.column_stack((lp_fast(saw_l, f * 6.0) * sw, lp_fast(saw_r, f * 6.0) * sw))
    return anchor_low_end(st, 150.0, circular=False)


def boss_music(name, bars=8, bpm=104, root=82.4, intensity=1.0, seed=21):
    """Boss battle: stereo bowed drone, centered punchy taiko + hall crackle,
    panned driving low guqin ostinato, dissonant stabs and wide bronze gong swells."""
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    dur = bars * 4.0 * beat
    n = _n(dur)
    mix = np.zeros((n, 2), dtype=np.float64)
    # drone: root + fifth, swelling per 4 bars
    for b in range(0, bars, 4):
        i = int(round(b * 4.0 * beat * SR))
        seg = (
            bowed_stereo(root, beat * 16.0, 0.50)
            + bowed_stereo(root * 1.5, beat * 16.0, 0.25)
            + bowed_stereo(root * 2.0 * 2.0 ** (1.0 / 12.0), beat * 16.0, 0.08 * intensity)
        )
        add_at(mix, i, seg * 0.35, wrap=True)
    # taiko: centered punchy body + subtle stereo rim crackle
    pat = [1.0, 0, 0, 0.5, 1.0, 0, 0.6, 0] if intensity <= 1.0 else [1.0, 0.4, 0.5, 0.6, 1.0, 0.4, 0.8, 0.6]
    for b in range(bars):
        for k, a in enumerate(pat):
            if a <= 0:
                continue
            i = int(round((b * 4.0 + k * 0.5) * beat * SR))
            dr = taiko(0.8, 58.0 if k % 4 == 0 else 74.0, a, rng_local=r) * a
            add_at(mix, i, stereo_bloom(dr * 0.9, width=0.32, damp_hz=3600.0), wrap=True)
    # ostinato: low pentatonic plucks on 8ths, alternating slightly L/R
    scale = [0, 3, 5, 7, 10]
    for b in range(bars):
        for k in range(8):
            if r.random() < (0.55 if intensity <= 1.0 else 0.85):
                deg = scale[int(r.integers(0, 3)) if k % 2 == 0 else int(r.integers(1, 5))]
                f = root * 2.0 * 2.0 ** (deg / 12.0)
                p = ks_pluck(f, 0.6, bright=0.62, rng_local=r) * 0.5
                pan = (-0.44 if k % 2 == 0 else 0.44) + float(r.uniform(-0.10, 0.10))
                i = int(round((b * 4.0 + k * 0.5) * beat * SR))
                add_at(mix, i, pan_stereo(p, pan), wrap=True)
    # dissonant stab + wide bronze gong every 8 bars
    for b in range(0, bars, 8):
        i = int(round(b * 4.0 * beat * SR))
        add_at(mix, i, gong_stereo(3.8, root * 1.33, rng_local=r) * 0.35, wrap=True)
        j = i + int(round(beat * 14.0 * SR))
        for s_idx, s in enumerate((0, 1, 6)):
            st_p = ks_pluck(root * 4.0 * 2.0 ** (s / 12.0), 1.2, 0.8, rng_local=r) * 0.25 * intensity
            add_at(mix, j, pan_stereo(st_p, (-0.42, 0.0, 0.42)[s_idx]), wrap=True)
    taps_l = [(0.047, 0.28), (0.107, 0.20), (0.181, 0.13)]
    taps_r = [(0.071, 0.28), (0.143, 0.20), (0.233, 0.13)]
    wet = stereo_reverb_circular(mix, taps_l, taps_r, damp_hz=5200.0, wet=0.40, cross=0.36)
    save(name, anchor_low_end(hp_circ(lp_circ(wet, 7200.0), 34.0), 145.0, circular=True))


def mixl_stereo(*parts):
    n = max(p.shape[0] for p in parts)
    out = np.zeros((n, 2), dtype=np.float64)
    for p in parts:
        arr = np.asarray(p, dtype=np.float64)
        if arr.ndim == 1:
            arr = pan_stereo(arr, 0.0)
        out[:arr.shape[0]] += arr
    return out


def stingers():
    r = np.random.default_rng(77)
    sb = mixl_stereo(
        pan_stereo(taiko(1.4, 50.0, 1.4, rng_local=r), 0.0),
        gong_stereo(2.3, 98.0, rng_local=r) * 0.62,
        bowed_stereo(98.0, 2.3, 0.32),
    )
    save("stinger_boss", stereo_reverb_oneshot(sb, damp_hz=4800.0, wet=0.28))
    up = np.zeros((_n(2.3), 2), dtype=np.float64)
    for idx, (f, a, pan_v) in enumerate([(392.0, 1.0, -0.42), (523.25, 0.85, -0.14), (659.25, 0.72, 0.16), (783.99, 0.64, 0.44)]):
        p = ks_pluck(f, 2.1, 0.72, rng_local=r) * a
        add_at(up, int(round(idx * 0.075 * SR)), pan_stereo(p, pan_v), wrap=False)
    sv = mixl_stereo(up, modal_stereo(2.3, [523.25, 783.99, 1046.5], [1.65, 1.3, 1.0], [0.52, 0.42, 0.32], spread=0.42, detune_hz=1.4))
    save("stinger_victory", stereo_reverb_oneshot(sv, damp_hz=5600.0, wet=0.34))


def make_all_music():
    # Bar-aligned 44.1 kHz stereo loops (~13.7-17.1s each; exact 4-bar / 8-bar cycles)
    music("music_title", 196.0, 16.0 * 60.0 / 68.0, 68, 0.75, 2, 11, bells=True, wood=False)
    music("music_wander", 220.0, 16.0 * 60.0 / 70.0, 70, 0.80, 3, 12)
    music("music_taint", 185.0, 16.0 * 60.0 / 68.0, 68, 0.72, 0, 13, wood=True)
    music("music_temple", 174.6, 16.0 * 60.0 / 68.0, 68, 0.75, 1, 14, bells=True)
    boss_music("music_boss", bars=8, bpm=112, intensity=1.0, seed=21)
    boss_music("music_boss2", bars=8, bpm=124, intensity=1.4, seed=22)
    stingers()


if __name__ == "__main__":
    mode = "all"
    if len(sys.argv) > 1 and sys.argv[1] in SUBCOMMANDS:
        mode = sys.argv[1]
    elif len(sys.argv) > 2 and sys.argv[2] in SUBCOMMANDS:
        mode = sys.argv[2]
    if mode == "sfx":
        make_sfx()
        sys.exit(0)
    if mode == "combat":
        make_combat_sfx()
        sys.exit(0)
    if mode == "beds":
        ambience_beds()
        sys.exit(0)
    if mode == "boss":
        boss_music("music_boss", bars=8, bpm=112, intensity=1.0, seed=21)
        boss_music("music_boss2", bars=8, bpm=124, intensity=1.4, seed=22)
        stingers()
        sys.exit(0)
    ambience_beds()
    make_sfx()
    ambience()
    make_all_music()
    print("audio done")
