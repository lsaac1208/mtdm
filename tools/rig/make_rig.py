"""Build a skinned cut-out rig (part layers + meshes + bone weights) from one
concept-art pose. Output is consumed by game/scripts/actors/cutout_rig.gd.

Usage: python -I tools/rig/make_rig.py tools/rig/hero_rig_def.py game/assets/rig/hero
"""
import sys, os, json, importlib.util
import numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

spec = importlib.util.spec_from_file_location("rigdef", sys.argv[1])
D = importlib.util.module_from_spec(spec); spec.loader.exec_module(D)
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
root = os.path.join(os.path.dirname(__file__), "..", "..")
meta = json.load(open(os.path.join(root, "game/assets/sprites/sprites_meta.json")))[D.SOURCE]
img = np.array(Image.open(os.path.join(root, "game/assets/sprites", D.SOURCE + ".png")).convert("RGBA"))
H, W = img.shape[:2]
alpha = img[..., 3] > 40
FX, FY = meta["foot_x"], meta["foot_y"]
STEP = getattr(D, "MESH_STEP", 6)


def poly_mask(poly):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in poly], fill=255)
    return np.asarray(m) > 0


for poly in getattr(D, "ERASE_GREY", []):
    labg = cv2.cvtColor(img[..., :3], cv2.COLOR_RGB2LAB).astype(np.int32)
    grey = np.hypot(labg[..., 1] - 128, labg[..., 2] - 128) < 14
    alpha &= ~(poly_mask(poly) & grey & (labg[..., 0] > 90))
assigned = np.zeros((H, W), bool)
own = {}
for name, z, poly, bones in D.PARTS:
    m = poly_mask(poly) & alpha & ~assigned
    own[name] = m
    assigned |= m
body = alpha & ~assigned
lb, nb = ndi.label(body)
if nb > 1:
    sz = ndi.sum(body, lb, range(1, nb + 1))
    body = np.isin(lb, [i + 1 for i, s in enumerate(sz) if s >= sz.max() * 0.03])
body[int(FY) - 2:] = False   # painted ground shadow under the feet

# --- rebuild the torso hidden under the arms/sword: per-row span fill + inpaint
fill = np.zeros_like(body)
under = np.zeros_like(body)
for n in getattr(D, "FILL_UNDER", ("arm_f", "arm_b", "sword")):
    if n in own:
        under |= own[n]
rows_y = np.nonzero(body.any(axis=1))[0]
for y in rows_y:
    if y < getattr(D, "FILL_MIN_Y", 0):
        continue
    xs = np.nonzero(body[y])[0]
    span = np.zeros(W, bool); span[xs.min():xs.max() + 1] = True
    fill[y] = under[y] & span
fill = ndi.binary_opening(fill, iterations=1)
body_a = body | fill
rgb = img[..., :3].copy()
inpaint_mask = (fill | (ndi.binary_dilation(fill, iterations=3) & ~body)).astype(np.uint8) * 255
body_rgb = cv2.inpaint(np.ascontiguousarray(rgb), inpaint_mask, 6, cv2.INPAINT_TELEA)
# darken reconstructed cloth slightly so it reads as shadowed body behind the limb
body_rgb[fill] = (body_rgb[fill].astype(np.float32) * 0.82).astype(np.uint8)

layers = {"body": (body_a, body_rgb, D.BODY_Z, D.BODY_BONES)}
for name, z, poly, bones in D.PARTS:
    m = own[name]
    src = img[..., :3]
    if name in getattr(D, "EXTEND", {}):
        ext = poly_mask(D.EXTEND[name]) & ~m
        # hidden thigh under the skirt: synthesize trouser fabric by repeating the
        # visible band just below the hem (mirrored vertically so it tiles)
        ys, xs = np.nonzero(m)
        top = ys.min()
        band = img[top + 2:top + 14, :, :3].astype(np.float32)
        src = img[..., :3].copy()
        ey, ex = np.nonzero(ext)
        for y, x in zip(ey, ex):
            k = (top - y) % (2 * band.shape[0])
            k = k if k < band.shape[0] else 2 * band.shape[0] - 1 - k
            src[y, x] = (band[k, x] * 0.9).astype(np.uint8)
        m = m | ext
    layers[name] = (m, src, z, bones)

