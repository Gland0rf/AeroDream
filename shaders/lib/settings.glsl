#ifndef AERO_SETTINGS_GLSL
#define AERO_SETTINGS_GLSL

// AeroDream 1.4 - Windows Vista / Frutiger Aero-inspired world lighting.
// All user-editable options are collected here for Iris and OptiFine menus.

#define AERO_STYLE 0 // [0 1 2] Classic Aero, Tropical Aero, Soft Dream
#define BLUE_HOUR_STRENGTH 0.70 // [0.00 0.35 0.50 0.70 1.00] Velvety azure twilight
#define AURORA_STRENGTH 0.40 // [0.00 0.20 0.40 0.70 1.00] Optional subtle night curtains
#define BUBBLE_STRENGTH 0.60 // [0.00 0.30 0.60 0.85 1.00] Submerged iridescent bubbles
#define BUBBLE_QUALITY 2 // [0 2 4] Bubble layers sampled per pixel
#define RIPPLE_QUALITY 1 // [0 1 2] Off, 2x2, 3x3 rain ring grid
#define RAIN_RING_STRENGTH 0.65 // [0.00 0.35 0.65 0.85 1.00] Concentric rainfall rings
#define WATERFALL_MAGIC 0.70 // [0.00 0.35 0.50 0.70 1.00] Cascade foam and glossy flow
#define CRYSTAL_ICE 0.70 // [0.00 0.30 0.50 0.70 1.00] Ice clarity and chilly highlights
#define SNOW_SPARKLE 0.45 // [0.00 0.20 0.45 0.65 0.85] Tiny snow highlights

#define AERO_SATURATION 1.16 // [0.90 1.00 1.08 1.16 1.28 1.40] Clean, vibrant overall color
#define GREEN_VIBRANCE 1.40 // [1.00 1.15 1.25 1.40 1.55 1.75] Lush, biome-aware greens
#define FOLIAGE_TRANSLUCENCY 0.40 // [0.00 0.20 0.40 0.60 0.80] Backlit leaves and blades
#define WIND_STRENGTH 1.00 // [0.00 0.50 0.75 1.00 1.25 1.50] Rooted plant motion
#define DEW_SPARKLE 0.50 // [0.00 0.25 0.50 0.75 1.00] Morning grass glints
#define CLOUD_SHADOW_STRENGTH 0.65 // [0.00 0.35 0.65 1.00] Soft moving cloud shadows
#define MORNING_MIST 0.60 // [0.00 0.30 0.60 0.85 1.00] Early-morning blue mist

#define WATER_CLARITY 0.85 // [0.45 0.65 0.85 1.00] Visibility through shallow water
#define WATER_WAVES 1.00 // [0.00 0.50 1.00 1.50 2.00] Animated water normals
#define WATER_SPARKLE 0.60 // [0.00 0.25 0.40 0.60 0.90 1.20] Aqua water highlights
#define CAUSTIC_STRENGTH 0.75 // [0.00 0.30 0.50 0.75 1.00 1.25] Sunlight patterns on lakebeds
#define REFLECTION_STEPS 16 // [8 16 24] Water screen-space reflection steps
#define SHORE_TURQUOISE 0.85 // [0.00 0.45 0.65 0.85 1.00] Clear aqua shallows
#define SHORE_FOAM 0.70 // [0.00 0.35 0.50 0.70 1.00] Gentle wave contact foam

#define SKY_FRESHNESS 1.15 // [0.85 1.00 1.15 1.30] Azure/cyan sky intensity
#define CLOUD_DENSITY 0.65 // [0.25 0.45 0.65 0.85 1.00] Layered white cloud coverage
#define PASTEL_SUNSETS 0.85 // [0.00 0.45 0.70 0.85 1.15] Peach/pink/violet horizon
#define RAINBOW_STRENGTH 0.85 // [0.00 0.35 0.65 0.85 1.15] Optical rainbow after clearing rain
#define NIGHT_BRIGHTNESS 1.20 // [0.75 1.00 1.20 1.45] Cool moonlit outdoor ambiance
#define FOG_STRENGTH 0.85 // [0.00 0.40 0.65 0.85 1.20] Airy distant atmosphere

#define SHADOW_QUALITY 2 // [0 1 2] Disabled, hard, soft PCF shadows
#define BLOOM_STRENGTH 0.65 // [0.00 0.25 0.35 0.45 0.65 0.90 1.20] Bright glossy bloom
#define SUNRAY_STRENGTH 0.50 // [0.00 0.25 0.50 0.80] Screen-space sunshafts
#define SUNRAY_SAMPLES 12 // [8 12 18] Samples for sunbeams
#define GLASS_SHINE 0.70 // [0.00 0.35 0.70 1.00] Fresnel highlights on panes
#define SURFACE_SHEEN 0.50 // [0.00 0.25 0.50 0.75 1.00] Gloss on polished blocks/ice
#define WET_GLOSS 0.65 // [0.00 0.35 0.65 0.90 1.20] Rain-washed open-air surfaces
#define LENS_FLARE_STRENGTH 0.35 // [0.00 0.20 0.35 0.60] Subtle sun ghosts/halo
#define EXPOSURE_ADAPT 0.60 // [0.00 0.35 0.60 0.85] Gentle cave-aware exposure
#define IRIDESCENCE 0.40 // [0.00 0.20 0.40 0.60 0.80] Pearlescent glass and ice
#define FXAA_QUALITY 1 // [0 1 2] Off, fast, high quality anti-aliasing
#define AO_STRENGTH 0.25 // [0.00 0.15 0.25 0.40 0.60] Subtle contact shadows

#define AERO_WIND // Plant motion follows geometry into shadow pass
#define AERO_REFLECTIONS // Reflect visible geometry on water
#define AERO_REFRACTION // Gently distort what is below the waterline
#define AERO_CLOUDS // Wispy procedural high-altitude clouds
#define AERO_CLOUD_SHADOWS // Matching clouds shade sunlit landscapes
//#define AERO_AURORA // Peaceful nighttime blue-green auroras, off by default
#define AERO_WATERFALLS // Flowing water gets a distinct vertical-face treatment
//#define AERO_DOUBLE_RAINBOW // Secondary bow, visible after rain
//#define AERO_GLASS_SSR // Additional screen-space reflection on glass and ice
#define AERO_RAIN_RIPPLES // Tiny ripples during rainfall

const int shadowMapResolution = 2048; // [1024 1536 2048 3072] Directional shadow texture
const float shadowDistance = 112.0; // [64.0 96.0 112.0 160.0] Shadow draw distance
const float sunPathRotation = -30.0;
const float ambientOcclusionLevel = 0.72;
// The gloss hangs around briefly after the rain stops.
const float wetnessHalflife = 150.0;
const float drynessHalflife = 170.0;
// Smooths sky/block-light transitions when walking into a cave.
const float eyeBrightnessHalflife = 9.0;

#endif
