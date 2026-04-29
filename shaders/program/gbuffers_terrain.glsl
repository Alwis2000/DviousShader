/* 
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float mat, recolor;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;


#ifdef IRIS_FEATURE_FADE_VARIABLE
varying float chunkFade;
#endif

//Uniforms//
uniform int bedrockLevel;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int moonPhase;
uniform int worldTime;

uniform float cloudHeight;
uniform float endFlashIntensity;
uniform float frameTimeCounter;
uniform float near, far;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 relativeEyePosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

uniform sampler2D noisetex;


#if DYNAMIC_HANDLIGHT > 0
uniform int heldBlockLightValue, heldBlockLightValue2;
#endif

#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
uniform int heldItemId, heldItemId2;
#endif

#ifdef MULTICOLORED_BLOCKLIGHT
uniform sampler3D lighttex0;
#define LIGHTTEX0_DECLARED
uniform sampler3D lighttex1;
#endif

#ifdef MCBL_SS
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;

uniform sampler2D colortex9;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float moonVisibility = clamp(dot(-sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif


vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/lightSkyColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/specularColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/vertex/waving.glsl"
#include "/lib/atmospherics/weatherDensity.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/chunkFade.glsl"
#include "/lib/lighting/dynamicHandlight.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/surface/hardcodedEmission.glsl"



#ifdef MULTICOLORED_BLOCKLIGHT
#include "/lib/util/voxelMapHelper.glsl"
#endif

#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
#include "/lib/lighting/coloredBlocklight.glsl"
#endif

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * vec4(color.rgb, 1.0);

	// Early alpha discard — skip all lighting math for transparent leaf/plant pixels
	if (albedo.a < 0.1) discard;

	vec3 newNormal = normal;
	float smoothness = 0.0;
	vec3 lightAlbedo = vec3(0.0);


	{
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		
		float foliage   = float(mat > 0.98 && mat < 1.02);
		float leaves    = float(mat > 1.98 && mat < 2.02);
		float emissive  = float(mat > 2.98 && mat < 3.02);
		float lava      = float(mat > 3.98 && mat < 4.02);
		float candle    = float(mat > 4.98 && mat < 5.02);
		float ore       = float(mat > 5.98 && mat < 6.02);
		float netherOre = float(mat > 6.98 && mat < 7.02);

		float emission        = (emissive + candle + lava);
		vec3 baseReflectance  = vec3(0.04);
		
		vec3 hsv = vec3(0.0);
		if (emission > 0.5 || ore + netherOre > 0.5) {
			hsv = RGB2HSV(albedo.rgb);
			emission *= GetHardcodedEmission(albedo.rgb, hsv);
		}
		
		#ifdef GLOWING_ORES
		float oreEmission = 0.0;
		if (ore + netherOre > 0.5) {
			oreEmission = GetOreEmission(hsv, ore, netherOre);
		}
		#endif

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		vec3 viewPos = ToNDC(screenPos);
		vec3 worldPos = ToWorld(viewPos);
		
		#if defined DISTANT_HORIZONS && !defined VOXY
		float dither = Bayer8(gl_FragCoord.xy);

		float viewLength = length(viewPos);
		float minDist = (dither - 0.75) * 16.0 + far;
		if (viewLength > minDist) {
			discard;
		}
		#endif

		
		#if DYNAMIC_HANDLIGHT == 2
		lightmap = ApplyDynamicHandlight(lightmap, worldPos);
		#endif

		#ifdef TOON_LIGHTMAP
		lightmap = floor(lightmap * 14.999 * (0.75 + 0.25 * color.a)) / 14.0;
		lightmap = clamp(lightmap, vec2(0.0), vec2(1.0));
		#endif
		
    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		if (lava > 0.5) {
			albedo.rgb = mix(albedo.rgb, vec3(1.0, 0.3, 0.01), 0.4);
		}

		#ifdef EMISSIVE_RECOLOR
		float ec = GetLuminance(albedo.rgb) * 1.7;
		if (recolor > 0.5) {
			albedo.rgb = blocklightCol * pow(ec, 1.5) / (BLOCKLIGHT_I * BLOCKLIGHT_I);
			albedo.rgb /= 0.7 * albedo.rgb + 0.7;
		}
		if (lava > 0.5) {
			albedo.rgb = pow(blocklightCol * ec / BLOCKLIGHT_I, vec3(2.0));
			albedo.rgb /= 0.5 * albedo.rgb + 0.5;
		}
		#endif

		lightAlbedo = albedo.rgb + 0.00001;
		#ifdef MCBL_SS
		if (lava > 0.5) {
			lightAlbedo = pow(lightAlbedo, vec3(0.25));
		}
		lightAlbedo = sqrt(normalize(lightAlbedo) * emission);

		#ifdef MULTICOLORED_BLOCKLIGHT
		lightAlbedo *= GetMCBLLegacyMask(worldPos);
		#endif
		#endif

		#ifdef WHITE_WORLD
		albedo.rgb = vec3(0.35);
		#endif
		
		vec3 outNormal = newNormal;
		#ifdef NORMAL_PLANTS
		if (foliage > 0.5){
			newNormal = upVec;
			
		}
		#endif
		
		#ifndef HALF_LAMBERT
		float NoL = clamp(dot(newNormal, lightVec), 0.0, 1.0);
		#else
		float NoL = clamp(dot(newNormal, lightVec) * 0.5 + 0.5, 0.0, 1.0);
		NoL *= NoL;
		#endif

		if (foliage > 0.5 || leaves > 0.5) NoL = 1.0;

		float vanillaDiffuse = 1.0;
		
// Removed foliage diffuse boost

		float parallaxShadow = 1.0;

		#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
		// Skip expensive 3D voxel lookup for foliage/leaves — they rarely benefit from MCBL
		if (foliage < 0.5 && leaves < 0.5) {
			blocklightCol = ApplyMultiColoredBlocklight(blocklightCol, screenPos, worldPos, newNormal, 0.0, lightmap.x);
		}
		#endif

		#ifdef GLOWING_ORES
		if (ore + netherOre > 0.5) {
			oreEmission *= pow(lightmap.x, 4.0 / max(EMISSIVE_CURVE, 1.0)) * vanillaDiffuse;
			emission += oreEmission;
		}
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, normal, lightmap, color.a, NoL, 
					vanillaDiffuse, parallaxShadow, emission, 0.0);



		
		
		#ifdef IRIS_FEATURE_FADE_VARIABLE
		ChunkFade(albedo.rgb, viewPos, chunkFade);
		#endif

		#if ALPHA_BLEND == 0
		albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
		#endif
	}

		/* DRAWBUFFERS:08 */
		gl_FragData[0] = albedo;
		gl_FragData[1] = vec4(lightAlbedo, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat, recolor;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;


#ifdef IRIS_FEATURE_FADE_VARIABLE
varying float chunkFade;
#endif

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;
uniform vec3 relativeEyePosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;


//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;


//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"




//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));

	int blockID = int(mc_Entity.x / 100);

	normal = normalize(gl_NormalMatrix * gl_Normal);

    
	color = gl_Color;
	
	mat = 0.0; recolor = 0.0;

	if (blockID >= 100 && blockID < 150)
		mat = 1.0;
	if (blockID == 105 || blockID == 106){
		mat = 2.0;
		// Removed color boost
	}
	if (blockID >= 150 && blockID < 200)
		mat = 3.0;
	if (blockID == 153){
		mat = 4.0;
		lmCoord.x += 0.0667;
	}
	if (blockID == 158)
		mat = 5.0;
	if (blockID == 159)
		mat = 6.0;
	if (blockID == 160)
		mat = 7.0;
	if (blockID == 251)
		mat = 8.0;

	if (blockID == 151 || blockID == 155 || blockID == 156)
		recolor = 1.0;

	if (blockID == 152)
		lmCoord.x -= 0.0667;

	if (color.a < 0.1)
		color.a = 1.0;

	#ifdef IRIS_FEATURE_FADE_VARIABLE
	chunkFade = mc_chunkFade;
	#endif

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
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

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz = WavingBlocks(position.xyz, blockID, istopv);



	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
}

#endif
