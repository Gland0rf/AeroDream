# Validation and showcase capture

Source checks and driver compilation do not establish Minecraft compatibility,
visual correctness, or performance. Record actual game results here before a release.

## Automated checks

Run `python tools/validate.py` for include paths, dimension entry points, profile
values, shader menus, and English/German option labels. Run
`python tools/validate.py --compile` with `glslangValidator` installed for GLSL
compilation and vertex/fragment linking. On Windows,
`python tools/validate.py --driver` uses a hidden OpenGL context without extra
Python dependencies. These checks cover three dimensions, all quality presets,
oldPBR/LabPBR modes, both loader macro paths, the three palettes, photo autofocus
and manual focus, temporal sampling on the Performance preset, and disabled effects.

`python tools/render_checks.py` additionally renders numerical probes to an
offscreen floating-point framebuffer on Windows: full/new moon visibility,
climate weights, both-hand lighting, underwater shadow occlusion, LabPBR material
decoding and dimension skies. They also check colored-glass transmission versus
opaque occlusion, water height/normal consistency, empty/disoccluded temporal
history, jitter cycle centering, cloud volume bounds, focus blur and local light
color. These are synthetic probes, not Minecraft captures.

Local verification on 2026-11-24: all 1,224 Glass & Motion GLSL program variants
compiled and linked on AMD Radeon PRO Graphics, OpenGL 4.6.0 compatibility driver
`26.10.1.261008`. Offscreen numerical checks and eight tooling tests passed.
The 136 generated loader entry points and archive dependencies were verified.
In-game support and FPS
remain unmeasured. CI configuration uses glslang on Linux; the hosted CI run has
not been executed as part of this local change.

Shader entry points are generated from `shaders/program/*.glsl` using
`python tools/build_entrypoints.py`. Edit shared programs, then regenerate; use
`--check` to detect stale generated files. Libraries remain in `shaders/lib`.

## Runtime compatibility

| Minecraft | Loader and version | GPU / driver | Result |
|---|---|---|---|
| Not recorded | Iris: not tested in-game | Not recorded | Pending |
| Not recorded | OptiFine: not tested in-game | Not recorded | Pending |

Use a disposable showcase world with cheats enabled. Record the exact Minecraft,
loader, Sodium (if applicable), Java, OS, GPU, driver, and resource-pack versions.
Check Minecraft's log for shader compilation errors after every pack reload.

## Visual acceptance checklist

- [ ] Rotate the camera over wet stone, ice, snow and grass: highlights follow the sun/view consistently.
- [ ] Rain on plains and stone: puddles grow, reflect sky, and dry gradually after clearing.
- [ ] Dream puddles reflect an on-screen building; off-screen geometry falls back to the sky.
- [ ] No puddles on plants, snow, ice, entities, inside caves, or beneath solid roofs. Check partial skylight under eaves; exposure uses a lightmap approximation.
- [ ] Compare Performance (no puddles), Balanced (sky), Dream (sky + scene).
- [ ] Walk between jungle, desert, snowy plains and high mountains: atmosphere changes smoothly without tinting nearby blocks.
- [ ] Swim below an open surface at noon: shafts appear; a solid roof blocks sunlight. Check near and beyond shadow distance.
- [ ] No underwater sunlight at night, with shadows disabled, or in the End.
- [ ] Nether amber and soul-biome teal remain readable; End sky is violet/pearl. Check water/glass reflections there too.
- [ ] Torches, soul torches and sea lanterns work in each hand; empty hands emit no light. Check interaction with dynamic-light mods.
- [ ] Check full, quarter, crescent and new moon with `/time set 18000`, `/time set 42000`, `/time set 66000`, `/time set 90000`, and `/time set 114000`.
- [ ] Observe a clear night for several minutes for occasional meteors; daytime and rain suppress them.
- [ ] Vanilla textures look unchanged with Material Format Off; oldPBR and LabPBR test packs show correctly oriented relief and roughness-dependent shine on terrain and glass.
- [ ] LabPBR specular alpha 255 stays non-emissive; metallic materials use albedo-tinted reflections.
- [ ] Switch dimensions and presets repeatedly; resize the window, reload the pack and inspect transparent/cutout edges.
- [ ] Build a stained-glass roof and colored panes above white blocks: direct sunlight takes the glass color; opaque roofs and tinted glass block it.
- [ ] Check colored transmission on water caustics and underwater shafts. Stacked panes use the closest shadow layer.
- [ ] Compare wisps and volumetric clouds at noon/sunset; fly below, through and above Y174–236. Terrain in front of the cloud layer must remain visible.
- [ ] Compare foliage in clear weather and rain; plant roots and matching shadows remain attached during gusts.
- [ ] Inspect source water, flowing edges, waterfalls, shorelines and waterlogged blocks. Small geometric waves must not open visible seams; disable Surface Motion where needed.
- [ ] Put warm lanterns, soul lanterns and froglights beside a pale floor: visible sources spread different colors. Check occlusion, then move each source off-screen to confirm fallback lighting remains readable.
- [ ] Enable TAA, stand still, pan, sprint, switch dimensions and resize. Check thin grass, hand items, moving mobs, waves and sky for trails, shimmer or stale frames.
- [ ] Toggle TAA off and compare FXAA. First frames, empty history and newly revealed surfaces should not blend with unrelated old colors.
- [ ] Photo mode: focus on a near object, then a distant one; switch to manual focus. Focused edges should remain sharp, and cinematic bars must disappear when Photo Mode is off.

