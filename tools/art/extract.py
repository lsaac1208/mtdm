"""Extract per-pose transparent sprites from the concept sheets.

Usage: python -I tools/art/extract.py tools/art/sprites.json game/assets/sprites [preview.png]
Each entry: {name, sheet, box:[x0,y0,x1,y1], keep:"largest"|"all", min_area, flip, hole_max}
Writes <name>.png (trimmed RGBA) and sprites_meta.json (size + foot anchor).
"""
import sys, json, os
import numpy as np, cv2
from PIL import Image
from scipy import ndimage as ndi

def remove_lines(m, length=45):
    h = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((1, length), np.uint8))
    v = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((length, 1), np.uint8))
    lines = (h | v).astype(bool)
    # only remove thin lines: re-grow figure where line pixels have thick neighbourhood
    thick = ndi.binary_erosion(m, iterations=2)
    thick = ndi.binary_dilation(thick, iterations=2)
    return m & ~(lines & ~thick)

def mask_for(rgb, l_thr, c_thr, hole_max):
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.int32)
    L = lab[..., 0]
    chroma = np.hypot(lab[..., 1] - 128, lab[..., 2] - 128)
    m = (L < l_thr) | (chroma > c_thr)
    m = remove_lines(m)
    m = ndi.binary_opening(m, iterations=1)
    m = ndi.binary_closing(m, iterations=2)
    # fill only small enclosed holes (skin patches), keep gaps between limbs open
    holes = ndi.binary_fill_holes(m) & ~m
    hl, hn = ndi.label(holes)
    if hn:
        sizes = ndi.sum(holes, hl, range(1, hn + 1))
        small = np.isin(hl, np.nonzero(sizes <= hole_max)[0] + 1)
        m |= small
    return m

def extract(entry, sheets_root):
    img = np.array(Image.open(os.path.join(sheets_root, entry["sheet"])).convert("RGB"))
    x0, y0, x1, y1 = entry["box"]
    rgb = img[y0:y1, x0:x1].copy()
    m = mask_for(rgb, entry.get("l_thr", 170), entry.get("c_thr", 27), entry.get("hole_max", 900))
    lab, n = ndi.label(m)
    if n == 0:
        raise SystemExit("empty " + entry["name"])
    sizes = ndi.sum(m, lab, range(1, n + 1))
    if entry.get("keep", "largest") == "largest":
        big = sizes.max()
        keep_ids = [i + 1 for i, s in enumerate(sizes) if s >= big * entry.get("rel", 0.12)]
    else:
        keep_ids = [i + 1 for i, s in enumerate(sizes) if s >= entry.get("min_area", 60)]
    m = np.isin(lab, keep_ids)
    # drop the painted ground-shadow strokes under the feet (light, desaturated)
    lab_c = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.int32)
    Lc = lab_c[..., 0]
    chc = np.hypot(lab_c[..., 1] - 128, lab_c[..., 2] - 128)
    ys_m = np.nonzero(m.any(axis=1))[0]
    if len(ys_m):
        y_bot = ys_m.max()
        band0 = max(0, y_bot - int((y_bot - ys_m.min()) * entry.get("shadow_band", 0.07)))
        smear = np.zeros_like(m)
        smear[band0:y_bot + 1] = (Lc[band0:y_bot + 1] > 120) & (chc[band0:y_bot + 1] < 18)
        m &= ~smear
        m = ndi.binary_opening(m, iterations=1) | (m & ndi.binary_erosion(m, iterations=1))
    for (bx0, by0, bx1, by1) in entry.get("erase", []):   # sheet coords
        m[max(0, by0 - y0):max(0, by1 - y0), max(0, bx0 - x0):max(0, bx1 - x0)] = False
    # soft edge
    a = cv2.GaussianBlur(m.astype(np.float32), (3, 3), 0.8)
    a = np.clip(a * 1.15, 0, 1)
    rgba = np.dstack([rgb, (a * 255).astype(np.uint8)])
    ys, xs = np.nonzero(a > 0.05)
    rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    if entry.get("flip"):
        rgba = rgba[:, ::-1]
    # foot anchor: centre of the opaque pixels in the lowest 6% rows (or explicit)
    al = rgba[..., 3] > 128
    h, w = al.shape
    band = al[int(h * 0.94):]
    cols = np.nonzero(band.any(axis=0))[0]
    foot_x = float(entry.get("foot_x", (cols.min() + cols.max()) / 2 if len(cols) else w / 2))
    if "foot_x_sheet" in entry:
        fx = entry["foot_x_sheet"] - x0 - xs.min()
        foot_x = float(w - fx if entry.get("flip") else fx)
    # transparent padding so the sway/stride shader can displace pixels
    pad = int(max(w, h) * 0.06) + 2
    canvas = np.zeros((h + 2 * pad, w + 2 * pad, 4), np.uint8)
    canvas[pad:pad + h, pad:pad + w] = rgba
    return Image.fromarray(canvas, "RGBA"), dict(w=w + 2 * pad, h=h + 2 * pad, body_h=h, foot_x=foot_x + pad, foot_y=float(h + pad))

def main():
    spec_path, out_dir = sys.argv[1], sys.argv[2]
    preview = sys.argv[3] if len(sys.argv) > 3 else None
    full = json.load(open(spec_path))
    spec, groups = full["sprites"], full["groups"]
    root = os.path.join(os.path.dirname(spec_path), "..", "..", "concept_art")
    os.makedirs(out_dir, exist_ok=True)
    meta, tiles = {}, []
    for e in spec:
        im, md = extract(e, root)
        im.save(os.path.join(out_dir, e["name"] + ".png"))
        meta[e["name"]] = md
        tiles.append((e["name"], im))
    for nm, md in meta.items():
        g = next(e["group"] for e in spec if e["name"] == nm)
        ref, px = groups[g]
        md["group"] = g
        md["scale"] = round(px / meta[ref]["body_h"], 5) if ref else 1.0
    json.dump(meta, open(os.path.join(out_dir, "sprites_meta.json"), "w"), indent=1)
    if preview:
        cell = 240
        cols = 8
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * cell), (60, 70, 60))
        from PIL import ImageDraw
        d = ImageDraw.Draw(sheet)
        for i, (nm, im) in enumerate(tiles):
            t = im.copy(); t.thumbnail((cell - 10, cell - 22))
            cx, cy = (i % cols) * cell, (i // cols) * cell
            sheet.paste(t, (cx + 5, cy + 18), t)
            d.text((cx + 4, cy + 3), nm, fill=(255, 255, 0))
        sheet.save(preview)
    print("extracted", len(tiles))

if __name__ == "__main__":
    main()
