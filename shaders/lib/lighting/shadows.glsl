#ifdef SHADOW
#ifndef VOXY_PATCH
uniform sampler2DShadow shadowtex0;

uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

float texture2DShadow(sampler2DShadow shadowtex, vec3 shadowPos) {
    return shadow2D(shadowtex, shadowPos).x;
}

vec3 DistortShadow(vec3 shadowPos, float distortFactor) {
	shadowPos.xy /= distortFactor;
	shadowPos.z *= 0.2;
	shadowPos = shadowPos * 0.5 + 0.5;

    return shadowPos;
}

vec3 SampleBasicShadow(vec3 shadowPos) {
    float shadow0 = texture2DShadow(shadowtex0, shadowPos);

    if (shadow0 < 0.999) {
        vec3 shadowCol = texture2D(shadowcolor0, shadowPos.xy).rgb *
                        texture2DShadow(shadowtex1, shadowPos);
        #ifdef WATER_CAUSTICS
        shadowCol *= 4.0;
        #endif
        return clamp(mix(shadowCol, vec3(1.0), shadow0), vec3(0.0), vec3(16.0));
    }

    return vec3(shadow0);
}

vec3 GetShadow(vec3 worldPos, vec3 normal, float NoL, float skylight, float isEntity) {
    vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;

    // Grid snapping for blocks (16x16 pixels per block)
    if (isEntity < 0.5) {
        worldPos = (floor((worldPos + cameraPosition) * 16.0 + 0.01) + 0.1) * 0.0625 - cameraPosition;
        worldPos += worldNormal * 0.05;
    }

    vec3 rawShadowPos = ToShadow(worldPos);
    
    // Snap distortion steps to the world grid for visual consistency
    float distb = length(rawShadowPos.xy);
    distb = floor(distb * shadowDistance * 16.0 + 0.5) / (shadowDistance * 16.0);
    float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);

    vec3 shadowPos = DistortShadow(rawShadowPos, distortFactor);

    float shadowFade = clamp(100.0 - 100.0 * max(abs(rawShadowPos.x), abs(rawShadowPos.y)), 0.0, 1.0);

    #ifdef OVERWORLD
    shadowFade *= clamp(skylight * 1000.0 - 1.0, 0.0, 1.0);
    #endif

    #if defined DISTANT_HORIZONS && !defined VOXY
    float viewLength = length(worldPos);
    shadowFade *= smoothstep(far + 12.0, far - 4.0, viewLength);
    #endif

    if (shadowFade < 0.00001) return vec3(1.0);

    float bias = 0.0;
    
    float biasFactor = clamp(sqrt(1.0 - NoL * NoL) / (NoL + 0.001), 0.0, 0.1);
    float distortBias = distortFactor * shadowDistance / 256.0;
    bias = (distortBias * biasFactor * 0.1 + 0.01) / shadowMapResolution;

    if (isEntity > 1.5) bias += 0.05 / 16.0;
    else if (isEntity < 0.5) bias += 0.001 / 16.0;
    else bias += 0.001 / 16.0;

    shadowPos.z -= bias;

    vec3 shadow = SampleBasicShadow(shadowPos);

    return mix(vec3(1.0), shadow, shadowFade);
}
#endif
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

float GetCloudShadow(vec3 worldPos) {
	return 1.0;
}