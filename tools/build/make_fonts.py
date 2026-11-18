"""Subset bundled OFL fonts to ASCII + GB2312 level-1 + punctuation used by the game."""
import os, sys, subprocess
from fontTools import subset
from fontTools.ttLib import TTFont, TTCollection
out = sys.argv[1]
chars = set(chr(c) for c in range(0x20, 0x7f))
for hi in range(0xB0, 0xD8):
    for lo in range(0xA1, 0xFF):
        try: chars.add(bytes([hi, lo]).decode("gb2312"))
        except UnicodeDecodeError: pass
chars |= set("·—–…“”‘’「」『』《》〈〉、。，！？：；（）【】～×→←↑↓○●◆◇☯⚊⚋")
# include every non-ascii char used in game scripts/data
root = os.path.join(os.path.dirname(__file__), "..", "..", "game")
for dp, _, fs in os.walk(root):
    for f in fs:
        if f.endswith((".gd", ".tscn", ".json", ".tres")):
            chars |= set(open(os.path.join(dp, f), encoding="utf-8", errors="ignore").read())
text = "".join(sorted(c for c in chars if c.isprintable()))
def sub(src, dst, index=None):
    opts = subset.Options(); opts.layout_features = ["*"]; opts.name_IDs = ["*"]; opts.notdef_outline = True
    font = TTCollection(src).fonts[index] if index is not None else TTFont(src)
    s = subset.Subsetter(opts); s.populate(text=text); s.subset(font)
    font.save(dst); print(dst, os.path.getsize(dst) // 1024, "KB")
sub("/usr/share/fonts/truetype/sand-box/google/Ma Shan Zheng/" + os.listdir("/usr/share/fonts/truetype/sand-box/google/Ma Shan Zheng")[0], os.path.join(out, "MaShanZheng-subset.ttf"))
# Noto Serif CJK: index 0 in the TTC is JP; find the SC face
col = TTCollection("/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc")
idx = next(i for i, f in enumerate(col.fonts) if "SC" in f["name"].getDebugName(1))
sub("/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc", os.path.join(out, "NotoSerifSC-Bold-subset.otf"), idx)
