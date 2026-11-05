#version 330 compatibility
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
    if (texel.a < 0.50) discard;
    shadowColor = vec4(texel.rgb, 1.0);
}
