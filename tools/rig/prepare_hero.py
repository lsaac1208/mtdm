"""Cut the v0.3 painted masters into transparent gameplay poses.

From the repository root, run this first, then tools/rig/make_rig.py with
tools/rig/hero_rig_def.py and game/assets/rig/hero as its arguments.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
MASTERS = ROOT / "tools/rig/masters"
SPRITES = ROOT / "game/assets/sprites"
SCALE = 0.49511
SOURCE_RATIO = 0.45


def figures(name):
    image = Image.open(MASTERS / name).convert("RGBA")
    alpha = np.array(image.getchannel("A"))
    labels, count = ndimage.label(alpha > 80)
    components = ndimage.find_objects(labels)
    identifiers = [i for i in range(1, count + 1) if (components[i - 1][1].stop - components[i - 1][1].start) > 250]
    if len(identifiers) != 3:
        raise ValueError(f"{name}: expected three separate full figures")
    for ident in sorted(identifiers, key=lambda i: components[i - 1][1].start):
        # Keep the antialias pixels adjacent to this particular silhouette,
        # including where a sword's bounding box overlaps its neighbour.
        mask = ndimage.binary_dilation(labels == ident, iterations=3)
        out = image.copy()
        out.putalpha(Image.fromarray(np.where(mask, alpha, 0).astype(np.uint8)))
        yield out


def register(image, source_anchor, name, metadata):
    if name == "hero_05_thrust":
        # The thrust reaches further than the slash. Register the straight
        # middle section to the 160 px reach, retaining the painted tip and
        # guard at their native aspect. The forward boot stays on its mark.
        first, last, add = 2025, 2090, 185
        top, bottom = 260, 330
        extended = Image.new("RGBA", (image.width + add, image.height))
        extended.alpha_composite(image)
        blade = image.crop((first, top, image.width, bottom))
        extended.paste((0, 0, 0, 0), (first, top, image.width, bottom))
        mid = blade.crop((0, 0, last - first, bottom - top))
        extended.alpha_composite(mid.resize((mid.width + add, mid.height), Image.Resampling.BICUBIC), (first, top))
        extended.alpha_composite(blade.crop((last - first, 0, blade.width, blade.height)), (last + add, top))
        image = extended
    bounds = image.getbbox()
    left, top, right, bottom = bounds
    if name == "hero_01_ready":
        # The original rig canvas and foot-origin contract are shared by the
        # cutout mesh and pose renderer. Map the new shoulders/feet to them.
        size = (276, 347)
        foot_x, foot_y = 118.5, 327.0
    else:
        size = (round((right - left) * SOURCE_RATIO) + 24, round((bottom - top) * SOURCE_RATIO) + 24)
        foot_x = 12 + (source_anchor[0] - left) * SOURCE_RATIO
        foot_y = 12 + (source_anchor[1] - top) * SOURCE_RATIO
    canvas = Image.new("RGBA", size)
    paint = image.crop(bounds).resize(
        (round((right - left) * SOURCE_RATIO), round((bottom - top) * SOURCE_RATIO)), Image.Resampling.LANCZOS)
    canvas.alpha_composite(paint, (
        round(foot_x + (left - source_anchor[0]) * SOURCE_RATIO),
        round(foot_y + (top - source_anchor[1]) * SOURCE_RATIO)))
    canvas.save(SPRITES / f"{name}.png", optimize=True)
    # Measure the body's height, independent of extended sword tips.
    metadata[name] = {
        "w": size[0], "h": size[1], "body_h": round((source_anchor[1] - source_anchor[2]) * SOURCE_RATIO),
        "foot_x": round(foot_x, 2), "foot_y": round(foot_y, 2), "group": "hero_r1", "scale": SCALE,
    }


if __name__ == "__main__":
    meta_path = SPRITES / "sprites_meta.json"
    metadata = json.loads(meta_path.read_text())
    # World pivot X (between support feet), ground Y and crown Y on each master.
    for master, poses in [
        ("hero_guard.png", [
            ("hero_01_ready", (300, 704, 20)),
            ("hero_02_draw", (960, 696, 69)),
            ("hero_slash_pass", (1700, 693, 84)),
        ]),
        ("hero_strikes.png", [
            ("hero_03_hslash", (271, 673, 63)),
            ("hero_04_downslash", (920, 671, 113)),
            ("hero_05_thrust", (1637, 671, 135)),
        ]),
        ("hero_recovery.png", [
            ("hero_overhead_load", (285, 705, 96)),
            ("hero_thrust_load", (958, 705, 120)),
            ("hero_strike_settle", (1701, 705, 81)),
        ]),
    ]:
        for figure, (pose_name, anchor) in zip(figures(master), poses):
            register(figure, anchor, pose_name, metadata)
    meta_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=1) + "\n")
