"""Exercise a release ZIP on its target OS. Saves full engine logs and viewport evidence."""
import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


ENGINE_GATES = {
    "hslash_whiffs_crawler", "downslash_hits_crawler", "talisman_interrupts_spitter",
    "elite_windup_readable", "elite_sweep_jumpable", "elite_chop_escapable", "elite_sweep_dash_through",
    "respawn_at_checkpoint", "restart_keeps_progress", "new_run_resets_state", "demo_completes",
    "settings_persist", "difficulty_scales", "gamepad_actions_fire", "hud_and_active_sign_bindings",
}


def test_package(archive, out, expected_sha256=None):
    out.mkdir(parents=True, exist_ok=True)
    results = {}
    info = {"archive": archive.name, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "os": platform.platform(), "architecture": platform.machine(), "checks": results}
    if expected_sha256 is not None:
        digest = expected_sha256.lower().removeprefix("sha256:")
        results["archive-digest"] = {"pass": digest == info["sha256"], "expected": digest}
    (out / "native.json").write_text(json.dumps(info, indent=2))
    if expected_sha256 is not None and not results["archive-digest"]["pass"]:
        print(f"Archive SHA-256 does not match: {info['sha256']}", flush=True)
        return False
    with tempfile.TemporaryDirectory(prefix="wanderer-package-") as tmp:
        root = Path(tmp)
        if sys.platform == "darwin":
            subprocess.run(["ditto", "-x", "-k", str(archive), str(root)], check=True)
            bundle = next(root.glob("*.app"))
            app = next((bundle / "Contents/MacOS").iterdir())
            subprocess.run(["codesign", "--verify", "--deep", "--strict", str(bundle)], check=True)
        else:
            with zipfile.ZipFile(archive) as package:
                package.extractall(root)
                if sys.platform.startswith("linux"):
                    entry = next(item for item in package.infolist() if item.filename.endswith(".x86_64"))
                    stored_mode = (entry.external_attr >> 16) & 0o777
                    valid_mode = entry.create_system == 3 and bool(stored_mode & stat.S_IXUSR)
                    results["archive-executable"] = {"pass": valid_mode, "mode": oct(stored_mode),
                                                       "zip_host": entry.create_system}
                    (out / "native.json").write_text(json.dumps(info, indent=2))
                    if not valid_mode:
                        print("Linux executable is missing its Unix owner execute bit in the ZIP", flush=True)
                        return False
                    # Python's extractall does not restore ZIP Unix permissions.
                    (root / entry.filename).chmod(stored_mode)
            app = next(root.glob("*.exe" if os.name == "nt" else "*.x86_64"))
            if os.name == "nt" and os.getenv("MESA_BIN"):
                # Win32 resolves system OpenGL before PATH. Place Mesa alongside
                # the executable for this hosted runner only.
                mesa = Path(os.environ["MESA_BIN"])
                for dll in ("opengl32.dll", "libgallium_wgl.dll"):
                    shutil.copy2(mesa / dll, root / dll)

        def run(name, flags, expected, render=False, timeout=300):
            log = out / (name + ".log")
            pictures = out / name
            pictures.mkdir(exist_ok=True)
            godot_flags = ["--resolution", "1280x720"] if render else ["--headless"]
            if os.name == "nt" and render:
                # Microsoft-hosted Windows runners have no accelerated desktop GPU.
                # Mesa's native OpenGL implementation is installed by the workflow.
                godot_flags += ["--rendering-driver", "opengl3"]
            game_flags = [x.replace("{out}", pictures.as_posix()) for x in flags]
            engine_log = root / (name + "-engine.log")
            cmd = [str(app), *godot_flags, "--fixed-fps", "60", "--log-file", str(engine_log),
                   "--", *game_flags, "--mute", "--qa-settings=" + (root / (name + ".cfg")).as_posix()]
            if sys.platform == "darwin" and name == "title":
                cmd = ["open", "-n", "-W", str(bundle), "--args", *cmd[1:]]
            timed_out = False
            exit_code = None
            with log.open("w", encoding="utf-8") as fh:
                try:
                    proc = subprocess.run(cmd, cwd=root, stdout=fh, stderr=subprocess.STDOUT, timeout=timeout)
                    exit_code = proc.returncode
                except subprocess.TimeoutExpired:
                    timed_out = True
                    if sys.platform == "darwin" and name == "title":
                        # LaunchServices starts the app outside the open -W process.
                        # This path belongs solely to this extracted ZIP.
                        subprocess.run(["pkill", "-KILL", "-f", "^" + re.escape(str(app)) + "( |$)"], check=False)
            # GUI Windows export templates can route all diagnostics to the engine log.
            captured = log.read_text(encoding="utf-8", errors="replace")
            if engine_log.exists():
                engine_text = engine_log.read_text(encoding="utf-8", errors="replace")
                if engine_text.strip() and engine_text.strip() not in captured:
                    captured += "\n" + engine_text
                    log.write_text(captured, encoding="utf-8")
            bad = re.findall(r"(?m)^.*(?:SCRIPT ERROR:|\bERROR:|\bFAIL\b|leaked at exit).*$", captured)
            images = sorted(pictures.glob("*.png"))
            if timed_out:
                bad.append(f"Case exceeded {timeout} seconds")
            if name == "engine":
                passed = set(re.findall(r"(?m)^TEST\s+(\w+)\s+PASS\b", captured))
                summary = re.search(r"TESTS DONE pass=(\d+) fail=0\b", captured)
                if len(passed) < 52 or not summary or len(passed) != int(summary.group(1)):
                    bad.append(f"Expected at least 52 distinct passing engine checks and a matching total, found {len(passed)}")
                missing = ENGINE_GATES - passed
                if missing:
                    bad.append("Missing core checks: " + ", ".join(sorted(missing)))
            if name == "soak":
                for number in (0, 1):
                    if not re.search(rf"(?m)^SOAK run {number} nodes=\d+ orphans=\d+ objects=\d+", captured):
                        bad.append(f"Missing completed soak run {number}")
            valid = exit_code == 0 and not bad and bool(re.search(expected, captured))
            details = {"exit": exit_code, "timed_out": timed_out, "errors": bad[:12],
                       "screens": [p.name for p in images]}
            if render:
                valid = valid and any(p.stat().st_size > 15000 for p in images)
                renderer = re.search(r"(?im)^(?:OpenGL|Vulkan|Metal|Direct3D|D3D12)[^\r\n]*Using Device:[^\r\n]+", captured)
                details["renderer"] = renderer.group(0).strip() if renderer else "unreported"
            results[name] = {"pass": valid, **details}
            (out / "native.json").write_text(json.dumps(info, indent=2))
            print(name, "PASS" if valid else "FAIL", flush=True)
            if not valid:
                print(captured[-2200:], flush=True)

        run("engine", ["--test=all", "--nohitstop"], r"TESTS DONE pass=[1-9]\d* fail=0")
        run("normal-route", ["--test=bot", "--difficulty=1", "--bot_limit=1500"], r"TEST bot_completes_demo\s+PASS")
        if sys.platform.startswith("linux"):
            run("soak", ["--test=soak", "--difficulty=1", "--bot_limit=1500"], r"TEST soak_no_leak\s+PASS", timeout=420)
        run("title", ["--shots={out}", "--shot_times=0.7", "--quit_after=1.8"], r"SHOT ", True)
        run("village", ["--test=visual_replay", "--scene=village", "--evidence={out}"], r"REPLAY_END", True)
    return all(v["pass"] for v in results.values())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--sha256", help="Expected digest from the release, as hexadecimal or sha256:<hex>")
    args = parser.parse_args()
    sys.exit(0 if test_package(args.zip.resolve(), args.output.resolve(), args.sha256) else 1)
