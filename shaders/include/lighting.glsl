#ifndef INCLUDE_LIGHTING
    #define INCLUDE_LIGHTING

    IRCResult sampleReflectionLighting (vec3 playerPos, vec3 normal, vec2 rand)
    {
        vec3 sampleUv = playerToScreenPos(playerPos);
        ivec2 sampleTexel = ivec2(sampleUv.xy * renderSize);

        float weight = exp(-128.0 * lengthSquared(playerPos - screenToPlayerPos(vec3(sampleUv.xy, texelFetch(depthtex1, sampleTexel, 0).x)).xyz)) 
                     * (1.0 - smoothstep(0.3, 0.5, abs(sampleUv.x - 0.5))) 
                     * (1.0 - smoothstep(0.3, 0.5, abs(sampleUv.y - 0.5)));

        IRCResult screen = IRCResult(vec3(0.0), vec3(0.0));
        IRCResult cache  = IRCResult(vec3(0.0), vec3(0.0));

        if (weight > 0.001) screen = IRCResult(texelFetch(colortex12, sampleTexel, 0).rgb, texelFetch(colortex5, sampleTexel, 0).rgb);

        #ifdef SMOOTH_IRCACHE
            if (weight < 0.999) cache = irradianceCacheSmooth(playerPos, normal, 0u, rand);
        #else
            if (weight < 0.999) cache = irradianceCache(playerPos, normal, 0u);
        #endif
        
        return IRCResult(mix(cache.diffuseIrradiance, screen.diffuseIrradiance, weight), mix(cache.directIrradiance, screen.directIrradiance, weight));
    }

#endif