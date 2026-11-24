#ifndef AERO_SHADOWS_GLSL
#define AERO_SHADOWS_GLSL

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

vec3 aeroShadowSample(vec3 sc, float bias) {
    float allVisible = step(sc.z - bias, texture(shadowtex0, sc.xy).r);
#ifdef AERO_COLORED_SHADOWS
    float opaqueVisible = step(sc.z - bias, texture(shadowtex1, sc.xy).r);
    vec3 transmission = clamp(texture(shadowcolor0, sc.xy).rgb, 0.0, 1.0);
    return opaqueVisible * mix(transmission, vec3(1.0), allVisible);
#else
    return vec3(allVisible);
#endif
}

vec3 aeroShadowCoordinate(vec3 playerPos) {
    vec4 clip = shadowProjection * shadowModelView * vec4(playerPos, 1.0);
    return clip.xyz / max(clip.w, 0.0001) * 0.5 + 0.5;
}

bool aeroInsideShadow(vec3 sc) {
    return all(greaterThan(sc, vec3(0.003))) && all(lessThan(sc, vec3(0.997)));
}

#endif
