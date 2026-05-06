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

varying vec4 vColor;

//Uniforms//
uniform int blockEntityId;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int moonPhase;

uniform float cloudHeight;
uniform float endFlashIntensity;
uniform float frameTimeCounter;
uniform float near, far;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

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

float time = frameTimeCounter * ANIMATION_SPEED;

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

int endPortalLayerCount = 6;

vec3 endPortalColors[6] = vec3[6](
	vec3(0.4,1.0,0.9),
	vec3(0.2,0.9,1.0) * 0.80,
	vec3(0.7,0.5,1.0) * 0.25,
	vec3(0.4,0.5,1.0) * 0.30,
	vec3(0.3,0.8,1.0) * 0.30,
	vec3(0.3,0.8,1.0) * 0.35
);

vec3 endPortalParams[6] = vec3[6](
	vec3( 0.5,  0.00, 0.000),
	vec3( 1.5,  1.40, 0.125),
	vec3( 4.0,  2.50, 0.375),
	vec3( 8.0, -0.40, 0.250),
	vec3(12.0,  3.14, 0.500),
	vec3(12.0, -2.20, 0.625)
);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

vec2 GetTriplanar(vec3 value, vec3 absWorldNormal, vec3 signWorldNormal) {
	vec2 xValue = value.zy * vec2( signWorldNormal.x,  1.0) * absWorldNormal.x;
	vec2 yValue = value.xz * vec2(-1.0, -signWorldNormal.y) * absWorldNormal.y;
	vec2 zValue = value.xy * vec2(-signWorldNormal.z,  1.0) * absWorldNormal.z;
	return xValue + yValue + zValue;
}

