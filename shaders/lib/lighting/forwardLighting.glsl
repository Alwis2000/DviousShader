#if defined OVERWORLD || defined END || (defined NETHER && defined MULTICOLORED_BLOCKLIGHT)
#include "/lib/lighting/shadows.glsl"
#endif

void GetLighting(inout vec3 albedo, out vec3 shadow, vec3 viewPos, vec3 worldPos, vec3 normal, 
                 vec2 lightmap, float smoothLighting, float dotNL, float vanillaDiffuse,
                 float parallaxShadow, float emission, float isEntity) {
    smoothLighting = 1.0;


    float skylightSqr = lightmap.y * lightmap.y;

    #ifdef FLAT_DIRECTIONAL_LIGHTING
    if (isEntity < 0.5) dotNL = 1.0;
    #endif

    #if defined OVERWORLD || defined END
    shadow = GetShadow(worldPos, normal, dotNL, lightmap.y, isEntity);
    shadow *= parallaxShadow;
    
    #ifdef SHADOW
    vec3 fullShadow = max(shadow * dotNL, vec3(0.0));
    #else
    vec3 fullShadow = vec3(shadow);
    #ifdef OVERWORLD
    float timeBrightnessAbs = abs(sin(timeAngle * 6.28318530718));
    fullShadow *= 0.25 + 0.5 * (1.0 - (1.0 - timeBrightnessAbs) * (1.0 - timeBrightnessAbs));
    #else
    fullShadow *= 0.75;
    #endif
    #endif

    fullShadow = mix(vec3(1.0), fullShadow, 1.05);
    
    #ifdef OVERWORLD
    float shadowMult = (1.0 - 0.95 * rainStrength) * shadowFade;
    vec3 toonShadow = fullShadow * shadowMult;
    
    vec3 ambientPart = (ambientCol * lightmap.y + minIndigo) * shadowToning;
    vec3 directPart = lightCol * vanillaDiffuse;
    vec3 sceneLighting = mix(ambientPart, directPart, toonShadow);
    sceneLighting *= skylightSqr;
    #endif

    #ifdef END
    vec3 ambientPart = endCol.rgb * 0.015;
    vec3 directPart = endCol.rgb * 0.04 * vanillaDiffuse;
    vec3 sceneLighting = ambientPart + directPart * fullShadow;
    #if MC_VERSION >= 12109
    sceneLighting *= (1.0 + endFlashIntensity) * skylightSqr;
    #endif
    #endif

    #else
    vec3 sceneLighting = netherColSqrt.rgb * 0.07;
    #endif
    
    float newLightmap  = pow(lightmap.x, 12.0) * 2.8 + lightmap.x * 0.8;
    vec3 blockLighting = blocklightCol * (newLightmap * newLightmap);
    vec3 minLighting = minLightCol * (1.0 - skylightSqr);

    #ifdef TOON_LIGHTMAP
    minLighting *= floor(smoothLighting * 8.0 + 1.001) / 4.0;
    smoothLighting = 1.0;
    #endif
    
    vec3 albedoNormalized = normalize(albedo.rgb + 0.00001);
    emission = pow(emission, max(EMISSIVE_CURVE, 1.0));
    vec3 emissiveLighting = mix(albedoNormalized, vec3(1.0), emission * 0.5);
    emissiveLighting *= emission * EMISSIVE_INTENSITY;

    float lightFlatten = clamp(1.0 - pow(1.0 - emission, 128.0), 0.0, 1.0);
    vanillaDiffuse = mix(vanillaDiffuse, 1.0, lightFlatten);
    smoothLighting = mix(smoothLighting, 1.0, lightFlatten);
        
    albedo *= max(sceneLighting + blockLighting + emissiveLighting + minLighting + nightVision * 0.25, vec3(0.0));
    
    #ifdef FLAT_DIRECTIONAL_LIGHTING
    if (isEntity > 0.5) albedo *= vanillaDiffuse;
    albedo *= smoothLighting * smoothLighting;
    #else
    albedo *= smoothLighting * smoothLighting;
    #endif
}
