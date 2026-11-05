#version 330 compatibility
uniform sampler2D colortex6;
uniform float viewWidth;
in vec2 texcoord;
/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 blurHorizontal;
void main() {
    vec2 stepUV = vec2(2.0 / viewWidth, 0.0);
    vec3 c = texture(colortex6, texcoord).rgb * 0.227027;
    c += texture(colortex6, texcoord + stepUV * 1.384615).rgb * 0.316216;
    c += texture(colortex6, texcoord - stepUV * 1.384615).rgb * 0.316216;
    c += texture(colortex6, texcoord + stepUV * 3.230769).rgb * 0.070270;
    c += texture(colortex6, texcoord - stepUV * 3.230769).rgb * 0.070270;
    blurHorizontal = vec4(c, 1.0);
}
