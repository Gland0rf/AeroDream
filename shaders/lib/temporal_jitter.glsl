#ifndef AERO_TEMPORAL_JITTER_GLSL
#define AERO_TEMPORAL_JITTER_GLSL
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec2 aeroJitter(int frame, vec2 resolution) {
#if TAA_ENABLED == 1
    const vec2 sequence[8] = vec2[8](
        vec2(0.5, 0.333333), vec2(0.25, 0.666667), vec2(0.75, 0.111111), vec2(0.125, 0.444444),
        vec2(0.625, 0.777778), vec2(0.375, 0.222222), vec2(0.875, 0.555556), vec2(0.0625, 0.888889));
    return (sequence[frame % 8] - vec2(0.4453125, 0.5)) / max(resolution, vec2(1.0));
#else
    return vec2(0.0);
#endif
}

#endif
