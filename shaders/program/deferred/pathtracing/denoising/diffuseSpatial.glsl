
    #include "/include/uniforms.glsl"
    #include "/include/checker.glsl"
    #include "/include/config.glsl"
    #include "/include/constants.glsl"
    #include "/include/common.glsl"
    #include "/include/pbr.glsl"
    #include "/include/main.glsl"
    #include "/include/textureSampling.glsl"
    #include "/include/spaceConversion.glsl"

    #include "/include/text.glsl"

    /* RENDERTARGETS: 2 */
    layout (location = 0) out vec4 filteredData;

    const vec2 kernel[8] = vec2[8](
        vec2(2.0, 3.0),
        vec2(3.0, -2.0),
        vec2(-4.0, 6.0),
        vec2(6.0, 4.0),
        vec2(-16.0, 16.0),
        vec2(16.0, 16.0),
        vec2(0.0, 32.0),
        vec2(32.0, 0.0)
    );

    void main ()
    {   
        ivec2 texel = ivec2(gl_FragCoord.xy);
        float depth = texelFetch(depthtex1, texel, 0).x;

        if (depth == 1.0) 
        {
            filteredData = texelFetch(colortex2, texel, 0);
            return;
        }

        float dither = blueNoise(gl_FragCoord.xy).r;
        
        vec4 currData = texelFetch(colortex2, texel, 0);
        uint normalData = texelFetch(colortex9, texel, 0).r;
        vec3 currNormal = octDecode(unpackExp4x8(normalData).zw);
        vec3 currGeoNormal = octDecode(unpackExp4x8(normalData).xy);
        vec4 currPos = screenToPlayerPos(vec3((texel + 0.5) * texelSize, depth));

		vec2 sampleDir = kernel[FILTER_PASS] * (2.0 - smoothstep(0.0, 4.0, currData.w));
        float temporalWeight = (isnan(currData.w) ? 0.01 : clamp(currData.w, 0.01, 64.0)) * sqrt(DIFFUSE_SAMPLES) * 0.5;
        vec4 samples = vec4(0.0);
        float weights = 0.0;

        #if FILTER_PASS < 4 
            vec2 samplePos = gl_FragCoord.xy + (1.5 * dither - 1.5) * sampleDir;
            for (int i = 0; i < 2; i++, samplePos += sampleDir * 1.5) 
        #elif FILTER_PASS < 7
            vec2 samplePos = gl_FragCoord.xy + (dither - 1.5) * sampleDir;
            for (int i = 0; i < 3; i++, samplePos += sampleDir) 
        #else
            vec2 samplePos = gl_FragCoord.xy + (0.6 * dither - 1.5) * sampleDir;
            for (int i = 0; i < 5; i++, samplePos += sampleDir * 0.6) 
        #endif
        {
            ivec2 sampleCoord = ivec2(samplePos);

            if (clamp(sampleCoord, ivec2(0), ivec2(renderSize) - 1) == sampleCoord) {
                vec4 sampleData = texelFetch(colortex2, sampleCoord, 0);

                if (!any(isnan(sampleData))) {
                    vec3 sampleNormal = octDecode(unpackExp4x8(texelFetch(colortex9, sampleCoord, 0).r).zw);
                    vec3 posDiff = currPos.xyz - screenToPlayerPos(vec3((sampleCoord + 0.5) * texelSize, texelFetch(depthtex1, sampleCoord, 0).x)).xyz;

                    float sampleWeight = exp(-temporalWeight * (
                          DENOISER_NORMAL_WEIGHT * currPos.w * (-dot(sampleNormal, currNormal) * 0.5 + 0.5)
                        + DENOISER_DEPTH_WEIGHT * abs(dot(currGeoNormal, posDiff))
                        + DENOISER_SHARPENING * max(0.0, FILTER_PASS - 1.0) * pow(lengthSquared(sampleData.rgb - currData.rgb), 0.14)
                        )
                    );

                    weights += sampleWeight;
                    samples += sampleWeight * sampleData;
                }
            }
        }

        if (weights > (0.00016 * temporalWeight)) filteredData = samples / weights;
        else filteredData = currData;
    }