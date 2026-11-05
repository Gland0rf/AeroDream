#version 330 compatibility
#include "/lib/wind.glsl"

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

in vec2 mc_Entity;
in vec4 at_midBlock;
out vec2 shadowUV;
out vec4 shadowTint;
flat out int shadowMaterial;

void main() {
    int material = int(mc_Entity.x);
    vec4 shadowView = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPosition = (shadowModelViewInverse * shadowView).xyz;
    vec3 displacement = aeroWindOffset(material, playerPosition, cameraPosition,
                                       at_midBlock, frameTimeCounter);
    shadowView.xyz += mat3(shadowModelView) * displacement;

    gl_Position = gl_ProjectionMatrix * shadowView;
    shadowUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    shadowTint = gl_Color;
    shadowMaterial = material;
}
