#ifndef AERO_WATERLIFE_GLSL
#define AERO_WATERLIFE_GLSL

// World-anchored concentric rainfall rings. Ripples have a short lifetime and
// fade in/out so the hash grid never looks like a repeating checkerboard.
float aeroRainRings(vec2 worldXZ, float time, out vec2 slope) {
    slope = vec2(0.0);
#if RIPPLE_QUALITY == 0
    return 0.0;
#else
    vec2 p = worldXZ * 1.65;
    vec2 origin = floor(p - vec2(0.5));
    float surface = 0.0;
    // Balanced: 2x2 raindrop field. Dream: 3x3 and more cross-cell detail.
#if RIPPLE_QUALITY == 1
    const int ringGrid = 2;
#else
    const int ringGrid = 3;
#endif
    for (int y = 0; y < ringGrid; y++) {
        for (int x = 0; x < ringGrid; x++) {
            vec2 id = origin + vec2(float(x), float(y));
            float seed = aeroHash(id + vec2(19.17, 7.61));
            float age = fract(time * (0.36 + 0.11 * seed) + seed * 7.13);
            vec2 center = id + vec2(0.24 + aeroHash(id + 13.7) * 0.52,
                                    0.24 + aeroHash(id + 39.4) * 0.52);
            vec2 offset = p - center;
            float distanceToHit = length(offset);
            float radius = age * 0.89;
            float band = exp(-pow((distanceToHit - radius) * 19.0, 2.0));
            float fade = smoothstep(0.01, 0.19, age)
                       * (1.0 - smoothstep(0.75, 0.99, age));
            float ripple = band * fade;
            surface += ripple;
            // Different slopes along the leading/trailing rim yield genuinely
            // circular reflections instead of animated stripe normals.
            float side = clamp((distanceToHit - radius) * 18.0, -1.0, 1.0);
            slope += offset / max(distanceToHit, 0.04)
                   * ripple * side * 0.115;
        }
    }
    return clamp(surface * 0.65, 0.0, 1.0);
#endif
}

// Tiny streaks of streaming foam for *vertical water faces*. These are
// surface shading, not fake spawned Minecraft particles or fluid simulation.
float aeroCascadeFoam(vec3 world, float time) {
    float stripe = sin(world.x * 7.8 + world.z * 5.2 + world.y * 3.1
                     - time * 6.1 + sin(world.y * 1.8) * 0.8);
    float streak = pow(0.5 + 0.5 * stripe, 7.0);
    float noise = aeroNoise(world.xz * 4.7 + vec2(time * 0.24, -time * 0.31));
    float flecks = smoothstep(0.68, 0.89, noise) *
                   (0.5 + 0.5 * sin(world.y * 12.0 + time * 9.0));
    return clamp(streak * 0.56 + flecks * 0.35, 0.0, 1.0);
}

// Submerged visual bubble accents. World-locked centers are projected onto the
// view ray; visibility is depth-tested against the opaque depth buffer in the
// calling composite pass. This is not real geometry or bubble entities.
vec3 aeroUnderwaterBubbles(vec3 ray, vec3 eye, float maxDist, float time) {
#if BUBBLE_QUALITY == 0
    return vec3(0.0);
#else
    vec3 tint = vec3(0.0);
    float cellSize = 2.8;
    // Distribute checks along a ray, with small centered spawn regions to
    // avoid abruptly cutting bubbles at their hash-cell boundaries.
    for (int i = 0; i < BUBBLE_QUALITY; i++) {
        float stepDist = 2.1 + float(i) * 3.1;
        vec3 sampleP = eye + ray * stepDist;
        vec3 id = floor(sampleP / cellSize);
        vec2 h = vec2(id.x + id.y * 37.17, id.z + id.y * 11.73);
        float choice = aeroHash(h);
        if (choice < 0.31) continue;
        float speed = 0.16 + choice * 0.18;
        float lift = fract(choice * 3.1 + time * speed / cellSize);
        vec3 c = (id + vec3(0.30 + aeroHash(h + 11.2) * 0.40,
                             0.12 + 0.76 * lift,
                             0.30 + aeroHash(h + 37.8) * 0.40)) * cellSize;
        vec3 diff = c - eye;
        float forward = dot(diff, ray);
        if (forward < 0.70 || forward > min(maxDist - 0.15, 30.0)) continue;
        float radius = 0.075 + choice * 0.09;
        float r = length(diff - ray * forward);
        float silhouette = 1.0 - smoothstep(radius * 0.91, radius * 1.13, r);
        float core = 1.0 - smoothstep(0.0, radius * 0.66, r);
        float rim = silhouette * (1.0 - core * 0.92);
        float glint = pow(max(0.0, 1.0 - r / max(radius, 0.001)), 5.0);
        float fade = smoothstep(0.0, 0.12, lift)
                   * (1.0 - smoothstep(0.87, 1.0, lift));
        float distanceFade = 1.0 - smoothstep(10.0, 29.0, forward);
        vec3 pearl = aeroThinFilm(choice * 0.46 + r / max(radius, 0.001) * 0.21);
        tint += (vec3(0.31, 0.83, 0.95) * rim * 0.48
              + vec3(0.88, 1.00, 1.00) * (rim * 0.58 + glint * 0.09)
              + pearl * rim * 0.13)
              * fade * distanceFade * BUBBLE_STRENGTH;
    }
    return clamp(tint, vec3(0.0), vec3(0.95));
#endif
}

#endif
