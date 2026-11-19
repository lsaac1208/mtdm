"""Measure each character against the exact same background in five Godot scenes."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ZONES = {"village": "grunt", "road": "crawler", "lowland": "spitter", "temple": "husk", "burial": "elite"}
SCALES = (100, 67, 50, 33)


def compare(foreground, background, scale):
    dims = tuple(round(n * scale / 100) for n in foreground.size)
    fg = np.asarray(foreground.resize(dims, Image.Resampling.LANCZOS), dtype=float)
    bg = np.asarray(background.resize(dims, Image.Resampling.LANCZOS), dtype=float)
    difference = fg - bg
    mask = np.max(np.abs(difference), axis=2) > 18
    luma = difference @ [0.299, 0.587, 0.114]
    return {"pixels": int(mask.sum()), "contrast": round(float(np.abs(luma[mask]).mean()), 1) if mask.any() else 0}


def main(src, out):
    out.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGB", (854, 3 * 265), "#242424")
    draw = ImageDraw.Draw(canvas)
    rows = []
    lines = ["# Five-zone figure readability", "",
             "Godot renders four plates without advancing simulation. Pixels with an RGB channel difference above 18 form the mask. Contrast is the mean absolute luminance difference from the background, on a 0–255 scale. The historical joint gate is 300 pixels and contrast 20 at 33%. Each figure must also contribute at least 75 changed pixels and contrast 20 independently.", "",
             "| Zone | Figure | Pixels at 33% | Contrast at 33% | Result |", "| --- | --- | ---: | ---: | --- |"]
    for index, (zone, enemy) in enumerate(ZONES.items()):
        with Image.open(src / f"read_{enemy}_bg.png") as image:
            bg = image.convert("RGB")
        for plate in ("with", "hero", "enemy"):
            with Image.open(src / f"read_{enemy}_{plate}.png") as image:
                fg = image.convert("RGB")
            if fg.size != (1280, 720) or fg.size != bg.size:
                raise ValueError(f"Expected matching 1280×720 captures for {zone}/{plate}, got {fg.size} and {bg.size}")
            by_scale = {str(s): compare(fg, bg, s) for s in SCALES}
            reduced = by_scale["33"]
            passed = reduced["pixels"] >= (300 if plate == "with" else 75) and reduced["contrast"] >= 20
            rows.append({"zone": zone, "plate": plate, "measurements": by_scale, "pass": passed})
            lines.append(f"| {zone} | {plate if plate != 'enemy' else enemy} | {reduced['pixels']} | {reduced['contrast']} | {'PASS' if passed else 'FAIL'} |")
            if plate == "with":
                x, y = (index % 2) * 427, (index // 2) * 265
                canvas.paste(fg.resize((427, 240), Image.Resampling.LANCZOS), (x, y + 20))
                draw.text((x + 4, y + 2), f"{zone} / {enemy}", fill="white")
    canvas.save(out / "readability_33pct.png")
    (out / "readability.json").write_text(json.dumps(rows, indent=2) + "\n")
    (out / "READABILITY.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    passed = all(row["pass"] for row in rows)
    print("PASS" if passed else "FAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]), Path(sys.argv[2])))
