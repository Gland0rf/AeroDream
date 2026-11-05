#version 330 compatibility
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/waterlife.glsl"

/*
const int colortex4Format = RGBA16F;
*/
/* RENDERTARGETS: 4 */
uniform sampler2D colortex0;
uniform float wetness;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
#ifdef IS_IRIS
uniform bool hasSkylight;
#endif
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;
layout(location = 0) out vec4 sceneOut;

vec3 aeroViewRay(vec2 uv) {
    vec4 view = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
    return normalize(view.xyz / max(abs(view.w), 0.0001));
}

vec3 aeroViewPosAt(vec2 uv, float z) {
    vec4 view = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
    return view.xyz / max(abs(view.w), 0.0001);
}

vec2 aeroSunScreen(vec3 sunDir, out float inFront) {
    vec3 sunView = mat3(gbufferModelView) * sunDir;
    vec4 projected = gbufferProjection * vec4(sunView * 100.0, 1.0);
    inFront = step(0.0001, projected.w);
    return projected.xy / max(abs(projected.w), 0.0001) * 0.5 + 0.5;
}

// Affordable screen-space light shafts through gaps in trees or hills.
float aeroSunBeams(vec2 uv, vec3 sunDir) {
    if (SUNRAY_STRENGTH < 0.001 || sunDir.y < -0.04) return 0.0;
    float inFront;
    vec2 sunScreen = aeroSunScreen(sunDir, inFront);
    if (inFront < 0.5 || any(lessThan(sunScreen, vec2(-0.13))) ||
        any(greaterThan(sunScreen, vec2(1.13)))) return 0.0;
    float amount = 0.0;
    float jitter = (aeroHash(floor(uv * vec2(viewWidth, viewHeight) * 0.39)) - 0.5) * 0.38;
    for (int i = 0; i < SUNRAY_SAMPLES; i++) {
        float f = (float(i) + 0.5 + jitter) / float(SUNRAY_SAMPLES);
        vec2 st = mix(uv, sunScreen, clamp(f * 0.97, 0.0, 1.0));
        if (any(lessThanEqual(st, vec2(0.002))) ||
            any(greaterThanEqual(st, vec2(0.998)))) continue;
        float sky = step(0.99995, texture(depthtex0, st).r);
        amount += sky * (1.0 - f * 0.66);
    }
    float dist = length((sunScreen - uv) * vec2(viewWidth / viewHeight, 1.0));
    return amount / float(SUNRAY_SAMPLES) * exp(-dist * 2.65)
         * SUNRAY_STRENGTH * smoothstep(-0.04, 0.23, sunDir.y)
         * (1.0 - rainStrength * 0.90);
}

// Small early-2000s lens flare ghosts. Disabled behind terrain by sampling
// the sun pixel's depth, rather than drawing flares through roofs.
vec3 aeroLensFlare(vec2 uv, vec3 sunDir) {
    if (LENS_FLARE_STRENGTH < 0.001 || sunDir.y < 0.02) return vec3(0.0);
    float inFront;
    vec2 sunUV = aeroSunScreen(sunDir, inFront);
    if (inFront < 0.5 || any(lessThan(sunUV, vec2(0.01))) ||
        any(greaterThan(sunUV, vec2(0.99)))) return vec3(0.0);
    float visible = step(0.99995, texture(depthtex0, sunUV).r);
    if (visible < 0.5) return vec3(0.0);
    vec2 aspect = vec2(viewWidth / viewHeight, 1.0);
    vec2 fromCenter = sunUV - vec2(0.5);
    vec2 ghostA = vec2(0.5) - fromCenter * 0.72;
    vec2 ghostB = vec2(0.5) + fromCenter * 0.27;
    vec2 ghostC = vec2(0.5) - fromCenter * 0.22;
    vec2 dSun = (uv - sunUV) * aspect;
    vec2 dA = (uv - ghostA) * aspect;
    vec2 dB = (uv - ghostB) * aspect;
    vec2 dC = (uv - ghostC) * aspect;
    float sunHalo = exp(-dot(dSun, dSun) * 510.0) * 0.13;
    float blueGhost = exp(-dot(dA, dA) * 2200.0) * 0.25;
    float peachGhost = exp(-dot(dB, dB) * 900.0) * 0.11;
    float paleGhost = exp(-dot(dC, dC) * 3400.0) * 0.12;
    vec3 flare = vec3(1.0, 0.93, 0.79) * sunHalo
               + vec3(0.34, 0.88, 1.0) * blueGhost
               + vec3(1.0, 0.69, 0.79) * peachGhost
               + vec3(0.79, 0.95, 1.0) * paleGhost;
    return flare * LENS_FLARE_STRENGTH * smoothstep(0.02, 0.28, sunDir.y)
         * (1.0 - rainStrength * 0.97);
}