bones_px = {n: (np.array(h, float), np.array(t, float)) for n, (p, h, t) in D.BONES.items()}


def seg_dist(P, a, b):
    ab = b - a
    k = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-6), 0, 1)
    return np.linalg.norm(P - (a + k[:, None] * ab), axis=1)


rig = {"source": D.SOURCE, "scale": meta["scale"] * getattr(D, "SCALE_MUL", 1.0), "bones": [], "parts": []}
for n, (p, h, t) in D.BONES.items():
    rig["bones"].append({"name": n, "parent": p, "head": [float(h[0] - FX), float(h[1] - FY)], "tail": [float(t[0] - FX), float(t[1] - FY)]})

for name, (m, src, z, bnames) in layers.items():
    m = ndi.binary_opening(m, iterations=1) | m & ndi.binary_erosion(m)
    if m.sum() < 30:
        continue
    ys, xs = np.nonzero(m)
    x0, x1 = max(0, xs.min() - STEP), min(W, xs.max() + STEP + 1)
    y0, y1 = max(0, ys.min() - STEP), min(H, ys.max() + STEP + 1)
    a = (m * 255).astype(np.uint8)
    a = cv2.GaussianBlur(a, (3, 3), 0.7)
    part = np.dstack([src, a])[y0:y1, x0:x1]
    Image.fromarray(part, "RGBA").save(os.path.join(OUT, name + ".png"))
    # mesh: regular grid over dilated mask
    md = ndi.binary_dilation(m, iterations=STEP // 2 + 2)
    gx = np.arange(x0, x1 + 1, STEP); gy = np.arange(y0, y1 + 1, STEP)
    gx = np.clip(gx, 0, W - 1); gy = np.clip(gy, 0, H - 1)
    idx = -np.ones((len(gy), len(gx)), int)
    verts = []
    for j, y in enumerate(gy):
        for i, x in enumerate(gx):
            yy0, yy1 = max(0, y - STEP // 2), min(H, y + STEP // 2 + 1)
            xx0, xx1 = max(0, x - STEP // 2), min(W, x + STEP // 2 + 1)
            if md[yy0:yy1, xx0:xx1].any():
                idx[j, i] = len(verts); verts.append((x, y))
    tris = []
    for j in range(len(gy) - 1):
        for i in range(len(gx) - 1):
            q = [idx[j, i], idx[j, i + 1], idx[j + 1, i + 1], idx[j + 1, i]]
            if min(q) >= 0:
                tris += [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
            else:
                good = [v for v in q if v >= 0]
                if len(good) == 3:
                    tris.append(good)
    V = np.array(verts, float)
    # weights: inverse distance to bone segments (smooth joints)
    W8 = {}
    dists = np.stack([seg_dist(V, *bones_px[b]) for b in bnames], axis=1)
    sharp = getattr(D, "WEIGHT_SHARPNESS", {}).get(name, (4.0, 4))
    w = 1.0 / np.power(dists + sharp[0], sharp[1])
    if name == "body":
        # skirt follows the thighs only below the waist, ramping in with height
        for k, b in enumerate(bnames):
            if b.startswith("thigh"):
                ramp = np.clip((V[:, 1] - getattr(D, 'SKIRT_Y', 190)) / 80.0, 0, 1) * getattr(D, 'SKIRT_FOLLOW', 0.45)
                s = 1.0 / (1.0 + np.exp(-(V[:, 0] - getattr(D, 'SPLIT_X', 121.0)) / 14.0))
                side = (1.0 - s) if b.endswith("_b") else s
                w[:, k] *= ramp * side + 1e-6
    w /= w.sum(axis=1, keepdims=True)
    for k, b in enumerate(bnames):
        W8[b] = [round(float(v), 4) for v in w[:, k]]
    rig["parts"].append({
        "name": name, "z": z, "png": name + ".png",
        "origin": [float(x0 - FX), float(y0 - FY)],
        "verts": [[float(x - FX), float(y - FY)] for x, y in verts],
        "uv": [[float(x - x0), float(y - y0)] for x, y in verts],
        "tris": [[int(a), int(b), int(c)] for a, b, c in tris], "weights": W8,
    })
    print(f"{name:8s} z={z} verts={len(verts):4d} tris={len(tris):4d}")
json.dump(rig, open(os.path.join(OUT, "rig.json"), "w"))
print("rig written", OUT)
