"""Remove non-Apple-Silicon slices before the bundle's final ad-hoc signature."""
import os
from pathlib import Path
import stat
import subprocess
import sys


def thin_bundle(bundle, architecture):
    if architecture != "arm64":
        raise ValueError("Only the Apple Silicon-only package is thinned")
    if not bundle.is_dir() or bundle.suffix != ".app":
        raise ValueError("Expected an existing .app bundle")
    magic = {bytes.fromhex(value) for value in (
        "feedface", "cefaedfe", "feedfacf", "cffaedfe",
        "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
    checked = thinned = 0
    for path in bundle.rglob("*"):
        if path.is_symlink() or not path.is_file():
            continue
        with path.open("rb") as source:
            if source.read(4) not in magic:
                continue
        slices = set(subprocess.check_output(["lipo", "-archs", str(path)], text=True).split())
        if architecture not in slices:
            raise RuntimeError(f"{path}: missing {architecture}: {slices}")
        checked += 1
        if slices == {architecture}:
            continue
        temporary = path.with_name(path.name + ".arm64.tmp")
        try:
            subprocess.run(["lipo", str(path), "-thin", architecture, "-output", str(temporary)], check=True)
            os.chmod(temporary, stat.S_IMODE(path.stat().st_mode))
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
        thinned += 1
    if checked < 2:
        raise RuntimeError("Expected both frontend and engine Mach-O files")
    print(f"Apple Silicon-only bundle: checked {checked} Mach-O files, thinned {thinned}")


if __name__ == "__main__":
    thin_bundle(Path(sys.argv[1]).resolve(), sys.argv[2])
