// Shared vertex shader. Only terrain and translucent terrain have mc_Entity
// and at_midBlock in Iris; other passes must not read those attributes.
#include "/lib/wind.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

#ifdef AERO_HAS_BLOCK_ATTRIBUTES
in vec2 mc_Entity;
in vec4 at_midBlock;
#endif

out vec2 vUV;
out vec2 vLM;
out vec4 vColor;
out vec3 vNormal;
out vec3 vWorldPos;
out vec3 vViewPos;
flat out int vMaterial;

void main() {
    vec4 viewPosition = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPosition = (gbufferModelViewInverse * viewPosition).xyz;
    int material = -1;

#ifdef AERO_HAS_BLOCK_ATTRIBUTES
    material = int(mc_Entity.x);
    vec3 displacement = aeroWindOffset(material, playerPosition, cameraPosition,
                                       at_midBlock, frameTimeCounter);
    playerPosition += displacement;
    viewPosition.xyz += mat3(gbufferModelView) * displacement;
#endif

    gl_Position = gl_ProjectionMatrix * viewPosition;
    vViewPos = viewPosition.xyz;
    vWorldPos = playerPosition;
    vNormal = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
    vUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLM = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vColor = gl_Color; // preserves the biome-dependent grass/leaf tint
    vMaterial = material;
}
