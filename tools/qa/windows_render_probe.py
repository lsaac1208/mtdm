"""Render the published Windows package on a native host, starting with the player configuration."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from PIL import Image, ImageStat


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def find_angle():
    paths = []
    if os.environ.get("ANGLE_BIN"):
        paths.append(Path(os.environ["ANGLE_BIN"]))
    for env_key in ("ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA"):
        if not os.environ.get(env_key):
            continue
        for browser in ("Google/Chrome", "Microsoft/Edge"):
            directory = Path(os.environ[env_key]) / browser / "Application"
            paths.extend(sorted(directory.glob("*/libEGL.dll"), reverse=True))
    for path in paths:
        folder = path.parent if path.suffix.lower() == ".dll" else path
        if (folder / "libEGL.dll").is_file() and (folder / "libGLESv2.dll").is_file():
            return folder
    return None


def prepare_backend(name, root, mesa, env):
    if name == "player-default":
        return []
    if name in ("mesa-wgl", "mesa-d3d12-warp"):
        # Godot 4.7.2 GLManagerNative_Windows::_create_context loads opengl32.dll.
        # opengl32sw.dll is a Qt convention and is never requested by this engine.
        for dll in ("opengl32.dll", "libgallium_wgl.dll"):
            shutil.copy2(mesa / dll, root / dll)
        env["PATH"] = str(mesa) + os.pathsep + env["PATH"]
        env["LIBGL_ALWAYS_SOFTWARE"] = "1"
        env["GALLIUM_DRIVER"] = "llvmpipe" if name == "mesa-wgl" else "d3d12"
        if name == "mesa-d3d12-warp":
            # Mesa's D3D12 DXGI selector uses EnumWarpAdapter for software GL.
            env["MESA_D3D12_DEFAULT_ADAPTER_NAME"] = "Microsoft Basic Render"
        return []
    if name == "angle-d3d11":
        angle = find_angle()
        if angle is None:
            raise FileNotFoundError("No ANGLE libEGL.dll and libGLESv2.dll installation")
        for dll in ("libEGL.dll", "libGLESv2.dll", "d3dcompiler_47.dll"):
            if (angle / dll).is_file():
                shutil.copy2(angle / dll, root / dll)
        env["PATH"] = str(angle) + os.pathsep + env["PATH"]
        return ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"]
    if name == "vulkan-lavapipe":
        icd = mesa.parent / "share/vulkan/icd.d/lvp_icd.x86_64.json"
        if not icd.is_file():
            raise FileNotFoundError(icd)
        env["PATH"] = str(mesa) + os.pathsep + env["PATH"]
        env["VK_DRIVER_FILES"] = str(icd)
        # Older loaders use this equivalent name.
        env["VK_ICD_FILENAMES"] = str(icd)
        return ["--rendering-method", "mobile", "--rendering-driver", "vulkan"]
    raise ValueError(name)


def check_image(path):
    with Image.open(path) as image:
        image.load()
        if image.size != (1280, 720):
            raise ValueError(f"Unexpected viewport {image.size}")
        rgb = image.convert("RGB").resize((160, 90))
        levels = ImageStat.Stat(rgb.convert("L")).stddev[0]
        colors = len(set(rgb.getdata()))
        if levels < 10 or colors < 80:
            raise ValueError(f"Empty or flat frame: {colors} colors, luminance deviation {levels:.1f}")
        return {"size": list(image.size), "colors_at_160px": colors, "luminance_stddev": round(levels, 1),
                "sha256": digest(path)}


def run_scene(exe, case_dir, flags, env, scene):
    # Fresh private paths prevent an earlier attempt's image from satisfying a new check.
    pictures = exe.parent / ("capture-" + scene)
    pictures.mkdir()
    engine_log = exe.parent / (scene + ".engine.log")
    process_log = case_dir / (scene + ".console.log")
    if scene == "title":
        game = ["--shots=" + pictures.as_posix(), "--shot_times=0.7", "--quit_after=1.8"]
        filename, marker, timeout = "shot_00.png", "SHOT ", 40
    else:
        game = ["--test=visual_replay", "--scene=village", "--evidence=" + pictures.as_posix()]
        filename, marker, timeout = "village.png", "REPLAY_END", 165
    cmd = [str(exe), "--verbose", "--resolution", "1280x720", "--fixed-fps", "60", "--audio-driver", "Dummy",
           "--log-file", str(engine_log), *flags, "--", *game, "--mute",
           "--qa-settings=" + (exe.parent / (scene + ".cfg")).as_posix()]
    result = {"pass": False, "renderer_flags": flags, "timed_out": False, "errors": []}
    with process_log.open("wb") as log:
        proc = subprocess.Popen(cmd, cwd=exe.parent, env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            result["timed_out"] = True
            # Includes a driver/Godot modal dialog and this instance's children only.
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], stdout=log, stderr=log, check=False)
            if proc.poll() is None:
                proc.kill()
            proc.wait(timeout=10)
            result["errors"].append(f"{scene} exceeded {timeout}s")
        result["exit"] = proc.returncode
    text = process_log.read_text(encoding="utf-8", errors="replace")
    if engine_log.exists():
        shutil.copy2(engine_log, case_dir / (scene + ".engine.log"))
        text += "\n" + engine_log.read_text(encoding="utf-8", errors="replace")
    renderer = re.search(r"(?im)^(?:OpenGL|Vulkan|Metal|Direct3D|D3D12)[^\r\n]*Using Device[^\r\n]+", text)
    result["renderer"] = renderer.group(0).strip() if renderer else None
    result["errors"].extend(dict.fromkeys(re.findall(r"(?im)^.*(?:SCRIPT ERROR:|\bERROR:|leaked at exit).*?$", text)))
    if marker not in text:
        result["errors"].append(f"Missing runtime marker {marker.strip()}")
    if renderer is None:
        result["errors"].append("No rendering device reported")
    try:
        result["image"] = check_image(pictures / filename)
        dest = case_dir / (scene + ".png")
        shutil.copy2(pictures / filename, dest)
        result["image"]["path"] = str(Path(case_dir.name) / dest.name)
    except (OSError, ValueError) as error:
        result["errors"].append(str(error))
    result["pass"] = result["exit"] == 0 and not result["errors"]
    return result


def probe(archive, output, expected):
    output.mkdir(parents=True, exist_ok=True)
    sha = digest(archive)
    data = {"os": platform.platform(), "architecture": platform.machine(), "archive": archive.name,
            "sha256": sha, "expected_sha256": expected.lower().removeprefix("sha256:"),
            "selected": None, "attempts": [], "pass": False}
    report = output / "windows-render.json"
    def save():
        report.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    save()
    if data["expected_sha256"] != sha:
        print("Archive digest mismatch", flush=True)
        return False
    if os.name != "nt":
        raise RuntimeError("A native Windows host is required")
    # Inherited by the child; suppresses Windows system error and fault dialogs.
    # Godot-owned graphics dialogs remain bounded by the per-process timeout.
    ctypes.windll.kernel32.SetErrorMode(0x0001 | 0x0002 | 0x8000)
    mesa = Path(os.environ.get("MESA_BIN", r"C:\msys64\mingw64\bin"))
    clean = os.environ.copy()
    for name in ("GALLIUM_DRIVER", "LIBGL_ALWAYS_SOFTWARE", "VK_DRIVER_FILES", "VK_ICD_FILENAMES",
                 "MESA_D3D12_DEFAULT_ADAPTER_NAME", "MESA_LOADER_DRIVER_OVERRIDE", "ANGLE_DEFAULT_PLATFORM"):
        clean.pop(name, None)
    clean["PATH"] = os.pathsep.join(p for p in clean["PATH"].split(os.pathsep)
                                    if os.path.normcase(p) != os.path.normcase(str(mesa)))
    for backend in ("player-default", "mesa-wgl", "angle-d3d11", "mesa-d3d12-warp", "vulkan-lavapipe"):
        attempt = {"backend": backend, "pass": False}
        data["attempts"].append(attempt)
        save()
        case_dir = output / backend
        case_dir.mkdir(exist_ok=True)
        print("Starting", backend, flush=True)
        with tempfile.TemporaryDirectory(prefix="wanderer-render-") as temp:
            root = Path(temp)
            with zipfile.ZipFile(archive) as z:
                z.extractall(root)
            exe = next(root.glob("*.exe"))
            env = clean.copy()
            try:
                flags = prepare_backend(backend, root, mesa, env)
                attempt["renderer_flags"] = flags
                attempt["driver_environment"] = {k: v for k, v in env.items() if k not in clean or v != clean[k] if k != "PATH"}
                attempt["sidecars"] = [p.name for p in sorted(root.glob("*.dll"))]
                for scene in ("title", "village"):
                    attempt[scene] = run_scene(exe, case_dir, flags, env, scene)
                    print(backend, scene, "PASS" if attempt[scene]["pass"] else "FAIL", flush=True)
                    save()
                    if not attempt[scene]["pass"]:
                        break
                if attempt.get("village", {}).get("pass"):
                    attempt["pass"] = attempt["title"]["image"]["sha256"] != attempt["village"]["image"]["sha256"]
            except (OSError, subprocess.SubprocessError) as error:
                attempt["error"] = str(error)
        if attempt["pass"]:
            data["selected"] = backend
            data["pass"] = True
        save()
        if data["pass"]:
            break
    return data["pass"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--sha256", required=True)
    args = parser.parse_args()
    sys.exit(0 if probe(args.zip.resolve(), args.output.resolve(), args.sha256) else 1)
