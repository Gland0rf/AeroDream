#ifndef AERO_UNDERWATER_GLSL
#define AERO_UNDERWATER_GLSL

#include "/lib/shadows.glsl"

vec3 aeroUnderwaterRays(vec3 ray, float maxDistance, vec3 sunDir) {
#if SHADOW_QUALITY > 0 && AERO_DIMENSION == 0
    if (UNDERWATER_RAYS < 0.001 || sunDir.y < 0.02 || aeroOverworld() < 0.5) return vec3(0.0);
    float marchDistance = min(maxDistance, 30.0);
    float stepLength = marchDistance / float(UNDERWATER_RAY_SAMPLES);
    float jitter = aeroHash(floor(gl_FragCoord.xy));
    vec3 light = vec3(0.0);
    for (int i = 0; i < UNDERWATER_RAY_SAMPLES; i++) {
        float t = (float(i) + 0.25 + jitter * 0.5) * stepLength;
        vec3 playerPos = ray * t;
        vec4 clip = shadowProjection * shadowModelView * vec4(playerPos, 1.0);
        vec3 shadowUV = clip.xyz / max(clip.w, 0.00001) * 0.5 + 0.5;
        if (any(lessThanEqual(shadowUV, vec3(0.003))) ||
            any(greaterThanEqual(shadowUV, vec3(0.997)))) continue;
        vec3 visible = aeroShadowSample(shadowUV, 0.0007);
        float caustic = aeroCausticPattern((playerPos + cameraPosition).xz, frameTimeCounter);
        light += visible * (0.65 + 0.35 * caustic) * exp(-t * 0.085) * stepLength;
    }
    float forwardScatter = 0.25 + 0.75 * pow(max(dot(ray, sunDir), 0.0), 6.0);
    return vec3(0.16, 0.59, 0.67) * light * 0.035 * forwardScatter
         * UNDERWATER_RAYS * smoothstep(0.02, 0.30, sunDir.y) * (1.0 - rainStrength * 0.85);
#else
    return vec3(0.0);
#endif
}

#endif
