#ifndef AERO_MATERIALS_GLSL
#define AERO_MATERIALS_GLSL

#if MATERIAL_MAPS > 0
uniform sampler2D normals;
uniform sampler2D specular;
#endif

struct AeroMaterial {
    vec3 normal;
    float smoothness;
    vec3 f0;
    float metal;
    float ao;
    float emission;
};

AeroMaterial aeroReadMaterial(vec2 uv, vec3 position, vec3 geometricNormal, vec3 albedo) {
    AeroMaterial m;
    m.normal = geometricNormal;
    m.smoothness = 0.0;
    m.f0 = vec3(0.04);
    m.metal = 0.0;
    m.ao = 1.0;
    m.emission = 0.0;
#if MATERIAL_MAPS > 0
    vec4 normalMap = texture(normals, uv);
    vec4 specMap = texture(specular, uv);
#if MATERIAL_MAPS == 2
    m.ao = normalMap.b;
#endif
    // Derivative frame follows atlas rotations and mirrored UVs without
    // relying on terrain-only attributes in hand/entity/particle programs.
    vec3 dpX = dFdx(position);
    vec3 dpY = dFdy(position);
    vec2 duvX = dFdx(uv);
    vec2 duvY = dFdy(uv);
    float determinant = duvX.x * duvY.y - duvX.y * duvY.x;
    vec3 tangent = (dpX * duvY.y - dpY * duvX.y) * sign(determinant);
    vec3 bitangent = (dpY * duvX.x - dpX * duvY.x) * sign(determinant);
    tangent -= geometricNormal * dot(tangent, geometricNormal);
    bitangent -= geometricNormal * dot(bitangent, geometricNormal);
    if (dot(tangent, tangent) > 1e-12 && dot(bitangent, bitangent) > 1e-12) {
        // Both formats encode +green down the texture, along the +V derivative.
        vec3 local = normalMap.rgb * 2.0 - 1.0;
#if MATERIAL_MAPS == 2
        local.z = sqrt(max(0.001, 1.0 - dot(local.xy, local.xy)));
#endif
        local.xy *= NORMAL_STRENGTH;
        local.z = max(local.z, 0.01);
        m.normal = normalize(normalize(tangent) * local.x
                           + normalize(bitangent) * local.y + geometricNormal * local.z);
    }
    m.smoothness = specMap.r;
#if MATERIAL_MAPS == 2
    // LabPBR 1.3: dielectric F0 in G=0..229; metals 230..255.
    // All predefined metal IDs use the documented albedo-metal fallback.
    m.metal = step(229.5 / 255.0, specMap.g);
    m.f0 = mix(vec3(specMap.g), albedo, m.metal);
    // Alpha 255 means a texture without emissive data, never full emission.
    m.emission = specMap.a < 254.5 / 255.0 ? specMap.a * (255.0 / 254.0) : 0.0;
#else
    m.metal = specMap.g;
    m.f0 = mix(vec3(0.04), albedo, m.metal);
    m.emission = specMap.b;
#endif
#endif
    return m;
}

// Compact GGX lobe. Smoothness is perceptual; linear roughness is its
// squared complement. The clamp avoids unstable subpixel mirror highlights.
vec3 aeroMaterialHighlight(AeroMaterial m, vec3 V, vec3 L) {
    vec3 sum = V + L;
    vec3 H = sum / max(length(sum), 0.0001);
    float nl = max(dot(m.normal, L), 0.0);
    float nv = max(dot(m.normal, V), 0.001);
    float nh = max(dot(m.normal, H), 0.0);
    float vh = max(dot(V, H), 0.0);
    float roughness = max(pow(1.0 - m.smoothness, 2.0), 0.06);
    float a2 = roughness * roughness;
    float denominator = nh * nh * (a2 - 1.0) + 1.0;
    float distribution = a2 / max(AERO_PI * denominator * denominator, 0.0001);
    float k = pow(roughness + 1.0, 2.0) * 0.125;
    float geometry = nv / (nv * (1.0 - k) + k)
                   * nl / (nl * (1.0 - k) + k);
    vec3 fresnel = m.f0 + (1.0 - m.f0) * pow(1.0 - vh, 5.0);
    return min(distribution * geometry * fresnel / max(4.0 * nv, 0.001), vec3(6.0))
         * MATERIAL_SHINE * smoothstep(0.0, 0.15, m.smoothness);
}

#endif
