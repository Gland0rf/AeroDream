#ifndef AERO_COMMON_GLSL
#define AERO_COMMON_GLSL

#include "/lib/settings.glsl"

const float AERO_PI = 3.14159265359;

uniform float frameTimeCounter;
uniform int worldTime;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform mat4 gbufferModelViewInverse;

float aeroSat(float x) { return clamp(x, 0.0, 1.0); }
vec3 aeroSat3(vec3 x) { return clamp(x, vec3(0.0), vec3(1.0)); }
float aeroLuma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

float aeroHash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float aeroNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(aeroHash(i), aeroHash(i + vec2(1.0, 0.0)), f.x),
               mix(aeroHash(i + vec2(0.0, 1.0)), aeroHash(i + vec2(1.0)), f.x), f.y);
}

float aeroFbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * aeroNoise(p);
        p = p * 2.03 + vec2(31.7, 17.3);
        amp *= 0.5;
    }
    return v;
}

// Wind-aligned cloud field sampled both by the sky and sunlit terrain.
// Coordinate input is absolute world XZ at the shared 205-block cloud plane.
float aeroCloudCoverage(vec2 worldXZ, float time) {
    vec2 p = worldXZ * 0.018 + vec2(time * 0.014, time * 0.007);
    float low = aeroNoise(p * 0.72);
    float detail = aeroNoise(p * 1.82 + vec2(8.6, 14.2));
    float wisps = aeroNoise(p * 3.63 - vec2(4.4, 2.8));
    float n = low * 0.57 + detail * 0.30 + wisps * 0.13;
    float threshold = mix(0.69, 0.40, CLOUD_DENSITY);
    return smoothstep(threshold, threshold + 0.16, n);
}

// Morning glow (the beginning of the Minecraft day, not both twilights).
// Minecraft local world time used for the deep-blue afterglow and predawn.
float aeroBlueHour() {
    float t = float(worldTime);
    float evening = smoothstep(11900.0, 13300.0, t)
                  * (1.0 - smoothstep(14800.0, 16900.0, t));
    float morning = smoothstep(21000.0, 22600.0, t)
                  * (1.0 - smoothstep(23500.0, 24000.0, t));
    return max(evening, morning) * BLUE_HOUR_STRENGTH;
}

// Art-direction profiles; these change colors only, not GPU-quality settings.
vec3 aeroPalette(vec3 classic, vec3 tropical, vec3 soft) {
#if AERO_STYLE == 1
    return tropical;
#elif AERO_STYLE == 2
    return soft;
#else
    return classic;
#endif
}

float aeroStyleGreen() {
#if AERO_STYLE == 1
    return 1.16;
#elif AERO_STYLE == 2
    return 0.78;
#else
    return 1.0;
#endif
}

float aeroStyleSaturation() {
#if AERO_STYLE == 1
    return 1.06;
#elif AERO_STYLE == 2
    return 0.87;
#else
    return 1.0;
#endif
}

float aeroMorning() {
    float t = float(worldTime);
    float early = 1.0 - smoothstep(1400.0, 4200.0, t);
    float beforeDawn = smoothstep(22600.0, 23999.0, t);
    return max(early, beforeDawn);
}

// Delicate soap-bubble color, limited to grazing angles on shiny surfaces.
vec3 aeroThinFilm(float phase) {
    vec3 shifted = vec3(0.00, 0.34, 0.68);
    return 0.50 + 0.50 * cos(6.2831853 * (phase + shifted));
}

vec3 aeroSunDir() {
    return normalize(mat3(gbufferModelViewInverse) * sunPosition);
}

vec3 aeroMoonDir() {
    return -aeroSunDir();
}

