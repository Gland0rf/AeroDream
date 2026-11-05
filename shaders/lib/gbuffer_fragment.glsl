#include "/lib/common.glsl"
#include "/lib/caustics.glsl"

uniform sampler2D gtexture;
uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float wetness;
uniform int isEyeInWater;
#ifdef IS_IRIS
uniform bool hasSkylight;
#endif

in vec2 vUV;
in vec2 vLM;
in vec4 vColor;
in vec3 vNormal;
in vec3 vWorldPos;
in vec3 vViewPos;
flat in int vMaterial;

#ifndef AERO_ALPHA_CUTOFF
#define AERO_ALPHA_CUTOFF 0.10
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 fragColor;

float aeroShadow(vec3 playerPos, vec3 N, vec3 L) {
#if SHADOW_QUALITY == 0
    return 1.0;
#else
    vec3 offsetPos = playerPos + N * 0.035 + L * 0.06;
    vec4 clip = shadowProjection * shadowModelView * vec4(offsetPos, 1.0);
    vec3 sc = (clip.xyz / max(clip.w, 0.0001)) * 0.5 + 0.5;
    if (min(min(sc.x, sc.y), sc.z) <= 0.001 || max(max(sc.x, sc.y), sc.z) >= 0.999) return 1.0;
    float bias = mix(0.00024, 0.00135, 1.0 - max(dot(N, L), 0.0));
#if SHADOW_QUALITY == 1
    return step(sc.z - bias, texture(shadowtex0, sc.xy).r);
#else
    float vis = 0.0;
    float spread = 1.35 / float(shadowMapResolution);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y)) * spread;
            vis += step(sc.z - bias, texture(shadowtex0, sc.xy + offset).r);
        }
    }
    return vis / 9.0;
#endif
#endif
}

