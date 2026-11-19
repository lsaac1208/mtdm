"""Slice hand-painted animation sheets into registered HD frame sequences and
bake 2.5D sculpted normal + thickness + cavity-AO maps (*_n.png) for every
character animation frame and legacy pose sprite.

Usage:
    python3 tools/art/build_anim_sheets.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEETS_DIR = ROOT / "tools/art/anim_sheets"
ANIMS_OUT = ROOT / "game/assets/anims"
SPRITES_DIR = ROOT / "game/assets/sprites"

# Target visual stature in game pixels (preserving docs/05 §2.1-2.3 & existing hurtboxes)
TARGET_H = {
    "hero": 152.0,
    "grunt": 132.0,
    "crawler": 54.0,
    "husk": 144.0,
    "spitter": 138.0,
    "elite": 182.0,
}

# Oversampling factor for stored PNGs (2.0x game px -> crisp at 720p/1440p)
STORE_MUL = 2.0


def _box_blur_1d(arr: np.ndarray, radius: int, axis: int) -> np.ndarray:
    if radius <= 0:
        return arr
    pad_w = [(0, 0)] * arr.ndim
    pad_w[axis] = (radius, radius)
    padded = np.pad(arr, pad_w, mode="edge")
    cs = np.cumsum(padded, axis=axis, dtype=np.float64)
    k = 2 * radius + 1
    zero_shape = list(padded.shape)
    zero_shape[axis] = 1
    cs0 = np.concatenate([np.zeros(zero_shape, dtype=np.float64), cs], axis=axis)
    sl_hi = [slice(None)] * arr.ndim
    sl_lo = [slice(None)] * arr.ndim
    sl_hi[axis] = slice(k, cs0.shape[axis])
    sl_lo[axis] = slice(0, cs0.shape[axis] - k)
    return ((cs0[tuple(sl_hi)] - cs0[tuple(sl_lo)]) / float(k)).astype(np.float32)


def gaussian_approx(arr: np.ndarray, radius: int, passes: int = 3) -> np.ndarray:
    out = arr.astype(np.float32, copy=True)
    for _ in range(passes):
        out = _box_blur_1d(out, radius, axis=1)
        out = _box_blur_1d(out, radius, axis=0)
    return out


def bake_normal_map(rgba: np.ndarray) -> Image.Image:
    """Compute a 2.5D sculptural dome normal + thickness + crevice-AO map.

    Channels:
      R, G: Smooth 2.5D surface normal (nx, ny) in [0..255], centered at 128.
            Combines multi-scale silhouette dome curvature + painted brushstroke
            luminance relief so clothing folds and armor planes catch 3D light.
      B:    Normalized interior thickness (0 at silhouette edge -> 255 in core),
            driving directional rim light without any hard sticker outline.
      A:    Micro-crevice ambient occlusion (255 = exposed, lower = shadow fold).
    """
    h, w = rgba.shape[:2]
    rgb = rgba[..., :3].astype(np.float32) / 255.0
    alpha = rgba[..., 3].astype(np.float32) / 255.0
    mask = alpha > 0.08

    dim = max(48.0, min(float(h), float(w)))
    r_small = max(1, int(round(dim * 0.015)))
    r_mid = max(3, int(round(dim * 0.055)))
    r_big = max(7, int(round(dim * 0.13)))

    a_s = gaussian_approx(alpha, r_small, passes=2)
    a_m = gaussian_approx(alpha, r_mid, passes=3)
    a_b = gaussian_approx(alpha, r_big, passes=3)
    dome = 0.28 * a_s + 0.44 * a_m + 0.28 * a_b

    gy_d, gx_d = np.gradient(dome)
    nx_dome = -gx_d
    ny_dome = -gy_d
    dmag = np.sqrt(nx_dome * nx_dome + ny_dome * ny_dome)
    scale_d = np.percentile(dmag[mask], 92) if np.any(mask) else 1.0
    scale_d = max(float(scale_d), 1e-4)
    nx_dome = np.clip(nx_dome / scale_d, -1.2, 1.2)
    ny_dome = np.clip(ny_dome / scale_d, -1.2, 1.2)

    luma = rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114
    mean_l = float(luma[mask].mean()) if np.any(mask) else 0.4
    luma_ext = np.where(mask, luma, mean_l)
    luma_s = gaussian_approx(luma_ext, max(1, r_small), passes=2)
    luma_m = gaussian_approx(luma_ext, max(2, r_mid // 2), passes=2)
    gy_l, gx_l = np.gradient(luma_s)
    lmag = np.sqrt(gx_l * gx_l + gy_l * gy_l)
    scale_l = np.percentile(lmag[mask], 90) if np.any(mask) else 1.0
    scale_l = max(float(scale_l), 1e-4)
    nx_rel = np.clip(-gx_l / scale_l, -1.0, 1.0)
    ny_rel = np.clip(-gy_l / scale_l, -1.0, 1.0)

    nx = nx_dome * 0.72 + nx_rel * 0.28
    ny = ny_dome * 0.72 + ny_rel * 0.28
    nz = np.full_like(nx, 0.85)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-6)
    nx = nx * inv_len
    ny = ny * inv_len

    thick = np.clip((a_m - 0.30) / 0.65, 0.0, 1.0) * np.clip(alpha * 2.0, 0.0, 1.0)
    crevice = np.clip(luma_m - luma_s, 0.0, 1.0)
    ao = np.clip(1.0 - crevice * 2.4, 0.38, 1.0)

    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., 0] = np.clip(np.round((nx * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    out[..., 1] = np.clip(np.round((ny * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    out[..., 2] = np.clip(np.round(thick * 255.0), 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(np.round(ao * 255.0), 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def find_grid_cuts(alpha: np.ndarray, count: int, axis: int) -> list:
    """Find `count - 1` minimum-opacity cut lines along `axis` (0=rows/Y, 1=cols/X)."""
    length = alpha.shape[axis]
    proj = (alpha > 20).sum(axis=1 - axis).astype(np.float64)
    cuts = [0]
    for i in range(1, count):
        center = int(round(length * i / float(count)))
        span = int(round(length * 0.30 / float(count)))
        lo = max(cuts[-1] + 16, center - span)
        hi = min(length - 16, center + span)
        window = proj[lo:hi + 1]
        zeros = np.where(window == 0)[0]
        if len(zeros) > 0:
            best = lo + int(zeros[np.argmin(np.abs((lo + zeros) - center))])
            zl, zr = best, best
            while zl > lo and proj[zl - 1] == 0:
                zl -= 1
            while zr < hi and proj[zr + 1] == 0:
                zr += 1
            cuts.append((zl + zr) // 2)
        else:
            cuts.append(lo + int(np.argmin(window)))
    cuts.append(length)
    return cuts


def clean_cell_rgba(cell: np.ndarray) -> np.ndarray:
    """Strip near-invisible alpha dust and trim tightly to figure bounds."""
    out = cell.copy()
    out[out[..., 3] <= 14] = 0
    mask = out[..., 3] > 28
    if not np.any(mask):
        return out
    ys, xs = np.nonzero(mask)
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    return out[y0:y1, x0:x1]


def measure_figure(rgba: np.ndarray) -> dict:
    """Measure opaque figure bounds, torso center-of-mass X, crown/sole Y, and boot contacts."""
    h, w = rgba.shape[:2]
    a = rgba[..., 3]
    solid = a > 70
    if not np.any(solid):
        solid = a > 20
    ys, xs = np.nonzero(solid)
    top_y = int(ys.min())
    bot_y = int(ys.max())
    body_h = max(1, bot_y - top_y)

    # Torso center X from upper-mid core (20%..68% height) so swords/ribbons don't jitter X
    ty0 = top_y + int(body_h * 0.20)
    ty1 = top_y + int(body_h * 0.68)
    torso_mask = solid[ty0:ty1, :]
    if np.any(torso_mask):
        _, txs = np.nonzero(torso_mask)
        center_x = float(np.median(txs))
    else:
        center_x = float(np.median(xs))

    # Detect left/right boot contacts in lowest 10% of silhouette
    fy0 = max(top_y, bot_y - max(4, int(body_h * 0.10)))
    foot_band = solid[fy0:bot_y + 1, :]
    if np.any(foot_band):
        fys, fxs = np.nonzero(foot_band)
        fl_x = float(np.percentile(fxs, 15))
        fr_x = float(np.percentile(fxs, 85))
        mid = (fl_x + fr_x) * 0.5
        left_sel = fxs <= mid
        right_sel = fxs >= mid
        ly = float(fy0 + fys[left_sel].max()) if np.any(left_sel) else float(bot_y)
        ry = float(fy0 + fys[right_sel].max()) if np.any(right_sel) else float(bot_y)
    else:
        fl_x, fr_x = center_x - 16.0, center_x + 16.0
        ly, ry = float(bot_y), float(bot_y)

    return {
        "w": w, "h": h, "top_y": top_y, "bot_y": bot_y, "body_h": body_h,
        "center_x": center_x, "foot_y": float(bot_y),
        "boots": [(fl_x, ly), (fr_x, ry)],
    }


def extract_grid_cells(sheet_path: Path, rows: int, cols: int) -> list:
    im = Image.open(sheet_path).convert("RGBA")
    arr = np.asarray(im)
    y_cuts = find_grid_cuts(arr[..., 3], rows, axis=0)
    cells = []
    for r in range(rows):
        row_strip = arr[y_cuts[r]:y_cuts[r + 1], :, :]
        x_cuts = find_grid_cuts(row_strip[..., 3], cols, axis=1)
        for c in range(cols):
            sub = row_strip[:, x_cuts[c]:x_cuts[c + 1], :]
            cells.append(clean_cell_rgba(sub))
    return cells


def save_frame(rgba: np.ndarray, measure: dict, game_scale: float, out_path: Path,
               airborne: bool = False, ref_h_src: float = 0.0) -> dict:
    """Resize cleanly to STORE_MUL * game_px, save RGBA PNG + baked *_n.png, return metadata."""
    resize_factor = game_scale * STORE_MUL
    nh = max(8, int(round(rgba.shape[0] * resize_factor)))
    nw = max(8, int(round(rgba.shape[1] * resize_factor)))
    pad = 8
    pil = Image.fromarray(rgba, "RGBA").resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (nw + pad * 2, nh + pad * 2), (0, 0, 0, 0))
    canvas.paste(pil, (pad, pad))
    canvas.save(out_path, optimize=True)

    n_path = out_path.with_name(out_path.stem + "_n.png")
    bake_normal_map(np.asarray(canvas)).save(n_path, optimize=True)

    render_scale = 1.0 / STORE_MUL
    foot_x = pad + measure["center_x"] * resize_factor
    if airborne and ref_h_src > 0.0:
        top_scaled = pad + measure["top_y"] * resize_factor
        foot_y = top_scaled + (ref_h_src * 0.94) * resize_factor
    else:
        foot_y = pad + measure["foot_y"] * resize_factor

    boots_game = []
    for bx, by in measure["boots"]:
        gx = ((pad + bx * resize_factor) - foot_x) * render_scale
        gy = ((pad + by * resize_factor) - foot_y) * render_scale
        boots_game.append([round(gx, 1), round(gy, 1)])

    return {
        "file": out_path.name,
        "w": nw + pad * 2,
        "h": nh + pad * 2,
        "body_h": round(measure["body_h"] * resize_factor, 1),
        "foot_x": round(foot_x, 2),
        "foot_y": round(foot_y, 2),
        "scale": round(render_scale, 5),
        "boots": boots_game,
    }


MANIFEST = {
    "hero": {
        "sheets": [
            {
                "file": "hero_run_sheet.png",
                "rows": 2, "cols": 4,
                "ref_indices": [0, 1, 2, 3, 4, 5, 6, 7],
                "clips": {
                    "run": {"indices": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 13.5, "loop": True},
                },
            },
            {
                "file": "hero_walk_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [0, 1, 2, 3, 4, 5],
                "clips": {
                    "walk": {"indices": [0, 1, 2, 3, 4, 5], "fps": 8.5, "loop": True},
                },
            },
            {
                "file": "hero_jump_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [0, 1, 3, 4],
                "clips": {
                    "jump": {"indices": [0, 1, 2], "fps": 10.0, "loop": False, "airborne": True},
                    "fall": {"indices": [2, 3, 4], "fps": 10.0, "loop": False, "airborne": True},
                    "land": {"indices": [5], "fps": 10.0, "loop": False},
                },
            },
            {
                "file": "hero_idle_react_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [0, 1, 2],
                "clips": {
                    "idle": {"indices": [0, 1, 2, 1], "fps": 3.2, "loop": True},
                    "block": {"indices": [3], "fps": 8.0, "loop": False},
                    "hit": {"indices": [4], "fps": 8.0, "loop": False},
                    "dead": {"indices": [5], "fps": 8.0, "loop": False},
                },
            },
        ],
    },
    "grunt": {
        "sheets": [
            {
                "file": "grunt_walk_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [0, 1, 2, 3, 4, 5],
                "clips": {
                    "walk": {"indices": [0, 1, 2, 3, 4, 5], "fps": 7.5, "loop": True},
                },
            },
            {
                "file": "grunt_combat_sheet.png",
                "rows": 2, "cols": 2,
                "ref_indices": [0, 1, 2, 3],
                "clips": {
                    "idle": {"indices": [0], "fps": 4.0, "loop": True},
                    "alert": {"indices": [1], "fps": 6.0, "loop": False},
                    "windup": {"indices": [2], "fps": 6.0, "loop": False},
                    "attack": {"indices": [3], "fps": 8.0, "loop": False},
                    "hit": {"indices": [1], "fps": 6.0, "loop": False},
                },
            },
        ],
    },
    "crawler": {
        "sheets": [
            {
                "file": "crawler_crawl_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [0, 1, 2, 3, 4, 5],
                "clips": {
                    "walk": {"indices": [0, 1, 2, 3, 4, 5], "fps": 12.0, "loop": True},
                    "idle": {"indices": [1], "fps": 4.0, "loop": True},
                    "prep": {"indices": [2], "fps": 8.0, "loop": False},
                    "alert": {"indices": [1], "fps": 8.0, "loop": False},
                },
            },
        ],
    },
    "husk": {
        "sheets": [
            {
                "file": "husk_walk_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [0, 1, 2, 3, 4, 5],
                "clips": {
                    "walk": {"indices": [0, 1, 2, 3, 4, 5], "fps": 5.5, "loop": True},
                    "idle": {"indices": [1], "fps": 3.0, "loop": True},
                },
            },
            {
                "file": "husk_combat_sheet.png",
                "rows": 2, "cols": 2,
                "ref_indices": [0, 1],
                "clips": {
                    "idle": {"indices": [0], "fps": 3.0, "loop": True},
                    "awaken": {"indices": [1], "fps": 5.0, "loop": False},
                    "windup": {"indices": [2], "fps": 5.0, "loop": False},
                    "hit": {"indices": [3], "fps": 6.0, "loop": False},
                },
            },
        ],
    },
    "spitter": {
        "sheets": [
            {
                "file": "spitter_walk_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [0, 1, 2, 3, 4, 5],
                "clips": {
                    "walk": {"indices": [0, 1, 2, 3, 4, 5], "fps": 6.5, "loop": True},
                    "idle": {"indices": [1], "fps": 3.5, "loop": True},
                },
            },
            {
                "file": "spitter_combat_sheet.png",
                "rows": 2, "cols": 2,
                "ref_indices": [0, 1],
                "clips": {
                    "alert": {"indices": [0], "fps": 5.0, "loop": False},
                    "windup": {"indices": [1], "fps": 4.0, "loop": False},
                    "recover": {"indices": [2], "fps": 4.0, "loop": False},
                    "hit": {"indices": [3], "fps": 6.0, "loop": False},
                },
            },
        ],
    },
    "elite": {
        "sheets": [
            {
                "file": "elite_walk_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [0, 1, 2, 3, 4, 5],
                "clips": {
                    "walk": {"indices": [0, 1, 2, 3, 4, 5], "fps": 5.5, "loop": True},
                    "idle": {"indices": [1], "fps": 3.0, "loop": True},
                },
            },
            {
                "file": "elite_combat_sheet.png",
                "rows": 2, "cols": 3,
                "ref_indices": [3, 4],
                "clips": {
                    "windup_chop": {"indices": [0, 1], "fps": 2.8, "loop": False},
                    "chop": {"indices": [2], "fps": 6.0, "loop": False},
                    "recover_chop": {"indices": [2], "fps": 4.0, "loop": False},
                    "windup_sweep": {"indices": [3], "fps": 4.0, "loop": False},
                    "sweep": {"indices": [4], "fps": 6.0, "loop": False},
                    "recover_sweep": {"indices": [4], "fps": 4.0, "loop": False},
                    "kneel": {"indices": [5], "fps": 4.0, "loop": False},
                    "recoil": {"indices": [3], "fps": 5.0, "loop": False},
                    "roar": {"indices": [1], "fps": 4.0, "loop": False},
                    "dead": {"indices": [5], "fps": 4.0, "loop": False},
                },
            },
        ],
    },
}


def build_actor_anims():
    for actor, cfg in MANIFEST.items():
        out_dir = ANIMS_OUT / actor
        out_dir.mkdir(parents=True, exist_ok=True)
        clips_meta = {}
        saved_cells = {}

        for sheet_cfg in cfg["sheets"]:
            sheet_path = SHEETS_DIR / sheet_cfg["file"]
            if not sheet_path.exists():
                print(f"[SKIP] missing {sheet_path.name}")
                continue
            cells = extract_grid_cells(sheet_path, sheet_cfg["rows"], sheet_cfg["cols"])
            measures = [measure_figure(c) for c in cells]
            ref_hs = [measures[i]["body_h"] for i in sheet_cfg["ref_indices"] if i < len(measures)]
            ref_h = float(np.median(ref_hs)) if ref_hs else float(np.median([m["body_h"] for m in measures]))
            game_scale = TARGET_H[actor] / max(ref_h, 1.0)
            print(f"[SLICE] {actor:8s} {sheet_path.name:28s} cells={len(cells)} ref_h={ref_h:.1f} -> scale={game_scale:.4f}")

            for clip_name, cdef in sheet_cfg["clips"].items():
                airborne = bool(cdef.get("airborne", False))
                frames = []
                for idx in cdef["indices"]:
                    key = (sheet_cfg["file"], idx, airborne)
                    if key not in saved_cells:
                        fname = f"{sheet_path.stem}_c{idx:02d}{'_air' if airborne else ''}.png"
                        saved_cells[key] = save_frame(
                            cells[idx], measures[idx], game_scale, out_dir / fname,
                            airborne=airborne, ref_h_src=ref_h,
                        )
                    frames.append(saved_cells[key])
                clips_meta[clip_name] = {
                    "fps": float(cdef["fps"]),
                    "loop": bool(cdef["loop"]),
                    "frames": frames,
                }

        if clips_meta:
            data = {"actor": actor, "target_h": TARGET_H[actor], "clips": clips_meta}
            (out_dir / "anims.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
            print(f"[OK] wrote {out_dir / 'anims.json'} ({len(clips_meta)} clips)")


def bake_legacy_sprite_normals():
    """Bake paired *_n.png 2.5D normal/thickness/AO maps for all existing actor sprites."""
    prefixes = ("hero_", "grunt_", "crawler_", "husk_", "spitter_", "elite_")
    count = 0
    for path in sorted(SPRITES_DIR.glob("*.png")):
        if path.stem.endswith("_n"):
            continue
        if not path.name.startswith(prefixes):
            continue
        im = Image.open(path).convert("RGBA")
        arr = np.asarray(im)
        nmap = bake_normal_map(arr)
        nmap.save(path.with_name(path.stem + "_n.png"), optimize=True)
        count += 1
    print(f"[OK] baked {count} 2.5D normal/thickness/AO maps in {SPRITES_DIR}")


if __name__ == "__main__":
    build_actor_anims()
    bake_legacy_sprite_normals()
