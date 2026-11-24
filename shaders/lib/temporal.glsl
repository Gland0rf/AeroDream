#ifndef AERO_TEMPORAL_GLSL
#define AERO_TEMPORAL_GLSL

float aeroHistoryConfidence(vec4 history, float expectedDepth) {
    // A negative depth marks sky; zero is an empty/newly allocated history.
    if (!all(lessThan(abs(history.rgb), vec3(10000.0)))) return 0.0;
    if (expectedDepth < 0.0) return history.a < -0.5 ? 1.0 : 0.0;
    if (history.a <= 0.0) return 0.0;
    float tolerance = 0.03 + expectedDepth * 0.02;
    return 1.0 - smoothstep(tolerance, tolerance * 2.0, abs(history.a - expectedDepth));
}

#endif
