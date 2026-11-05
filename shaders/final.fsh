#version 330 compatibility
#include "/lib/common.glsl"

uniform sampler2D colortex4; // Completed HDR world + sky + bloom + atmosphere
uniform float viewWidth;
uniform float viewHeight;
in vec2 texcoord;
layout(location = 0) out vec4 finalColor;

// Luminance-guided FXAA: edge smoothing on the finished image, including
// silhouettes of thin grass against procedural sky. No frame-history ghosts.
vec3 aeroFxaa(vec2 uv) {
    vec3 m = texture(colortex4, uv).rgb;
#if FXAA_QUALITY == 0
    return m;
#else
    vec2 pixel = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    vec3 nw = texture(colortex4, uv + vec2(-1.0, -1.0) * pixel).rgb;
    vec3 ne = texture(colortex4, uv + vec2( 1.0, -1.0) * pixel).rgb;
    vec3 sw = texture(colortex4, uv + vec2(-1.0,  1.0) * pixel).rgb;
    vec3 se = texture(colortex4, uv + vec2( 1.0,  1.0) * pixel).rgb;
    float lm  = aeroLuma(m);
    float lnw = aeroLuma(nw);
    float lne = aeroLuma(ne);
    float lsw = aeroLuma(sw);
    float lse = aeroLuma(se);
    float lo = min(lm, min(min(lnw, lne), min(lsw, lse)));
    float hi = max(lm, max(max(lnw, lne), max(lsw, lse)));
    // Skip low-contrast details, which preserves foliage texture crispness.
    if (hi - lo < max(0.055, hi * 0.13)) return m;
    vec2 dir;
    dir.x = -((lnw + lne) - (lsw + lse));
    dir.y =  ((lnw + lsw) - (lne + lse));
    float reduce = max((lnw + lne + lsw + lse) * 0.0078125, 0.0078125);
    float inv = 1.0 / (min(abs(dir.x), abs(dir.y)) + reduce);
    dir = clamp(dir * inv, vec2(-6.0), vec2(6.0)) * pixel;
    vec3 a = 0.5 * (
        texture(colortex4, uv + dir * (-0.166667)).rgb +
        texture(colortex4, uv + dir * ( 0.166667)).rgb);
#if FXAA_QUALITY == 1
    return mix(m, a, 0.84);
#else
    vec3 b = a * 0.5 + 0.25 * (
        texture(colortex4, uv + dir * (-0.500000)).rgb +
        texture(colortex4, uv + dir * ( 0.500000)).rgb);
    float lb = aeroLuma(b);
    return (lb < lo || lb > hi) ? a : b;
#endif
#endif
}

void main() {
    vec2 uv = texcoord;
    vec3 scene = aeroFxaa(uv);
    // Soft filmic highlight rolloff; maintain bright white clouds and cyan.
    scene = aeroToneMap(scene);
    scene = aeroSaturateColor(scene, AERO_SATURATION * aeroStyleSaturation());
    scene = clamp(scene, vec3(0.0), vec3(1.0));
    scene = pow(scene, vec3(0.96));
    vec2 centered = (uv - 0.5) * vec2(viewWidth / viewHeight, 1.0);
    float vignette = 1.0 - 0.052 * smoothstep(0.24, 1.16, length(centered));
    scene *= vignette;
    finalColor = vec4(scene, 1.0);
}
