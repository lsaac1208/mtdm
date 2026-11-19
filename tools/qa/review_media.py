"""Record one real-time Godot replay and combine two captures into a labelled MP4.

  python tools/qa/review_media.py record game village build/capture/before evidence/v0.3/before
  python tools/qa/review_media.py compare build/capture/before build/capture/after village build/village.mp4
"""
import argparse
import os
import re
import subprocess
from pathlib import Path

SCENES = ("village", "lowland", "elite")


def record(game, scene, raw, pictures):
    raw.mkdir(exist_ok=True, parents=True)
    pictures.mkdir(exist_ok=True, parents=True)
    avi = raw / (scene + ".avi")
    log = raw / (scene + ".log")
    cmd = [os.getenv("GODOT", "godot"), "--path", str(game), "--resolution", "1280x720",
           "--rendering-driver", "opengl3", "--write-movie", str(avi.resolve()), "--fixed-fps", "60", "--",
           "--test=visual_replay", "--scene=" + scene, "--evidence=" + str(pictures.resolve()),
           "--qa-settings=" + str((raw / "review-settings.cfg").resolve())]
    with log.open("w") as fh:
        subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT, check=True, timeout=180)
    if "REPLAY_END" not in log.read_text() or not (pictures / (scene + ".png")).is_file():
        raise RuntimeError(f"Incomplete capture in {log}")


def combine(before, after, scene, out):
    from PIL import Image, ImageDraw, ImageFont
    from tempfile import TemporaryDirectory

    out.parent.mkdir(exist_ok=True, parents=True)
    with TemporaryDirectory() as cache:
        args = ["ffmpeg", "-v", "error", "-y"]
        streams = []
        for index, (folder, label) in enumerate([(before, "BEFORE   66db6bc"), (after, "AFTER   v0.3.0")]):
            trace = (folder / (scene + ".log")).read_text()
            start = int(re.search(r"REPLAY_START frame=(\d+)", trace)[1])
            end = int(re.search(r"REPLAY_END frame=(\d+)", trace)[1])
            args += ["-ss", str(start / 60), "-t", str((end - start) / 60), "-i", str(folder / (scene + ".avi"))]
            png = Image.new("RGBA", (228, 36), (20, 20, 19, 205))
            ctx = ImageDraw.Draw(png)
            try:
                font = ImageFont.truetype("DejaVuSans.ttf", 19)
            except OSError:
                font = ImageFont.load_default(size=19)
            ctx.text((12, 6), label, font=font, fill=(242, 230, 198))
            badge = Path(cache) / f"{index}.png"
            png.save(badge)
            args += ["-i", str(badge)]
            movie, tag = index * 2, index * 2 + 1
            streams.append(f"[{movie}:v][{tag}:v]overlay=W-w-16:14,setsar=1[v{index}]")
        graph = ";".join(streams + ["[v0][0:a][v1][2:a]concat=n=2:v=1:a=1[outv][outa]"])
        subprocess.run(args + ["-filter_complex", graph, "-map", "[outv]", "-map", "[outa]", "-c:v", "libx264",
                               "-pix_fmt", "yuv420p", "-crf", "19", "-preset", "fast", "-c:a", "aac",
                               "-b:a", "128k", "-movflags", "+faststart", str(out)], check=True)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="action", required=True)
    rec = sub.add_parser("record")
    rec.add_argument("game", type=Path)
    rec.add_argument("scene", choices=SCENES)
    rec.add_argument("raw", type=Path)
    rec.add_argument("pictures", type=Path)
    cmp = sub.add_parser("compare")
    cmp.add_argument("before", type=Path)
    cmp.add_argument("after", type=Path)
    cmp.add_argument("scene", choices=SCENES)
    cmp.add_argument("output", type=Path)
    a = p.parse_args()
    if a.action == "record":
        record(a.game, a.scene, a.raw, a.pictures)
    else:
        combine(a.before, a.after, a.scene, a.output)
