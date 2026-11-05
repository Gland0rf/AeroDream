#version 330 compatibility
#include "/lib/common.glsl"
#include "/lib/caustics.glsl"
#include "/lib/waterlife.glsl"

uniform sampler2D gtexture;
uniform sampler2D colortex5; // Opaque scene snapshot (deferred stage).
uniform sampler2D depthtex1; // Opaque-only scene depth.
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform float viewWidth;
uniform float viewHeight;
uniform float wetness;
uniform sampler2D shadowtex0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform int isEyeInWater;

in vec2 vUV;
in vec2 vLM;
in vec4 vColor;
in vec3 vNormal;
in vec3 vWorldPos;
in vec3 vViewPos;
flat in int vMaterial;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 fragColor;

vec3 fromScreen(vec2 uv, float depth) {
    vec4 h = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return h.xyz / max(abs(h.w), 0.0001);
}

vec2 toScreen(vec3 viewPos) {
    vec4 h = gbufferProjection * vec4(viewPos, 1.0);
    return h.xy / max(h.w, 0.0001) * 0.5 + 0.5;
}

// Animated, organic normals with three spatial frequencies.
vec3 aeroWaterNormal(vec2 p, float time) {
    float a = p.x * 0.68 + p.y * 0.49 + time * 1.15;
    float b = p.x * 1.57 - p.y * 1.34 - time * 1.72;
    float c = (p.x + p.y) * 3.10 + time * 2.15;
    vec2 grad = vec2(0.68, 0.49) * cos(a) * 0.095;
    grad += vec2(1.57, -1.34) * cos(b) * 0.029;
    grad += vec2(3.10) * cos(c) * 0.0065;
    grad *= WATER_WAVES;
    return normalize(vec3(-grad.x, 1.0, -grad.y));
}

// Reflections of visible geometry, with analytic sky used as a fallback.
vec4 aeroTraceReflection(vec3 origin, vec3 dir) {
    vec3 rayPos = origin + dir * 0.32;
    float t = 0.32;
    for (int i = 0; i < REFLECTION_STEPS; i++) {
        t += 0.36 + float(i) * 0.13;
        rayPos = origin + dir * t;
        if (rayPos.z > -0.06) break;
        vec2 uv = toScreen(rayPos);
        if (any(lessThanEqual(uv, vec2(0.012))) || any(greaterThanEqual(uv, vec2(0.988)))) break;
        float depth = texture(depthtex1, uv).r;
        if (depth > 0.9999) continue;
        vec3 scenePos = fromScreen(uv, depth);
        // The marched ray should cross a visible surface, not one behind it by miles.
        float separation = length(rayPos - scenePos);
        if (rayPos.z < scenePos.z - 0.07 && separation < 1.3 + t * 0.065) {
            vec3 scene = texture(colortex5, uv).rgb;
            float border = smoothstep(0.012, 0.17, min(min(uv.x, uv.y), min(1.0-uv.x, 1.0-uv.y)));
            float fade = border * (1.0 - smoothstep(22.0, 55.0, t));
            return vec4(scene, fade);
        }
    }
    return vec4(0.0);
}

// Minimal shadow check for caustics on the seabed (water itself does not
// cast an opaque shadow in AeroDream).
float aeroCausticSunVisibility(vec3 playerPos) {
#if SHADOW_QUALITY == 0
    return 1.0;
#else
    vec4 shadowClip = shadowProjection * shadowModelView
                    * vec4(playerPos + vec3(0.0, 0.065, 0.0), 1.0);
    vec3 screen = shadowClip.xyz / max(shadowClip.w, 0.0001) * 0.5 + 0.5;
    if (any(lessThanEqual(screen, vec3(0.003))) ||
        any(greaterThanEqual(screen, vec3(0.997)))) return 1.0;
    return step(screen.z - 0.0007, texture(shadowtex0, screen.xy).r);
#endif
}

