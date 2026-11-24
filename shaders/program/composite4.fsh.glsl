#include "/lib/common.glsl"
#include "/lib/reflections.glsl"
#include "/lib/temporal.glsl"

uniform sampler2D colortex4;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
in vec2 texcoord;

/*
const int colortex3Format = RGBA16F;
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
*/
const bool colortex3Clear = false;
/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 resolvedScene;

void main() {
    vec2 resolution = vec2(viewWidth, viewHeight);
    vec2 currentUV = clamp(texcoord + aeroJitter(frameCounter, resolution), 0.0, 1.0);
    vec3 current = texture(colortex4, currentUV).rgb;
    float depth = texture(depthtex0, currentUV).r;
    vec3 view = aeroUnproject(currentUV, depth, gbufferProjectionInverse);
    float linearDepth = depth > 0.99999 ? -1.0 : max(-view.z, 0.001);
    vec3 result = current;
#if TAA_ENABLED == 1
    vec3 relativeWorld = (gbufferModelViewInverse * vec4(view, 1.0)).xyz;
    vec3 cameraMovement = cameraPosition - previousCameraPosition;
    vec4 previousView;
    if (depth > 0.99999) {
        vec3 direction = normalize(mat3(gbufferModelViewInverse) * view);
        previousView = gbufferPreviousModelView * vec4(direction, 0.0);
    } else {
        previousView = gbufferPreviousModelView * vec4(relativeWorld + cameraMovement, 1.0);
    }
    vec4 previousClip = gbufferPreviousProjection * previousView;
    vec2 previousUV = previousClip.xy / max(previousClip.w, 0.0001) * 0.5 + 0.5;
    bool valid = previousClip.w > 0.0 && frameCounter > 1 && length(cameraMovement) < 8.0
              && all(greaterThan(previousUV, vec2(0.001)))
              && all(lessThan(previousUV, vec2(0.999))) && depth > 0.56;
    if (valid) {
        vec4 history = texture(colortex3, previousUV);
        float expectedDepth = depth > 0.99999 ? -1.0 : max(-previousView.z, 0.001);
        float confidence = aeroHistoryConfidence(history, expectedDepth);
        vec3 lo = current;
        vec3 hi = current;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 neighborUV = clamp(currentUV + vec2(x, y) / resolution, 0.0, 1.0);
                vec3 neighbor = texture(colortex4, neighborUV).rgb;
                lo = min(lo, neighbor);
                hi = max(hi, neighbor);
            }
        }
        vec3 clipped = clamp(history.rgb, lo, hi);
        float movement = length((previousUV - texcoord) * resolution);
        float lightChange = abs(aeroLuma(clipped) - aeroLuma(current)) / max(aeroLuma(current), 0.10);
        float weight = TAA_HISTORY * confidence * exp(-movement * 0.045)
                     * (1.0 - smoothstep(0.25, 1.0, lightChange));
        result = mix(current, clipped, weight);
    }
#endif
    resolvedScene = vec4(max(result, vec3(0.0)), linearDepth);
}
