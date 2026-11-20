"""Automated audio review for game/assets/audio.

Per file: sample rate, channels, duration, peak dBFS, RMS dBFS (whole file and
loudest 400 ms), crest factor, clipped samples, DC offset, and stereo phase
correlation / L-R balance. For loops (music_*/amb_*): per-channel seam jump
(sample discontinuity and RMS step across the wrap point). Flags outliers
against the category targets and optionally writes a Markdown report, JSON
metrics, and spectrogram sheet when OUT is provided.

Usage: python3 -I tools/audio/audio_review.py [game/assets/audio] [docs/audio_review]
"""
import sys, os, wave, glob, json
import numpy as np

EXPECTED_SR = 44100
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join("game", "assets", "audio")
OUT = sys.argv[2] if len(sys.argv) > 2 else None
if OUT:
    os.makedirs(OUT, exist_ok=True)

# category -> (min, max) loudest-400ms RMS dBFS
TARGETS = {
    "music": (-24.0, -12.0),
    "ambience": (-30.0, -16.0),
    "impact": (-18.0, -6.0),
    "ui": (-26.0, -10.0),
    "chime": (-26.0, -10.0),
    "voice": (-22.0, -8.0),
    "foley": (-30.0, -10.0),
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


def load(path):
    with wave.open(path, "rb") as w:
        ch = w.getnchannels()
        sr = w.getframerate()
        sw = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if sw != 2:
        raise ValueError(f"{path}: expected 16-bit PCM, got {sw * 8}-bit")
    x = np.frombuffer(raw, np.int16).astype(np.float64) / 32768.0
    x = x.reshape(-1, ch) if ch > 1 else x.reshape(-1, 1)
    return x, sr, ch


def db(v):
    return 20.0 * np.log10(max(float(v), 1e-9))


def compute_spectrogram(mono, sr, nperseg=1024, noverlap=512):
    step = nperseg - noverlap
    if len(mono) < nperseg:
        mono = np.pad(mono, (0, nperseg - len(mono)))
    n_frames = 1 + (len(mono) - nperseg) // step
    idx = np.arange(nperseg)[None, :] + np.arange(n_frames)[:, None] * step
    win = np.hanning(nperseg)
    frames = mono[idx] * win[None, :]
    spec = np.fft.rfft(frames, axis=1)
    psd = (np.abs(spec) ** 2) / (sr * np.sum(win ** 2))
    return psd.T


rows = []
total_bytes = 0
for f in sorted(glob.glob(os.path.join(SRC, "*.wav"))):
    name = os.path.basename(f)[:-4]
    fsize = os.path.getsize(f)
    total_bytes += fsize
    x, sr, ch = load(f)
    pwr = np.mean(x * x, axis=1)
    n400 = int(0.4 * sr)
    if len(pwr) > n400:
        c = np.convolve(pwr, np.ones(n400) / n400, mode="valid")
        loud = np.sqrt(c.max())
    else:
        loud = np.sqrt(np.mean(pwr))
    rms = np.sqrt(np.mean(pwr))
    peak = float(np.max(np.abs(x)))
    dc = float(np.max(np.abs(np.mean(x, axis=0))))
    row = {
        "name": name,
        "cat": category(name),
        "sr": sr,
        "ch": ch,
        "bytes": fsize,
        "dur": x.shape[0] / sr,
        "peak_db": db(peak),
        "rms_db": db(rms),
        "loud_db": db(loud),
        "crest_db": db(peak) - db(rms),
        "clipped": int((np.abs(x) > 0.999).sum()),
        "dc": dc,
    }
    if ch == 2:
        l_rms = np.sqrt(np.mean(x[:, 0] ** 2))
        r_rms = np.sqrt(np.mean(x[:, 1] ** 2))
        row["lr_imb_db"] = float(abs(db(l_rms) - db(r_rms)))
        lx = x[:, 0] - np.mean(x[:, 0])
        rx = x[:, 1] - np.mean(x[:, 1])
        denom = np.sqrt(np.sum(lx * lx) * np.sum(rx * rx))
        row["corr"] = float(np.sum(lx * rx) / denom) if denom > 1e-12 else 1.0
    if row["cat"] in ("music", "ambience"):
        k = min(int(0.05 * sr), x.shape[0])
        row["seam_jump"] = float(np.max(np.abs(x[0] - x[-1])))
        row["seam_rms_step_db"] = float(max(
            abs(db(np.sqrt(np.mean(x[:k, ci] ** 2))) - db(np.sqrt(np.mean(x[-k:, ci] ** 2))))
            for ci in range(ch)
        ))
    lo, hi = TARGETS[row["cat"]]
    issues = []
    if sr != EXPECTED_SR:
        issues.append(f"sr={sr}!={EXPECTED_SR}")
    if row["cat"] in ("music", "ambience") and ch != 2:
        issues.append("not stereo")
    if row["clipped"] > 0:
        issues.append("clipping")
    if row["peak_db"] > -0.5:
        issues.append("peak>-0.5dB")
    if abs(row["dc"]) > 0.01:
        issues.append("DC offset")
    if row["loud_db"] < lo:
        issues.append(f"quiet ({row['loud_db']:.1f} < {lo})")
    if row["loud_db"] > hi:
        issues.append(f"loud ({row['loud_db']:.1f} > {hi})")
    if row.get("seam_jump", 0.0) > 0.05:
        issues.append(f"loop click ({row['seam_jump']:.3f})")
    if row["cat"] == "ambience" and row.get("seam_rms_step_db", 0.0) > 6.0:
        issues.append(f"loop level step ({row['seam_rms_step_db']:.1f} dB)")
    if ch == 2 and row["corr"] < 0.0:
        issues.append(f"phase<0 ({row['corr']:.2f})")
    if ch == 2 and row["lr_imb_db"] > 3.0:
        issues.append(f"L/R imbalance ({row['lr_imb_db']:.1f} dB)")
    row["issues"] = issues
    rows.append(row)

bad = [r for r in rows if r["issues"]]
sr_set = sorted({r["sr"] for r in rows})
n_stereo = sum(1 for r in rows if r["ch"] == 2)
n_mono = sum(1 for r in rows if r["ch"] == 1)
total_mb = total_bytes / (1024.0 * 1024.0)
max_peak = max((r["peak_db"] for r in rows), default=-99.0)
max_seam = max((r["seam_jump"] for r in rows if "seam_jump" in r), default=0.0)
stereo_corrs = [r["corr"] for r in rows if "corr" in r]
min_corr = min(stereo_corrs) if stereo_corrs else 1.0

if OUT:
    with open(os.path.join(OUT, "audio_metrics.json"), "w") as jf:
        json.dump(rows, jf, indent=1)
    with open(os.path.join(OUT, "AUDIO_REVIEW.md"), "w") as md:
        md.write("# Automated audio review\n\n")
        md.write(
            f"{len(rows)} files analysed · **{len(bad)} flagged** · "
            f"SR {sr_set} Hz · {n_stereo} stereo / {n_mono} mono · {total_mb:.2f} MB. "
            f"Category targets (loudest 400 ms RMS, dBFS): "
            + ", ".join(f"{k} {v[0]:.0f}…{v[1]:.0f}" for k, v in TARGETS.items()) + ".\n\n"
        )
        md.write("Not a listening test — levels, clipping, DC, stereo balance/correlation, loop seams and spectra only.\n\n")
        md.write("| file | cat | sr | ch | dur s | peak dB | loud dB | crest dB | corr | clip | seam | issues |\n")
        md.write("|---|---|---|---|---|---|---|---|---|---|---|---|\n")
        for r in rows:
            seam = f"{r['seam_jump']:.4f}/{r['seam_rms_step_db']:.1f}dB" if "seam_jump" in r else ""
            corr = f"{r['corr']:.2f}" if "corr" in r else "-"
            md.write(
                f"| {r['name']} | {r['cat']} | {r['sr']} | {r['ch']} | {r['dur']:.2f} | "
                f"{r['peak_db']:.1f} | {r['loud_db']:.1f} | {r['crest_db']:.1f} | {corr} | "
                f"{r['clipped']} | {seam} | {', '.join(r['issues'])} |\n"
            )

print(f"{len(rows)} files, {len(bad)} flagged")
print(
    f"summary: sr={sr_set}Hz, stereo={n_stereo}, mono={n_mono}, total={total_mb:.2f} MB, "
    f"max_peak={max_peak:.2f} dBFS, max_seam={max_seam:.4f}, min_stereo_corr={min_corr:.2f}"
)
for r in bad:
    print(f"  {r['name']:18s} {r['cat']:9s} {', '.join(r['issues'])}")

if OUT:
    try:
        from PIL import Image, ImageDraw
        tiles = []
        for r in rows:
            if r["cat"] not in ("music", "ambience") and not r["name"].startswith("elite"):
                continue
            x, sr, _ch = load(os.path.join(SRC, r["name"] + ".wav"))
            mono = x.mean(axis=1)[: sr * 20]
            S = compute_spectrogram(mono, sr, nperseg=1024, noverlap=512)
            S = 10.0 * np.log10(S + 1e-10)
            S = np.clip((S + 100.0) / 80.0, 0.0, 1.0)[::-1]
            im = Image.fromarray((S * 255).astype(np.uint8)).resize((600, 160))
            tiles.append((r["name"], im))
        if tiles:
            sheet = Image.new("L", (600, 180 * len(tiles)), 0)
            draw = ImageDraw.Draw(sheet)
            for i, (n, im) in enumerate(tiles):
                sheet.paste(im, (0, i * 180 + 18))
                draw.text((4, i * 180 + 2), n, fill=255)
            sheet.save(os.path.join(OUT, "spectrograms.png"))
    except Exception as e:
        print("spectrograms skipped:", e)