// A very restrained optional night-only ribbon, restricted to sky pixels.
vec3 aeroAurora(vec3 ray) {
#ifdef AERO_AURORA
    if (ray.y < 0.12 || aeroSunDir().y > -0.17 || rainStrength > 0.73) return vec3(0.0);
    float horizonBand = smoothstep(0.15, 0.43, ray.y)
                      * (1.0 - smoothstep(0.65, 0.89, ray.y));
    float shifted = atan(ray.z, ray.x) * 3.5 + frameTimeCounter * 0.036;
    float curtain = pow(0.5 + 0.5 * sin(shifted * 2.0
                    + sin(ray.y * 17.0 + frameTimeCounter * 0.07) * 1.65), 5.0);
    float fine = aeroNoise(vec2(shifted * 0.55, ray.y * 14.0));
    float intensity = horizonBand * curtain * (0.42 + 0.58 * fine)
                    * (1.0 - rainStrength) * AURORA_STRENGTH;
    return mix(vec3(0.08, 0.46, 0.68), vec3(0.22, 0.75, 0.57),
               smoothstep(0.2, 0.8, ray.y)) * intensity * 0.55;
#else
    return vec3(0.0);
#endif
}

void main() {
    vec2 uv = texcoord;
    float depth = texture(depthtex0, uv).r;
    vec3 source = max(texture(colortex0, uv).rgb, vec3(0.0));
    vec3 rayView = aeroViewRay(uv);
    vec3 rayWorld = normalize(mat3(gbufferModelViewInverse) * rayView);
    vec3 sunDir = aeroSunDir();
    // Prevent dimension-specific skies from being forced blue in Nether/End.
    // Iris exposes the actual dimension skylight flag. This preserves a
    // vivid blue midnight sky WITHOUT painting the Nether/End bright cyan.
#ifdef IS_IRIS
    float overworldSky = hasSkylight ? 1.0 : 0.0;
#else
    // OptiFine best-effort fallback (does not expose hasSkylight).
    float overworldSky = smoothstep(0.055, 0.14, skyColor.b)
                       * (1.0 - smoothstep(0.16, 0.36, skyColor.r - skyColor.b));
#endif
    float isSky = step(0.99999, depth);
    vec3 scene = source;
    // Do not evaluate two expensive cloud FBM layers for every ground pixel.
    if (isSky > 0.5 && overworldSky > 0.001) {
        scene = mix(scene, aeroSky(rayWorld, sunDir, frameTimeCounter), overworldSky);
        if (isEyeInWater == 0) {
            scene += aeroAfterRainRainbow(rayWorld, sunDir, wetness) * overworldSky;
            scene += aeroAurora(rayWorld) * overworldSky;
        }
    }

    if (depth < 0.99999) {
        vec3 pos = aeroViewPosAt(uv, depth);
        float distanceToCamera = length(pos);
        float fogFactor = 1.0 - exp(-pow(distanceToCamera / 150.0, 1.50) * FOG_STRENGTH);
        fogFactor *= (0.88 + rainStrength * 0.55);
        if (fogFactor > 0.001) {
            vec3 fogTint = fogColor;
            if (overworldSky > 0.001) {
                vec3 horizon = aeroSky(normalize(vec3(rayWorld.x, 0.045, rayWorld.z)),
                                       sunDir, frameTimeCounter);
                fogTint = mix(fogTint, horizon, 0.78 * overworldSky);
            }
            fogTint = mix(fogTint, vec3(0.24, 0.43, 0.69),
                          aeroBlueHour() * overworldSky * 0.26);
            scene = mix(scene, fogTint, aeroSat(fogFactor));
        }
        // Thin dawn mist hangs just above distant fields and lakes, never
        // washing out close blocks or entire caves.
        if (overworldSky > 0.001 && isEyeInWater == 0 && MORNING_MIST > 0.001) {
            float timeMask = aeroMorning() * smoothstep(-0.03, 0.18, sunDir.y);
            float lowAngle = 1.0 - smoothstep(0.12, 0.65, abs(rayWorld.y));
            float distant = smoothstep(22.0, 125.0, distanceToCamera);
            float mist = MORNING_MIST * timeMask * lowAngle * distant * 0.43;
            scene = mix(scene, vec3(0.66, 0.85, 0.93), aeroSat(mist));
        }
    }

    if (isEyeInWater == 1) {
        float underDist = depth < 0.99999 ? length(aeroViewPosAt(uv, depth)) : 130.0;
        float fog = 1.0 - exp(-underDist * 0.055);
        vec3 aquaticTint = aeroPalette(vec3(0.56, 0.88, 1.05),
                                        vec3(0.49, 1.02, 0.98),
                                        vec3(0.66, 0.91, 1.04));
        scene = mix(scene * aquaticTint, vec3(0.012, 0.22, 0.40), fog * 0.91);
        // Transparent bubble outlines appear only when the camera is submerged
        // and only in front of actual scene geometry.
        scene += aeroUnderwaterBubbles(rayWorld, cameraPosition, underDist,
                                      frameTimeCounter);
    } else if (isEyeInWater == 2) {
        scene = mix(scene, vec3(0.92, 0.22, 0.02), 0.73);
    } else if (isEyeInWater == 3) {
        scene = mix(scene, vec3(0.79, 0.87, 0.92), 0.66);
    }

    // Dual-pass half-resolution bloom smooths lamps, water sparkles and sunshine.
    vec3 bloom = max(texture(colortex6, uv).rgb, vec3(0.0));
    scene += bloom * BLOOM_STRENGTH * 0.86;
    if (isEyeInWater == 0 && overworldSky > 0.001) {
        float sunBeams = aeroSunBeams(uv, sunDir) * overworldSky;
        scene += vec3(1.0, 0.94, 0.78) * sunBeams * 0.36;
        scene += aeroLensFlare(uv, sunDir) * overworldSky;
    }

    // A lightweight four-direction depth test adds subtle contact shadows
    // where foreground geometry overlaps nearby surfaces. No screen-wide blur.
    if (AO_STRENGTH > 0.001 && depth < 0.9999 && isEyeInWater == 0) {
        vec3 center = aeroViewPosAt(uv, depth);
        float ao = 0.0;
        vec2 pixel = 2.5 / vec2(viewWidth, viewHeight);
        for (int i = 0; i < 4; i++) {
            vec2 offsetUV = i == 0 ? vec2(pixel.x, 0.0) :
                            i == 1 ? vec2(-pixel.x, 0.0) :
                            i == 2 ? vec2(0.0, pixel.y) : vec2(0.0, -pixel.y);
            vec2 probe = clamp(uv + offsetUV, vec2(0.001), vec2(0.999));
            float otherDepth = texture(depthtex0, probe).r;
            if (otherDepth > 0.9999) continue;
            vec3 other = aeroViewPosAt(probe, otherDepth);
            float closer = other.z - center.z;
            ao += smoothstep(0.07, 0.72, closer) *
                  (1.0 - smoothstep(0.5, 3.3, length(other - center)));
        }
        scene *= 1.0 - AO_STRENGTH * ao * 0.070;
    }

    // eyeBrightnessSmooth is already filtered by the game. A subtle exposure
    // lift in caves avoids hard flashes and does not wash out daylight.
    float availableLight = clamp(max(float(eyeBrightnessSmooth.y),
                                     float(eyeBrightnessSmooth.x) * 0.60)
                                 / 240.0, 0.0, 1.0);
    float cave = 1.0 - smoothstep(0.10, 0.76, availableLight);
    float exposure = 1.0 + 0.23 * cave * EXPOSURE_ADAPT;

    // HDR clean scene gets anti-aliased in final.fsh AFTER all sky/atmosphere
    // effects, so the sky/terrain silhouette is treated consistently.
    sceneOut = vec4(max(scene * (1.04 * exposure), vec3(0.0)), 1.0);
}
