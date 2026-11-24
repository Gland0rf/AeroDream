#ifndef AERO_ENVIRONMENT_GLSL
#define AERO_ENVIRONMENT_GLSL

// Custom uniforms use loader-side smoothing, shared by every render pass.
uniform float aeroTemperature;
uniform float aeroRainfall;
uniform float aeroPrecipitation;
#ifdef IS_IRIS
uniform bool hasSkylight;
#endif

float aeroOverworld() {
#if AERO_DIMENSION != 0
    return 0.0;
#elif defined(IS_IRIS)
    return hasSkylight ? 1.0 : 0.0;
#else
    return 1.0;
#endif
}

// Cold, arid, humid weights; temperature/rainfall retain modded-biome support.
vec3 aeroClimate() {
    float cold = 1.0 - smoothstep(0.05, 0.45, aeroTemperature);
    float arid = smoothstep(0.85, 1.65, aeroTemperature)
               * (1.0 - smoothstep(0.10, 0.45, aeroRainfall));
    float humid = smoothstep(0.60, 0.95, aeroRainfall)
                * smoothstep(0.50, 0.90, aeroTemperature);
    return vec3(cold, arid, humid) * BIOME_ATMOSPHERE * aeroOverworld();
}

float aeroFogDensity() {
    vec3 climate = aeroClimate();
    float mountain = smoothstep(95.0, 190.0, cameraPosition.y);
    return max(0.45, 1.0 + climate.z * 0.55 - climate.x * 0.24
                    - mountain * BIOME_ATMOSPHERE * 0.18 * aeroOverworld());
}

vec3 aeroClimateTint(vec3 color) {
    vec3 climate = aeroClimate();
    color = mix(color, color * vec3(0.88, 0.97, 1.08), climate.x * 0.45);
    color = mix(color, color * vec3(1.12, 1.01, 0.87), climate.y * 0.48);
    return mix(color, color * vec3(0.88, 1.05, 0.98), climate.z * 0.38);
}

// Native rain/snow eligibility prevents desert puddles and snow-biome rain rings.
float aeroLocalRain() {
    return aeroOverworld() * aeroPrecipitation
         * smoothstep(0.10, 0.20, aeroTemperature);
}

vec3 aeroDimensionAmbient(vec3 original) {
#if AERO_DIMENSION == -1
    float soul = smoothstep(0.01, 0.14, fogColor.b - fogColor.r);
    vec3 tint = mix(vec3(0.58, 0.25, 0.12), vec3(0.12, 0.43, 0.47), soul);
    return mix(original, tint, DIMENSION_STYLE);
#elif AERO_DIMENSION == 1
    return mix(original, vec3(0.37, 0.30, 0.53), DIMENSION_STYLE);
#else
    return original;
#endif
}

vec3 aeroDimensionSky(vec3 ray, float time) {
#if AERO_DIMENSION == -1
    float soul = smoothstep(0.01, 0.14, fogColor.b - fogColor.r);
    float horizon = exp(-abs(ray.y) * 2.6);
    vec3 amber = mix(vec3(0.12, 0.035, 0.025), vec3(0.51, 0.22, 0.075), horizon);
    vec3 teal = mix(vec3(0.015, 0.075, 0.10), vec3(0.10, 0.40, 0.43), horizon);
    return mix(fogColor, mix(amber, teal, soul), DIMENSION_STYLE);
#elif AERO_DIMENSION == 1
    float azimuth = atan(ray.z, ray.x);
    float ribbon = pow(0.5 + 0.5 * sin(azimuth * 2.0 + ray.y * 5.0
                                  + sin(azimuth * 3.0 - time * 0.012)), 4.0);
    float horizon = exp(-abs(ray.y - 0.08) * 3.5);
    vec3 pearl = mix(vec3(0.065, 0.035, 0.15), vec3(0.34, 0.23, 0.48), horizon);
    pearl += mix(vec3(0.17, 0.13, 0.27), vec3(0.13, 0.27, 0.30), ribbon)
           * ribbon * horizon * 0.35;
    vec2 stars = vec2(azimuth * 170.0, ray.y * 210.0);
    float pin = (1.0 - smoothstep(0.04, 0.16, length(fract(stars) - 0.5)))
              * step(0.997, aeroHash(floor(stars)));
    pearl += vec3(0.62, 0.74, 0.90) * pin * smoothstep(0.05, 0.25, ray.y);
    return mix(fogColor, pearl, DIMENSION_STYLE);
#else
    return fogColor;
#endif
}

#endif
