#ifndef AERO_COLOREDLIGHT_GLSL
#define AERO_COLOREDLIGHT_GLSL

uniform sampler2D colortex2;

vec3 aeroColoredBlockLight(vec2 uv, vec3 center, vec3 worldNormal) {
    if (COLORED_LIGHT_STRENGTH < 0.001) return vec3(0.0);
    vec3 light = vec3(0.0);
    vec3 viewNormal = mat3(gbufferModelView) * worldNormal;
    float projectedRadius = clamp(abs(gbufferProjection[1][1]) * 3.0 / max(-center.z, 1.0), 0.006, 0.32);
    for (int i = 0; i < COLORED_LIGHT_SAMPLES; i++) {
        float radius = sqrt((float(i) + 0.5) / float(COLORED_LIGHT_SAMPLES));
        float angle = float(i) * 2.39996323;
        vec2 offset = vec2(cos(angle) * viewHeight / viewWidth, sin(angle)) * radius * projectedRadius;
        vec2 probeUV = uv + offset;
        if (any(lessThan(probeUV, vec2(0.001))) || any(greaterThan(probeUV, vec2(0.999)))) continue;
        // A small mip footprint makes compact lamps less likely to be missed.
        vec3 emitter = textureLod(colortex2, probeUV, 1.0).rgb;
        if (max(max(emitter.r, emitter.g), emitter.b) < 0.002) continue;
        float depth = texture(depthtex0, probeUV).r;
        if (depth > 0.9999) continue;
        vec3 source = aeroUnproject(probeUV, depth, gbufferProjectionInverse);
        vec3 delta = source - center;
        float distanceToLight = length(delta);
        if (distanceToLight < 0.08 || distanceToLight > 6.0) continue;
        float visible = 1.0;
        // Reject screen-visible occluders between the receiver and source.
        for (int j = 1; j <= 3; j++) {
            float fraction = float(j) * 0.25;
            vec3 rayPos = mix(center, source, fraction) + viewNormal * 0.08;
            vec4 clip = gbufferProjection * vec4(rayPos, 1.0);
            if (clip.w <= 0.0) { visible = 0.0; break; }
            vec2 rayUV = clip.xy / clip.w * 0.5 + 0.5 + aeroJitter(frameCounter, vec2(viewWidth, viewHeight));
            float blockerDepth = texture(depthtex0, rayUV).r;
            vec3 blocker = aeroUnproject(rayUV, blockerDepth, gbufferProjectionInverse);
            if (blockerDepth < 0.9999 && blocker.z > rayPos.z + 0.14) { visible = 0.0; break; }
        }
        float diffuse = 0.12 + 0.88 * max(dot(viewNormal, delta / distanceToLight), 0.0);
        float falloff = pow(1.0 - distanceToLight / 6.0, 2.0);
        light += emitter * diffuse * falloff * visible;
    }
    return light * (18.0 / float(COLORED_LIGHT_SAMPLES)) * COLORED_LIGHT_STRENGTH;
}

#endif