void main() {
    vec4 texel = texture(gtexture, vUV) * vColor;
    bool grassBlade = vMaterial == 10010 || vMaterial == 10018 || vMaterial == 10019;
    bool foliage = vMaterial == 10011;
    bool flora = grassBlade || foliage || vMaterial == 10017 || vMaterial == 10015;
    bool turf = vMaterial == 10012;
    bool polished = vMaterial == 10020;
    bool icy = vMaterial == 10014;
    bool snow = vMaterial == 10023;

    // Separate cutout program has 0.50 alpha by default. The explicit foliage
    // test also fixes OptiFine/older fallbacks and makes blade outlines crisp.
    float cutoff = AERO_ALPHA_CUTOFF;
    if (flora) cutoff = max(cutoff, 0.50);
    if (texel.a < cutoff) discard;

    vec3 N = normalize(vNormal);
    vec3 L = aeroSunDir();
    vec3 V = normalize(-vViewPos);
    float day = smoothstep(-0.14, 0.24, L.y);
    float skyLight = aeroSat((vLM.y - 0.03125) / 0.9375);
    float blockLight = aeroSat((vLM.x - 0.03125) / 0.9375);
    float ndl = max(dot(N, L), 0.0);
    float shadow = 1.0;
#if SHADOW_QUALITY > 0
    if (day > 0.01 && skyLight > 0.10 && ndl > 0.005) {
        shadow = aeroShadow(vWorldPos, N, L);
    }
#endif

    // Crossed grass planes cannot be treated as fully opaque walls. Gentle
    // diffuse wrap and transmitted sunlight make the tuft readable on both
    // sides without artificially recoloring its biome-specific pixels.
    float diffuse = mix(ndl, aeroSat(ndl * 0.70 + 0.30), flora ? 0.68 : 0.06);
    float reverseSun = max(dot(-N, L), 0.0);
    float transmitted = flora ? reverseSun * FOLIAGE_TRANSLUCENCY * 0.31 : 0.0;

    vec3 nightAmbient = vec3(0.10, 0.15, 0.26) * NIGHT_BRIGHTNESS;
    vec3 blueAmbient = aeroPalette(vec3(0.57, 0.71, 0.86),
                                   vec3(0.52, 0.78, 0.91),
                                   vec3(0.66, 0.76, 0.88));
    float skyFill = mix(0.32, 1.0, skyLight);
    vec3 ambient = mix(nightAmbient, blueAmbient, day) * skyFill;
    if (flora || turf) ambient += vec3(0.011, 0.022, 0.006) * skyLight * day;

    // Cloud shadow is a moving *lighting* mask, never a black texture over
    // the block: ambient light and colorful biome tint remain visible.
    float cloudShade = 1.0;
#ifdef AERO_CLOUD_SHADOWS
    if (day > 0.10 && skyLight > 0.30 && ndl > 0.01 &&
        (vWorldPos.y + cameraPosition.y) < 204.5) {
        float cloudPlane = max((205.0 - (vWorldPos.y + cameraPosition.y)) /
                               max(L.y, 0.12), 0.0);
        vec2 cloudXZ = (vWorldPos + cameraPosition).xz + L.xz * cloudPlane;
        float cover = aeroCloudCoverage(cloudXZ, frameTimeCounter);
        cloudShade = 1.0 - cover * CLOUD_SHADOW_STRENGTH * 0.42
                   * (1.0 - rainStrength * 0.70);
    }
#endif

    vec3 directSun = mix(vec3(1.0, 0.52, 0.30), vec3(1.0, 0.98, 0.84), smoothstep(0.02, 0.42, L.y));
    float sunVisibility = shadow;
    // Blades need some light from the opposite face even when their physical
    // shadow normal points away from the sun.
    if (flora && ndl < 0.005) {
        sunVisibility = 0.68;
    }
    vec3 sunlight = directSun * (diffuse + transmitted) * (0.82 * skyLight)
                  * sunVisibility * cloudShade * day * (1.0 - rainStrength * 0.48);
    // Moonlight is a soft directional accent, not a second noon sun.
    float night = 1.0 - day;
    float moonFacing = max(dot(N, -L), 0.0);
    vec3 moonLight = vec3(0.12, 0.19, 0.32) * (0.30 + 0.70 * moonFacing)
                   * skyLight * night * NIGHT_BRIGHTNESS;
#ifdef IS_IRIS
    moonLight *= hasSkylight ? 1.0 : 0.0;
#endif
    vec3 lampLight = vec3(1.0, 0.72, 0.46) * pow(blockLight, 2.25) * 0.77;

    vec3 base = aeroFreshGreen(texel.rgb, float(vMaterial));
    vec3 rgb = base * (ambient + sunlight + moonLight + lampLight);
    // Snow keeps a clean icy-blue ambient tint; highlights stay white.
    if (snow && CRYSTAL_ICE > 0.001) {
        float air = skyLight * (0.55 + 0.45 * day);
        rgb += base * vec3(0.007, 0.040, 0.095) * air * CRYSTAL_ICE;
    }

    // Post-rain gloss: only surfaces open to the sky, mostly upward facing.
    // Material sheen also helps polished stone and ice when the world is dry.
    float exposed = smoothstep(0.14, 0.78, skyLight);
    float upward = smoothstep(-0.13, 0.78, N.y);
    float wetSurface = wetness * WET_GLOSS * exposed * upward;
    wetSurface *= flora ? 0.24 : 1.0;
    if (isEyeInWater != 0) wetSurface = 0.0;
    float materialShine = SURFACE_SHEEN * (polished ? 0.36 : (icy ? 0.50 : 0.0));
    materialShine += foliage ? FOLIAGE_TRANSLUCENCY * 0.025 : 0.0;
    if (wetSurface > 0.001) {
        // Wet stone is slightly darker, with concentrated clean sky highlights.
        rgb *= 1.0 - min(wetSurface * 0.11, 0.18);
        float edgeFresnel = pow(1.0 - aeroSat(dot(N, V)), 4.0);
        rgb += vec3(0.17, 0.34, 0.52) * edgeFresnel * wetSurface * 0.20
             * day * exposed;
    }
    vec3 microN = N;
    if (wetSurface > 0.001 && upward > 0.1) {
        vec2 p = (vWorldPos + cameraPosition).xz;
        float dropletA = sin(p.x * 4.70 + frameTimeCounter * 0.81);
        float dropletB = cos(p.y * 5.10 - frameTimeCounter * 0.96);
        microN = normalize(N + vec3(dropletA, 0.0, dropletB)
                        * (wetSurface * 0.035));
    }
    float gloss = materialShine + wetSurface * 0.63;
    vec3 reflectedSun = reflect(-L, microN);
    float spec = pow(max(dot(reflectedSun, V), 0.0),
                     mix(62.0, 172.0, aeroSat(gloss)));
    rgb += directSun * spec * gloss * 1.50 * day * exposed * shadow * cloudShade;

    // Packed/blue ice can render in the opaque terrain pass. Keep its
    // pearlescent sheen here as well as in the translucent water/glass pass.
    if (icy && IRIDESCENCE > 0.001) {
        float grazing = pow(1.0 - aeroSat(dot(N, V)), 2.0);
        float phase = (1.0 - aeroSat(dot(N, V))) * 0.45
                    + dot((vWorldPos + cameraPosition).xz, vec2(0.023, 0.016));
        rgb += aeroThinFilm(phase) * IRIDESCENCE * SURFACE_SHEEN * grazing
             * (0.13 + 0.17 * skyLight);
    }

    // Small, world-locked glints on ice and snow; night lighting stays calm.
    if ((snow || icy) && day > 0.05 && skyLight > 0.25) {
        float strength = snow ? SNOW_SPARKLE : CRYSTAL_ICE * 0.67;
        vec3 absolute = vWorldPos + cameraPosition;
        vec2 cell = floor(absolute.xz * 3.7 + absolute.y * 1.8);
        float crystal = smoothstep(0.91, 0.995, aeroHash(cell + 49.2));
        float facet = pow(max(dot(reflect(-L, N), V), 0.0), 110.0);
        float glint = crystal * facet * strength * skyLight * day;
        rgb += vec3(0.66, 0.89, 1.00) * glint * 0.75;
    }

    // Sparse, position-anchored dew drops on sunny grass. Spatial hashing
    // prevents screen-space speckle from sticking to the camera during motion.
    if ((grassBlade || turf) && DEW_SPARKLE > 0.001 && day > 0.01) {
        vec3 world = vWorldPos + cameraPosition;
        vec2 cell = floor(world.xz * 5.5);
        float drop = smoothstep(0.925, 0.995, aeroHash(cell));
        vec2 scatter = vec2(aeroHash(cell + 19.17), aeroHash(cell + 87.39)) - 0.5;
        vec3 microNormal = normalize(N + vec3(scatter.x * 0.55, 0.18, scatter.y * 0.55));
        float glint = pow(max(dot(reflect(-L, microNormal), V), 0.0), 80.0);
        rgb += vec3(0.81, 0.97, 1.00) * drop * glint * DEW_SPARKLE
             * skyLight * day * shadow * cloudShade
             * (1.0 - rainStrength * 0.85) * (1.5 + 0.7 * aeroMorning());
    }

    if (vMaterial == 10016) rgb = max(rgb, base * 1.85);

    // Underwater camera: project the animated light net onto visible seabeds.
    // Above-water caustics are separately applied in gbuffers_water.fsh.
    if (isEyeInWater == 1 && CAUSTIC_STRENGTH > 0.001) {
        float caustic = aeroCausticPattern((vWorldPos + cameraPosition).xz,
                                           frameTimeCounter);
        float sunThroughWater = day * skyLight * max(N.y, 0.0) *
                                (1.0 - rainStrength * 0.70);
        rgb += (base * vec3(0.10, 0.31, 0.35) + vec3(0.015, 0.035, 0.040))
             * caustic * sunThroughWater * CAUSTIC_STRENGTH;
    }

    fragColor = vec4(max(rgb, vec3(0.0)), texel.a);
}
