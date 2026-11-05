#ifndef AERO_CAUSTICS_GLSL
#define AERO_CAUSTICS_GLSL

// Smooth, world-locked overlapping wavefronts. Used both through the surface
// and while the camera itself is submerged, avoiding a screen-space pattern.
float aeroCausticPattern(vec2 worldXZ, float time) {
    vec2 p = worldXZ * 0.83;
    p += vec2(time * 0.13, -time * 0.075);
    vec2 warp = vec2(sin(p.y * 1.82 + time * 0.63),
                     cos(p.x * 1.59 - time * 0.59)) * 0.28;
    p += warp;
    float a = sin(p.x * 2.61 + sin(p.y * 1.35))
            * sin(p.y * 2.27 - cos(p.x * 1.19));
    float b = sin(p.x * 3.28 + p.y * 0.63 - time * 0.35)
            * sin(p.y * 2.82 - p.x * 0.37 + time * 0.27);
    float threadA = pow(1.0 - abs(a), 12.0);
    float threadB = pow(1.0 - abs(b), 16.0);
    return clamp((threadA * 0.72 + threadB * 0.36) * 1.65, 0.0, 1.0);
}

#endif
