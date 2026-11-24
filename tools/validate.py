"""Check pack wiring and compile/link GLSL variants with glslang or a Windows GL driver."""
from pathlib import Path
import argparse
import itertools
import re
import shutil
import subprocess
import tempfile

from build_entrypoints import ROOT, SHADERS, expected_entries

INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$', re.MULTILINE)
DEFINE = re.compile(r'^(?://)?#define\s+(\w+)(?:\s+([^/\n]+?))?\s*(?://.*)?$', re.MULTILINE)


def properties(path):
    result = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.lstrip().startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            key = key.strip()
            if key in result:
                raise ValueError(f"Duplicate property {key} in {path}")
            result[key] = value.strip()
    return result


def option_values():
    text = (SHADERS / "lib/settings.glsl").read_text(encoding="utf-8")
    result = {}
    for line in text.splitlines():
        match = re.match(r'(?://)?#define (\w+)(?:\s+([^/]+))?\s*//', line)
        if match:
            name, default = match.groups()
            values = re.search(r'\[([^]]+)\]', line)
            result[name] = values.group(1).split() if values else ["on", "off"]
    for name, values in re.findall(r'const \w+ (\w+) = [^;]+; // \[([^]]+)\]', text):
        result[name] = values.split()
    return result


def profile_options(name):
    result = {}
    for token in properties(SHADERS / "shaders.properties")[f"profile.{name}"].split():
        if ":" in token:
            key, value = token.split(":", 1)
            result[key] = value
        else:
            result[token.lstrip("!")] = "off" if token.startswith("!") else "on"
    return result


def expand(path, options, stack=()):
    if path in stack or len(stack) > 9:
        raise ValueError(f"Cyclic/deep include at {path}")
    text = path.read_text(encoding="utf-8")

    def include(match):
        target = match.group(1)
        resolved = (SHADERS / target.lstrip("/") if target.startswith("/") else path.parent / target).resolve()
        if not resolved.is_relative_to(SHADERS.resolve()):
            raise ValueError(f"Include escapes shader directory: {target}")
        return expand(resolved, options, (*stack, path))

    text = INCLUDE.sub(include, text)
    for key, value in options.items():
        macro = re.compile(rf'^(?://)?#define[ \t]+{re.escape(key)}(?:[ \t]+[^/\n]+)?[ \t]*(?://[^\n]*)?$', re.MULTILINE)
        if value == "off":
            replacement = f"// disabled: {key}"
        elif value == "on":
            replacement = f"#define {key}"
        else:
            replacement = f"#define {key} {value}"
        text = macro.sub(lambda _: replacement, text)
        const = re.compile(rf'(const\s+\w+\s+{re.escape(key)}\s*=\s*)[^;]+;')
        text = const.sub(lambda m: m.group(1) + value + ";", text)
    return text


def source(path, options, iris):
    expanded = expand(path, options)
    header, body = expanded.split("\n", 1)
    macros = "#define MC_VERSION 12104\n"
    if iris:
        macros += "#define IS_IRIS\n"
    return header + "\n" + macros + body


def check_wiring():
    opts = option_values()
    props = properties(SHADERS / "shaders.properties")
    for path, expected in expected_entries():
        if not path.exists() or path.read_text(encoding="utf-8") != expected:
            raise ValueError(f"Stale/missing entry point {path}")
        expand(path, {})
    for name in ("PERFORMANCE", "BALANCED", "DREAM"):
        for key, value in profile_options(name).items():
            if key not in opts or value not in opts[key]:
                raise ValueError(f"Invalid {name} option: {key}:{value}")
    screens = {key.removeprefix("screen.") for key in props if key.startswith("screen.")}
    for key, value in props.items():
        if (key == "screen" or key.startswith("screen.")) and not key.endswith(".columns"):
            for token in value.split():
                if token.startswith("[") and token[1:-1] not in screens:
                    raise ValueError(f"Missing submenu {token}")
                if token not in ("<profile>", "<empty>", "*") and not token.startswith("[") and token not in opts:
                    raise ValueError(f"Unknown menu option {token}")
        if key == "sliders":
            for token in value.split():
                if token not in opts:
                    raise ValueError(f"Unknown slider {token}")
    for lang in (SHADERS / "lang").glob("*.lang"):
        labels = properties(lang)
        for option in opts:
            if f"option.{option}" not in labels:
                raise ValueError(f"Missing {option} label in {lang.name}")
    # Every packaged entry point must include its shared program; all include
    # paths are checked above with exact filename case on Linux CI.
    for path in (ROOT / "README.md", ROOT / "LICENSE", ROOT / "docs/VALIDATION.md"):
        if not path.is_file():
            raise ValueError(f"Missing packaged documentation: {path}")
    print("Includes, dimension entry points, profiles, menus and translations passed", flush=True)


