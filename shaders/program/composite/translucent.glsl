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

    float depth  = texelFetch(depthtex0, texel, 0).r;
    float depth1 = texelFetch(depthtex1, texel, 0).r;
    color        = texelFetch(colortex7, texel, 0);
    virtualDepth = texelFetch(colortex13, texel, 0);

    if (depth1 == depth) return;
    
    TranslucentMaterial mat = unpackTranslucentMaterial(texel);

    vec3 rayColor = vec3(0.0);

    vec3 rayPos = screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, depth)).xyz;

    if (mat.isHand) {
        rayPos += 0.5 * playerLookVector;
    }

    vec3 rayDir = normalize(rayPos - screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, 0.000001)).xyz);
    Ray ray = Ray(rayPos + mat.normal * 0.01, reflect(rayDir, mat.normal));

    RayHitInfo rt = TraceRay(ray, REFLECTION_MAX_RT_DISTANCE, true, true);

    if (rt.hit) {
        IRCResult r = sampleReflectionLighting(ray.origin + rt.dist * ray.direction, rt.normal, blueNoise(gl_FragCoord.xy).rg, 0.3);

        rayColor += rt.albedo.rgb * rt.emission + max(rt.albedo.rgb, rt.F0) * r.diffuseIrradiance + getLightTransmittance(shadowDir) * lightBrightness * r.directIrradiance * evalCookBRDF(normalize(shadowDir + rt.normal * 0.03125), ray.direction, max(0.1, rt.roughness), rt.normal, rt.albedo.rgb, rt.F0);
    } else {
        rayColor += rt.albedo.rgb * sampleSkyView(ray.direction);
    }

    #if defined GLASS_REFRACTION || defined WATER_REFRACTION
        vec3 throughput = vec3(0.25);
        vec3 refractColor = vec3(0.0); 
        
        if (
            #if defined GLASS_REFRACTION && defined WATER_REFRACTION
                mat.blockId == 99 || mat.blockId == 100
            #elif defined GLASS_REFRACTION
                mat.blockId == 99
            #else
                mat.blockId == 100
            #endif
        ) {
            Ray refractRay = Ray(rayPos - mat.normal * 0.01, refract(rayDir, mat.normal, rcp(GLASS_IOR)));
            bool medium = true;

            for (int i = 0; i < REFRACTION_BOUNCES; i++) {
                RayHitInfo refraction = TraceRay(refractRay, 1024.0, true, i == (REFRACTION_BOUNCES - 1));

                if (refraction.hit) {
                    vec3 hitPos = refractRay.origin + refractRay.direction * refraction.dist;
                    vec3 nextDir = refract(refractRay.direction, refraction.normal, medium ? GLASS_IOR : rcp(GLASS_IOR));

                    if (
                        (!mat.isHand && medium && nextDir == vec3(0.0)) || 
                        #if defined GLASS_REFRACTION && defined WATER_REFRACTION
                            refraction.blockId == 99 || refraction.blockId == 100
                        #elif defined GLASS_REFRACTION
                            refraction.blockId == 99
                        #else
                            refraction.blockId == 100
                        #endif
                    ) {
                        if (nextDir == vec3(0.0)) {
                            refractRay.origin = hitPos + refraction.normal * 0.005;
                            refractRay.direction = reflect(refractRay.direction, refraction.normal);
                            throughput *= 1.45;
                        } else {
                            refractRay.origin = hitPos - refraction.normal * 0.005;
                            refractRay.direction = nextDir;
                            throughput *= mix(vec3(1.0), refraction.albedo.rgb, GLASS_OPACITY);
                            medium = !medium;
                        }
                    } else {
                        IRCResult r = sampleReflectionLighting(hitPos, refraction.normal, blueNoise(gl_FragCoord.xy).rg, 0.45);

                        refractColor += throughput * (refraction.albedo.rgb * refraction.emission + refraction.albedo.rgb * r.diffuseIrradiance + getLightTransmittance(shadowDir) * lightBrightness * r.directIrradiance * evalCookBRDF(normalize(shadowDir + refraction.normal * 0.03125), refractRay.direction, refraction.roughness, refraction.normal, refraction.albedo.rgb, refraction.F0));
                    }
                } else {
                    refractColor += throughput * sampleSkyView(refractRay.direction);
                    break;
                }
            }
        } else {
            refractColor = color.rgb;
        }
    #else
        vec3 refractColor = color.rgb;
    #endif

    vec3 transmittance;

    if (mat.blockId == 100) transmittance = exp(-vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * distance(rayPos.xyz, screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, depth1)).xyz));
    else transmittance = mix(vec3(1.0), mat.albedo.rgb, GLASS_OPACITY);

    virtualDepth.r = max(texelFetch(colortex13, texel, 0).r, rt.hit ? playerToScreenPos(rayPos.xyz + rayDir * rt.dist).z : 0.0);

    color = vec4(mix(refractColor.rgb * transmittance, rayColor, schlickFresnel(vec3(mat.blockId == 100 ? WATER_REFLECTANCE : GLASS_REFLECTANCE), -dot(rayDir, mat.normal))), 1.0);
}