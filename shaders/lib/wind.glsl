#ifndef AERO_WIND_GLSL
#define AERO_WIND_GLSL

#include "/lib/settings.glsl"

// at_midBlock is the offset FROM the vertex TO the block centre, in 1/64 blocks.
// Using it means the *bottom* of a flower or tuft stays rooted, while its tip
// swings. Reused verbatim by the shadow pass, preventing detached silhouettes.
vec3 aeroWindOffset(int material, vec3 playerPos, vec3 cameraPos,
                    vec4 midBlock, float time) {
#ifdef AERO_WIND
    bool shortPlant = material == 10010 || material == 10017;
    bool leaf = material == 10011;
    bool waterPlant = material == 10015;
    bool tallLower = material == 10018;
    bool tallUpper = material == 10019;
    if (!(shortPlant || leaf || waterPlant || tallLower || tallUpper)) {
        return vec3(0.0);
    }

    // Each vertex is 0 at the base of its block and 1 at the top.
    float localHeight = clamp(0.5 - midBlock.y / 64.0, 0.0, 1.0);
    float height = localHeight;
    if (tallLower) height *= 0.5;
    if (tallUpper) height = 0.5 + 0.5 * height;
    float flex = smoothstep(0.0, 1.0, height);
    if (leaf) flex = 0.30 + 0.70 * flex;

    // Phase is constant across a plant (also across both halves of tall grass).
    vec3 blockCenter = playerPos + cameraPos + midBlock.xyz / 64.0;
    vec2 p = blockCenter.xz;
    float slow = sin(dot(p, vec2(0.72, 0.46)) + time * 1.15);
    float quick = sin(dot(p, vec2(-1.31, 1.17)) - time * 1.83);
    float gust = 0.79 + 0.21 * sin(time * 0.27 + dot(p, vec2(0.045, 0.063)));
    float sway = (slow * 0.70 + quick * 0.30) * gust;

    float amplitude = leaf ? 0.025 : (waterPlant ? 0.038 : (material == 10017 ? 0.047 : 0.083));
    amplitude *= WIND_STRENGTH;
    vec3 direction = vec3(sway, leaf ? quick * 0.18 : 0.0,
                          0.65 * slow - 0.21 * quick);
    return direction * (amplitude * flex);
#else
    return vec3(0.0);
#endif
}

#endif
