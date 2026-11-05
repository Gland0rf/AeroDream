#version 330 compatibility
#include "/lib/settings.glsl"
uniform sampler2D colortex0;
in vec2 texcoord;

/*
const int colortex0Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
*/

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 brightPixels;
void main() {
    vec3 c = max(texture(colortex0, texcoord).rgb, vec3(0.0));
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    // Smooth knee prevents an ugly hard edge around medium-bright objects.
    float knee = smoothstep(0.72, 1.50, lum);
    vec3 bloomSource = max(c - vec3(0.75), vec3(0.0)) * (0.32 + 0.68 * knee);
    brightPixels = vec4(bloomSource, 1.0);
}