Handheld lighting is intentionally unshadowed and may reach through nearby walls.
Reflections use only visible geometry; puddles are surface shading, not fluid blocks.
Underwater shafts use the directional shadow map rather than a full water-volume simulation.

## Reproducible screenshots

Capture the same camera position, view direction, FOV, resolution, render distance,
weather, time, resource pack and color style for each quality preset. Wait for
chunks, exposure and weather to settle. Use F1 to hide the HUD and F2 to capture.
Do not compare captures taken from different positions or after changing textures.

Place actual captures in `docs/screenshots/` with names
`<scene>-<preset>.png`, where preset is `performance`, `balanced`, or `dream`.
Open `docs/showcase.html` to compare them. Empty slots are explicitly marked as
uncaptured; the project does not include fabricated Minecraft screenshots.

| Scene | Suggested setup | What to show |
|---|---|---|
| noon | Plains lake, `/time set 6000`, clear | Water, greenery, clouds, shadows |
| sunset | Same lake, `/time set 12000` | Pastel horizon, reflection, bloom |
| rain | Exposed stone/plains, rain then clear | Puddle coverage and drying |
| underwater | Shallow lake, `/time set 6000` | Caustics, bubbles, light shafts |
| cave | Fixed dark room, torch in one hand | Held light and exposure |
| nether | Nether wastes and nearby soul valley | Amber/teal air and lighting |
| end | Island edge | Pearl sky, terrain readability |

## FPS measurement

Disable VSync and FPS caps for benchmarking. Use the same world, location,
resolution, FOV, render/simulation distances, resource pack and GPU power settings.
Warm up for 60 seconds after changing presets, then record at least 60 seconds of
frame times without moving. Repeat three times per scene and preset. A profiler
or frame-time capture tool is needed for meaningful averages and 1% lows; the F3
instantaneous FPS display alone is not an average.

Convert frame times with `python tools/benchmark.py capture.csv --column ms`.
The selected column must contain milliseconds per frame. The report computes
average FPS from total frame time and a 1% low from the slowest 1% of frame times.
Keep raw captures with the results. Report GPU, CPU, RAM, resolution, Minecraft,
loader/driver versions and settings alongside every published number.

| Hardware / versions | Resolution / distance | Scene | Preset | Average FPS | 1% low FPS |
|---|---|---|---|---|---|
| Not measured | Not recorded | Pending | Performance | — | — |
| Not measured | Not recorded | Pending | Balanced | — | — |
| Not measured | Not recorded | Pending | Dream | — | — |
