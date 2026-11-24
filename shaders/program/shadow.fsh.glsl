#include "/lib/settings.glsl"
uniform sampler2D gtexture;
in vec2 shadowUV;
in vec4 shadowTint;
flat in int shadowMaterial;
layout(location = 0) out vec4 shadowColor;
void main() {
    // Water is transparent to sunlight. Hard-cutout alpha makes sure blades,
    // petals and leaves cast silhouettes, not unwanted square shadows.
    if (shadowMaterial == 10001) discard;
    vec4 texel = texture(gtexture, shadowUV) * shadowTint;
#ifdef AERO_COLORED_SHADOWS
    if (shadowMaterial == 10013 || shadowMaterial == 10014) {
        float tint = smoothstep(0.01, 0.18, texel.a);
        vec3 transmission = mix(vec3(1.0), max(texel.rgb, vec3(0.02)), tint);
        transmission *= mix(0.96, 0.68, clamp(texel.a, 0.0, 1.0));
        shadowColor = vec4(transmission, 1.0);
        return;
    }
    if (shadowMaterial == 10022) {
        shadowColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
#endif
    if (texel.a < 0.50) discard;
    shadowColor = vec4(0.0, 0.0, 0.0, 1.0);
}
