#ifndef AERO_PHOTO_GLSL
#define AERO_PHOTO_GLSL

uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform float centerDepthSmooth;

float aeroPhotoDepth(vec2 uv) {
    vec2 sampleUV = clamp(uv + aeroJitter(frameCounter, vec2(viewWidth, viewHeight)), 0.0, 1.0);
    float depth = texture(depthtex0, sampleUV).r;
    if (depth > 0.99999) return 10000.0;
    vec4 view = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return max(-view.z / max(abs(view.w), 0.00001), 0.05);
}

float aeroCircleOfConfusion(float distanceToCamera, float focus) {
    return clamp(abs(distanceToCamera - focus) / max(distanceToCamera, 0.05), 0.0, 1.0)
         * PHOTO_APERTURE * 12.0;
}

vec3 aeroPhotoColor(vec2 uv, vec3 sharp) {
#ifdef AERO_PHOTO_MODE
    float focus = PHOTO_FOCUS_DISTANCE;
#ifdef PHOTO_AUTOFOCUS
    vec4 center = gbufferProjectionInverse * vec4(0.0, 0.0, centerDepthSmooth * 2.0 - 1.0, 1.0);
    focus = centerDepthSmooth > 0.99999 ? 10000.0 : max(-center.z / max(abs(center.w), 0.00001), 0.05);
#endif
    float centerDistance = aeroPhotoDepth(uv);
    float radius = aeroCircleOfConfusion(centerDistance, focus);
    if (radius < 0.4) return sharp;
    vec3 color = sharp;
    float total = 1.0;
    for (int i = 0; i < 16; i++) {
        float angle = float(i) * 2.39996323;
        float diskRadius = sqrt((float(i) + 0.5) / 16.0);
        vec2 sampleUV = clamp(uv + vec2(cos(angle), sin(angle)) * diskRadius * radius
                                      / vec2(viewWidth, viewHeight), vec2(0.001), vec2(0.999));
        float otherDistance = aeroPhotoDepth(sampleUV);
        float otherRadius = aeroCircleOfConfusion(otherDistance, focus);
        // A focused foreground silhouette must not bleed into a blurred sky.
        float weight = smoothstep(radius * diskRadius - 1.0, radius * diskRadius + 1.0, otherRadius);
        if (otherDistance < centerDistance * 0.85) weight *= smoothstep(0.5, 2.0, otherRadius);
        color += texture(colortex3, sampleUV).rgb * weight;
        total += weight;
    }
    return color / total;
#else
    return sharp;
#endif
}

#endif
