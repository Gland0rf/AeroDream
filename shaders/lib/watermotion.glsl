#ifndef AERO_WATERMOTION_GLSL
#define AERO_WATERMOTION_GLSL

float aeroSurfaceHeight(vec2 p, float time, float weather) {
    float a = dot(p, vec2(0.32, 0.21)) + time * 0.85;
    float b = dot(p, vec2(0.61, -0.49)) - time * 1.12;
    return (sin(a) * 0.040 + sin(b) * 0.018) * WATER_SURFACE_MOTION
         * WATER_WAVES * (1.0 + weather * STORM_WIND * 0.35);
}

vec2 aeroSurfaceGradient(vec2 p, float time, float weather) {
    float a = dot(p, vec2(0.32, 0.21)) + time * 0.85;
    float b = dot(p, vec2(0.61, -0.49)) - time * 1.12;
    return (cos(a) * vec2(0.32, 0.21) * 0.040 + cos(b) * vec2(0.61, -0.49) * 0.018)
         * WATER_SURFACE_MOTION * WATER_WAVES * (1.0 + weather * STORM_WIND * 0.35);
}

#endif
