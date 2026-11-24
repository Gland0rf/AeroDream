#ifndef AERO_CLOUDVOLUME_GLSL
#define AERO_CLOUDVOLUME_GLSL

float aeroNoise3(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n = dot(cell, vec3(1.0, 57.0, 113.0));
    vec4 low = vec4(aeroHash(vec2(n, 0.7)), aeroHash(vec2(n + 1.0, 0.7)),
                    aeroHash(vec2(n + 57.0, 0.7)), aeroHash(vec2(n + 58.0, 0.7)));
    vec4 high = vec4(aeroHash(vec2(n + 113.0, 0.7)), aeroHash(vec2(n + 114.0, 0.7)),
                     aeroHash(vec2(n + 170.0, 0.7)), aeroHash(vec2(n + 171.0, 0.7)));
    return mix(mix(mix(low.x, low.y, f.x), mix(low.z, low.w, f.x), f.y),
               mix(mix(high.x, high.y, f.x), mix(high.z, high.w, f.x), f.y), f.z);
}

float aeroCloudDensity3(vec3 world, float time) {
    float h = (world.y - 174.0) / 62.0;
    if (h <= 0.0 || h >= 1.0) return 0.0;
    float coverage = aeroCloudCoverage(world.xz, time);
    if (coverage < 0.025) return 0.0;
    float shape = smoothstep(0.0, 0.20, h) * (1.0 - smoothstep(0.52, 1.0, h));
    vec3 p = world * vec3(0.038, 0.052, 0.038) + vec3(time * 0.030, 0.0, time * 0.015);
    float erosion = aeroNoise3(p);
    return max(coverage * shape - erosion * 0.25, 0.0) * 0.065;
}

// Front-to-back integration of a real 62-block-thick world-space volume.
// RGB is premultiplied radiance and A is integrated opacity.
vec4 aeroVolumeClouds(vec3 ray, vec3 sunDir, float time, float maxDistance) {
#if defined(AERO_CLOUDS) && CLOUD_MODE == 1 && AERO_DIMENSION == 0
    if (aeroOverworld() < 0.5) return vec4(0.0);
    float entry = 0.0;
    float finish = min(maxDistance, 4200.0);
    if (abs(ray.y) > 0.0001) {
        float lower = (174.0 - cameraPosition.y) / ray.y;
        float upper = (236.0 - cameraPosition.y) / ray.y;
        entry = max(min(lower, upper), 0.0);
        finish = min(max(lower, upper), finish);
    } else if (cameraPosition.y < 174.0 || cameraPosition.y > 236.0) {
        return vec4(0.0);
    }
    if (finish <= entry) return vec4(0.0);
    float stepLength = (finish - entry) / float(CLOUD_SAMPLES);
    float transmittance = 1.0;
    vec3 radiance = vec3(0.0);
    float daylight = smoothstep(-0.18, 0.20, sunDir.y);
    float twilight = 1.0 - smoothstep(0.02, 0.40, abs(sunDir.y));
    vec3 lightDir = daylight > 0.5 ? sunDir : -sunDir;
    vec3 litColor = mix(vec3(0.24, 0.34, 0.53), vec3(1.04, 1.02, 0.99), daylight);
    litColor = mix(litColor, vec3(1.0, 0.73, 0.65), twilight * daylight * PASTEL_SUNSETS * 0.48);
    litColor = mix(litColor, vec3(0.58, 0.66, 0.74), rainStrength * daylight * 0.66);
    for (int i = 0; i < CLOUD_SAMPLES; i++) {
        vec3 world = cameraPosition + ray * (entry + (float(i) + 0.5) * stepLength);
        float density = aeroCloudDensity3(world, time);
        if (density < 0.0001) continue;
        float opacity = 1.0 - exp(-density * stepLength);
        float towardLight = aeroCloudDensity3(world + lightDir * 14.0, time);
        float selfShadow = exp(-towardLight * 22.0);
        float topLight = smoothstep(174.0, 232.0, world.y);
        vec3 scattering = litColor * (0.42 + 0.40 * selfShadow + 0.18 * topLight);
        scattering += vec3(0.78, 0.88, 1.0) * pow(max(dot(ray, lightDir), 0.0), 14.0)
                    * selfShadow * daylight * 0.12;
        radiance += transmittance * opacity * scattering;
        transmittance *= 1.0 - opacity;
        if (transmittance < 0.025) break;
    }
    return vec4(radiance, 1.0 - transmittance);
#else
    return vec4(0.0);
#endif
}

#endif
