"""Extract six circular 256x256 HUD/whisper portraits and three prologue story plates
from the protagonist expression concept sheet.

Reads `concept_art/03_protagonist_expressions_mood.png` and writes:
  - game/assets/ui/portrait.png          (01 平常·冷静 — calm default)
  - game/assets/ui/portrait_alert.png    (02 警惕·戒备 — wary/alert)
  - game/assets/ui/portrait_fierce.png   (03 压抑之怒 — fierce/restrained anger)
  - game/assets/ui/portrait_combat.png   (04 专注施法 — focused combat)
  - game/assets/ui/portrait_hurt.png     (05 忍痛承受 — wounded/pained)
  - game/assets/ui/portrait_wistful.png  (09 隐忍的悲伤 — wistful/sorrow)
  - game/assets/ui/prologue_01.webp      (Story moment 01: 独行废土)
  - game/assets/ui/prologue_02.webp      (Story moment 02: 面对遗物)
  - game/assets/ui/prologue_03.webp      (Story moment 04: 凝视前路)

Usage:
  python3 tools/art/extract_portraits.py [--preview /tmp/mtdm_hud_qa/portraits_preview.png]
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path
from typing import Dict, Tuple

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SHEET = ROOT / "concept_art" / "03_protagonist_expressions_mood.png"
DEFAULT_OUT_DIR = ROOT / "game" / "assets" / "ui"
OUT_SIZE = 256

# Panel crop parameters tuned on 1448x1086 `03_protagonist_expressions_mood.png`.
# Each `box` stays strictly inside the panel gutters and well above the captions (y=354).
# `cx`, `cy`, `size` place the hero's eyes at ~46-47% vertical height while showing
# the red headband/hair, full face, chin, and upper ochre collar inside the circle.
PORTRAIT_SPECS: Dict[str, dict] = {
    "portrait.png": {
        "label": "01 Calm (default)",
        "box": (72, 132, 185, 354),
        "cx": 131.5,
        "cy": 236.0,
        "size": 146.0,
        "eye_y": 232.0,
        "bg_center": (126.0, 106.0, 80.0),
        "bg_edge": (40.0, 32.0, 24.0),
        "seed": 101,
    },
    "portrait_alert.png": {
        "label": "02 Wary (alert)",
        "box": (190, 132, 300, 354),
        "cx": 244.0,
        "cy": 237.5,
        "size": 146.0,
        "eye_y": 233.5,
        "bg_center": (114.0, 102.0, 82.0),
        "bg_edge": (34.0, 30.0, 26.0),
        "seed": 151,
    },
    "portrait_fierce.png": {
        "label": "03 Restrained Anger (fierce)",
        "box": (303, 132, 412, 354),
        "cx": 356.5,
        "cy": 239.0,
        "size": 146.0,
        "eye_y": 235.0,
        "bg_center": (128.0, 92.0, 68.0),
        "bg_edge": (44.0, 22.0, 18.0),
        "seed": 181,
    },
    "portrait_combat.png": {
        "label": "04 Focused (combat)",
        "box": (417, 132, 525, 354),
        "cx": 471.0,
        "cy": 239.5,
        "size": 146.0,
        "eye_y": 236.0,
        "bg_center": (132.0, 104.0, 70.0),
        "bg_edge": (42.0, 30.0, 21.0),
        "seed": 202,
    },
    "portrait_hurt.png": {
        "label": "05 In Pain (hurt)",
        "box": (531, 132, 639, 354),
        "cx": 585.0,
        "cy": 241.5,
        "size": 146.0,
        "eye_y": 238.0,
        "bg_center": (118.0, 82.0, 66.0),
        "bg_edge": (46.0, 22.0, 18.0),
        "seed": 303,
    },
    "portrait_wistful.png": {
        "label": "09 Sadness (wistful)",
        "box": (1002, 132, 1112, 354),
        "cx": 1057.0,
        "cy": 238.5,
        "size": 146.0,
        "eye_y": 234.5,
        "bg_center": (102.0, 98.0, 94.0),
        "bg_edge": (30.0, 29.0, 34.0),
        "seed": 404,
    },
}

PROLOGUE_PLATES: Dict[str, Tuple[int, int, int, int]] = {
    "prologue_01.webp": (18, 796, 286, 990),
    "prologue_02.webp": (299, 796, 507, 990),
    "prologue_03.webp": (756, 796, 972, 990),
}


def _dilate(mask: np.ndarray, steps: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(steps):
        prev = out.copy()
        out[1:, :] |= prev[:-1, :]
        out[:-1, :] |= prev[1:, :]
        out[:, 1:] |= prev[:, :-1]
        out[:, :-1] |= prev[:, 1:]
    return out


def extract_portrait(sheet_rgb: np.ndarray, spec: dict, out_size: int = OUT_SIZE) -> Tuple[Image.Image, float]:
    x0, y0, x1, y1 = spec["box"]
    cx = float(spec["cx"])
    cy = float(spec["cy"])
    crop_size = float(spec["size"])
    eye_y = float(spec["eye_y"])

    panel = sheet_rgb[y0:y1, x0:x1].astype(np.float32)
    ph, pw, _ = panel.shape

    corners = np.concatenate(
        [
            panel[:12, :12].reshape(-1, 3),
            panel[:12, -12:].reshape(-1, 3),
        ],
        axis=0,
    )
    bg_col = np.median(corners, axis=0)
    bg_lum = float(0.299 * bg_col[0] + 0.587 * bg_col[1] + 0.114 * bg_col[2])

    diff = panel - bg_col[None, None, :]
    dist = np.sqrt((diff ** 2).sum(axis=2))
    lum = 0.299 * panel[..., 0] + 0.587 * panel[..., 1] + 0.114 * panel[..., 2]
    sat = panel.max(axis=2) - panel.min(axis=2)
    warmth = panel[..., 0] - panel[..., 2]
    redness = panel[..., 0] - panel[..., 1]

    yy_p, xx_p = np.mgrid[0:ph, 0:pw].astype(np.float32)
    face_cx = cx - x0 + 0.5
    face_cy = (eye_y - y0) + 17.0
    # Taper the face protection shield narrower toward the chin so background wedges beside the jaw stay clean.
    chin_t = np.clip((yy_p - (eye_y - y0)) / 48.0, 0.0, 1.0)
    face_rx = 21.5 - 8.0 * chin_t
    face_core = (((xx_p - face_cx) / face_rx) ** 2 + ((yy_p - face_cy) / 33.0) ** 2) <= 1.0
    eye_core = (((xx_p - face_cx) / 28.0) ** 2 + ((yy_p - (eye_y - y0)) / 9.0) ** 2) <= 1.0
    vivid_paint = (warmth > 44.0) | (redness > 26.0) | (sat > 48.0)
    protected = face_core | eye_core

    parch_ext = ((dist < 68.0) & (lum > 142.0) & (sat < 44.0)) | (
        (dist < 86.0) & (lum > 134.0) & (sat < 30.0)
    )
    bg = np.zeros((ph, pw), dtype=bool)
    queue: deque[Tuple[int, int]] = deque()
    for col in range(pw):
        if parch_ext[0, col]:
            bg[0, col] = True
            queue.append((0, col))
    for row in range(ph):
        for col in (0, pw - 1):
            if parch_ext[row, col] and not bg[row, col]:
                bg[row, col] = True
                queue.append((row, col))
    while queue:
        row, col = queue.popleft()
        for drow, dcol in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nrow, ncol = row + drow, col + dcol
            if 0 <= nrow < ph and 0 <= ncol < pw and not bg[nrow, ncol] and parch_ext[nrow, ncol]:
                bg[nrow, ncol] = True
                queue.append((nrow, ncol))

    parch_pocket = (~protected) & (~vivid_paint) & (dist < 62.0) & (lum > 148.0) & (sat < 40.0) & (warmth < 40.0)
    bg |= parch_pocket

    alpha = (~bg).astype(np.float32)
    fg = panel.copy()
    fringe_zone = _dilate(bg, 3) & (~bg) & (~protected)

    ink_base = np.array([22.0, 18.0, 16.0], dtype=np.float32)
    if fringe_zone.any():
        fz_lum = lum[fringe_zone]
        fz_sat = sat[fringe_zone]
        fz_warm = warmth[fringe_zone]
        fz_red = redness[fringe_zone]
        fz_rgb = panel[fringe_zone]

        neutral = (
            np.clip((46.0 - fz_sat) / 26.0, 0.0, 1.0)
            * np.clip((44.0 - fz_warm) / 22.0, 0.0, 1.0)
            * np.clip((26.0 - fz_red) / 14.0, 0.0, 1.0)
        )
        ink_cov = np.clip((bg_lum - 14.0 - fz_lum) / max(bg_lum - 46.0, 1.0), 0.0, 1.0)
        ink_cov = np.power(ink_cov, 0.9)

        color_cov = np.clip((dist[fringe_zone] - 20.0) / 118.0, 0.0, 1.0)
        is_light = np.clip((fz_lum - 100.0) / 68.0, 0.0, 1.0)
        color_a = 1.0 - (1.0 - neutral) * is_light * (1.0 - color_cov) * 0.95

        new_a = neutral * ink_cov + (1.0 - neutral) * color_a
        alpha[fringe_zone] = np.minimum(alpha[fringe_zone], new_a)

        safe_a = np.maximum(new_a, 0.16)[:, None]
        unmixed = np.clip((fz_rgb - (1.0 - new_a)[:, None] * bg_col[None, :]) / safe_a, 0.0, 255.0)
        dehaloed = neutral[:, None] * (0.72 * ink_base[None, :] + 0.28 * unmixed) + (1.0 - neutral[:, None]) * unmixed
        fg[fringe_zone] = np.clip(dehaloed, 0.0, 255.0)

    edge_dx = np.minimum(xx_p, (pw - 1.0) - xx_p)
    edge_t = np.clip(edge_dx / 6.5, 0.0, 1.0)
    edge_fade = edge_t * edge_t * (3.0 - 2.0 * edge_t)
    alpha *= edge_fade

    panel_rgba = np.zeros((ph, pw, 4), dtype=np.uint8)
    panel_rgba[..., :3] = np.clip(fg * alpha[..., None], 0.0, 255.0).astype(np.uint8)
    panel_rgba[..., 3] = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    panel_img = Image.fromarray(panel_rgba)

    lcx = cx - x0
    lcy = cy - y0
    half = crop_size * 0.5
    crop_box = (lcx - half, lcy - half, lcx + half, lcy + half)

    resized_pm = panel_img.transform(
        (out_size, out_size),
        Image.Transform.EXTENT,
        crop_box,
        resample=Image.Resampling.BICUBIC,
    )
    rarr = np.array(resized_pm, dtype=np.float32)
    ra = rarr[..., 3] / 255.0
    rrgb = np.where(
        ra[..., None] > 0.015,
        np.clip(rarr[..., :3] / np.maximum(ra[..., None], 0.015), 0.0, 255.0),
        0.0,
    )

    yy, xx = np.mgrid[0:out_size, 0:out_size].astype(np.float32)
    nx = (xx + 0.5) / out_size * 2.0 - 1.0
    ny = (yy + 0.5) / out_size * 2.0 - 1.0
    glow_d = np.sqrt((nx * 0.90) ** 2 + ((ny + 0.14) * 1.00) ** 2)
    gt = np.clip(glow_d, 0.0, 1.0)
    gt_smooth = gt * gt * (3.0 - 2.0 * gt)

    c0 = np.array(spec["bg_center"], dtype=np.float32)
    c1 = np.array(spec["bg_edge"], dtype=np.float32)
    backing = c0[None, None, :] * (1.0 - gt_smooth[..., None]) + c1[None, None, :] * gt_smooth[..., None]

    rng = np.random.default_rng(int(spec["seed"]))
    grain = rng.normal(0.0, 2.6, size=(out_size, out_size, 1)).astype(np.float32)
    backing = np.clip(backing + grain, 0.0, 255.0)

    comp = rrgb * ra[..., None] + backing * (1.0 - ra[..., None])

    r_norm = np.sqrt(nx ** 2 + ny ** 2)
    vignette = 1.0 - 0.28 * np.power(np.clip((r_norm - 0.66) / 0.34, 0.0, 1.0), 1.65)
    comp = np.clip(comp * vignette[..., None], 0.0, 255.0)

    px_r = np.sqrt((xx + 0.5 - out_size * 0.5) ** 2 + (yy + 0.5 - out_size * 0.5) ** 2)
    max_r = out_size * 0.5 - 1.0
    circ_a = np.clip((max_r - px_r) / 1.5, 0.0, 1.0)

    out = np.zeros((out_size, out_size, 4), dtype=np.uint8)
    out[..., :3] = comp.astype(np.uint8)
    out[..., 3] = np.clip(circ_a * 255.0, 0.0, 255.0).astype(np.uint8)

    eye_pct = (eye_y - (cy - half)) / crop_size
    return Image.fromarray(out), eye_pct


def build_preview(portraits: Dict[str, Tuple[Image.Image, float, str]], preview_path: Path) -> None:
    count = len(portraits)
    width = count * 284 + 28
    height = 256 + 136
    canvas = Image.new("RGBA", (width, height), (20, 18, 16, 255))
    draw = ImageDraw.Draw(canvas)

    for idx, (fname, (img, eye_pct, label)) in enumerate(portraits.items()):
        x = 28 + idx * 284
        canvas.alpha_composite(img, (x, 30))
        for frac, col in ((0.45, (105, 225, 145, 220)), (0.48, (242, 192, 92, 220))):
            gy = int(round(30 + OUT_SIZE * frac))
            draw.line([(x - 10, gy), (x + 12, gy)], fill=col, width=1)
            draw.line([(x + OUT_SIZE - 12, gy), (x + OUT_SIZE + 10, gy)], fill=col, width=1)
        draw.text((x + 4, 8), f"{fname} | {label} | eye={eye_pct * 100:.1f}%", fill=(240, 226, 198, 255))

        small = img.resize((60, 60), Image.Resampling.LANCZOS)
        sx, sy = x + 98, 308
        draw.ellipse((sx - 4, sy - 4, sx + 64, sy + 64), outline=(140, 102, 54, 255), width=2)
        draw.ellipse((sx - 2, sy - 2, sx + 62, sy + 62), outline=(218, 174, 102, 255), width=2)
        canvas.alpha_composite(small, (sx, sy))
        draw.text((sx + 74, sy + 22), "60px HUD", fill=(195, 180, 155, 255))

    preview_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(preview_path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sheet", type=Path, default=DEFAULT_SHEET, help="Path to concept expression sheet")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR, help="Output directory for portrait PNGs")
    parser.add_argument("--preview", type=Path, default=None, help="Optional QA preview sheet path")
    args = parser.parse_args()

    sheet_rgb = np.array(Image.open(args.sheet).convert("RGB"))
    args.out_dir.mkdir(parents=True, exist_ok=True)

    results: Dict[str, Tuple[Image.Image, float, str]] = {}
    for fname, spec in PORTRAIT_SPECS.items():
        img, eye_pct = extract_portrait(sheet_rgb, spec, OUT_SIZE)
        dest = args.out_dir / fname
        img.save(dest)
        results[fname] = (img, eye_pct, spec["label"])
        print(f"Wrote {dest} ({img.size[0]}x{img.size[1]} {img.mode}, eye_y={eye_pct * 100:.1f}%)")

    sheet_img = Image.fromarray(sheet_rgb)
    for fname, box in PROLOGUE_PLATES.items():
        crop = sheet_img.crop(box)
        scale = 640.0 / float(crop.width)
        up = crop.resize((640, int(round(crop.height * scale))), Image.Resampling.LANCZOS)
        dest = args.out_dir / fname
        up.save(dest, quality=92)
        print(f"Wrote {dest} ({up.size[0]}x{up.size[1]} RGB)")

    if args.preview is not None:
        build_preview(results, args.preview)
        print(f"Wrote preview {args.preview}")


if __name__ == "__main__":
    main()
