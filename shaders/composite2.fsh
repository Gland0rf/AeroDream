#version 330 compatibility
uniform sampler2D colortex7;
uniform float viewHeight;
in vec2 texcoord;
/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 blurVertical;
void main() {
    vec2 stepUV = vec2(0.0, 2.0 / viewHeight);
    vec3 c = texture(colortex7, texcoord).rgb * 0.227027;
    c += texture(colortex7, texcoord + stepUV * 1.384615).rgb * 0.316216;
    c += texture(colortex7, texcoord - stepUV * 1.384615).rgb * 0.316216;
    c += texture(colortex7, texcoord + stepUV * 3.230769).rgb * 0.070270;
    c += texture(colortex7, texcoord - stepUV * 3.230769).rgb * 0.070270;
    blurVertical = vec4(c, 1.0);
}
