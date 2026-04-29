/* 
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;


//Uniforms//
uniform int entityId;
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

uniform vec4 entityColor;

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
#include "/lib/color/specularColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
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

#ifdef NORMAL_SKIP
#undef PARALLAX
#undef SELF_SHADOW
#endif

#if MC_VERSION <= 10710
#undef PARALLAX
#undef SELF_SHADOW
#endif

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * color;
	vec3 vlAlbedo = vec3(1.0);
	vec3 newNormal = normal;
	float smoothness = 0.0;
	float skyOcclusion = 0.0;


	#ifdef ENTITY_FLASH
	albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
	#endif
	
	float lightningBolt = float(entityId == 10101);
	if(lightningBolt > 0.5) {
		#ifdef OVERWORLD
		albedo.rgb = weatherCol.rgb / weatherCol.a;
		albedo.rgb *= albedo.rgb * albedo.rgb;
		#endif
		#ifdef NETHER
		albedo.rgb = sqrt(netherCol.rgb / netherCol.a);
		#endif
		#ifdef END
		albedo.rgb = endCol.rgb / endCol.a;
		#endif
		albedo.a = 1.0;
	}

	if (lightningBolt < 0.5) {
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		
		float emission       = float(entityColor.a > 0.05);
		vec3 baseReflectance = vec3(0.04);
		
		vec3 hsv = RGB2HSV(albedo.rgb);
		emission *= GetHardcodedEmission(albedo.rgb, hsv);

		#ifndef ENTITY_FLASH
		emission = 0.0;
		#endif

		float correctedZ = (gl_FragCoord.z * 2.0 - 1.0) * 100.0 * 0.5 + 0.5;
		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), correctedZ);
		vec3 viewPos = ToNDC(screenPos);
		vec3 worldPos = ToWorld(viewPos);

		
		#if DYNAMIC_HANDLIGHT == 2
		lightmap = ApplyDynamicHandlight(lightmap, worldPos);
		#endif

		#ifdef TOON_LIGHTMAP
		lightmap = floor(lightmap * 14.999 * (0.75 + 0.25 * color.a)) / 14.0;
		lightmap = clamp(lightmap, vec2(0.0), vec2(1.0));
		#endif
		
    	albedo.rgb = pow(albedo.rgb, vec3(2.2));
		
		vlAlbedo = mix(vec3(1.0), albedo.rgb, sqrt(albedo.a)) * (1.0 - pow(albedo.a, 64.0));

		#ifdef WHITE_WORLD
		albedo.rgb = vec3(0.35);
		#endif
		
		#ifndef HALF_LAMBERT
		float NoL = clamp(dot(newNormal, lightVec), 0.0, 1.0);
		#else
		float NoL = clamp(dot(newNormal, lightVec) * 0.5 + 0.5, 0.0, 1.0);
		NoL *= NoL;
		#endif

		float vanillaDiffuse = 1.05; // Standardized to match terrain (with 1.05x compensation)

		/* 
		if (entityId >= 10104) {
			float dotL = dot(newNormal, lightVec);
			float directionalFactor = mix(1.0, mix(0.5, 1.0, clamp(dotL * 0.5 + 0.5, 0.0, 1.0)), lightmap.y);
			vanillaDiffuse *= directionalFactor;
		}
		*/

		float parallaxShadow = 1.0;

		#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
		blocklightCol = ApplyMultiColoredBlocklight(blocklightCol, screenPos, worldPos, newNormal, 0.0, lightmap.x);
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, normal, lightmap, 1.0, NoL, 
					vanillaDiffuse, parallaxShadow, emission, 1.0);





		#if ALPHA_BLEND == 0
		albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
		#endif
	}

    /* DRAWBUFFERS:013 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(vlAlbedo, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, 1.0, 1.0);

	#ifdef MCBL_SS
		/* DRAWBUFFERS:0138 */
		gl_FragData[3] = vec4(0.0,0.0,0.0,1.0);
		
	#else
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;


//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;


//Attributes//
attribute vec4 mc_Entity;


//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//



//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));

	normal = normalize(gl_NormalMatrix * gl_Normal);

    
	color = gl_Color;

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

	gl_Position = ftransform();

	gl_Position.z *= 0.01;
	
}

#endif