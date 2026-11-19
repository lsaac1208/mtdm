"""Figure/background readability at reduced display scales.
Input: pairs read_<name>_with.png / read_<name>_bg.png (same frame with and without
characters). Mask = pixels changed by the figures. Metric per scale: mean luminance
contrast of figure pixels vs the background they cover (0-255) and the figure's
outline coverage. Usage: python -I tools/readability.py <shots_dir> <out_dir>"""
import sys, os, glob, json
import numpy as np
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
SCALES = [1.0, 0.667, 0.5, 0.333]
rows = []
tiles = []
for fw in sorted(glob.glob(os.path.join(src, "*_with.png"))):
    name = os.path.basename(fw).split("read_")[1].replace("_with.png", "")
    fb = glob.glob(os.path.join(src, f"*read_{name}_bg.png"))[0]
    A = Image.open(fw).convert("RGB"); B = Image.open(fb).convert("RGB")
    r = {"name": name}
    for s in SCALES:
        size = (int(A.width * s), int(A.height * s))
        a = np.asarray(A.resize(size, Image.LANCZOS)).astype(np.float32)
        b = np.asarray(B.resize(size, Image.LANCZOS)).astype(np.float32)
        La = a @ [0.299, 0.587, 0.114]; Lb = b @ [0.299, 0.587, 0.114]
        diff = np.abs(a - b).max(axis=2)
        mask = diff > 18
        n = int(mask.sum())
        contrast = float(np.abs(La - Lb)[mask].mean()) if n else 0.0
        r[f"contrast@{int(round(s * 100))}"] = round(contrast, 1)
        r[f"pixels@{int(round(s * 100))}"] = n
        if s == 0.333:
            tiles.append((name, Image.fromarray(a.astype(np.uint8))))
    rows.append(r)
json.dump(rows, open(os.path.join(out, "readability.json"), "w"), indent=1)
w = 427
sheet = Image.new("RGB", (w * len(tiles), 260), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(tiles):
    sheet.paste(im, (i * w, 20)); d.text((i * w + 4, 4), n + " @33%", fill=(255, 255, 0))
sheet.save(os.path.join(out, "readability_33pct.png"))
ok = all(r["contrast@33"] >= 20 and r["pixels@33"] >= 300 for r in rows)
with open(os.path.join(out, "READABILITY.md"), "w") as md:
    md.write("# Readability at reduced display scale\n\nSame frame rendered with and without the hero + one enemy; mask = pixels the figures change. ")
    md.write("Contrast = mean |ΔL| (0–255) between figure pixels and the background they cover. Gate: contrast@33% ≥ 20 and ≥ 300 figure pixels @33%.\n\n")
    md.write("| zone / enemy | " + " | ".join(f"contrast@{int(round(s*100))}%" for s in SCALES) + " | pixels@33% |\n|---|" + "---|" * (len(SCALES) + 1) + "\n")
    for r in rows:
        md.write(f"| {r['name']} | " + " | ".join(str(r[f'contrast@{int(round(s*100))}']) for s in SCALES) + f" | {r['pixels@33']} |\n")
    md.write(f"\n**Result: {'PASS' if ok else 'FAIL'}** · sheet: readability_33pct.png\n")
print(json.dumps(rows, ensure_ascii=False)); print("PASS" if ok else "FAIL")
