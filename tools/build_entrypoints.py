"""Generate loader entry points; edit shader logic in shaders/program instead."""
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "shaders"
FOLDERS = {"": 0, "world0": 0, "world-1": -1, "world1": 1}


def expected_entries():
    for source in sorted((SHADERS / "program").glob("*.glsl")):
        name = source.name.removesuffix(".glsl")
        for folder, dimension in FOLDERS.items():
            yield SHADERS / folder / name, (
                "#version 330 compatibility\n"
                f"#define AERO_DIMENSION {dimension}\n"
                f'#include "/program/{source.name}"\n'
            )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    entries = list(expected_entries())
    if not entries:
        raise SystemExit("No shared shader programs found")
    for path, content in entries:
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                raise SystemExit(f"Stale entry point: {path.relative_to(ROOT)}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    print(f"{'Checked' if args.check else 'Generated'} {len(entries)} shader entry points")


if __name__ == "__main__":
    main()
