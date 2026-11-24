#ifndef AERO_REFLECTIONS_GLSL
#define AERO_REFLECTIONS_GLSL

vec3 aeroUnproject(vec2 uv, float depth, mat4 inverseProjection) {
    uv -= aeroJitter(frameCounter, vec2(viewWidth, viewHeight));
    vec4 h = inverseProjection * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return h.xyz / (abs(h.w) > 0.00001 ? h.w : 0.00001);
}

vec4 aeroScreenReflection(sampler2D colorBuffer, sampler2D depthBuffer,
                          mat4 projection, mat4 inverseProjection,
                          vec3 origin, vec3 direction) {
    float distanceAlong = 0.32;
    for (int i = 0; i < REFLECTION_STEPS; i++) {
        distanceAlong += 0.36 + float(i) * 0.13;
        vec3 rayPos = origin + direction * distanceAlong;
        if (rayPos.z > -0.06) break;
        vec4 clip = projection * vec4(rayPos, 1.0);
        if (clip.w <= 0.0) break;
        vec2 uv = clip.xy / clip.w * 0.5 + 0.5 + aeroJitter(frameCounter, vec2(viewWidth, viewHeight));
        if (any(lessThanEqual(uv, vec2(0.012))) || any(greaterThanEqual(uv, vec2(0.988)))) break;
        float depth = texture(depthBuffer, uv).r;
        if (depth > 0.9999) continue;
        vec3 scenePos = aeroUnproject(uv, depth, inverseProjection);
        float separation = length(rayPos - scenePos);
        if (rayPos.z < scenePos.z - 0.07 && separation < 1.3 + distanceAlong * 0.065) {
            float border = smoothstep(0.012, 0.17, min(min(uv.x, uv.y), min(1.0-uv.x, 1.0-uv.y)));
            float fade = border * (1.0 - smoothstep(22.0, 55.0, distanceAlong));
            return vec4(texture(colorBuffer, uv).rgb, fade);
        }
    }
    return vec4(0.0);
}

#endif
