/* 
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Global Uniforms//
uniform int moonPhase;
uniform int worldTime;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform vec3 cameraPosition;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

//Includes//
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/dither.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH
//Varyings//
varying float mat;
varying float dist;

varying vec2 texCoord, lmCoord;

varying vec3 normal, binormal, tangent;
varying vec3 sunVec, upVec, eastVec;
varying vec3 viewVector;
varying vec3 vViewPos, vWorldPos, vShadowPos; // Added varyings for performance

varying vec4 color;
varying vec4 vTexCoord, vTexCoordAM;

#ifdef IRIS_FEATURE_FADE_VARIABLE
varying float chunkFade;
#endif

//Common Variables//
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float moonVisibility = clamp(dot(-sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif

#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/lightSkyColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/specularColor.glsl"
#include "/lib/color/waterColor.glsl"

//Uniforms//
uniform int bedrockLevel;
uniform int frameCounter;
uniform int isEyeInWater;

uniform float blindFactor, darknessFactor, nightVision;
uniform float cloudHeight;
uniform float endFlashIntensity;
uniform float far, near;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 previousCameraPosition;
uniform vec3 relativeEyePosition;

uniform mat4 gbufferProjection, gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform sampler2D texture;
uniform sampler2D gaux2;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#ifdef ADVANCED_MATERIALS
uniform ivec2 atlasSize;

uniform sampler2D specular;
uniform sampler2D normals;

#ifdef REFLECTION_RAIN
uniform float wetness;
#endif
#endif

#if DYNAMIC_HANDLIGHT > 0
uniform int heldBlockLightValue, heldBlockLightValue2;
#endif

#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
uniform int heldItemId, heldItemId2;
#endif

#ifdef MULTICOLORED_BLOCKLIGHT
uniform sampler3D lighttex0;
uniform sampler3D lighttex1;
#endif

#ifdef MCBL_SS
uniform sampler2D colortex8;
uniform sampler2D colortex9;
#endif

#if CLOUDS == 2
uniform sampler2D gaux1;
#endif

#ifdef VOXY
uniform int vxRenderDistance;

uniform mat4 vxProjInv;

uniform sampler2D vxDepthTexOpaque;
#endif

#ifdef DISTANT_HORIZONS
uniform int dhRenderDistance;
uniform float dhFarPlane;

uniform mat4 dhProjectionInverse;

uniform sampler2D dhDepthTex1;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
vec2 dcdx = dFdx(texCoord);
vec2 dcdy = dFdy(texCoord);

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetWaterHeightMap(vec3 worldPos, vec2 offset) {
    float noise = 0.0, noiseA = 0.0, noiseB = 0.0;
    
    vec2 wind = vec2(time) * 0.5 * WATER_SPEED;

	worldPos.xz += worldPos.y * 0.2;

	#if WATER_NORMALS == 1
	offset /= 256.0;
	noiseA = texture2DLod(noisetex, (worldPos.xz - wind) / 256.0 + offset, 0).g;
	noiseB = texture2DLod(noisetex, (worldPos.xz + wind) / 48.0 + offset, 0).g;
	#elif WATER_NORMALS == 2
	offset /= 256.0;
	noiseA = texture2DLod(noisetex, (worldPos.xz - wind) / 256.0 + offset, 0).r;
	noiseB = texture2DLod(noisetex, (worldPos.xz + wind) / 96.0 + offset, 0).r;
	noiseA *= noiseA; noiseB *= noiseB;
	#endif
	
	#if WATER_NORMALS > 0
	noise = mix(noiseA, noiseB, WATER_DETAIL);
	#endif

    return noise * WATER_BUMP;
}

vec3 GetParallaxWaves(vec3 worldPos, vec3 viewVector) {
	float height = -0.5 * GetWaterHeightMap(worldPos, vec2(0.0)) + 0.1;
	worldPos.xz += (height * viewVector.xy / dist) * 0.4;
	return worldPos;
}

vec3 GetWaterNormal(vec3 worldPos, vec3 viewPos, vec3 viewVector) {
	vec3 waterPos = worldPos + cameraPosition;

	#if WATER_PIXEL > 0
	waterPos = floor(waterPos * WATER_PIXEL) / WATER_PIXEL;
	#endif

	#ifdef WATER_PARALLAX
	waterPos = GetParallaxWaves(waterPos, viewVector);
	#endif

	float normalOffset = WATER_SHARPNESS;
	
	float h0 = GetWaterHeightMap(waterPos, vec2(0.0));
	float h1 = GetWaterHeightMap(waterPos, vec2(normalOffset, 0.0));
	float h2 = GetWaterHeightMap(waterPos, vec2(0.0, normalOffset));

	float xDelta = (h0 - h1) / normalOffset;
	float yDelta = (h0 - h2) / normalOffset;

	vec3 normalMap = normalize(vec3(xDelta, yDelta, 0.25));
	return normalMap;
}

void NetherPortalParallax(inout vec4 albedo, float dither) {
	int sampleCount = 4;
	float parallaxDepth = 0.125;

	#ifdef TAA
	dither = fract(dither + frameCounter * 0.618);
	#endif
	
	for (int i = 0; i < sampleCount; i++) {
		float currentDepth = float(i + dither) / sampleCount * parallaxDepth;
		float weight = 1.0 - currentDepth * 2.0;

		vec2 offset = viewVector.xy / -viewVector.z * currentDepth;
		vec2 newCoord = fract(vTexCoord.st + offset) * vTexCoordAM.pq + vTexCoordAM.st;

		vec4 parallaxSample = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
		albedo = max(albedo, parallaxSample * weight);
	}
}

#include "/lib/atmospherics/weatherDensity.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/atmospherics/chunkFade.glsl"
#include "/lib/lighting/dynamicHandlight.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/reflections/raytrace.glsl"
#include "/lib/reflections/simpleReflections.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/surface/hardcodedEmission.glsl"

#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef ADVANCED_MATERIALS

#include "/lib/surface/directionalLightmap.glsl"


#ifdef REFLECTION_RAIN
#include "/lib/reflections/rainPuddles.glsl"
#endif
#endif

#ifdef MULTICOLORED_BLOCKLIGHT
#include "/lib/util/voxelMapHelper.glsl"
#endif

#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
#include "/lib/lighting/coloredBlocklight.glsl"
#endif

#define ToShadow(pos) vShadowPos // Optimization: Use varying instead of per-fragment matrix math

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * vec4(color.rgb, 1.0);
	vec3 vlAlbedo = vec3(1.0);
	vec3 lightAlbedo = vec3(0.0);
	vec3 newNormal = normal;
	float smoothness = 0.0;
	vec3 refraction = vec3(0.0);
	
	#ifdef ADVANCED_MATERIALS
	vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
	float surfaceDepth = 1.0;
	float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
	float skipParallax = float(mat > 0.98 && mat < 1.02);
		  skipParallax+= float(mat > 4.98 && mat < 5.02);

	#ifdef PARALLAX_PORTAL
		  skipParallax+= float(mat > 3.98 && mat < 4.02);
	#endif
	

	#endif

	float cloudBlendOpacity = 1.0;

	{
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		
		float water       = float(mat > 0.98 && mat < 1.02);
		float glass 	  = float(mat > 1.98 && mat < 2.02);
		float translucent = float(mat > 2.98 && mat < 3.02);
		float portal      = float(mat > 3.98 && mat < 4.02);
		
		float emission        = portal;
		vec3 baseReflectance  = vec3(0.04);

		vec3 hsv = RGB2HSV(albedo.rgb);
		emission *= GetHardcodedEmission(albedo.rgb, hsv);
		
		#ifndef REFLECTION_TRANSLUCENT
		glass = 0.0;
		translucent = 0.0;
		#endif

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		vec3 viewPos = vViewPos;
		vec3 worldPos = vWorldPos;

		float dither = Bayer8(gl_FragCoord.xy);
		float viewLength = length(viewPos);

		#if CLOUDS == 2
		float cloudMaxDistance = 2.0 * far;
		#ifdef VOXY
		cloudMaxDistance = max(cloudMaxDistance, vxRenderDistance * 16.0);
		#endif
		#ifdef DISTANT_HORIZONS
		cloudMaxDistance = max(cloudMaxDistance, dhFarPlane);
		#endif

		float cloudViewLength = texture2D(gaux1, screenPos.xy).r * cloudMaxDistance;

		cloudBlendOpacity = step(viewLength, cloudViewLength);

		if (cloudBlendOpacity == 0) {
			discard;
		}
		// albedo.rgb *= fract(viewLength);
		#endif
		
		#if defined DISTANT_HORIZONS && !defined VOXY
		float minDist = (dither - 0.75) * 16.0 + far;
		if (viewLength > minDist) {
			discard;
		}
		#endif

		vec3 normalMap = vec3(0.0, 0.0, 1.0);
		
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

		#if WATER_NORMALS > 0
		if (water > 0.5) {
			#if WATER_NORMALS == 1 || WATER_NORMALS == 2
			normalMap = GetWaterNormal(worldPos, viewPos, viewVector);
			newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
			#elif WATER_NORMALS == 3 && defined ADVANCED_MATERIALS
			float tempF0 = 0.04, tempPorosity = 0.0, tempAo = 1.0;
			vec3 normalMap = vec3(0.0, 0.0, 1.0);
			smoothness = 0.9;
			emission = 0.0;

			newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
			#endif
		}
		#endif

		#ifdef ADVANCED_MATERIALS
		if (water < 0.5) {
			float f0 = 0.04, porosity = 0.0, ao = 1.0;
			vec3 normalMap = vec3(0.0, 0.0, 1.0);
			smoothness = 0.0;

			if ((normalMap.x > -0.999 || normalMap.y > -0.999) && viewVector == viewVector)
				newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		}
		#endif

		#if REFRACTION == 1
		refraction = vec3((newNormal.xy - normal.xy) * 0.5 + 0.5, float(albedo.a < 0.95) * water);
		#elif REFRACTION == 2
		refraction = vec3((newNormal.xy - normal.xy) * 0.5 + 0.5, float(albedo.a < 0.95));
		#endif
		
		#if DYNAMIC_HANDLIGHT == 2
		lightmap = ApplyDynamicHandlight(lightmap, worldPos);
		#endif

		#ifdef TOON_LIGHTMAP
		lightmap = floor(lightmap * 14.999 * (0.75 + 0.25 * color.a)) / 14.0;
		lightmap = clamp(lightmap, vec2(0.0), vec2(1.0));
		#endif

		#ifdef PARALLAX_PORTAL
		if (portal > 0.5) {
			NetherPortalParallax(albedo, dither);
		}
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));
		
		vlAlbedo = albedo.rgb;

		lightAlbedo = albedo.rgb + 0.00001;
		#ifdef MCBL_SS
		vec3 opaquelightAlbedo = texture2D(colortex8, screenPos.xy).rgb;
		if (water < 0.5) {
			opaquelightAlbedo *= vlAlbedo;
		}

		if (portal > 0.5) {
			lightAlbedo = lightAlbedo * 0.95 + 0.05;
		}

		lightAlbedo = normalize(lightAlbedo + 0.00001) * emission;
		lightAlbedo = mix(opaquelightAlbedo, sqrt(lightAlbedo), albedo.a);

		#ifdef MULTICOLORED_BLOCKLIGHT
		lightAlbedo *= GetMCBLLegacyMask(worldPos);
		#endif
		#endif

		#ifdef WHITE_WORLD
		albedo.rgb = vec3(0.35);
		#endif
		
		if (water > 0.5) {
			#if WATER_MODE == 0
			albedo.rgb = waterColor.rgb * waterColor.a;
			#elif WATER_MODE == 1
			albedo.rgb *= WATER_VI * WATER_VI;
			#elif WATER_MODE == 2
			float waterLuma = length(albedo.rgb / pow(color.rgb, vec3(2.2))) * 2.0;
			albedo.rgb = waterLuma * waterColor.rgb * waterColor.a;
			#elif WATER_MODE == 3
			albedo.rgb = color.rgb * color.rgb * WATER_VI * WATER_VI;
			#endif
			#if WATER_ALPHA_MODE == 0
			albedo.a = waterAlpha;
			#else
			albedo.a = pow(albedo.a, WATER_VA);
			#endif
			vlAlbedo = sqrt(albedo.rgb);
			baseReflectance = vec3(0.02);
		}
		
		#if WATER_FOG == 1
		vec3 fogAlbedo = albedo.rgb;
		#endif
		
		vlAlbedo = mix(vec3(1.0), vlAlbedo, sqrt(albedo.a)) * (1.0 - pow(albedo.a, 64.0));
		
		#ifndef HALF_LAMBERT
		float NoL = clamp(dot(newNormal, lightVec), 0.0, 1.0);
		#else
		float NoL = clamp(dot(newNormal, lightVec) * 0.5 + 0.5, 0.0, 1.0);
		NoL *= NoL;
		#endif

		float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
		float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
		float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
			  vanillaDiffuse*= vanillaDiffuse;

		float parallaxShadow = 1.0;
		#ifdef ADVANCED_MATERIALS
		vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
		albedo.rgb *= ao;

		#ifdef REFLECTION_SPECULAR
		albedo.rgb *= 1.0;
		#endif
		
		#ifdef SELF_SHADOW
		if (lightmap.y > 0.0 && NoL > 0.0 && water < 0.5) {
			parallaxShadow = GetParallaxShadow(surfaceDepth, parallaxFade, newCoord, lightVec,
											   tbnMatrix);
		}
		#endif

		#ifdef DIRECTIONAL_LIGHTMAP
		mat3 lightmapTBN = GetLightmapTBN(viewPos);
		lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, newNormal, lightmapTBN);
		lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, newNormal, lightmapTBN);
		#endif
		#endif

		#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
		blocklightCol = ApplyMultiColoredBlocklight(blocklightCol, screenPos, worldPos, newNormal, 0.0);
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, normal, lightmap, 1.0, NoL, 
					vanillaDiffuse, parallaxShadow, emission, 0.0);

		#ifdef ADVANCED_MATERIALS
		float puddles = 0.0;
		#ifdef REFLECTION_RAIN	
		if (water < 0.5) {
			puddles = GetPuddles(worldPos, newCoord, lightmap.y, NoU, wetness);
		}

		ApplyPuddleToMaterial(puddles, albedo, smoothness, f0, porosity);

		if (puddles > 0.001 && rainStrength > 0.001) {
			mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

			vec3 puddleNormal = GetPuddleNormal(worldPos, viewPos, tbnMatrix);
			newNormal = normalize(
				mix(newNormal, puddleNormal, puddles * sqrt(1.0 - porosity) * rainStrength)
			);
		}
		#endif
		#endif
		
		float fresnel = 0.30; // Mirror-like water for toon aesthetic


		if (water > 0.5 || ((translucent + glass) > 0.5 && albedo.a > 0.01 && albedo.a < 0.95)) {
			#if REFLECTION > 0
			vec4 reflection = vec4(0.0);
			vec3 skyReflection = vec3(0.0);
			float reflectionMask = 0.0;
	
			fresnel = fresnel * 0.98 + 0.02;
			fresnel*= max(1.0 - isEyeInWater * 0.5 * water, 0.5);
			// fresnel = 1.0;
			
			#if REFLECTION == 2
			reflection = DHReflection(viewPos, newNormal, dither, reflectionMask);
			#endif
			
			if (reflection.a < 1.0) {
				#ifdef OVERWORLD
				vec3 skyRefPos = reflect(normalize(viewPos), newNormal);
				skyReflection = GetSkyColor(skyRefPos, true);
				
				#if AURORA > 0
				skyReflection += DrawAurora(skyRefPos * 100.0, dither, 12);
				#endif

				#if CLOUDS == 1
				vec4 cloud = DrawCloudSkybox(skyRefPos * 100.0, 1.0, dither, lightCol, ambientCol, true);
				skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
				#endif
				#if CLOUDS == 2
				vec3 cameraPos = GetReflectedCameraPos(worldPos, newNormal);
				float cloudViewLength = 0.0;

				vec4 cloud = DrawCloudVolumetric(skyRefPos * 8192.0, cameraPos, 1.0, dither, lightCol, ambientCol, cloudViewLength, true);
				skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
				#endif

//				#ifdef CLASSIC_EXPOSURE
//				skyReflection *= 4.0 - 3.0 * eBS;
//				#endif
				
				float waterSkyOcclusion = lightmap.y;
				#if REFLECTION_SKY_FALLOFF > 1
				waterSkyOcclusion = clamp(1.0 - (1.0 - waterSkyOcclusion) * REFLECTION_SKY_FALLOFF, 0.0, 1.0);
				#endif
				waterSkyOcclusion *= waterSkyOcclusion;
				skyReflection *= waterSkyOcclusion;
				#endif

				#ifdef NETHER
				skyReflection = netherCol.rgb * 0.04;
				#endif

				#ifdef END
				skyReflection = endCol.rgb * 0.01;
				#endif

				skyReflection *= clamp(1.0 - isEyeInWater, 0.0, 1.0);
			}
			
			reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));

			#if (defined OVERWORLD || defined END) && SPECULAR_HIGHLIGHT == 2
			vec3 halfVec = normalize(lightVec - normalize(viewPos));
			float NoH = max(dot(newNormal, halfVec), 0.0);
			float specular = step(0.985, pow(NoH, 128.0)) * shadow.r;
			vec3 specularColor = GetSpecularColor(lightmap.y, vec3(1.0));

			#if ALPHA_BLEND == 0
			float specularAlpha = pow(mix(albedo.a, 1.0, fresnel), 2.2) * fresnel;
			#else
			float specularAlpha = mix(albedo.a , 1.0, fresnel) * fresnel;
			#endif

			reflection.rgb += specular * specularColor * 1.5 * (1.0 - reflectionMask) / max(specularAlpha, 0.01);
			#endif
			
			albedo.rgb = mix(albedo.rgb, reflection.rgb, fresnel);
			albedo.a = mix(albedo.a, 1.0, fresnel);
			#endif
		} else if (albedo.a > 0.01) {
			#ifdef ADVANCED_MATERIALS
			skyOcclusion = lightmap.y;
			#if REFLECTION_SKY_FALLOFF > 1
			skyOcclusion = clamp(1.0 - (1.0 - skyOcclusion) * REFLECTION_SKY_FALLOFF, 0.0, 1.0);
			#endif
			skyOcclusion *= skyOcclusion;

			baseReflectance = vec3(f0);

			#ifdef REFLECTION_SPECULAR
			vec3 fresnel3 = mix(baseReflectance, vec3(1.0), fresnel);
			#if MATERIAL_FORMAT == 0
			if (f0 >= 0.9 && f0 < 1.0) {
				baseReflectance = GetMetalCol(f0);
				fresnel3 = ComplexFresnel(pow(fresnel, 0.2), f0);
				#ifdef ALBEDO_METAL
				fresnel3 *= rawAlbedo;
				#endif
			}
			#endif
			
			float aoSquared = ao * ao;
			shadow *= aoSquared; fresnel3 *= aoSquared * smoothness * smoothness;

			if (smoothness > 0.0) {
				vec4 reflection = vec4(0.0);
				vec3 skyReflection = vec3(0.0);
				float reflectionMask = 0.0;
				
				float ssrMask = clamp(length(fresnel3) * 400.0 - 1.0, 0.0, 1.0);
				if(ssrMask > 0.0) reflection = SimpleReflection(viewPos, newNormal, dither, reflectionMask);
				reflection.rgb = pow(reflection.rgb * 2.0, vec3(8.0));
				reflection.a *= ssrMask;

				if (reflection.a < 1.0) {
					#ifdef OVERWORLD
					vec3 skyRefPos = reflect(normalize(viewPos.xyz), newNormal);
					skyReflection = GetSkyColor(skyRefPos, true);
					
					#if AURORA > 0
					skyReflection += DrawAurora(skyRefPos * 100.0, dither, 12);
					#endif
					
					#if CLOUDS == 1
					vec4 cloud = DrawCloudSkybox(skyRefPos * 100.0, 1.0, dither, lightCol, ambientCol, false);
					skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
					#endif
					#if CLOUDS == 2
					vec3 cameraPos = GetReflectedCameraPos(worldPos, newNormal);
					float cloudViewLength = 0.0;

					vec4 cloud = DrawCloudVolumetric(skyRefPos * 8192.0, cameraPos, 1.0, dither, lightCol, ambientCol, cloudViewLength, true);
					skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
					#endif

//					#ifdef CLASSIC_EXPOSURE
//					skyReflection *= 4.0 - 3.0 * eBS;
//					#endif

					skyReflection = mix(vanillaDiffuse * minLightCol, skyReflection, skyOcclusion);
					#endif

					#ifdef NETHER
					skyReflection = netherCol.rgb * 0.04;
					#endif

					#ifdef END
					skyReflection = endCol.rgb * 0.01;
					#endif
				}

				reflection.rgb = max(mix(skyReflection, reflection.rgb, reflectionMask), vec3(0.0));

				albedo.rgb = albedo.rgb * (1.0 - fresnel3) +
							 reflection.rgb * fresnel3;
				albedo.a = mix(albedo.a, 1.0, GetLuminance(fresnel3));
			}
			#endif
			#endif

			#if (defined OVERWORLD || defined END) && SPECULAR_HIGHLIGHT == 2
			vec3 specularColor = GetSpecularColor(lightmap.y, baseReflectance);

			albedo.rgb += GetSpecularHighlight(newNormal, viewPos, smoothness, baseReflectance,
										   	   specularColor, shadow * vanillaDiffuse, color.a);
			#endif
		}

		#if WATER_FOG == 1
		if((isEyeInWater == 0 && water > 0.5) || (isEyeInWater == 1 && water < 0.5)) {
			float opaqueDepth = texture2D(depthtex1, screenPos.xy).r;
			vec3 opaqueScreenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), opaqueDepth);
			#ifdef TAA
			vec3 opaqueViewPos = ToNDC(vec3(TAAJitter(opaqueScreenPos.xy, -0.5), opaqueScreenPos.z));
			#else
			vec3 opaqueViewPos = ToNDC(opaqueScreenPos);
			#endif

			vec4 waterFog = GetWaterFog(opaqueViewPos - viewPos.xyz, fogAlbedo);
			waterFog.rgb *= waterFog.a;
			albedo = mix(waterFog, albedo / max(albedo.a, 0.0001), albedo.a);
		}
		#endif

		#ifdef IRIS_FEATURE_FADE_VARIABLE
		ChunkFade(albedo.rgb, viewPos, chunkFade);
		#endif
		Fog(albedo.rgb, viewPos);

		#ifdef OVERWORLD
		#ifdef FAR_VANILLA_FOG_OVERWORLD
		float cloudMask = GetCloudMask(viewPos, 0.0);
		albedo.a *= 1.0 - pow(cloudMask, 4.0);
		#endif
		#endif

		#if ALPHA_BLEND == 0
		albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
		#endif
	}
	albedo.a *= cloudBlendOpacity;

    /* DRAWBUFFERS:018 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(vlAlbedo, 1.0);
	gl_FragData[2] = vec4(lightAlbedo, 1.0);

	#if REFRACTION > 0
		/* DRAWBUFFERS:0186 */
		gl_FragData[3] = vec4(refraction, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat;
varying float dist;

varying vec2 texCoord, lmCoord;

varying vec3 normal, binormal, tangent;
varying vec3 sunVec, upVec, eastVec;
varying vec3 viewVector;
varying vec3 vViewPos, vWorldPos, vShadowPos; // Added varyings for performance

varying vec4 color;
varying vec4 vTexCoord, vTexCoordAM;

#ifdef IRIS_FEATURE_FADE_VARIABLE
varying float chunkFade;
#endif

//Uniforms//
uniform float far;

uniform vec3 relativeEyePosition;

#ifdef TAA
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif

//Common Functions//
float WavingWater(vec3 worldPos) {
	float viewLength = length(worldPos);

	worldPos += cameraPosition;
	float fractY = fract(worldPos.y + 0.005);
		
	float wave = sin(6.2831854 * (time * 0.7 + worldPos.x * 0.14 + worldPos.z * 0.07)) +
				 sin(6.2831854 * (time * 0.5 + worldPos.x * 0.10 + worldPos.z * 0.20));

    #if defined DISTANT_HORIZONS || defined VOXY
    wave *= smoothstep(far + 4.0, far - 12.0, length(viewLength));
    #endif

	if (fractY > 0.01) return wave * 0.0125 * ANIMATION_STRENGTH;
	
	return 0.0;
}

//Includes//
#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));
	
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vWorldPos = position.xyz;
	vViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	vShadowPos = ToShadow(vWorldPos);

	int blockID = int(mc_Entity.x / 100);

	normal   = normalize(gl_NormalMatrix * gl_Normal);
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
								  
	viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);

	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = texCoord - midCoord;

	vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
	vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
	
	vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
    
	color = gl_Color;

	if(color.a < 0.1) color.a = 1.0;
	
	mat = 0.0;
	
	if (blockID == 200 || blockID == 204 || blockID == 205) mat = 1.0;
	if (blockID == 201) mat = 2.0;
	if (blockID == 202) mat = 3.0;
	if (blockID == 203) mat = 4.0;
	if (blockID == 251) mat = 5.0;

	#ifdef IRIS_FEATURE_FADE_VARIABLE
	chunkFade = mc_chunkFade;
	#endif

	const vec2 sunRotationData = vec2(
		 cos(sunPathRotation * 0.01745329251994),
		-sin(sunPathRotation * 0.01745329251994)
	);
	#ifndef END
	float ang = fract(timeAngle - 0.25);
	#else
	#if defined IS_IRIS || MC_VERSION < 12111
	float ang = 0.0;
	#else
	float ang = 0.5;
	#endif
	#endif
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

	#ifdef WAVING_WATER
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	if (blockID == 200 || blockID == 202 || blockID == 204) position.y += WavingWater(position.xyz);
	#endif

    #ifdef WORLD_CURVATURE
	position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	if (mat == 0.0) gl_Position.z -= 0.00001;
	
	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif