#if defined SHADOW && !defined VOXY_PATCH
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

float texture2DShadow(sampler2D shadowtex, ivec2 pixelCoord, float z) {
    float depth = texelFetch(shadowtex, pixelCoord, 0).r;
    return step(z, depth);
}

vec4 DistortShadow(vec3 shadowPos) {
    float r = length(shadowPos.xy);
    float rCenter = 48.0 / shadowDistance;
    float densityRatio = (16.0 * 2.0 * shadowDistance) / float(shadowMapResolution);
    densityRatio = min(densityRatio, 0.95 / rCenter);

    float biasMult = 1.0;

    if (r > 0.0001) {
        float distortedR;
        if (r < rCenter) {
            distortedR = r * densityRatio;
            biasMult = 1.0;
        } else {
            float r1 = (r - rCenter) / (1.0 - rCenter);
            float k = SHADOW_DISTORTION;
            float distorted = r1 / (1.0 - k + k * r1);
            float start = rCenter * densityRatio;
            distortedR = mix(start, 1.0, distorted);

            float deriv = (1.0 - start) / (1.0 - rCenter) * (1.0 - k) / pow(1.0 - k + k * r1, 2.0);
            biasMult = densityRatio / max(deriv, 0.0001);
        }
        shadowPos.xy *= (distortedR / r);
    }

    shadowPos.z *= 0.2;
    shadowPos = shadowPos * 0.5 + 0.5;

    return vec4(shadowPos, biasMult);
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

    // Local resolution-aware bias scaling
    vec3 initialRawShadowPos = ToShadow(worldPos);
    vec4 initialDistorted = DistortShadow(initialRawShadowPos);
    float localBiasMult = initialDistorted.w;

    // Shadow Bias calculations
    float slopeBias = clamp(1.0 - NoL, 0.0, 1.0);
    float biasMultiplier = SHADOW_MAP_BIAS * localBiasMult;

    // Normal Offset Bias
    float distBias = sqrt(shadowDistance / 128.0);
    float normalOffset = 0.003 * distBias * (1.0 + slopeBias);
    if (isEntity > 0.5) normalOffset *= 0.2;

    worldPos += worldNormal * normalOffset * biasMultiplier;

    // Grid snapping for blocks (Adaptive pixel lock)
    if (isEntity < 0.5) {
        #if SHADOW_PIXEL > 0
        float lockDensity = float(SHADOW_PIXEL) / localBiasMult;
        worldPos = (floor((worldPos + cameraPosition) * lockDensity + 0.01) + 0.1) / lockDensity - cameraPosition;
        #endif
    }

    vec3 rawShadowPos = ToShadow(worldPos);
    vec3 shadowPos = DistortShadow(rawShadowPos).xyz;

    float shadowFade = clamp(100.0 - 100.0 * max(abs(rawShadowPos.x), abs(rawShadowPos.y)), 0.0, 1.0);

    #ifdef OVERWORLD
    shadowFade *= clamp(skylight * 1000.0 - 1.0, 0.0, 1.0);
    #endif

    #if defined DISTANT_HORIZONS && !defined VOXY
    float viewLength = length(worldPos);
    shadowFade *= smoothstep(far + 12.0, far - 4.0, viewLength);
    #endif

    if (shadowFade < 0.00001) return vec3(1.0);

    // Depth Bias
    float bias = 0.00010 * (1.0 + slopeBias);

    shadowPos.z -= bias * biasMultiplier;

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