def variants():
    for profile, material, iris in itertools.product(
        ("PERFORMANCE", "BALANCED", "DREAM"), (0, 1, 2), (False, True)
    ):
        options = profile_options(profile) | {"MATERIAL_MAPS": str(material)}
        yield f"{profile}/maps{material}/{'Iris' if iris else 'OptiFine'}", options, iris
    for style in (1, 2):
        yield f"DREAM/style{style}", profile_options("DREAM") | {"AERO_STYLE": str(style), "MATERIAL_MAPS": "2"}, True
    for autofocus in ("on", "off"):
        yield f"photo/autofocus-{autofocus}", profile_options("DREAM") | {
            "AERO_PHOTO_MODE": "on", "PHOTO_AUTOFOCUS": autofocus, "PHOTO_LETTERBOX": "0.10",
            "MATERIAL_MAPS": "2"}, True
    yield "temporal/Performance", profile_options("PERFORMANCE") | {"TAA_ENABLED": "1"}, True
    disabled = {key: "off" for key, values in option_values().items() if values == ["on", "off"]}
    disabled.update({"SHADOW_QUALITY": "0", "PUDDLE_QUALITY": "0", "BUBBLE_QUALITY": "0", "RIPPLE_QUALITY": "0",
                     "TAA_ENABLED": "0", "COLORED_LIGHT_STRENGTH": "0.00", "WATER_SURFACE_MOTION": "0.00"})
    yield "effects-disabled", profile_options("PERFORMANCE") | disabled, True


class Glslang:
    def __init__(self, executable):
        self.executable = executable

    def link(self, vertex, fragment, label):
        with tempfile.TemporaryDirectory(prefix="aerodream-glsl-") as folder:
            paths = [Path(folder) / "shader.vert", Path(folder) / "shader.frag"]
            for path, content in zip(paths, (vertex, fragment)):
                path.write_text(content, encoding="utf-8")
            result = subprocess.run([self.executable, "-l", *map(str, paths)], capture_output=True, text=True)
            if result.returncode:
                raise RuntimeError(f"{label}\n{result.stdout}\n{result.stderr}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compile", action="store_true", help="Require actual GLSL compilation and linking")
    parser.add_argument("--driver", action="store_true", help="Use a hidden Windows WGL context")
    args = parser.parse_args()
    check_wiring()
    if not args.compile and not args.driver:
        return
    if args.driver:
        from windows_gl import WindowsGL
        compiler = WindowsGL()
    else:
        executable = shutil.which("glslangValidator")
        if not executable:
            raise SystemExit("glslangValidator is required (Windows alternative: --driver)")
        compiler = Glslang(executable)
    count = 0
    for label, options, iris in variants():
        for folder in ("world0", "world-1", "world1"):
            for vertex_path in sorted((SHADERS / folder).glob("*.vsh")):
                fragment_path = vertex_path.with_suffix(".fsh")
                compiler.link(source(vertex_path, options, iris), source(fragment_path, options, iris),
                              f"{folder}/{vertex_path.stem}/{label}")
                count += 1
        print(f"Compiled and linked {label}", flush=True)
    print(f"Passed: {count} GLSL program variants", flush=True)


if __name__ == "__main__":
    main()
