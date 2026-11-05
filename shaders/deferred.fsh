#version 330 compatibility
uniform sampler2D colortex0;
in vec2 texcoord;
/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 opaqueScene;
void main() {
    // Save opaque world color before translucent water renders.
    // This avoids sampling the framebuffer while it is being written.
    opaqueScene = texture(colortex0, texcoord);
}
