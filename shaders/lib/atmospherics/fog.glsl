#ifdef OVERWORLD
vec3 GetFogColor(vec3 viewPos) {
	vec3 nViewPos = normalize(viewPos);
	float lViewPos = length(viewPos) / 64.0;
	lViewPos = 1.0 - exp(-lViewPos * lViewPos);

    float VoU = clamp(dot(nViewPos,  upVec), -1.0, 1.0);
    float VoL = clamp(dot(nViewPos, sunVec), -1.0, 1.0);

	float density = 0.4;
    float nightDensity = 1.0;
    float weatherDensity = 1.5;
    float groundDensity = 0.08 * (4.0 - 3.0 * sunSkyVisibility) *
                          (10.0 * rainStrength * rainStrength + 1.0);
    
    float exposure = 1.0;
    float nightExposure = 1.0;

	float baseGradient = exp(-(VoU * 0.5 + 0.5) * 0.5 / density);

	float groundVoU = clamp(-VoU * 0.5 + 0.5, 0.0, 1.0);
    float ground = 1.0 - exp(-groundDensity / groundVoU);

    vec3 fog = skyCol;
	#ifdef USE_FOG_COLOR
    fog = mix(skyCol, fogCol, FOG_BLEND);
	#endif
	fog *= baseGradient / (SKY_I * SKY_I);
    fog = fog / sqrt(fog * fog + 1.0) * exposure * sunSkyVisibility * (SKY_I * SKY_I);

	float sunMix = pow((VoL * 0.5 + 0.5) * clamp(1.0 - VoU, 0.0, 1.0), 2.0 - sunSkyVisibility) *
                   pow(1.0 - timeBrightness * 0.6, 3.0);
    float horizonMix = pow(1.0 - abs(VoU), 2.5) * 0.125;
    float lightMix = (1.0 - (1.0 - sunMix) * (1.0 - horizonMix)) * lViewPos;

	vec3 lightFog = pow(lightSun, vec3(4.0 - sunSkyVisibility)) * baseGradient;
	lightFog = lightFog / (1.0 + lightFog * rainStrength);

    fog = mix(
        sqrt(fog * (1.0 - lightMix)), 
        sqrt(lightFog), 
        lightMix
    );
    fog *= fog;

	float nightGradient = exp(-(VoU * 0.5 + 0.5) * 0.35 / nightDensity);
    vec3 nightFog = lightNight * lightNight * nightGradient * nightExposure;

    fog = mix(nightFog, fog, sunSkyVisibility * sunSkyVisibility);

    float rainGradient = exp(-(VoU * 0.5 + 0.5) * 0.125 / weatherDensity);
    vec3 weatherFog = weatherCol.rgb * weatherCol.rgb;
    weatherFog *= GetLuminance(ambientCol / (weatherFog)) * (0.2 * sunSkyVisibility + 0.2);
    fog = mix(fog, weatherFog * rainGradient, rainStrength);

	float exteriorFactor = eBS;
	#ifdef FOG_INTERIOR
	exteriorFactor = max(exteriorFactor, clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0));
	#endif
	
	fog = mix(minLightCol * 0.5, fog * exteriorFactor, exteriorFactor);


	#ifdef IS_IRIS
	fog *= clamp((cameraPosition.y - bedrockLevel + 6.0) / 8.0, 0.0, 1.0);
	#else
	#if MC_VERSION >= 11800
	fog *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	fog *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif
	#endif

	return fog;
}
#endif

void NormalFog(inout vec3 color, vec3 viewPos) {
	float viewLength = length(viewPos);
	
	#ifdef OVERWORLD
	float fogFar = far;
	#if defined DISTANT_HORIZONS || defined VOXY
	fogFar = max(fogFar, 256.0);
	#ifdef VOXY
	fogFar = max(fogFar, vxRenderDistance * 16.0);
	#endif
	#ifdef DISTANT_HORIZONS
	fogFar = max(fogFar, float(dhRenderDistance));
	#endif
	#endif

	float fog = viewLength * (fogDensity * 1.5) / fogFar;
	fog = 1.0 - exp(-2.5 * fog * fog);

	vec3 fogColor = GetFogColor(viewPos);
	#endif

	#ifdef NETHER
	float fog = viewLength * fogDensity / 128.0;
	fog = 1.0 - exp(-fog);
	vec3 fogColor = netherCol.rgb * 0.0425;
	#endif

	#ifdef END
	float fog = viewLength * fogDensity / 256.0;
	fog = 1.0 - exp(-fog);
	vec3 fogColor = endCol.rgb * 0.012;
	#endif
	
	color = mix(color, fogColor, clamp(fog, 0.0, 1.0));
}

void BlindFog(inout vec3 color, vec3 viewPos) {
	float fog = length(viewPos) * max(blindFactor * 0.2, darknessFactor * 0.075);
	fog = (1.0 - exp(-6.0 * fog * fog * fog)) * max(blindFactor, darknessFactor);
	color = mix(color, vec3(0.0), fog);
}

vec3 denseFogColor[2] = vec3[2](
	vec3(1.0, 0.3, 0.01),
	vec3(0.1, 0.16, 0.2)
);

void DenseFog(inout vec3 color, vec3 viewPos) {
	float fog = length(viewPos) * 0.5;
	fog = (1.0 - exp(-4.0 * fog * fog * fog));
	color = mix(color, denseFogColor[isEyeInWater - 2], fog);
}

void Fog(inout vec3 color, vec3 viewPos) {
	NormalFog(color, viewPos);
	if (isEyeInWater > 1) DenseFog(color, viewPos);
	if (blindFactor > 0.0 || darknessFactor > 0.0) BlindFog(color, viewPos);
}