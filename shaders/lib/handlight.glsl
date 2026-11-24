#ifndef AERO_HANDLIGHT_GLSL
#define AERO_HANDLIGHT_GLSL

uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int heldItemId;
uniform int heldItemId2;

vec3 aeroHeldColor(int item) {
    if (item == 11002) return vec3(0.28, 0.76, 1.0); // soul light
    if (item == 11003) return vec3(0.68, 0.93, 1.0); // sea lantern/end rod
    if (item == 11004) return vec3(1.0, 0.22, 0.10); // redstone torch
    return vec3(1.0, 0.70, 0.40);
}

vec3 aeroOneHandLight(vec3 viewPos, vec3 viewNormal, float side, int level, int item) {
    if (level <= 0) return vec3(0.0);
    vec3 delta = vec3(side * 0.30, -0.25, -0.35) - viewPos;
    float distanceToLight = length(delta);
    float reach = HANDHELD_RADIUS * clamp(float(level) / 15.0, 0.0, 1.0);
    float falloff = pow(max(0.0, 1.0 - distanceToLight / max(reach, 0.01)), 2.0);
    float diffuse = 0.20 + 0.80 * max(dot(viewNormal, delta / max(distanceToLight, 0.01)), 0.0);
    return aeroHeldColor(item) * falloff * diffuse;
}

vec3 aeroHandLight(vec3 viewPos, vec3 worldNormal) {
    if (HANDHELD_LIGHT < 0.001) return vec3(0.0);
    // Inverse of the camera rotation; both hands contribute without doubling
    // the brightness when carrying two torches. This is an unshadowed light.
    vec3 viewNormal = transpose(mat3(gbufferModelViewInverse)) * worldNormal;
    vec3 mainLight = aeroOneHandLight(viewPos, viewNormal, 1.0, heldBlockLightValue, heldItemId);
    vec3 offLight = aeroOneHandLight(viewPos, viewNormal, -1.0, heldBlockLightValue2, heldItemId2);
    return max(mainLight, offLight) * HANDHELD_LIGHT * 1.15;
}

#endif
