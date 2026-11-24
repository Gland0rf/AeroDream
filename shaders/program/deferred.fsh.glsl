#include "/lib/common.glsl"
#include "/lib/waterlife.glsl"
#include "/lib/reflections.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform int isEyeInWater;
#include "/lib/coloredlight.glsl"
in vec2 texcoord;
/*
const int colortex1Format = RGBA16F;
const vec4 colortex1ClearColor = vec4(0.5, 1.0, 0.5, 0.0);
const int colortex2Format = RGBA16F;
const vec4 colortex2ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
const bool colortex2MipmapEnabled = true;
/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 sceneOut;
layout(location = 1) out vec4 opaqueScene;
void main() {
    vec4 scene = texture(colortex0, texcoord);
    float receiverDepth = texture(depthtex0, texcoord).r;
    if (receiverDepth < 0.99999 && COLORED_LIGHT_STRENGTH > 0.001) {
        vec3 center = aeroUnproject(texcoord, receiverDepth, gbufferProjectionInverse);
        vec3 normal = normalize(texture(colortex1, texcoord).rgb * 2.0 - 1.0);
        vec3 illumination = aeroColoredBlockLight(texcoord, center, normal);
        scene.rgb += (scene.rgb * 0.65 + vec3(0.12)) * illumination;
    }
#if PUDDLE_QUALITY > 0 && AERO_DIMENSION == 0
    vec4 surface = texture(colortex1, texcoord);
    float depth = texture(depthtex0, texcoord).r;
    if (surface.a > 0.001 && depth < 0.99999 && isEyeInWater == 0) {
        vec3 viewPos = aeroUnproject(texcoord, depth, gbufferProjectionInverse);
        vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 N = normalize(surface.xyz * 2.0 - 1.0);
#ifdef AERO_RAIN_RIPPLES
        if (rainStrength > 0.001) {
            vec2 slope;
            aeroRainRings((worldPos + cameraPosition).xz, frameTimeCounter, slope);
            N = normalize(N + vec3(slope.x, 0.0, slope.y) * rainStrength * RAIN_RING_STRENGTH * 0.35);
        }
#endif
        vec3 V = normalize(mat3(gbufferModelViewInverse) * (-viewPos));
        vec3 reflected = reflect(-V, N);
        vec3 reflection = aeroSky(reflected, aeroSunDir(), frameTimeCounter);
#if PUDDLE_QUALITY == 2
        vec4 hit = aeroScreenReflection(colortex0, depthtex0, gbufferProjection,
                                        gbufferProjectionInverse,
                                        viewPos + mat3(gbufferModelView) * N * 0.06,
                                        normalize(mat3(gbufferModelView) * reflected));
        reflection = mix(reflection, hit.rgb, hit.a);
#endif
        float fresnel = 0.035 + 0.965 * pow(1.0 - aeroSat(dot(N, V)), 5.0);
        scene.rgb = mix(scene.rgb * (1.0 - surface.a * 0.08), reflection,
                        fresnel * surface.a * 0.90);
    }
#endif
    sceneOut = scene;
    // Snapshot includes puddles before water/glass render and sample it.
    opaqueScene = scene;
}
