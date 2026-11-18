"""Concept-sheet figure segmentation helpers (Taoist Wanderer asset pipeline).

Foreground = ink/colour that differs from the aged-parchment background.
Holes enclosed by ink outlines are filled so pale corpse skin survives.
"""
import sys, json
import numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

def load(path):
    return np.array(Image.open(path).convert("RGB"))

def fg_mask(rgb, l_thr=168, c_thr=26, close=3):
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.int32)
    L = lab[..., 0]
    chroma = np.hypot(lab[..., 1] - 128, lab[..., 2] - 128)
    # parchment: L ~ 205-235, chroma ~ 8-18
    m = (L < l_thr) | (chroma > c_thr)
    m = ndi.binary_opening(m, iterations=1)
    if close:
        m = ndi.binary_closing(m, iterations=close)
    m = ndi.binary_fill_holes(m)
    return m

def overview(path, out, min_area=1500, **kw):
    rgb = load(path)
    m = fg_mask(rgb, **kw)
    lab, n = ndi.label(m)
    objs = ndi.find_objects(lab)
    img = Image.fromarray(rgb).convert("RGBA")
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    res = []
    for i, sl in enumerate(objs, 1):
        area = int((lab[sl] == i).sum())
        if area < min_area:
            continue
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        res.append(dict(id=i, bbox=[x0, y0, x1, y1], area=area))
        d.rectangle([x0, y0, x1, y1], outline=(0, 120, 255, 255), width=2)
        d.text((x0 + 3, y0 + 3), str(i), fill=(255, 0, 255, 255))
    tint = np.zeros((*m.shape, 4), np.uint8); tint[m] = (0, 255, 0, 60)
    img = Image.alpha_composite(img, Image.fromarray(tint))
    Image.alpha_composite(img, ov).convert("RGB").save(out)
    print(json.dumps(res))

if __name__ == "__main__":
    overview(sys.argv[1], sys.argv[2])