// The optimistic Aero sky is a real world-direction gradient, not a texture.
// Sunsets are intentionally pastel, while the noon dome is crisp cyan/azure.
vec3 aeroSky(vec3 ray, vec3 sunDir, float time) {
    ray = normalize(ray);
    float height = aeroSat(ray.y * 0.82 + 0.12);
    float sunHeight = sunDir.y;
    float daylight = smoothstep(-0.18, 0.20, sunHeight);
    float twilight = 1.0 - smoothstep(0.02, 0.40, abs(sunHeight));
    float horizon = exp(-abs(ray.y) * 6.7);

    vec3 horizonBlue = aeroPalette(vec3(0.50, 0.84, 0.99),
                                   vec3(0.34, 0.91, 0.98),
                                   vec3(0.70, 0.87, 1.00));
    vec3 zenithBlue  = aeroPalette(vec3(0.055, 0.345, 0.93),
                                   vec3(0.035, 0.47, 0.95),
                                   vec3(0.30, 0.53, 0.84));
    vec3 daylightSky = mix(horizonBlue, zenithBlue, pow(height, 0.67));
    // Saturate the blues without dyeing the nearly-white horizon.
    daylightSky = mix(vec3(aeroLuma(daylightSky)), daylightSky, SKY_FRESHNESS);
    vec3 nightSky = mix(vec3(0.060, 0.125, 0.275),
                        vec3(0.010, 0.028, 0.118), pow(height, 0.69))
                  * NIGHT_BRIGHTNESS;
    vec3 sky = mix(nightSky, daylightSky, daylight);
    // Saturated but luminous blue hour; fades outside early-night/dawn time.
    float blueHour = aeroBlueHour() * (1.0 - rainStrength * 0.62);
    vec3 afterglow = mix(vec3(0.036, 0.11, 0.31), vec3(0.19, 0.42, 0.74),
                         exp(-abs(ray.y) * 4.3));
    sky = mix(sky, afterglow, 0.44 * blueHour);

    // Soft peach and pink nearest the sun, periwinkle toward the opposite edge.
    vec2 rayAz = normalize(ray.xz + vec2(0.00001));
    vec2 sunAz = normalize(sunDir.xz + vec2(0.00001));
    float towardsSun = pow(max(dot(rayAz, sunAz), 0.0), 2.3);
    vec3 peach = vec3(1.0, 0.71, 0.58);
    vec3 pink  = vec3(0.95, 0.52, 0.78);
    vec3 lilac = vec3(0.56, 0.55, 0.90);
    vec3 sunsetTint = mix(lilac, mix(pink, peach, towardsSun),
                          0.30 + towardsSun * 0.70);
    float sunsetMask = min(PASTEL_SUNSETS * twilight * horizon *
                           (0.24 + 0.73 * towardsSun), 0.92);
    sky = mix(sky, sunsetTint, sunsetMask);
    // Luminous cool-white morning haze before the sun reaches its zenith.
    float morning = aeroMorning() * daylight;
    sky = mix(sky, vec3(0.73, 0.91, 1.02),
              morning * horizon * 0.095);

#ifdef AERO_CLOUDS
    // Clouds are pinned to a real world-space layer: their projected shadows
    // can match the visible drifting cloud masses below.
    if (ray.y > 0.025 && cameraPosition.y < 203.0) {
        float toLayer = 205.0 - cameraPosition.y;
        vec2 cloudXZ = cameraPosition.xz + ray.xz * min(toLayer / ray.y, 4200.0);
        float clouds = aeroCloudCoverage(cloudXZ, time);
        clouds *= smoothstep(0.025, 0.15, ray.y);
        vec3 white = mix(vec3(0.44, 0.58, 0.77),
                         vec3(1.0, 1.0, 0.995), daylight);
        white = mix(white, mix(vec3(0.90, 0.72, 0.88),
                                vec3(1.0, 0.83, 0.73), towardsSun),
                    twilight * 0.51);
        white = mix(white, vec3(0.68, 0.76, 0.85), rainStrength * 0.63);
        sky = mix(sky, white, clouds * (0.67 + 0.24 * daylight));
    }
#endif

    float solar = max(dot(ray, sunDir), 0.0);
    float sunDisk = smoothstep(0.999906, 0.999976, solar);
    float halo = pow(solar, 165.0);
    sky += vec3(1.0, 0.88, 0.73) * (halo * 0.65 + sunDisk * 2.10)
         * daylight * (1.0 - rainStrength * 0.92);

    float night = 1.0 - daylight;
    float lunar = max(dot(ray, -sunDir), 0.0);
    float moonDisk = smoothstep(0.999932, 0.999975, lunar);
    sky += vec3(0.66, 0.81, 1.0) * (moonDisk * 0.88 + pow(lunar, 200.0) * 0.11)
         * night * (1.0 - rainStrength * 0.70);
    // Tiny non-twinkling stars, fixed to world direction, never screen space.
    if (ray.y > 0.045 && night > 0.65) {
        vec2 starUV = vec2(atan(ray.z, ray.x) * 132.0, ray.y * 185.0);
        vec2 cell = floor(starUV);
        vec2 offset = fract(starUV) - 0.50;
        float chosen = smoothstep(0.9958, 0.9991, aeroHash(cell));
        float starShape = 1.0 - smoothstep(0.035, 0.19, length(offset));
        sky += vec3(0.53, 0.69, 1.0) * chosen * starShape
             * night * (1.0 - rainStrength) * 0.58;
    }

    vec3 overcast = mix(vec3(0.71, 0.81, 0.87), vec3(0.35, 0.52, 0.69),
                        pow(height, 0.49));
    sky = mix(sky, overcast, rainStrength * 0.74);
    return max(sky, vec3(0.0));
}

// Selective greens: always respect the vanilla biome tint and the original
// texture (including yellow savanna grass, snowy grass sides, and pink leaves).
// Ground cover and plant ID labels increase influence, not force every face green.
vec3 aeroFreshGreen(vec3 c, float material) {
    float greenHue = smoothstep(-0.075, 0.115, c.g - c.r)
                   * smoothstep(-0.035, 0.135, c.g - c.b);
    float chroma = smoothstep(0.075, 0.28, c.g);
    float green = greenHue * chroma;
    float terrainOrPlant = float(material == 10010.0 || material == 10011.0
                             || material == 10012.0 || material == 10015.0
                             || material == 10017.0 || material == 10018.0
                             || material == 10019.0);
    green *= mix(0.88, 1.14, terrainOrPlant);
    float boost = (GREEN_VIBRANCE * aeroStyleGreen() - 1.0) * aeroSat(green);
    c.g *= 1.0 + boost * 0.42;
    c.r *= 1.0 + boost * 0.07;
    c.b *= 1.0 - boost * 0.11;
    return c;
}

vec3 aeroToneMap(vec3 c) {
    c = max(c, vec3(0.0));
    // A gentle filmic rolloff, calibrated for glossy but readable white clouds.
    c = (c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14);
    return clamp(c, 0.0, 1.0);
}

vec3 aeroSaturateColor(vec3 c, float amount) {
    return mix(vec3(aeroLuma(c)), c, amount);
}

#endif