vec3 DrawEndPortal(vec3 worldPos, vec3 worldNormal, float dither) {
	vec3 absWorldNormal = abs(worldNormal);
	vec3 signWorldNormal = sign(worldNormal);
	vec3 bobbing = gbufferModelViewInverse[3].xyz;

	absWorldNormal.x = float(absWorldNormal.x > 0.5);
	absWorldNormal.y = float(absWorldNormal.y > 0.5);
	absWorldNormal.z = float(absWorldNormal.z > 0.5);
	signWorldNormal *= absWorldNormal;

	worldPos -= bobbing;
	vec3 cameraPos = cameraPosition + bobbing;

	vec2 portalCoord = GetTriplanar(worldPos, absWorldNormal, signWorldNormal);
	vec2 portalNormal = GetTriplanar(worldNormal, absWorldNormal, signWorldNormal);
	vec2 portalOffset = GetTriplanar(cameraPos, absWorldNormal, signWorldNormal);
	float portalDepth = dot(worldPos, -worldNormal);

	vec2 wind = vec2(0, time * 0.0125);

	portalCoord /= 16.0;
	portalOffset /= 16.0;
	
	// dither = fract(dither + frameCounter * 0.618);

	vec3 portalCol = vec3(0.0);

	int parallaxSampleCount = 6;
	float parallaxDepth = 0.0625;

	for (int i = 0; i < endPortalLayerCount; i++) {
		float layerScale = (portalDepth + endPortalParams[i].x) / portalDepth;
		vec2 scaledPortalCoord = portalCoord * layerScale;
		vec2 layerCoord = scaledPortalCoord + (portalOffset + endPortalParams[i].z);

		vec2 rot = vec2(cos(endPortalParams[i].y), sin(endPortalParams[i].y));
		layerCoord = vec2(layerCoord.x * rot.x - layerCoord.y * rot.y, layerCoord.x * rot.y + layerCoord.y * rot.x);
		layerCoord += wind;

		vec3 layerCol = texture2D(texture, layerCoord).r * endPortalColors[i];

		#ifdef PARALLAX_PORTAL
		for (int j = 0; j < parallaxSampleCount; j++) {
			float parallaxProgress = (j + dither) / parallaxSampleCount;
			float layerDepth = endPortalParams[i].x + parallaxProgress * parallaxDepth;
			
			layerScale = (portalDepth + layerDepth) / portalDepth;
			layerCoord = portalCoord * layerScale + (portalOffset + endPortalParams[i].z);
			
			layerCoord = vec2(layerCoord.x * rot.x - layerCoord.y * rot.y, layerCoord.x * rot.y + layerCoord.y * rot.x);
			layerCoord += wind;
			
			vec3 parallaxCol = texture2D(texture, layerCoord).r * endPortalColors[i];
			layerCol = max(layerCol, parallaxCol * (1.0 - parallaxProgress));
		}
		#endif

		float scaledLayerDistance = max(abs(scaledPortalCoord.x), abs(scaledPortalCoord.y)) * 0.25;
		float falloff = clamp(1.0 - scaledLayerDistance, 0.0, 1.0);
		layerCol *= falloff;

		portalCol += layerCol;
	}



	portalCol *= portalCol;
	return portalCol;
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

//Includes//

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

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * vColor;
	vec3 newNormal = normal;
	float smoothness = 0.0;
	vec3 lightAlbedo = vec3(0.0);
	
	#if MC_VERSION >= 11300
	int blockID = blockEntityId / 100;
	#else
	int blockID = blockEntityId;
	#endif

	float endPortal = float(blockID == 252);

	if (endPortal < 0.5) {
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		
		float emission        = float(blockID == 155);
		vec3 baseReflectance  = vec3(0.04);
		
		vec3 hsv = vec3(0.0);
		if (emission > 0.5) {
			hsv = RGB2HSV(albedo.rgb);
			emission *= GetHardcodedEmission(albedo.rgb, hsv);
		}

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		vec3 viewPos = ToNDC(screenPos);
		vec3 worldPos = ToWorld(viewPos);
		
		#if DYNAMIC_HANDLIGHT == 2
		lightmap = ApplyDynamicHandlight(lightmap, worldPos);
		#endif

		#ifdef TOON_LIGHTMAP
		lightmap = floor(lightmap * 14.999 * (0.75 + 0.25 * vColor.a)) / 14.0;
		lightmap = clamp(lightmap, vec2(0.0), vec2(1.0));
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef EMISSIVE_RECOLOR
		if (blockID == 155 && dot(vColor.rgb, vec3(1.0)) > 2.66) {
			float ec = length(albedo.rgb);
			albedo.rgb = blocklightCol * (ec * 0.63 / BLOCKLIGHT_I) + ec * 0.07;
		}
		#endif

		lightAlbedo = albedo.rgb + 0.00001;
		#ifdef MCBL_SS
		lightAlbedo = sqrt(normalize(lightAlbedo) * emission);

		#ifdef MULTICOLORED_BLOCKLIGHT
		lightAlbedo *= GetMCBLLegacyMask(worldPos);
		#endif
		#endif

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

		float parallaxShadow = 1.0;

		#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
		blocklightCol = ApplyMultiColoredBlocklight(blocklightCol, screenPos, worldPos, newNormal, 0.0, lightmap.x);
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, normal, lightmap, vColor.a, NoL, 
					vanillaDiffuse, parallaxShadow, emission, 1.0);




		#if ALPHA_BLEND == 0
		albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
		if(blockID == 155) albedo.a = sqrt(albedo.a);
		#endif
	}
	else
	{
		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		vec3 viewPos = ToNDC(screenPos);
		vec3 worldPos = ToWorld(viewPos);
		vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * normal);
		
		float dither = Bayer8(gl_FragCoord.xy);

		albedo.rgb = DrawEndPortal(worldPos, worldNormal, dither);
		albedo.a = 1.0;

		lightAlbedo = normalize(albedo.rgb * 20.0 + 0.00001);
		
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
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 vColor;

//Uniforms//

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;


//Attributes//
attribute vec4 mc_Entity;

//Common Variables//
float time = frameTimeCounter * ANIMATION_SPEED;

//Includes//

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));

	normal = normalize(gl_NormalMatrix * gl_Normal);

	vColor = gl_Color;

	if(vColor.a < 0.1) vColor.a = 1.0;

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
}

#endif