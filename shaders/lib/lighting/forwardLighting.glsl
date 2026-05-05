#if defined OVERWORLD || defined END || (defined NETHER && defined MULTICOLORED_BLOCKLIGHT)
#include "/lib/lighting/shadows.glsl"
#endif

void GetLighting(inout vec3 albedo, out vec3 shadow, vec3 viewPos, vec3 worldPos, vec3 normal, 
                 vec2 lightmap, float smoothLighting, float dotNL, float vanillaDiffuse,
                 float parallaxShadow, float emission, float isEntity) {
    float skylightCurve = pow(lightmap.y, 4.0);

    #ifdef FLAT_DIRECTIONAL_LIGHTING
    if (isEntity < 0.5) dotNL = 1.0;
    #endif

    #if defined OVERWORLD || defined END
    shadow = GetShadow(worldPos, normal, dotNL, lightmap.y, isEntity);
    shadow *= parallaxShadow;
    
    #ifdef SHADOW
    vec3 fullShadow = vec3(shadow * dotNL);
    #else
    vec3 fullShadow = vec3(dotNL);
    #endif
    
    #ifdef OVERWORLD
    float shadowMult = (1.0 - 0.95 * rainStrength) * shadowFade;
    vec3 toonShadow = fullShadow * shadowMult;
    
    vec3 ambientTotal = ambientCol * lightmap.y;

    vec3 sceneLighting = mix(ambientTotal, lightCol, toonShadow);
    sceneLighting *= skylightCurve * 0.7; // Toned down brightness for flat lighting
    #endif

    #ifdef END
    vec3 sceneLighting = endCol.rgb * (0.04 * fullShadow + 0.015);
    #if MC_VERSION >= 12109
    sceneLighting *= (1.0 + endFlashIntensity) * skylightCurve;
    #endif
    #endif

    #else
    vec3 sceneLighting = netherColSqrt.rgb * 0.07;
    #endif
    
    float newLightmap  = pow(lightmap.x, 12.0) * 2.8 + lightmap.x * 0.8;
    vec3 blockLighting = blocklightCol * (newLightmap * newLightmap);
    vec3 minLighting = minLightCol * (1.0 - skylightCurve);

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
        
    // Apply the Subsurface Color Overlay only to skylight-related lighting
    // This ensures block lighting (torches, etc.) remains unaffected.
    // Subsurface Color Overlay: orange (sky-lit) → indigo (dark)
    vec3 sssOrange = vec3(1.1, 1, 1);
    vec3 sssIndigo = vec3(0.1, 0.0, 0.7);
    vec3 sssOverlay = mix(sssIndigo, sssOrange, skylightCurve);

    // Height-based factor: Sea level (Y=62) to Mountain top (Y=150)
    float worldHeight = worldPos.y + cameraPosition.y;
    float heightFactor = clamp((worldHeight - 62.0) / 56.0, 0.0, 1.0); // 150 - 62 = 88
    sssOverlay *= mix(0.85, 2.0, heightFactor); // Broadened range for stronger effect

    vec3 skyLighting = (sceneLighting + minLighting + nightVision * 0.25) * sssOverlay;
        
    albedo *= max(skyLighting + blockLighting + emissiveLighting, vec3(0.0));
}
