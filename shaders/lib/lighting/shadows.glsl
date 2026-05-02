#if defined SHADOW && !defined VOXY_PATCH
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

float texture2DShadow(sampler2D shadowtex, ivec2 pixelCoord, float z) {
    float depth = texelFetch(shadowtex, pixelCoord, 0).r;
    return step(z, depth);
}

vec3 DistortShadow(vec3 shadowPos) {
	shadowPos.z *= 0.2;
	shadowPos = shadowPos * 0.5 + 0.5;

    return shadowPos;
}

vec3 SampleBasicShadow(vec3 shadowPos) {
    ivec2 pixelCoord = ivec2(shadowPos.xy * float(shadowMapResolution));
    float shadow0 = texture2DShadow(shadowtex0, pixelCoord, shadowPos.z);

    #ifdef SHADOW_COLOR
    if (shadow0 < 0.999) {
        vec3 shadowCol = texelFetch(shadowcolor0, pixelCoord, 0).rgb *
                        texture2DShadow(shadowtex1, pixelCoord, shadowPos.z);
        #ifdef WATER_CAUSTICS
        shadowCol *= 4.0;
        #endif
        return clamp(mix(shadowCol, vec3(1.0), shadow0), vec3(0.0), vec3(16.0));
    }
    #endif

    return vec3(shadow0);
}

vec3 GetShadow(vec3 worldPos, vec3 normal, float NoL, float skylight, float isEntity) {
    vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;

    // Grid snapping for blocks (16x16 pixels per block)
    if (isEntity < 0.5) {
        #if SHADOW_PIXEL > 0
        worldPos = (floor((worldPos + cameraPosition) * float(SHADOW_PIXEL) + 0.01) + 0.1) / float(SHADOW_PIXEL) - cameraPosition;
        #endif
        worldPos += worldNormal * (0.02 * (shadowDistance / 128.0) * (1.0 + 1.0 * clamp(1.0 - NoL, 0.0, 1.0)));
    }

    vec3 rawShadowPos = ToShadow(worldPos);
    
    vec3 shadowPos = DistortShadow(rawShadowPos);

    float shadowFade = clamp(100.0 - 100.0 * max(abs(rawShadowPos.x), abs(rawShadowPos.y)), 0.0, 1.0);

    #ifdef OVERWORLD
    shadowFade *= clamp(skylight * 1000.0 - 1.0, 0.0, 1.0);
    #endif

    #if defined DISTANT_HORIZONS && !defined VOXY
    float viewLength = length(worldPos);
    shadowFade *= smoothstep(far + 12.0, far - 4.0, viewLength);
    #endif

    if (shadowFade < 0.00001) return vec3(1.0);

    float bias = 0.00025;
    
    #if SHADOW_PIXEL > 0
    if (isEntity > 1.5) bias += 0.001 / float(SHADOW_PIXEL);
    else if (isEntity < 0.5) bias += 0.0005 / float(SHADOW_PIXEL);
    else bias += 0.0005 / float(SHADOW_PIXEL);
    #else
    if (isEntity > 1.5) bias += 0.002 / 16.0;
    else if (isEntity < 0.5) bias += 0.0005 / 16.0;
    else bias += 0.0005 / 16.0;
    #endif

    shadowPos.z -= bias;

    vec3 shadow = SampleBasicShadow(shadowPos);

    return mix(vec3(1.0), shadow, shadowFade);
}
#else
vec3 GetShadow(vec3 worldPos, vec3 normal, float NoL, float skylight, float isEntity) {
    #ifdef OVERWORLD
    float skylightShadow = smoothstep(SHADOW_SKY_FALLOFF * 0.5, 1.0, skylight);


    return vec3(skylightShadow);
    #else
    return vec3(1.0);
    #endif
}
#endif
