#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/octree.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/brdf.glsl"
#include "/include/ircache.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/textureSampling.glsl"
#include "/include/atmosphere.glsl"
#include "/include/heitz.glsl"
#include "/include/lighting.glsl"
#include "/include/text.glsl"

/* RENDERTARGETS: 7,13 */
layout (location = 0) out vec4 color;
layout (location = 1) out vec4 virtualDepth;

void main ()
{
    ivec2 texel = ivec2(gl_FragCoord.xy);

    float depth = texelFetch(depthtex0, texel, 0).r;
    float depth1 = texelFetch(depthtex1, texel, 0).r;
    color = texelFetch(colortex7, texel, 0);
    virtualDepth = texelFetch(colortex13, texel, 0);

    if (depth1 == depth) return;
    
    TranslucentMaterial mat = unpackTranslucentMaterial(texel);

    vec3 rayColor = vec3(0.0);

    vec4 rayPos = screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, depth));
    vec3 rayDir = normalize(rayPos.xyz - screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, 0.000001)).xyz);
    Ray ray = Ray(rayPos.xyz + mat.normal * 0.01, reflect(rayDir, mat.normal));

    RayHitInfo rt = TraceRay(ray, 1024.0, true, true);

    rayColor += rt.albedo.rgb * rt.emission;

    vec3 hitPos = ray.origin + rt.dist * ray.direction;

    if (rt.hit) {
        IRCResult r = sampleReflectionLighting(hitPos, rt.normal, blueNoise(gl_FragCoord.xy).rg);

        rayColor += max(rt.albedo.rgb, rt.F0) * r.diffuseIrradiance;
        rayColor += getLightTransmittance(shadowDir) * lightBrightness * r.directIrradiance * evalCookBRDF(shadowDir, ray.direction, max(0.1, rt.roughness), rt.normal, rt.albedo.rgb, rt.F0);
    } else {
        rayColor += rt.albedo.rgb * sampleSkyView(ray.direction);
    }

    vec3 transmittance;

    if (mat.blockId == 100) transmittance = exp(-vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * distance(rayPos.xyz, screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, depth1)).xyz));
    else transmittance = mat.albedo.rgb;

    virtualDepth.r = max(texelFetch(colortex13, texel, 0).r, rt.hit ? playerToScreenPos(rayPos.xyz + rayDir * rt.dist).z : 0.0);

    color = vec4(mix(color.rgb * transmittance, rayColor, schlickFresnel(vec3(mat.blockId == 100 ? WATER_REFLECTANCE : GLASS_REFLECTANCE), -dot(rayDir, mat.normal))), 1.0);
}