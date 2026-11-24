
# AeroDream

**A Frutiger Aero-inspired shader pack for Minecraft Java Edition.**

Crystal-blue water, fresh greens, glossy highlights and soft pastel evenings.
The Living Worlds development update adds rain puddles, biome atmosphere,
underwater light shafts, dimension styling, handheld light, moon phases,
shooting stars, and optional resource-pack material maps.
Glass & Motion extends it with stained-glass shadows, volumetric clouds,
weather-driven gusts, geometric water waves, visible-source colored block light,
optional temporal anti-aliasing, and photo depth of field.

## Features

- Clear water with waves, screen-space reflections, refraction and shoreline foam
- Animated lakebed caustics, underwater bubbles and shadow-tested underwater sunlight
- Rooted foliage wind, translucent leaves, moving cloud shadows and dew sparkle
- Rain rings, wet surface gloss, and irregular puddles that grow and dry with wetness
- Climate-aware haze: humid jungle air, warmer dry horizons and crisp cold/high terrain
- Pastel sunsets, blue hour, after-rain rainbows, moon phases and rare shooting stars
- Glass reflections, pearlescent ice, snow sparkles and optional night auroras
- Amber/soul-teal Nether lighting and a pearlescent violet End sky
- Warm or cool handheld lights from either hand, with adjustable strength and radius
- Optional oldPBR and LabPBR 1.3 normal/smoothness maps on terrain and translucent materials
- Colored sunlight through glass, including water caustics and underwater shafts
- Optional clouds with volume, internal shading, and support for flying through them
- Weather gusts and small water height waves with matching reflection normals
- Depth-tested colored light from visible lamps and material-map emission
- Optional TAA with camera reprojection, neighborhood clipping and depth rejection
- Photo mode with automatic/manual focus, depth of field and optional cinematic bars

## Visual styles and quality

Color styles are independent of quality: **Classic Aero** has fresh greens and
bright blues; **Tropical Aero** favors turquoise; **Soft Dream** uses gentle pastels.

| Setting | Performance | Balanced | Dream |
|---|---|---|---|
| Shadows | Hard, 1024 | Soft, 1536 | Soft, 2048 |
| Water reflection steps | 8 | 16 | 24 |
| Rain puddles | Off | Sky reflections | Sky + visible scene reflections |
| Underwater shafts | Off | 8 samples | 12 samples |
| Clouds / cloud shadows | Off | On | On |
| Glass scene reflections | Off | Off | On |
| Auroras | Off | Off | On |
| Material maps | Off | Off | Off |
| Colored glass shadows | Off | On | On |
| Cloud shape | Off | Wisps | Volume, 20 steps |
| Visible-source colored block light | Off | 12 samples | 24 samples |
| Temporal anti-aliasing | Off | Off | On |
| Photo mode | Off by default | Off by default | Off by default |

Material maps stay opt-in across all presets because the correct format depends
on your resource pack. Choose it under **Resource-Pack Materials** after selecting
a quality preset. Most new features have independent strength or quality controls.

Start with Balanced for everyday play. Dream adds volumetric clouds and TAA;
cloud integration also runs for reflections and can be expensive. You can enable
**Temporal Anti-Aliasing** independently under **Lighting & Shine**. It replaces
FXAA while active. Wind and water movement can be reduced independently.

Enable **Photo Mode** in its own menu to use depth of field. Autofocus follows
the smoothed center-screen distance; disable it to choose a manual distance in
blocks. **Photo Blur Strength** controls blur, and **Cinematic Bars** controls
framing. Photo mode does not pause the game or hide the HUD; use F1 for captures.

## Installation and compatibility

1. Install [Iris Shaders](https://www.irisshaders.dev/) for your Minecraft version.
2. Place the AeroDream folder or release ZIP in `.minecraft/shaderpacks`.
3. Enable AeroDream, select a quality preset, then choose your color style.

The pack targets the Iris/OptiFine shader interface with GLSL 3.30 compatibility
shaders. Separate entry points cover the Overworld, Nether and End. Custom
dimensions use the loader's fallback and may need their own mapping.

**Exact Minecraft/loader versions have not yet been verified in-game for this
update.** Source and GLSL compilation checks are separate from runtime support.
The [validation record](docs/VALIDATION.md) tracks the checks needed before release.

## Resource-pack materials

With vanilla textures, leave **Material Format** set to **Off**. With a material
resource pack, select **oldPBR** or **LabPBR 1.3** to match its maps; formats cannot
be detected automatically. Normal intensity and material shine are adjustable.

| Format | Normal map | Specular map |
|---|---|---|
| oldPBR | RGB tangent-space normals | R smoothness, G metalness, B emission |
| LabPBR 1.3 | RG normal XY with reconstructed Z, B ambient occlusion | R smoothness, G dielectric F0/metal IDs, A emission |

LabPBR metal IDs use the albedo-metal fallback; alpha 255 is non-emissive.
Height/parallax, porosity and texture-driven subsurface scattering are not
implemented. Water keeps its procedural wave normals. Material maps add surface
detail without altering block geometry.

The encoding follows the [LabPBR material standard](https://shaderlabs.org/wiki/LabPBR_Material_Standard).
Biome transitions use loader-side [custom uniforms](https://shaders.properties/current/reference/shadersproperties/custom_uniforms/).

## Screenshots and performance results

Use the [preset comparison viewer](docs/showcase.html) for matching in-game
captures of noon, sunset, rain, underwater, caves, Nether and End. Screenshots
have not yet been captured for this update; empty slots say so explicitly.

Measured FPS and tested hardware are also pending. The
[capture and benchmark protocol](docs/VALIDATION.md) describes consistent
settings, test scenes and a compatibility matrix. `tools/benchmark.py` calculates
average FPS and 1% lows from real per-frame millisecond CSV captures.

## Development checks

```text
python tools/build_entrypoints.py --check
python -m unittest discover -s tools -p "test_*.py"
python tools/validate.py --compile
```

`--compile` needs `glslangValidator`; on Windows, `--driver` instead uses a hidden
OpenGL driver context without Python dependencies. CI compiles and links all
dimension/preset/material combinations and checks menus, profiles and translations.
Edit shared programs in `shaders/program`, libraries in `shaders/lib`, and run
`python tools/build_entrypoints.py` after adding programs.

Screen-space reflections cannot show off-screen geometry. Puddles use a skylight
exposure approximation, handheld lights do not cast shadows, and underwater
shafts use the existing directional shadow map. External dynamic-light mods may
add their own lighting; turn Handheld Light to zero if the combined effect is too bright.

Colored block light gathers visible emitters over roughly six blocks and uses
screen-space depth checks; it does not replace Minecraft's off-screen lighting or
provide full voxel/global illumination. Overlapping glass uses the nearest shadow
layer. Water displacement is deliberately small and can be disabled for waterlogged
builds. TAA lacks per-object motion vectors, so fast entities, foliage and ripples
can still trail; disable TAA or lower Temporal Smoothing if needed.
