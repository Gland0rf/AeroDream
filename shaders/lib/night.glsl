#ifndef AERO_NIGHT_GLSL
#define AERO_NIGHT_GLSL

uniform int moonPhase;

float aeroMoonDisk(vec3 ray, vec3 moonDir) {
    vec3 axis = abs(moonDir.y) < 0.98 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);
    vec3 right = normalize(cross(moonDir, axis));
    vec3 up = cross(right, moonDir);
    vec2 p = vec2(dot(ray, right), dot(ray, up)) / 0.0105;
    float radius2 = dot(p, p);
    float disk = (1.0 - smoothstep(0.91, 1.0, radius2)) * step(0.0, dot(ray, moonDir));
#ifdef AERO_MOON_PHASES
    // Phase 0 is full, 4 is new; opposite sides light during waxing/waning.
    float phase = float(moonPhase) * (2.0 * AERO_PI / 8.0);
    float z = sqrt(max(0.0, 1.0 - radius2));
    float lit = z * cos(phase) + p.x * sin(phase);
    disk *= smoothstep(-0.025, 0.025, lit);
#endif
    return disk;
}

vec3 aeroShootingStar(vec3 ray, float time) {
    if (SHOOTING_STAR_STRENGTH < 0.001 || ray.y < 0.12) return vec3(0.0);
    // One possible event per 83 seconds, with empty intervals between events.
    float interval = floor(time / 83.0);
    float seed = aeroHash(vec2(interval, 73.9));
    if (seed < 0.38) return vec3(0.0);
    float age = mod(time, 83.0) - (8.0 + seed * 48.0);
    if (age < 0.0 || age > 1.15) return vec3(0.0);
    float azimuth = aeroHash(vec2(interval, 11.3)) * 2.0 * AERO_PI;
    float elevation = 0.47 + aeroHash(vec2(interval, 31.2)) * 0.60;
    vec3 start = vec3(cos(azimuth) * cos(elevation), sin(elevation),
                      sin(azimuth) * cos(elevation));
    vec3 tangent = normalize(cross(start, vec3(0.0, 1.0, 0.0))
                           + vec3(0.0, -0.4, 0.0));
    vec3 head = normalize(start + tangent * age * 0.20);
    vec3 trail = normalize(tangent - head * dot(tangent, head));
    float along = dot(ray - head, trail);
    float across = abs(dot(ray, normalize(cross(head, trail))));
    float streak = exp(-across * across * 1600000.0)
                 * smoothstep(-0.095, -0.002, along)
                 * (1.0 - smoothstep(0.0, 0.003, along));
    float facing = smoothstep(0.98, 0.999, dot(ray, head));
    float fade = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.75, 1.15, age));
    return vec3(0.67, 0.85, 1.0) * streak * facing * fade * SHOOTING_STAR_STRENGTH;
}

#endif
