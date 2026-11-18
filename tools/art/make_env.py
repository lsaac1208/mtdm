"""Procedural ink-wash environment art for the Taoist Wanderer demo.

No environment paintings exist in the concept set (Batch 3 is still to be
produced), so these layers are generated to match the art bible: aged
parchment, rough black ink outlines with dry-brush texture, ruined wasteland
silhouettes (towers, chimneys, pagodas, dead trees) as seen in the
backgrounds of concept sheets 06–10, and the faction palettes.

Usage: python -I tools/art/make_env.py <out_dir> [concept_art_dir]
"""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

OUT = sys.argv[1]
CONCEPT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "..", "concept_art")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)
random.seed(7)

INK = np.array([24, 21, 19], np.float32)
PAPER = np.array([222, 208, 180], np.float32)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


# ---------------------------------------------------------------- noise
def value_noise(h, w, cell, seed, tile_x=True):
    r = np.random.default_rng(seed)
    gh, gw = h // cell + 2, max(1, w // cell)
    g = r.random((gh, gw + 1))
    if tile_x:
        g[:, -1] = g[:, 0]
    ys = np.linspace(0, gh - 1.001, h)
    xs = np.linspace(0, gw, w, endpoint=False) if tile_x else np.linspace(0, gw - 0.001, w)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = ys - y0; fx = xs - x0
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    x1 = np.minimum(x0 + 1, gw)
    a = g[y0][:, x0]; b = g[y0][:, x1]; c = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(h, w, cell, seed, octaves=4, tile_x=True):
    v = np.zeros((h, w)); amp = 1.0; tot = 0
    for o in range(octaves):
        c = max(2, cell >> o)
        v += amp * value_noise(h, w, c, seed + o * 31, tile_x); tot += amp; amp *= 0.5
    return v / tot


