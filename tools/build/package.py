"""Export native desktop builds and zip them with the player documentation.

Usage: GODOT=/path/to/godot python3 tools/build/package.py [version] [linux|windows|macos ...]
"""
import os, subprocess, sys, zipfile

root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
godot = os.environ.get("GODOT", "godot")
ver = sys.argv[1] if len(sys.argv) > 1 else "0.3.0"
targets = [("Linux", "linux", "TaoistWanderer.x86_64", "linux-x86_64"),
           ("Windows", "windows", "TaoistWanderer.exe", "windows-x86_64"),
           ("macOS", "macos", "TaoistWanderer.zip", "macos-universal")]
requested = set(sys.argv[2:]) or {row[1] for row in targets}
unknown = requested - {row[1] for row in targets}
if unknown:
    sys.exit("Unknown platform: " + ", ".join(sorted(unknown)))
for preset, sub, binary, tag in targets:
    if sub not in requested:
        continue
    out_dir = os.path.join(root, "build", sub)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, binary)
    if os.path.exists(out):
        os.remove(out)   # never let a stale binary survive a failed export
    subprocess.run([godot, "--headless", "--path", os.path.join(root, "game"), "--export-release", preset, out], check=True,
                   stdout=subprocess.DEVNULL)
    if not os.path.exists(out):
        sys.exit("export failed: " + preset)
    zpath = os.path.join(root, "build", f"TaoistWanderer-v{ver}-{tag}.zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        if binary.endswith(".zip"):
            # macOS: Godot already produced a zipped .app; copy its entries (keeps exec bits)
            with zipfile.ZipFile(out) as src:
                for info in src.infolist():
                    z.writestr(info, src.read(info.filename))
        else:
            zi = zipfile.ZipInfo(binary)
            zi.external_attr = 0o755 << 16
            zi.compress_type = zipfile.ZIP_DEFLATED
            with open(out, "rb") as fh:
                z.writestr(zi, fh.read())
        for doc, name in [("RELEASE_NOTES.md", "README.md"), ("game/ASSETS_AND_CREDITS.md", "ASSETS_AND_CREDITS.md")]:
            z.write(os.path.join(root, doc), name)
    print(zpath, os.path.getsize(zpath) // 1048576, "MB")
