"""Automated audio review for game/assets/audio.

Per file: duration, peak dBFS, RMS dBFS (whole file and loudest 400 ms), crest
factor, clipped samples, DC offset. For loops (music_*/amb_*): seam jump (sample
discontinuity and RMS step across the wrap point). Flags outliers against the
category targets and writes a Markdown report + spectrogram sheet.

Usage: python -I tools/audio/audio_review.py game/assets/audio docs/audio_review
"""
import sys, os, wave, glob, json
import numpy as np

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

# category -> (min, max) loudest-400ms RMS dBFS
TARGETS = {
    "music": (-24.0, -12.0), "ambience": (-30.0, -16.0), "impact": (-18.0, -6.0),
    "ui": (-26.0, -10.0), "voice": (-22.0, -8.0), "foley": (-30.0, -10.0),
}


def category(name):
    if name.startswith("music"):
        return "music"
    if name.startswith("amb"):
        return "ambience"
    if name.startswith("ui_") or name in ("rest", "ending_chime", "barrier_up", "barrier_down"):
        return "ui"
    if name in ("growl", "husk_groan", "hiss", "gurgle", "elite_roar", "elite_die", "player_die", "spawn_rise"):
        return "voice"
    if name in ("step", "jump", "land", "swing_pre", "talisman_draw", "guard_up", "sac_swell", "elite_windup", "seal_charge", "beads_charge"):
        return "foley"
    return "impact"


def load(path):
    w = wave.open(path)
    x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768.0
    if w.getnchannels() == 2:
        x = x.reshape(-1, 2).mean(axis=1)
    return x, w.getframerate()


def db(v):
    return 20 * np.log10(max(v, 1e-9))


rows = []
for f in sorted(glob.glob(os.path.join(SRC, "*.wav"))):
    name = os.path.basename(f)[:-4]
    x, sr = load(f)
    n400 = int(0.4 * sr)
    if len(x) > n400:
        c = np.convolve(x * x, np.ones(n400) / n400, mode="valid")
        loud = np.sqrt(c.max())
    else:
        loud = np.sqrt(np.mean(x * x))
    rms = np.sqrt(np.mean(x * x))
    peak = np.abs(x).max()
    r = {"name": name, "cat": category(name), "dur": len(x) / sr, "peak_db": db(peak), "rms_db": db(rms),
         "loud_db": db(loud), "crest_db": db(peak) - db(rms), "clipped": int((np.abs(x) > 0.999).sum()),
         "dc": float(x.mean())}
    if r["cat"] in ("music", "ambience"):
        k = int(0.05 * sr)
        r["seam_jump"] = float(abs(x[0] - x[-1]))
        r["seam_rms_step_db"] = float(abs(db(np.sqrt(np.mean(x[:k] ** 2))) - db(np.sqrt(np.mean(x[-k:] ** 2)))))
    lo, hi = TARGETS[r["cat"]]
    issues = []
    if r["clipped"] > 0:
        issues.append("clipping")
    if r["peak_db"] > -0.5:
        issues.append("peak>-0.5dB")
    if abs(r["dc"]) > 0.01:
        issues.append("DC offset")
    if r["loud_db"] < lo:
        issues.append(f"quiet ({r['loud_db']:.1f} < {lo})")
    if r["loud_db"] > hi:
        issues.append(f"loud ({r['loud_db']:.1f} > {hi})")
    if r.get("seam_jump", 0) > 0.05:
        issues.append(f"loop click ({r['seam_jump']:.3f})")
    if r["cat"] == "ambience" and r.get("seam_rms_step_db", 0) > 6:
        issues.append(f"loop level step ({r['seam_rms_step_db']:.1f} dB)")
    r["issues"] = issues
    rows.append(r)

json.dump(rows, open(os.path.join(OUT, "audio_metrics.json"), "w"), indent=1)
bad = [r for r in rows if r["issues"]]
with open(os.path.join(OUT, "AUDIO_REVIEW.md"), "w") as md:
    md.write("# Automated audio review\n\n")
    md.write(f"{len(rows)} files analysed · **{len(bad)} flagged**. Category targets (loudest 400 ms RMS, dBFS): "
             + ", ".join(f"{k} {v[0]:.0f}…{v[1]:.0f}" for k, v in TARGETS.items()) + ".\n\n")
    md.write("Not a listening test — levels, clipping, DC, loop seams and spectra only.\n\n")
    md.write("| file | cat | dur s | peak dB | loud dB | crest dB | clip | seam | issues |\n|---|---|---|---|---|---|---|---|---|\n")
    for r in rows:
        seam = f"{r['seam_jump']:.3f}/{r['seam_rms_step_db']:.1f}dB" if "seam_jump" in r else ""
        md.write(f"| {r['name']} | {r['cat']} | {r['dur']:.2f} | {r['peak_db']:.1f} | {r['loud_db']:.1f} | {r['crest_db']:.1f} | {r['clipped']} | {seam} | {', '.join(r['issues'])} |\n")
print(f"{len(rows)} files, {len(bad)} flagged")
for r in bad:
    print(f"  {r['name']:16s} {r['cat']:9s} {', '.join(r['issues'])}")

try:
    from scipy.signal import spectrogram
    from PIL import Image
    tiles = []
    for r in rows:
        if r["cat"] not in ("music", "ambience") and not r["name"].startswith("elite"):
            continue
        x, sr = load(os.path.join(SRC, r["name"] + ".wav"))
        fr, tt, S = spectrogram(x[: sr * 20], sr, nperseg=1024, noverlap=512)
        S = 10 * np.log10(S + 1e-10)
        S = np.clip((S + 100) / 80, 0, 1)[::-1]
        im = Image.fromarray((S * 255).astype(np.uint8)).resize((600, 160))
        tiles.append((r["name"], im))
    sheet = Image.new("L", (600, 180 * len(tiles)), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(sheet)
    for i, (n, im) in enumerate(tiles):
        sheet.paste(im, (0, i * 180 + 18))
        d.text((4, i * 180 + 2), n, fill=255)
    sheet.save(os.path.join(OUT, "spectrograms.png"))
except Exception as e:
    print("spectrograms skipped:", e)