def ridge_1d(w, base, amp, cell, seed, octaves=5):
    r = np.random.default_rng(seed)
    y = np.zeros(w)
    a = amp
    for o in range(octaves):
        n = max(2, (w // max(2, cell >> o)))
        pts = r.random(n + 1); pts[-1] = pts[0]
        xs = np.linspace(0, n, w, endpoint=False)
        i0 = xs.astype(int); f = xs - i0; f = f * f * (3 - 2 * f)
        y += a * (pts[i0] + (pts[i0 + 1] - pts[i0]) * f - 0.5)
        a *= 0.5
    return base + y


# ---------------------------------------------------------------- ink painting
def paint(mask, fill, outline=3, tex=0.18, seed=0, shade=0.35, hatch=0.0, wobble=1.5, ink=INK, alpha=1.0, bleed=0.6):
    """mask: float array (0..1) of the silhouette -> RGBA uint8 painted in ink style."""
    h, w = mask.shape
    if wobble > 0:
        dx = (fbm(h, w, 24, seed + 1, 3, False) - 0.5) * 2 * wobble * 2
        dy = (fbm(h, w, 24, seed + 2, 3, False) - 0.5) * 2 * wobble * 2
        yy, xx = np.mgrid[0:h, 0:w]
        mask = ndi.map_coordinates(mask, [yy + dy, xx + dx], order=1, mode="constant")
    m = mask > 0.5
    col = np.zeros((h, w, 3), np.float32)
    fill = np.asarray(fill, np.float32)
    n = fbm(h, w, 18, seed + 3, 4, False)
    streak = value_noise(h, w, 3, seed + 4, False)  # dry brush grain
    streak = ndi.uniform_filter1d(streak, 9, axis=1)
    k = 1.0 + (n - 0.5) * tex * 2 + (streak - 0.5) * tex
    yy = np.linspace(0, 1, h)[:, None]
    k = k * (1.0 - shade * yy)  # darker toward the bottom
    col[:] = fill[None, None, :] * k[..., None]
    if hatch > 0:
        hs = value_noise(h, w, 2, seed + 9, False)
        hs = ndi.uniform_filter1d(hs, 7, axis=0)
        hm = (hs > 1 - hatch) & m
        col[hm] = col[hm] * 0.55
    if outline > 0:
        er = ndi.binary_erosion(m, iterations=outline)
        edge = m & ~er
        # broken, pressure-varying outline
        press = fbm(h, w, 30, seed + 5, 2, False) > 0.32
        edge = edge & press | (m & ~ndi.binary_erosion(m, iterations=max(1, outline // 2)))
        col[edge] = ink
    a = mask.clip(0, 1)
    if bleed > 0:
        a = np.maximum(a, ndi.gaussian_filter(a, bleed) * 0.9)
    rgba = np.dstack([col.clip(0, 255), (a * 255 * alpha).clip(0, 255)]).astype(np.uint8)
    return rgba


def mask_from(draw_fn, w, h, ss=2):
    im = Image.new("L", (w * ss, h * ss), 0)
    d = ImageDraw.Draw(im)
    draw_fn(d, ss)
    im = im.resize((w, h), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0


def save(arr, name):
    Image.fromarray(arr).save(os.path.join(OUT, name + ".png"), optimize=True)
    print("wrote", name, arr.shape[1], "x", arr.shape[0])


def over(dst, src, x, y):
    """alpha-composite src (RGBA uint8) onto dst (float RGBA 0..1 arrays) at x,y with clipping & wrap in x."""
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    s = src.astype(np.float32) / 255.0
    for xo in (0, -W, W):
        x0 = x + xo
        if x0 >= W or x0 + w <= 0:
            continue
        sx0 = max(0, -x0); sx1 = min(w, W - x0)
        sy0 = max(0, -y); sy1 = min(h, H - y)
        if sx1 <= sx0 or sy1 <= sy0:
            continue
        reg = dst[y + sy0:y + sy1, x0 + sx0:x0 + sx1]
        sp = s[sy0:sy1, sx0:sx1]
        a = sp[..., 3:4]
        reg[..., :3] = sp[..., :3] * a + reg[..., :3] * (1 - a)
        reg[..., 3:4] = a + reg[..., 3:4] * (1 - a)


# ---------------------------------------------------------------- shapes
def tower(d, ss, x, base, w, h, seed):
    r = random.Random(seed)
    pts = [(x, base), (x, base - h)]
    # broken jagged top
    n = r.randint(3, 6)
    for i in range(n + 1):
        px = x + w * i / n
        pts.append((px, base - h - r.uniform(-h * 0.12, h * 0.08)))
    pts += [(x + w, base)]
    d.polygon([(p[0] * ss, p[1] * ss) for p in pts], fill=255)
    # window holes (gutted floors) and rebar sticking out of the broken top
    cols = max(1, int(w // 22))
    for row in range(int(h // 34)):
        for c in range(cols):
            if r.random() < 0.55:
                wx = x + 6 + c * (w - 12) / cols
                wy = base - h + 22 + row * 34
                if wy > base - 20:
                    continue
                d.rectangle([wx * ss, wy * ss, (wx + (w - 12) / cols * 0.55) * ss, (wy + 16) * ss], fill=0)
    for _ in range(r.randint(1, 4)):
        rx = x + r.uniform(0.1, 0.9) * w
        d.line([(rx * ss, (base - h + 4) * ss), ((rx + r.uniform(-12, 12)) * ss, (base - h - r.uniform(14, 40)) * ss)], fill=255, width=2 * ss)


def chimney(d, ss, x, base, w, h):
    d.polygon([(x * ss, base * ss), ((x + w * 0.12) * ss, (base - h) * ss), ((x + w * 0.88) * ss, (base - h) * ss), ((x + w) * ss, base * ss)], fill=255)
    d.rectangle([(x - 3) * ss, (base - h - 8) * ss, (x + w + 3) * ss, (base - h) * ss], fill=255)


def pagoda(d, ss, x, base, w, h, tiers=4):
    th = h / (tiers + 0.6)
    for i in range(tiers):
        ww = w * (1 - i * 0.16)
        y1 = base - i * th
        cx = x + w / 2
        d.rectangle([(cx - ww * 0.32) * ss, (y1 - th) * ss, (cx + ww * 0.32) * ss, y1 * ss], fill=255)
        # flared roof eave
        ey = y1 - th * 0.95
        d.polygon([((cx - ww * 0.62) * ss, (ey + th * 0.05) * ss), ((cx - ww * 0.35) * ss, (ey - th * 0.3) * ss),
                   ((cx + ww * 0.35) * ss, (ey - th * 0.3) * ss), ((cx + ww * 0.62) * ss, (ey + th * 0.05) * ss),
                   ((cx + ww * 0.4) * ss, (ey - th * 0.1) * ss), ((cx - ww * 0.4) * ss, (ey - th * 0.1) * ss)], fill=255)
    cx = x + w / 2
    d.line([(cx * ss, (base - h) * ss), (cx * ss, (base - h - th * 0.8) * ss)], fill=255, width=3 * ss)


def pylon(d, ss, x, base, w, h, lean):
    top = (x + w / 2 + lean, base - h)
    for fx in (x, x + w):
        d.line([(fx * ss, base * ss), (top[0] * ss, top[1] * ss)], fill=255, width=3 * ss)
    for i in range(1, 8):
        k = i / 8
        ya = base - h * k
        xa = x + (top[0] - x) * k
        xb = x + w + (top[0] - x - w) * k
        d.line([(xa * ss, ya * ss), (xb * ss, ya * ss)], fill=255, width=2 * ss)
        if i < 7:
            k2 = (i + 1) / 8
            d.line([(xa * ss, ya * ss), ((x + w + (top[0] - x - w) * k2) * ss, (base - h * k2) * ss)], fill=255, width=1 * ss)
    d.line([((top[0] - w * 0.7) * ss, (top[1] + 10) * ss), ((top[0] + w * 0.7) * ss, (top[1] + 6) * ss)], fill=255, width=3 * ss)


def dead_tree(d, ss, x, base, h, seed, width=10):
    r = random.Random(seed)

    def branch(x0, y0, ang, ln, wd, depth):
        x1 = x0 + math.cos(ang) * ln
        y1 = y0 + math.sin(ang) * ln
        d.line([(x0 * ss, y0 * ss), (x1 * ss, y1 * ss)], fill=255, width=max(1, int(wd * ss)))
        d.ellipse([(x1 - wd / 2) * ss, (y1 - wd / 2) * ss, (x1 + wd / 2) * ss, (y1 + wd / 2) * ss], fill=255)
        if depth <= 0 or ln < 8:
            return
        for _ in range(r.randint(2, 3)):
            branch(x1, y1, ang + r.uniform(-0.75, 0.75), ln * r.uniform(0.55, 0.75), wd * 0.62, depth - 1)
    # trunk with slight curve
    branch(x, base, -math.pi / 2 + r.uniform(-0.15, 0.15), h * 0.42, width, 5)
    d.polygon([((x - width * 1.4) * ss, base * ss), ((x - width * 0.3) * ss, (base - h * 0.15) * ss),
               ((x + width * 0.3) * ss, (base - h * 0.15) * ss), ((x + width * 1.5) * ss, base * ss)], fill=255)


def house(d, ss, x, base, w, h, seed):
    r = random.Random(seed)
    wall_h = h * 0.55
    d.rectangle([x * ss, (base - wall_h) * ss, (x + w) * ss, base * ss], fill=255)
    # broken sagging roof with upturned eaves
    left = (x - w * 0.12, base - wall_h + 4)
    right = (x + w * 1.12, base - wall_h + 4)
    peak = x + w * r.uniform(0.4, 0.6)
    pts = [left, (x + w * 0.05, base - wall_h - h * 0.08), (peak, base - h), (x + w * 0.95, base - wall_h - h * 0.12), right,
           (x + w * 0.9, base - wall_h - 2), (x + w * 0.1, base - wall_h - 2)]
    d.polygon([(p[0] * ss, p[1] * ss) for p in pts], fill=255)
    # hole in roof
    hx = x + w * r.uniform(0.55, 0.75)
    d.polygon([(hx * ss, (base - h * 0.85) * ss), ((hx + w * 0.15) * ss, (base - h * 0.75) * ss), ((hx + w * 0.05) * ss, (base - wall_h - 6) * ss)], fill=0)


# ---------------------------------------------------------------- layers
def make_sky(w=1280, h=720, name="sky", sun=(0.72, 0.36), night=False):
    yy = np.linspace(0, 1, h)[:, None, None]
    top = hexc("#cfc0a0"); mid = hexc("#d8c3a0"); hor = hexc("#c79a72")
    col = np.where(yy < 0.55, top + (mid - top) * (yy / 0.55), mid + (hor - mid) * ((yy - 0.55) / 0.45))
    col = np.broadcast_to(col, (h, w, 3)).copy()
    n = fbm(h, w, 80, 11, 5, False)
    col *= (0.92 + 0.16 * n)[..., None]
    # big faded red sun
    cy, cx = sun[1] * h, sun[0] * w
    Y, X = np.mgrid[0:h, 0:w]
    dd = np.hypot(X - cx, (Y - cy))
    sunm = np.clip((95 - dd) / 3, 0, 1)
    glow = np.exp(-(dd / 260) ** 2) * 0.25
    red = hexc("#a8382a")
    col = col * (1 - sunm[..., None] * 0.7) + red * sunm[..., None] * 0.7
    col = col + (hexc("#e8b080") - col) * glow[..., None]
    # ink cloud streaks
    c = fbm(h, w, 140, 12, 5, False)
    c = ndi.uniform_filter1d(c, 61, axis=1)
    band = np.exp(-((yy[..., 0] - 0.3) / 0.18) ** 2) + 0.6 * np.exp(-((yy[..., 0] - 0.5) / 0.08) ** 2)
    cl = np.clip((c - 0.52) * 4, 0, 1) * band
    col = col * (1 - cl[..., None] * 0.45) + INK * cl[..., None] * 0.45
    # paper fibre grain
    g = rng.normal(0, 4, (h, w, 1))
    col = np.clip(col + g, 0, 255)
    out = np.dstack([col, np.full((h, w), 255)]).astype(np.uint8)
    save(out, name)
    return out


def mountains(w=2048, h=420):
    dst = np.zeros((h, w, 4), np.float32)
    for i, (base, amp, cell, tone, a) in enumerate([(170, 150, 700, "#9c8e7a", 0.55), (230, 120, 420, "#7d7266", 0.7), (300, 70, 260, "#665c52", 0.8)]):
        ridge = ridge_1d(w, base, amp, cell, 20 + i)
        Y = np.arange(h)[:, None]
        m = (Y > ridge[None, :]).astype(np.float32)
        # wash: dark at ridge, fading to mist downwards
        depth = np.clip((Y - ridge[None, :]) / 140.0, 0, 1)
        fill = hexc(tone)
        n = fbm(h, w, 60, 30 + i, 4, True)
        col = fill[None, None, :] * (0.85 + 0.3 * n[..., None]) * (1 - 0.25 * (1 - depth[..., None]))
        alpha = m * a * (1 - 0.75 * depth) * (0.8 + 0.4 * n)
        # ink ridge line
        edge = (np.abs(Y - ridge[None, :]) < 2.2) * (n > 0.35)
        col[edge] = INK
        alpha = np.maximum(alpha, edge * a)
        src = np.dstack([col, alpha[..., None] * 255]).clip(0, 255).astype(np.uint8)
        over(dst, src, 0, 0)
    out = np.dstack([dst[..., :3], dst[..., 3:4] * 255]).clip(0, 255).astype(np.uint8)
    save(out, "far")


def ruins_layer(w, h, name, tone, seed, density, kinds, base_y, scale, alpha, mist=0.55):
    r = random.Random(seed)
    dst = np.zeros((h, w, 4), np.float32)

    def draw(d, ss):
        x = 0
        while x < w:
            k = r.choice(kinds)
            s = scale * r.uniform(0.7, 1.3)
            if k == "tower":
                tw, th = r.uniform(40, 90) * s, r.uniform(150, 280) * s
                tower(d, ss, x, base_y, tw, th, r.random())
                x += tw + r.uniform(10, 60) * density
            elif k == "chimney":
                cw, ch = r.uniform(18, 30) * s, r.uniform(180, 300) * s
                chimney(d, ss, x, base_y, cw, ch)
                x += cw + r.uniform(20, 80) * density
            elif k == "pagoda":
                pw, ph = r.uniform(80, 120) * s, r.uniform(160, 240) * s
                pagoda(d, ss, x, base_y, pw, ph, r.randint(3, 5))
                x += pw + r.uniform(30, 90) * density
            elif k == "pylon":
                pw, ph = r.uniform(40, 60) * s, r.uniform(180, 260) * s
                pylon(d, ss, x, base_y, pw, ph, r.uniform(-20, 20))
                x += pw + r.uniform(40, 120) * density
            elif k == "tree":
                dead_tree(d, ss, x + 20, base_y, r.uniform(140, 240) * s, r.random(), 9 * s)
                x += r.uniform(60, 140) * density
            elif k == "house":
                hw, hh = r.uniform(110, 170) * s, r.uniform(90, 130) * s
                house(d, ss, x, base_y, hw, hh, r.random())
                x += hw + r.uniform(20, 70) * density
            elif k == "wall":
                ww, wh = r.uniform(80, 200) * s, r.uniform(30, 70) * s
                pts = [(x, base_y), (x, base_y - wh)]
                for i in range(7):
                    pts.append((x + ww * (i + 1) / 7, base_y - wh * r.uniform(0.3, 1.15)))
                pts.append((x + ww, base_y))
                d.polygon([(p[0] * ss, p[1] * ss) for p in pts], fill=255)
                # missing bricks
                for _ in range(int(ww // 25)):
                    bx = x + r.uniform(5, ww - 20); by = base_y - r.uniform(10, wh * 0.8)
                    d.rectangle([bx * ss, by * ss, (bx + 14) * ss, (by + 7) * ss], fill=0)
                x += ww + r.uniform(10, 50) * density
            elif k == "gap":
                x += r.uniform(60, 200) * density
        # ground strip
        d.rectangle([0, (base_y - 6) * ss, w * ss, h * ss], fill=255)

    m = mask_from(draw, w, h)
    # make horizontal seam tile: blend wrap region
    rgba = paint(m, hexc(tone), outline=2, tex=0.22, seed=seed, shade=0.0, hatch=0.04, wobble=1.0)
    rgba = rgba.astype(np.float32)
    # mist fade toward the base
    Y = np.arange(h)[:, None]
    fade = 1 - mist * np.clip((Y - (base_y - 140)) / 160.0, 0, 1)
    rgba[..., 3] *= fade * alpha
    out = rgba.clip(0, 255).astype(np.uint8)
    save(out, name)


def foreground(w=2048, h=200):
    r = random.Random(5)

    def draw(d, ss):
        x = 0
        while x < w:
            k = r.random()
            if k < 0.55:
                # grass tuft
                for _ in range(r.randint(5, 12)):
                    bx = x + r.uniform(-12, 12)
                    ln = r.uniform(30, 90)
                    ang = -math.pi / 2 + r.uniform(-0.6, 0.6)
                    d.line([(bx * ss, h * ss), ((bx + math.cos(ang) * ln) * ss, (h + math.sin(ang) * ln) * ss)], fill=255, width=int(3 * ss))
                x += r.uniform(80, 300)
            elif k < 0.75:
                # broken post / grave marker
                pw, ph = r.uniform(12, 22), r.uniform(70, 150)
                d.polygon([(x * ss, h * ss), (x * ss, (h - ph) * ss), ((x + pw) * ss, (h - ph - r.uniform(-8, 12)) * ss), ((x + pw) * ss, h * ss)], fill=255)
                x += r.uniform(250, 600)
            else:
                x += r.uniform(200, 500)
    m = mask_from(draw, w, h)
    rgba = paint(m, hexc("#151210"), outline=0, tex=0.1, seed=9, shade=0.0, wobble=0.8)
    save(rgba, "fore")


def ground(w=512, h=512):
    n = fbm(h, w, 64, 40, 5, True)
    n2 = fbm(h, w, 12, 41, 3, True)
    top = hexc("#5a4a3a"); deep = hexc("#1d1714")
    Y = np.linspace(0, 1, h)[:, None]
    col = top + (deep - top) * np.clip(Y * 1.6, 0, 1)[..., None]
    col = col * (0.8 + 0.35 * n[..., None]) * (0.9 + 0.2 * n2[..., None])
    # strata streaks
    s = value_noise(h, w, 4, 42, True)
    s = ndi.uniform_filter1d(s, 31, axis=1)
    col *= (0.9 + 0.2 * s)[..., None]
    # pebbles
    for _ in range(140):
        cx, cy = rng.integers(0, w), rng.integers(30, h)
        rr = rng.uniform(2, 6)
        Yg, Xg = np.ogrid[0:h, 0:w]
        dd = ((Xg - cx) % w) ** 2 + (Yg - cy) ** 2
        pm = dd < rr * rr
        col[pm] = col[pm] * 0.6 + hexc("#8a7a66") * 0.4 * (1 - cy / h)
    # ink top edge + grass, first 20 px
    edge_y = 12 + 4 * ridge_1d(w, 0, 1.0, 64, 43, 3)
    Yi = np.arange(h)[:, None]
    above = Yi < edge_y[None, :]
    col[above] = 0
    line = (Yi >= edge_y[None, :]) & (Yi < edge_y[None, :] + 4)
    col[line] = INK
    alpha = np.where(above, 0, 255).astype(np.float32)
    rgba = np.dstack([col.clip(0, 255), alpha]).astype(np.uint8)
    im = Image.fromarray(rgba)
    d = ImageDraw.Draw(im)
    rr = random.Random(44)
    for _ in range(90):
        x = rr.uniform(0, w)
        ey = edge_y[int(x) % w]
        for _ in range(rr.randint(2, 5)):
            ln = rr.uniform(6, 18)
            ang = -math.pi / 2 + rr.uniform(-0.7, 0.7)
            c = tuple(int(v) for v in (hexc("#2a2418") * rr.uniform(0.8, 1.4)).clip(0, 255)) + (255,)
            d.line([(x, ey + 2), (x + math.cos(ang) * ln, ey + 2 + math.sin(ang) * ln)], fill=c, width=2)
    save(np.asarray(im), "ground")


# ---------------------------------------------------------------- props
def prop(name, w, h, draw, fill, outline=3, seed=1, shade=0.35, hatch=0.06, extra=None):
    m = mask_from(draw, w, h)
    rgba = paint(m, hexc(fill) if isinstance(fill, str) else fill, outline=outline, tex=0.22, seed=seed, shade=shade, hatch=hatch)
    if extra:
        rgba = extra(rgba)
    save(rgba, name)


def decorate(rgba, marks):
    im = Image.fromarray(rgba)
    d = ImageDraw.Draw(im)
    for kind, args in marks:
        getattr(d, kind)(**args)
    return np.asarray(im)


def talisman_strip(d, x, y, w, h, red=(140, 34, 26, 255), paper=(201, 164, 73, 255)):
    d.rectangle([x, y, x + w, y + h], fill=paper, outline=(40, 30, 20, 255), width=2)
    d.line([x + w / 2, y + 6, x + w / 2, y + h - 6], fill=red, width=3)
    d.line([x + 4, y + h * 0.3, x + w - 4, y + h * 0.3], fill=red, width=2)
    d.line([x + 4, y + h * 0.55, x + w - 4, y + h * 0.5], fill=red, width=2)


def make_props():
    prop("prop_house", 420, 300, lambda d, ss: house(d, ss, 40, 296, 340, 250, 3), "#4a3f35", seed=2)
    prop("prop_tree", 300, 420, lambda d, ss: dead_tree(d, ss, 150, 418, 400, 4, 16), "#2b2420", seed=3, hatch=0.0)
    prop("prop_deadtree", 320, 460, lambda d, ss: dead_tree(d, ss, 160, 458, 440, 8, 18), "#262420", seed=4, hatch=0.0)

    def well(d, ss):
        d.ellipse([40 * ss, 120 * ss, 220 * ss, 160 * ss], fill=255)
        d.rectangle([40 * ss, 140 * ss, 220 * ss, 230 * ss], fill=255)
        d.rectangle([50 * ss, 20 * ss, 62 * ss, 140 * ss], fill=255)
        d.rectangle([198 * ss, 20 * ss, 210 * ss, 140 * ss], fill=255)
        d.polygon([(30 * ss, 30 * ss), (130 * ss, 0), (230 * ss, 30 * ss), (230 * ss, 40 * ss), (30 * ss, 40 * ss)], fill=255)
    prop("prop_well", 260, 232, well, "#5a5046", seed=5)

    def post(d, ss):
        d.rectangle([60 * ss, 20 * ss, 78 * ss, 300 * ss], fill=255)
        d.polygon([(20 * ss, 40 * ss), (150 * ss, 30 * ss), (150 * ss, 80 * ss), (20 * ss, 90 * ss)], fill=255)
    prop("prop_post", 170, 300, post, "#4b3a2c", seed=6,
         extra=lambda a: decorate(a, [("rectangle", dict(xy=[90, 95, 108, 150], fill=(201, 164, 73, 255), outline=(40, 30, 20, 255), width=2)),
                                      ("line", dict(xy=[99, 100, 99, 145], fill=(124, 35, 29, 255), width=3)),
                                      ("line", dict(xy=[78, 60, 140, 200], fill=(124, 35, 29, 255), width=3))]))

    def cart(d, ss):
        d.polygon([(10 * ss, 60 * ss), (260 * ss, 40 * ss), (250 * ss, 110 * ss), (20 * ss, 120 * ss)], fill=255)
        d.ellipse([40 * ss, 90 * ss, 120 * ss, 170 * ss], fill=255)
        d.ellipse([170 * ss, 85 * ss, 240 * ss, 155 * ss], fill=255)
        d.line([(250 * ss, 70 * ss), (330 * ss, 150 * ss)], fill=255, width=8 * ss)
    prop("prop_cart", 340, 172, cart, "#4a3a2c", seed=7)

    def bones(d, ss):
        r = random.Random(3)
        for i in range(9):
            x = r.uniform(20, 260); y = r.uniform(60, 100)
            ang = r.uniform(-0.6, 0.6); ln = r.uniform(30, 60)
            d.line([(x * ss, y * ss), ((x + math.cos(ang) * ln) * ss, (y + math.sin(ang) * ln * 0.3) * ss)], fill=255, width=6 * ss)
            d.ellipse([(x - 6) * ss, (y - 6) * ss, (x + 6) * ss, (y + 6) * ss], fill=255)
        d.ellipse([120 * ss, 40 * ss, 170 * ss, 85 * ss], fill=255)
        d.rectangle([0, 100 * ss, 300 * ss, 112 * ss], fill=255)
    prop("prop_bones", 300, 112, bones, "#c5bfb3", seed=8, shade=0.2,
         extra=lambda a: decorate(a, [("ellipse", dict(xy=[132, 52, 142, 62], fill=(20, 18, 16, 255))), ("ellipse", dict(xy=[148, 52, 158, 62], fill=(20, 18, 16, 255)))]))

    def gate(d, ss):
        for x in (60, 330):
            d.rectangle([x * ss, 80 * ss, (x + 30) * ss, 420 * ss], fill=255)
        d.rectangle([150 * ss, 110 * ss, 270 * ss, 125 * ss], fill=255)
        d.polygon([(10 * ss, 70 * ss), (210 * ss, 30 * ss), (410 * ss, 70 * ss), (410 * ss, 90 * ss), (10 * ss, 90 * ss)], fill=255)
        d.rectangle([40 * ss, 120 * ss, 380 * ss, 140 * ss], fill=255)
        d.polygon([(250 * ss, 35 * ss), (330 * ss, 50 * ss), (300 * ss, 20 * ss)], fill=0)  # broken corner
    prop("prop_gate", 420, 420, gate, "#3a2a22", seed=9,
         extra=lambda a: decorate(a, [("rectangle", dict(xy=[175, 92, 245, 118], fill=(124, 35, 29, 255), outline=(30, 20, 15, 255), width=2))]))

    def statue(d, ss):
        d.rectangle([40 * ss, 250 * ss, 180 * ss, 300 * ss], fill=255)
        d.polygon([(60 * ss, 250 * ss), (70 * ss, 120 * ss), (100 * ss, 90 * ss), (130 * ss, 95 * ss), (155 * ss, 130 * ss), (165 * ss, 250 * ss)], fill=255)
        d.ellipse([88 * ss, 50 * ss, 132 * ss, 100 * ss], fill=255)
        d.polygon([(132 * ss, 60 * ss), (150 * ss, 45 * ss), (125 * ss, 78 * ss)], fill=0)  # cracked head
        d.polygon([(70 * ss, 140 * ss), (30 * ss, 200 * ss), (45 * ss, 205 * ss), (80 * ss, 160 * ss)], fill=255)
    prop("prop_statue", 220, 300, statue, "#6e675e", seed=10)

    def lantern(d, ss):
        d.rectangle([60 * ss, 40 * ss, 70 * ss, 300 * ss], fill=255)
        d.line([(65 * ss, 40 * ss), (130 * ss, 50 * ss)], fill=255, width=6 * ss)
        d.ellipse([105 * ss, 60 * ss, 155 * ss, 130 * ss], fill=255)
    prop("prop_lantern", 180, 300, lantern, "#3a2c24", seed=11,
         extra=lambda a: decorate(a, [("ellipse", dict(xy=[112, 70, 148, 120], fill=(150, 45, 30, 255))), ("line", dict(xy=[130, 74, 130, 116], fill=(220, 170, 90, 255), width=2))]))

    def shrine(d, ss):
        d.rectangle([40 * ss, 120 * ss, 280 * ss, 300 * ss], fill=255)
        d.polygon([(0, 130 * ss), (160 * ss, 40 * ss), (320 * ss, 130 * ss), (300 * ss, 140 * ss), (20 * ss, 140 * ss)], fill=255)
        d.rectangle([120 * ss, 180 * ss, 200 * ss, 300 * ss], fill=0)
    prop("prop_shrine", 320, 300, shrine, "#43362c", seed=12,
         extra=lambda a: decorate(a, [("rectangle", dict(xy=[60, 170, 80, 240], fill=(201, 164, 73, 255))), ("rectangle", dict(xy=[240, 160, 260, 236], fill=(201, 164, 73, 255))),
                                      ("line", dict(xy=[70, 176, 70, 232], fill=(124, 35, 29, 255), width=3)), ("line", dict(xy=[250, 166, 250, 230], fill=(124, 35, 29, 255), width=3))]))

    def graves(d, ss):
        r = random.Random(11)
        d.ellipse([10 * ss, 140 * ss, 400 * ss, 260 * ss], fill=255)
        for i in range(5):
            x = 40 + i * 75 + r.uniform(-10, 10)
            hgt = r.uniform(70, 130)
            tilt = r.uniform(-12, 12)
            d.polygon([(x * ss, 200 * ss), ((x + tilt) * ss, (200 - hgt) * ss), ((x + 34 + tilt) * ss, (200 - hgt - 6) * ss), ((x + 34) * ss, 200 * ss)], fill=255)
        d.rectangle([0, 200 * ss, 410 * ss, 220 * ss], fill=255)
    prop("prop_graves", 410, 220, graves, "#4f4a44", seed=13)

    def banner(d, ss):
        d.rectangle([40 * ss, 0, 50 * ss, 380 * ss], fill=255)
        d.polygon([(50 * ss, 20 * ss), (150 * ss, 30 * ss), (140 * ss, 220 * ss), (110 * ss, 200 * ss), (90 * ss, 240 * ss), (50 * ss, 210 * ss)], fill=255)
    prop("prop_banner", 170, 380, banner, "#5e2a22", seed=14)

    def stele(d, ss):
        d.rectangle([20 * ss, 240 * ss, 160 * ss, 270 * ss], fill=255)
        d.polygon([(40 * ss, 240 * ss), (40 * ss, 40 * ss), (90 * ss, 10 * ss), (140 * ss, 40 * ss), (140 * ss, 240 * ss)], fill=255)
    prop("prop_stele", 180, 270, stele, "#7a7266", seed=15,
         extra=lambda a: decorate(a, [("line", dict(xy=[90, 60, 90, 220], fill=(40, 34, 30, 255), width=4)), ("line", dict(xy=[70, 90, 110, 90], fill=(40, 34, 30, 255), width=3)),
                                      ("line", dict(xy=[70, 140, 110, 136], fill=(40, 34, 30, 255), width=3)), ("rectangle", dict(xy=[100, 40, 120, 110], fill=(201, 164, 73, 255)))]))

    def campfire(d, ss):
        r = random.Random(2)
        for i in range(7):
            x = 40 + i * 25; y = 70 + r.uniform(-6, 6)
            d.ellipse([(x - 16) * ss, (y - 12) * ss, (x + 16) * ss, (y + 12) * ss], fill=255)
        d.line([(40 * ss, 60 * ss), (200 * ss, 40 * ss)], fill=255, width=12 * ss)
        d.line([(50 * ss, 40 * ss), (190 * ss, 62 * ss)], fill=255, width=12 * ss)
    prop("prop_campfire", 240, 90, campfire, "#3b3029", seed=16)

    # platforms (drawn wider than tall; bottom sits on the ground)
    def plat(name, draw, fill, w=260, h=200):
        prop("plat_" + name, w, h, draw, fill, seed=hash(name) % 100)

    plat("wall", lambda d, ss: d.polygon([(4 * ss, 200 * ss), (4 * ss, 40 * ss), (60 * ss, 30 * ss), (120 * ss, 44 * ss), (190 * ss, 28 * ss), (256 * ss, 42 * ss), (256 * ss, 200 * ss)], fill=255), "#5d5145")
    plat("rubble", lambda d, ss: d.polygon([(0, 200 * ss), (10 * ss, 60 * ss), (80 * ss, 30 * ss), (170 * ss, 40 * ss), (250 * ss, 70 * ss), (260 * ss, 200 * ss)], fill=255), "#55493e")

    def cartp(d, ss):
        d.rectangle([0, 50 * ss, 400 * ss, 120 * ss], fill=255)
        d.ellipse([30 * ss, 90 * ss, 140 * ss, 200 * ss], fill=255)
        d.ellipse([260 * ss, 90 * ss, 370 * ss, 200 * ss], fill=255)
    prop("plat_cart", 400, 200, cartp, "#4a3a2c", seed=21)
    plat("rock", lambda d, ss: d.polygon([(0, 200 * ss), (20 * ss, 50 * ss), (90 * ss, 20 * ss), (200 * ss, 30 * ss), (250 * ss, 80 * ss), (260 * ss, 200 * ss)], fill=255), "#4d4a3c")

    def altar(d, ss):
        d.rectangle([10 * ss, 30 * ss, 250 * ss, 70 * ss], fill=255)
        d.rectangle([30 * ss, 70 * ss, 230 * ss, 200 * ss], fill=255)
    prop("plat_altar", 260, 200, altar, "#4b3a30", seed=22,
         extra=lambda a: decorate(a, [("rectangle", dict(xy=[110, 90, 150, 160], fill=(201, 164, 73, 255))), ("line", dict(xy=[130, 96, 130, 154], fill=(124, 35, 29, 255), width=3))]))
    plat("grave", lambda d, ss: d.ellipse([0, 30 * ss, 260 * ss, 300 * ss], fill=255), "#4a463f")


def concept_crop(path, box, name, size=None):
    im = Image.open(os.path.join(CONCEPT, path)).convert("RGB").crop(box)
    if size:
        im = im.resize(size, Image.LANCZOS)
    im.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def title_bg():
    sky = make_sky(1280, 720, "title_sky", sun=(0.78, 0.3))
    base = sky.astype(np.float32) / 255.0
    far = np.asarray(Image.open(os.path.join(OUT, "far.png")))
    mid = np.asarray(Image.open(os.path.join(OUT, "mid.png")))
    over(base, far[:, 300:1580], 0, 230)
    over(base, mid[:, 700:1980], 0, 260)

    def ridge(d, ss):
        pts = [(0, 720), (0, 650)]
        for i in range(21):
            x = i * 64
            y = 650 - 60 * math.exp(-((x - 930) / 260) ** 2) + random.uniform(-6, 6)
            pts.append((x, y))
        pts += [(1280, 720)]
        d.polygon([(p[0] * ss, p[1] * ss) for p in pts], fill=255)
        dead_tree(d, ss, 1130, 640, 300, 21, 12)
    m = mask_from(ridge, 1280, 720)
    rr = paint(m, hexc("#221d19"), outline=0, tex=0.15, seed=31, shade=0.0, wobble=1.0)
    over(base, rr, 0, 0)
    out = np.dstack([base[..., :3] * 255, np.full((720, 1280), 255)]).clip(0, 255).astype(np.uint8)
    save(out, "title_bg")
    # ending: soft dawn parchment with distant road
    end = make_sky(1280, 720, "ending_sky", sun=(0.5, 0.62)).astype(np.float32) / 255.0
    over(end, far[:, 700:1980], 0, 300)
    gm = mask_from(lambda d, ss: d.rectangle([0, 640 * ss, 1280 * ss, 720 * ss], fill=255), 1280, 720)
    over(end, paint(gm, hexc("#3a3028"), outline=0, tex=0.1, seed=3, shade=0.0), 0, 0)
    end[..., :3] = end[..., :3] * 0.75 + 0.25 * np.array([0.92, 0.86, 0.72])
    save(np.dstack([end[..., :3] * 255, np.full((720, 1280), 255)]).clip(0, 255).astype(np.uint8), "ending_bg")


if __name__ == "__main__":
    make_sky()
    mountains()
    ruins_layer(2048, 480, "mid", "#5f5850", 51, 1.0, ["tower", "chimney", "pylon", "pagoda", "gap", "tower", "tree"], 470, 1.0, 0.85)
    ruins_layer(2048, 520, "near", "#2c2622", 61, 1.3, ["house", "tree", "wall", "gap", "pagoda", "tree", "tower", "gap"], 512, 1.15, 0.95, mist=0.3)
    foreground()
    ground()
    make_props()
    title_bg()
    os.makedirs(os.path.join(OUT, "..", "ui"), exist_ok=True)
    im = Image.open(os.path.join(CONCEPT, "02_protagonist_combat_poses_v1.png")).convert("RGB").crop((30, 826, 118, 914)).resize((128, 128), Image.LANCZOS)
    im.save(os.path.join(OUT, "..", "ui", "portrait.png"))
    print("wrote portrait")
