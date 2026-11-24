"""Build a local shader-pack ZIP from an explicit runtime/documentation allowlist."""
from pathlib import Path
import argparse
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def package(output):
    files = [ROOT / "README.md", ROOT / "LICENSE"]
    allowed = {
        "shaders": {".glsl", ".vsh", ".fsh", ".properties", ".lang"},
        "docs": {".md", ".html", ".png", ".jpg", ".webp"},
    }
    for directory, suffixes in allowed.items():
        files.extend(path for path in (ROOT / directory).rglob("*")
                     if path.suffix.lower() in suffixes
                     and not any(part.startswith(".") for part in path.relative_to(ROOT).parts)
                     and path.is_file())
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(files):
            archive.write(path, path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(output) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"ZIP integrity failure: {bad}")
        names = set(archive.namelist())
        for required in ("README.md", "LICENSE", "docs/VALIDATION.md", "shaders/shaders.properties",
                         "shaders/world0/final.fsh", "shaders/world-1/final.fsh", "shaders/world1/final.fsh"):
            if required not in names:
                raise RuntimeError(f"ZIP is missing {required}")
        if not all(path.split("/", 1)[0] in {"shaders", "docs", "README.md", "LICENSE"} for path in names):
            raise RuntimeError("Unexpected ZIP content")
    print(f"Built and verified {output.name}: {len(files)} files, {output.stat().st_size:,} bytes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist/AeroDream-GlassMotion-dev.zip")
    args = parser.parse_args()
    package(args.output)


if __name__ == "__main__":
    main()