void main() {
    vec4 texel = texture(gtexture, vUV) * vColor;
    if (texel.a < 0.02) discard;

    vec3 sunDir = aeroSunDir();
    vec3 V = normalize(-vViewPos);
    vec3 worldView = normalize(mat3(gbufferModelViewInverse) * V);
    vec3 faceNormal = normalize(vNormal);
    vec2 worldXZ = (vWorldPos + cameraPosition).xz;

    if (vMaterial == 10001) {
        float cascade = 1.0 - smoothstep(0.28, 0.80, abs(faceNormal.y));
        // Horizontal water has rolling normals; vertical faces get down-flow
        // normals instead, avoiding horizontal-mirror waterfalls.
        vec3 surfaceN = aeroWaterNormal(worldXZ, frameTimeCounter);
        vec3 flowN = normalize(faceNormal + vec3(
            sin((vWorldPos.y + cameraPosition.y) * 5.0
                - frameTimeCounter * 5.6 + worldXZ.x * 3.1) * 0.065,
            0.0,
            cos((vWorldPos.y + cameraPosition.y) * 5.6
                - frameTimeCounter * 6.7 + worldXZ.y * 3.6) * 0.055) * WATER_WAVES);
        vec3 N = normalize(mix(surfaceN, flowN, cascade));
        float rainRings = 0.0;
#ifdef AERO_RAIN_RIPPLES
        if (rainStrength > 0.001 && cascade < 0.90 && RAIN_RING_STRENGTH > 0.001) {
            vec2 rainSlope;
            rainRings = aeroRainRings(worldXZ, frameTimeCounter, rainSlope)
                      * rainStrength * (1.0 - cascade) * RAIN_RING_STRENGTH;
            N = normalize(N + vec3(rainSlope.x, 0.0, rainSlope.y)
                        * rainStrength * (1.0 - cascade) * RAIN_RING_STRENGTH);
        }
#endif
        if (dot(N, worldView) < 0.0) N = -N;
        vec3 nView = normalize(mat3(gbufferModelView) * N);
        vec2 screen = gl_FragCoord.xy / vec2(viewWidth, viewHeight);

        float rawDepth = texture(depthtex1, screen).r;
        float thickness = rawDepth > 0.9999 ? 30.0 : length(fromScreen(screen, rawDepth) - vViewPos);
        thickness = clamp(thickness, 0.0, 45.0);
        // A waterfall face has no horizontal water column. Don't interpret
        // the background distance behind it as an infinitely deep ocean.
        thickness = mix(thickness, min(thickness, 5.0), cascade);
        // Vertical depth below the water surface; unlike ray length it
        // doesn't change color just because the camera looks sideways.
        float verticalDepth = 30.0;
        if (rawDepth < 0.9999) {
            vec3 floorPlayer = (gbufferModelViewInverse *
                 vec4(fromScreen(screen, rawDepth), 1.0)).xyz;
            verticalDepth = max(vWorldPos.y - floorPlayer.y, 0.0);
        }

        vec2 offset = nView.xy * 0.020 * (1.0 - exp(-thickness * 0.30));
        vec2 refrUV = screen;
#ifdef AERO_REFRACTION
        refrUV = clamp(screen + offset, vec2(0.002), vec2(0.998));
        if (texture(depthtex1, refrUV).r < gl_FragCoord.z - 0.0001) refrUV = screen;
#endif
        vec3 scene = texture(colortex5, refrUV).rgb;

        // Real lakebed caustics while ABOVE water. This operates only where
        // visible opaque depth actually lies below a rendered water surface.
        float behindDepth = texture(depthtex1, refrUV).r;
        if (CAUSTIC_STRENGTH > 0.001 && behindDepth < 0.9999 &&
            sunDir.y > -0.035 && isEyeInWater == 0) {
            vec3 bottomView = fromScreen(refrUV, behindDepth);
            vec3 bottomPlayer = (gbufferModelViewInverse * vec4(bottomView, 1.0)).xyz;
            float waterColumn = max(vWorldPos.y - bottomPlayer.y, 0.0);
            if (waterColumn > 0.12 && waterColumn < 25.0) {
                float pattern = aeroCausticPattern((bottomPlayer + cameraPosition).xz,
                                                   frameTimeCounter);
                float depthFade = smoothstep(0.12, 0.80, waterColumn)
                                * (1.0 - smoothstep(8.0, 23.0, waterColumn));
                float sun = smoothstep(-0.035, 0.34, sunDir.y)
                          * (1.0 - rainStrength * 0.82);
                float shadow = aeroCausticSunVisibility(bottomPlayer);
                float intensity = pattern * depthFade * sun * shadow
                                * CAUSTIC_STRENGTH;
                scene += (vec3(0.055, 0.32, 0.36) + scene * vec3(0.12, 0.30, 0.31))
                       * intensity;
            }
        }

        verticalDepth = mix(verticalDepth, 0.75, cascade);
        vec3 waterShallow = aeroPalette(vec3(0.075, 0.70, 0.89),
                                        vec3(0.045, 0.82, 0.82),
                                        vec3(0.27, 0.72, 0.88));
        vec3 coastAqua = aeroPalette(vec3(0.10, 0.82, 0.91),
                                     vec3(0.035, 0.94, 0.79),
                                     vec3(0.46, 0.86, 0.93));
        vec3 waterDeep = aeroPalette(vec3(0.011, 0.20, 0.47),
                                     vec3(0.010, 0.32, 0.51),
                                     vec3(0.055, 0.29, 0.52));
        float shallow = 1.0 - smoothstep(0.3, 5.0, verticalDepth);
        waterShallow = mix(waterShallow, coastAqua, shallow * SHORE_TURQUOISE);
        vec3 bodyColor = mix(waterShallow, waterDeep,
                             1.0 - exp(-verticalDepth * 0.14));
        vec3 absorption = exp(-thickness * vec3(0.072, 0.026, 0.013));
        float transmission = WATER_CLARITY * exp(-thickness * 0.20)
                           * (0.89 + shallow * SHORE_TURQUOISE * 0.11);
        vec3 transmitted = mix(bodyColor, scene * absorption * vec3(0.82, 1.02, 1.10), transmission);

        vec3 reflectedDir = normalize(reflect(-worldView, N));
        vec3 reflection = aeroSky(reflectedDir, sunDir, frameTimeCounter);
#ifdef AERO_REFLECTIONS
        vec3 reflViewDir = normalize(mat3(gbufferModelView) * reflectedDir);
        vec4 hit = aeroTraceReflection(vViewPos, reflViewDir);
        reflection = mix(reflection, hit.rgb, hit.a * 0.89);
#endif
        // Schlick Fresnel: transparent face-on; sky-blue mirror at low angles.
        float facing = aeroSat(dot(N, worldView));
        float fresnel = 0.055 + 0.945 * pow(1.0 - facing, 5.0);
        vec3 result = mix(transmitted, reflection, fresnel * 0.94);

        float glint = pow(max(dot(reflect(-sunDir, N), worldView), 0.0), 330.0);
        glint += pow(max(dot(reflect(-sunDir, N), worldView), 0.0), 70.0) * 0.12;
        float glimmer = 0.70 + 0.30 * aeroNoise(worldXZ * 2.4
                        + vec2(frameTimeCounter * 0.27, -frameTimeCounter * 0.18));
        result += vec3(1.0, 0.95, 0.77) * glint * 3.3 * glimmer
                * smoothstep(-0.1, 0.22, sunDir.y);
        // Aqua micro-glints accentuate the bright 2000s "glass water" look.
        float micro = pow(max(dot(reflect(-sunDir, N), worldView), 0.0), 110.0);
        result += vec3(0.58, 0.91, 1.0) * micro * glimmer * WATER_SPARKLE * 0.43
                * smoothstep(0.03, 0.32, sunDir.y);

        // Gentle translucent contact foam hugs terrain at the water edge;
        // two differently moving wave patterns break up rigid outlines.
        float edge = 1.0 - smoothstep(0.065, 0.89, thickness);
        float rippleA = sin(worldXZ.x * 4.2 + frameTimeCounter * 2.50)
                      * sin(worldXZ.y * 3.8 - frameTimeCounter * 1.90);
        float rippleB = aeroNoise(worldXZ * 4.10 +
                                 vec2(frameTimeCounter * 0.75, -frameTimeCounter * 0.41));
        float foamShape = smoothstep(0.22, 0.78, rippleA * 0.47 + rippleB * 0.68);
        float foam = edge * foamShape * SHORE_FOAM * 0.40;
        result = mix(result, vec3(0.88, 0.99, 1.0), foam * (1.0 - cascade));
        // The visible concentric bright ridges follow the refracted normals.
        result += vec3(0.29, 0.75, 0.87) * rainRings * 0.15;
#ifdef AERO_WATERFALLS
        if (cascade > 0.001 && WATERFALL_MAGIC > 0.001) {
            vec3 absolute = vWorldPos + cameraPosition;
            float streaks = aeroCascadeFoam(absolute, frameTimeCounter);
            float churn = 0.13 + streaks * 0.52;
            float strength = cascade * WATERFALL_MAGIC;
            result = mix(result, vec3(0.48, 0.86, 0.96), strength * churn * 0.47);
            result += vec3(0.59, 0.91, 1.00) * streaks * strength * 0.20;
            // A very small white contact haze where the water curtain
            // intersects solid geometry. No invented spray particle geometry.
            float contactSpray = strength * edge * edge * 0.22;
            result = mix(result, vec3(0.84, 0.98, 1.00), contactSpray);
        }
#endif

        if (isEyeInWater == 1) result = mix(result, bodyColor, 0.12);
        // Color is already refracted and composited with the captured opaque scene.
        fragColor = vec4(max(result, vec3(0.0)), 1.0);
    } else {
        // Frosted ice and colored glass still use Minecraft's translucent
        // blending, avoiding fake opaque rectangles or layered mirror panes.
        vec3 N = faceNormal;
        if (dot(N, worldView) < 0.0) N = -N;
        float lighting = 0.56 + 0.52 * aeroSat(vLM.y) + 0.26 * aeroSat(vLM.x);
        vec3 rgb = texel.rgb * lighting;
        float alpha = texel.a;
        bool glass = vMaterial == 10013;
        bool darkGlass = vMaterial == 10022;
        bool ice = vMaterial == 10014;
        if (glass || darkGlass || ice) {
            vec3 reflected = normalize(reflect(-worldView, N));
            vec3 reflectedSky = aeroSky(reflected, sunDir, frameTimeCounter);
            float facing = aeroSat(dot(N, worldView));
            float fresnel = 0.028 + 0.64 * pow(1.0 - facing, 5.0);
            float sparkle = pow(max(dot(reflect(-sunDir, N), worldView), 0.0),
                                180.0) * smoothstep(-0.05, 0.30, sunDir.y);
            float strength = (glass || darkGlass ? GLASS_SHINE : SURFACE_SHEEN);
            vec3 reflectionTint = mix(vec3(0.63, 0.91, 1.0), reflectedSky, 0.72);
            rgb += reflectionTint * fresnel * strength * 0.55;
            rgb += vec3(1.0, 0.95, 0.84) * sparkle * strength * 0.95;
            if (IRIDESCENCE > 0.001 && !darkGlass) {
                float filmPhase = (1.0 - facing) * 0.48
                                + dot((vWorldPos + cameraPosition).xz,
                                      vec2(0.023, 0.016));
                float edgeFilm = pow(1.0 - facing, 2.0);
                rgb += aeroThinFilm(filmPhase) * IRIDESCENCE * strength
                     * edgeFilm * (glass ? 0.32 : 0.22);
            }
#ifdef AERO_GLASS_SSR
            if ((glass || ice) && fresnel > 0.045) {
                vec3 reflectView = normalize(mat3(gbufferModelView) * reflected);
                vec4 hit = aeroTraceReflection(vViewPos, reflectView);
                rgb = mix(rgb, hit.rgb, hit.a * fresnel * strength * 0.44);
            }
#endif
            if (ice && CRYSTAL_ICE > 0.001) {
                // Extra blue-white crystal facet, still translucent.
                rgb += vec3(0.18, 0.55, 0.79) * pow(1.0 - facing, 3.0)
                     * CRYSTAL_ICE * 0.19;
            }
            if (glass) {
                // Vanilla resource packs differ in alpha; avoid opaque panes.
                alpha = clamp(alpha, 0.16, 0.61);
            } else if (ice) {
                alpha = clamp(alpha, 0.24, 0.83);
            } else {
                // Tinted glass is deliberately dark and less transparent.
                rgb *= 0.59;
                alpha = max(alpha, 0.58);
            }
        }
        fragColor = vec4(max(rgb, vec3(0.0)), alpha);
    }
}
