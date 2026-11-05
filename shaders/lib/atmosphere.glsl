#ifndef AERO_ATMOSPHERE_GLSL
#define AERO_ATMOSPHERE_GLSL

// A physically placed primary rainbow: the colored ring is centered on the
// antisolar point, at approximately 40-42 degrees from it. Intentionally
// restricted to clear skies after rain; it never appears in caves or at noon.
vec3 aeroRainbowSpectrum(float t) {
    t = clamp(t, 0.0, 1.0);
    vec3 violet = vec3(0.46, 0.23, 0.81);
    vec3 blue   = vec3(0.23, 0.51, 0.99);
    vec3 cyan   = vec3(0.26, 0.82, 0.99);
    vec3 green  = vec3(0.29, 0.83, 0.51);
    vec3 yellow = vec3(0.98, 0.90, 0.37);
    vec3 orange = vec3(1.00, 0.60, 0.29);
    vec3 red    = vec3(1.00, 0.32, 0.40);
    if (t < 0.16667) return mix(violet, blue, t * 6.0);
    if (t < 0.33333) return mix(blue, cyan, (t - 0.16667) * 6.0);
    if (t < 0.50000) return mix(cyan, green, (t - 0.33333) * 6.0);
    if (t < 0.66667) return mix(green, yellow, (t - 0.50000) * 6.0);
    if (t < 0.83333) return mix(yellow, orange, (t - 0.66667) * 6.0);
    return mix(orange, red, (t - 0.83333) * 6.0);
}

vec3 aeroAfterRainRainbow(vec3 ray, vec3 sunDir, float wet) {
    if (RAINBOW_STRENGTH < 0.001) return vec3(0.0);
    // wetness persists after rain, rainStrength falls quickly as it stops.
    float recentRain = smoothstep(0.02, 0.32, wet);
    float clearing = 1.0 - smoothstep(0.22, 0.78, rainStrength);
    float sunAngle = smoothstep(0.02, 0.17, sunDir.y)
                   * (1.0 - smoothstep(0.42, 0.71, sunDir.y));
    float horizon = smoothstep(0.005, 0.13, ray.y);
    float visibility = recentRain * clearing * sunAngle * horizon;
    if (visibility < 0.001) return vec3(0.0);

    float angle = acos(clamp(dot(normalize(ray), -sunDir), -1.0, 1.0));
    float primary = (angle - radians(39.6)) / radians(2.7);
    float band = smoothstep(0.005, 0.10, primary)
               * (1.0 - smoothstep(0.90, 0.997, primary));
    vec3 rainbow = aeroRainbowSpectrum(primary) * band;
#ifdef AERO_DOUBLE_RAINBOW
    // The faint secondary bow has reversed color ordering, outside the first.
    float secondary = (angle - radians(50.1)) / radians(2.9);
    float outerBand = smoothstep(0.02, 0.14, secondary)
                    * (1.0 - smoothstep(0.86, 0.99, secondary));
    rainbow += aeroRainbowSpectrum(1.0 - secondary) * outerBand * 0.29;
#endif
    return rainbow * visibility * RAINBOW_STRENGTH * 0.58;
}

#endif
