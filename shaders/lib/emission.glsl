#ifndef AERO_EMISSION_GLSL
#define AERO_EMISSION_GLSL

vec3 aeroBlockEmission(int material, vec3 albedo) {
    if (material == 10016) return vec3(1.0, 0.60, 0.23);
    if (material == 10024) return vec3(0.22, 0.76, 1.0);
    if (material == 10025) return vec3(0.54, 1.0, 0.31);
    if (material == 10026) return vec3(0.91, 0.52, 1.0);
    if (material == 10027) return vec3(1.0, 0.11, 0.04) * 0.65;
    return vec3(0.0);
}

#endif
