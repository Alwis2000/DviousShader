
#include "/lib/settings.glsl"

#ifdef FSH

varying vec2 texCoord;

varying vec3 sunVec, upVec, eastVec;

uniform int bedrockLevel;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int moonPhase;
uniform int worldTime;

uniform float blindFactor, darknessFactor, nightVision;
uniform float cloudHeight;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;



#if defined MCBL_SS || defined OUTLINE_ENABLED
uniform sampler2D colortex8;
#endif
#ifdef MCBL_SS
uniform sampler2D colortex9;
#endif

#ifdef VOXY
uniform int vxRenderDistance;

uniform mat4 vxProj, vxProjInv;

uniform sampler2D colortex16;
uniform sampler2D vxDepthTexTrans;
uniform sampler2D vxDepthTexOpaque;
#endif

#ifdef DISTANT_HORIZONS
uniform int dhRenderDistance;

uniform float dhFarPlane, dhNearPlane;

uniform mat4 dhProjection, dhProjectionInverse;

uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
#endif



float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float moonVisibility = clamp(dot(-sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth, mat4 invProjMatrix) {
    depth = depth * 2.0 - 1.0;
    vec2 zw = depth * invProjMatrix[2].zw + invProjMatrix[3].zw;
    return -zw.x / zw.y;
}

float GetNonLinearDepth(float linDepth, mat4 projMatrix) {
    vec2 zw = -linDepth * projMatrix[2].zw + projMatrix[3].zw;
    return (zw.x / zw.y) * 0.5 + 0.5;
}

#if defined DISTANT_HORIZONS || defined VOXY
#ifdef SHADOW
vec3 GetLODShadows(vec3 viewPos, sampler2D depthtex, mat4 projection, mat4 projectionInverse,
				   vec3 ambientCol, vec3 lightCol, float dither, vec3 normal, float shadowMask) {
	#if defined OVERWORLD || defined END
	float shadow = 1.0;


	float traceZ = 0.0;
	float zDelta = 0.0;
	float thickness = 4.0;

	vec3 lodNormal = normal;
	vec3 absN = abs(lodNormal);
	if (absN.x > absN.y && absN.x > absN.z) lodNormal = vec3(sign(lodNormal.x), 0.0, 0.0);
	else if (absN.y > absN.x && absN.y > absN.z) lodNormal = vec3(0.0, sign(lodNormal.y), 0.0);
	else lodNormal = vec3(0.0, 0.0, sign(lodNormal.z));

	vec3 traceOffset = lodNormal * (0.5 * SHADOW_MAP_BIAS);
	if (dot(traceOffset, lightVec) < 0.0) traceOffset = vec3(0.0);

	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	for (int i = 0; i < 16; i++) {
		float traceStep = (exp2(i * 0.32) - 1.0) * 4.0 + 0.1;
		vec3 tracePos = viewPos + traceOffset + lightVec * traceStep;

		vec4 pos = projection * vec4(tracePos, 1.0);
		pos.xy = pos.xy / pos.w * 0.5 + 0.5;

		if (pos.x < 0.0 || pos.x > 1.0 || pos.y < 0.0 || pos.y > 1.0) break;

		#ifdef VOXY
		traceZ = texelFetch(depthtex0, ivec2(pos.xy * vec2(viewWidth, viewHeight)), 0).r;
		float linZ = traceZ * 2.0 - 1.0;
		zDelta = -tracePos.z - (- (linZ * gbufferProjectionInverse[2].z + gbufferProjectionInverse[3].z) / (linZ * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w));

		if (traceZ >= 1.0) {
		#endif
			traceZ = texelFetch(depthtex, ivec2(pos.xy * vec2(viewWidth, viewHeight)), 0).r;

			float linZ2 = traceZ * 2.0 - 1.0;
			zDelta = -tracePos.z - (- (linZ2 * projectionInverse[2].z + projectionInverse[3].z) / (linZ2 * projectionInverse[2].w + projectionInverse[3].w));
		#ifdef VOXY
		}
		#endif

		float currentBias = (0.15 + traceStep * 0.02) * SHADOW_MAP_BIAS;
		if (zDelta > currentBias && zDelta < (thickness + traceStep * 0.4)) {
			shadow = 0.0;
			break;
		}
		thickness += 2.0;
	}

	vec3 shadowCol = ambientCol / mix(ambientCol, lightCol, shadowMask);

	return mix(shadowCol, vec3(1.0), shadow);
	#else
	return vec3(1.0);
	#endif
}
#else
vec3 GetLODShadows(vec3 viewPos, sampler2D depthtex, mat4 projection, mat4 projectionInverse,
				   vec3 ambientCol, vec3 lightCol, float dither, vec3 normal, float shadowMask) {
	return vec3(1.0);
}
#endif
#endif

#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/lightSkyColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/weatherDensity.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/atmospherics/stars.glsl"

#ifdef OUTLINE_ENABLED
#include "/lib/util/outlineOffset.glsl"
#include "/lib/util/outlineDepth.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/post/outline.glsl"
#endif

#include "/lib/util/encode.glsl"


#ifdef END
vec3 GetEndSkyColor(vec3 viewPos) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos.xyz, 1.0);
	worldPos.xyz /= worldPos.w;

	worldPos = normalize(worldPos);

	vec3 sky = vec3(0.0);
	vec3 absWorldPos = abs(worldPos.xyz);
	float maxViewDir = absWorldPos.x;
	sky = vec3(worldPos.yz, 0.0);
	if (absWorldPos.y > maxViewDir) {
		maxViewDir = absWorldPos.y;
		sky = vec3(worldPos.xz, 0.0);
	}
	if (absWorldPos.z > maxViewDir) {
		maxViewDir = absWorldPos.z;
		sky = vec3(worldPos.xy, 0.0);
	}
	vec2 skyUV = sky.xy * 2.0;
	skyUV = (floor(skyUV * 512.0) + 0.5) / 512.0;
	float noise = texture2D(noisetex, skyUV).b;
	sky = vec3(1.0) * pow(noise * 0.3 + 0.35, 2.0);
	sky *= sky;
	sky *= endCol.rgb * 0.03;
	return sky;
}
#endif

void main() {
    vec4 color = texture2D(colortex0, texCoord);
	float z = texture2D(depthtex0, texCoord).r;
	float rawZ = z;

	#ifdef VOXY
	float vxZ = texture2D(vxDepthTexOpaque, texCoord).r;
	#endif

	#ifdef DISTANT_HORIZONS
	float dhZ = texture2D(dhDepthTex0, texCoord).r;
	#endif

	#if defined DISTANT_HORIZONS || defined VOXY
	vec3 lodLight = vec3(1.0);
	vec3 lodAmbient = vec3(1.0);

	#ifdef OVERWORLD
	lodLight = lightCol;
	lodAmbient = ambientCol;
	#endif
	#ifdef END
	lodLight = vec3(0.055);
	lodAmbient = vec3(0.015);
	#endif
	#endif

	float dither = Bayer8(gl_FragCoord.xy);

	#if ALPHA_BLEND == 0
	bool isSky = z == 1.0;
	#ifdef DISTANT_HORIZONS
	isSky = isSky && (dhZ == 1.0);
	#endif
	#ifdef VOXY
	isSky = isSky && (vxZ == 1.0);
	#endif

	if (isSky) color.rgb = max(color.rgb - dither / vec3(128.0), vec3(0.0));
	color.rgb *= color.rgb;
	#endif

	vec4 screenPos = vec4(texCoord, z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	#ifdef OUTLINE_ENABLED
	vec4 innerOutline = vec4(0.0);
	float outlineLinZ = 0.0;
	Outline(color.rgb, false, innerOutline, outlineLinZ);

	color.rgb = mix(color.rgb, innerOutline.rgb, innerOutline.a);
	#endif

	if (z < 1.0) {

		Fog(color.rgb, viewPos.xyz);
	#ifdef VOXY
	} else if (vxZ < 1.0) {
		z = 1.0 - 2e-5;

		vec4 vxScreenPos = vec4(texCoord, vxZ, 1.0);
		viewPos = vxProjInv * (vxScreenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;

		vec4 lodData = texture2D(colortex6, texCoord);
		vec3 lodNormal = DecodeNormal(lodData.xy);
		float lodShadowMask = lodData.z;

		color.rgb *= GetLODShadows(viewPos.xyz, vxDepthTexOpaque, vxProj, vxProjInv,
									lodAmbient, lodLight, dither, lodNormal, lodShadowMask);

		Fog(color.rgb, viewPos.xyz);
	#endif
	#ifdef DISTANT_HORIZONS
	} else if (dhZ < 1.0) {
		z = 1.0 - 1e-5;

		vec4 dhScreenPos = vec4(texCoord, dhZ, 1.0);
		viewPos = dhProjectionInverse * (dhScreenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;

		// Performance optimization: Only run screen-space shadows where the real shadow map cannot reach.
		float viewLength = length(viewPos.xyz);
		if (viewLength > shadowDistance - 16.0) {
			vec4 lodData = texture2D(colortex6, texCoord);
			vec3 lodNormal = DecodeNormal(lodData.xy);
			float lodShadowMask = lodData.z;

			color.rgb *= GetLODShadows(viewPos.xyz, dhDepthTex0, dhProjection, dhProjectionInverse,
									   lodAmbient, lodLight, dither, lodNormal, lodShadowMask);
		}

		Fog(color.rgb, viewPos.xyz);
	#endif
	} else {
		#if defined OVERWORLD && defined SKY_DEFERRED
		color.rgb += GetSkyColor(viewPos.xyz, false);

		#ifdef STARS
		if (moonVisibility > 0.0) DrawStars(color.rgb, viewPos.xyz);
		#endif

		#if AURORA > 0
		color.rgb += DrawAurora(viewPos.xyz, dither, 24);
		#endif

		color.rgb *= 1.0 + nightVision;
		#ifdef CLASSIC_EXPOSURE
		color.rgb *= 4.0 - 3.0 * eBS;
		#endif
		#endif
		#ifdef NETHER
		color.rgb = netherCol.rgb * 0.0425;
		#endif
		#ifdef END
		#ifdef SHADER_END_SKY
		color.rgb = GetEndSkyColor(viewPos.xyz);
		#endif

		#ifndef LIGHT_SHAFT
		float VoL = dot(normalize(viewPos.xyz), lightVec);
		VoL = pow(VoL * 0.5 + 0.5, 16.0) * 0.75 + 0.25;
		color.rgb += endCol.rgb * 0.04 * VoL * LIGHT_SHAFT_STRENGTH;
		#endif
		#endif

		if (isEyeInWater > 1) {
			color.rgb = denseFogColor[isEyeInWater - 2];
		}

		if (blindFactor > 0.0 || darknessFactor > 0.0) color.rgb *= 1.0 - max(blindFactor, darknessFactor);
	}



	vec3 reflectionColor = pow(color.rgb, vec3(0.125)) * 0.5;

	#if ALPHA_BLEND == 0
	color.rgb = sqrt(max(color.rgb, vec3(0.0)));
	#endif

	#ifdef VOXY
	vec4 voxyTransparentColor = texture2D(colortex16, texCoord);
	voxyTransparentColor.rgb /= max(voxyTransparentColor.a, 0.00001);

	float vxZ0 = texture2D(vxDepthTexTrans, texCoord).r;

	float vanillaTransZ = texture2D(depthtex1, texCoord).r;
	float vxLinearZ = GetLinearDepth(vxZ0, vxProjInv);
	float vanillaLinearZ = GetLinearDepth(vanillaTransZ, gbufferProjectionInverse);

	if (vxLinearZ < vanillaLinearZ) {
		color.rgb = mix(color.rgb, voxyTransparentColor.rgb, voxyTransparentColor.a);
	}
	#endif

	float reflectionMask = float(z < 1.0);
	#ifdef DISTANT_HORIZONS
	reflectionMask = max(reflectionMask, float(dhZ < 1.0));
	#endif

	#if !defined REFLECTION_PREVIOUS && REFRACTION == 0
	/* DRAWBUFFERS:05 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(reflectionColor, reflectionMask);
	#elif defined REFLECTION_PREVIOUS && REFRACTION > 0
	/* DRAWBUFFERS:06 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
	#elif !defined REFLECTION_PREVIOUS && REFRACTION > 0
	/* DRAWBUFFERS:056 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(reflectionColor, reflectionMask);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	#else
	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
	#endif
}

#endif

#ifdef VSH

varying vec2 texCoord;

varying vec3 sunVec, upVec, eastVec;

uniform float timeAngle;

uniform mat4 gbufferModelView;

void main() {
	texCoord = gl_MultiTexCoord0.xy;

	gl_Position = ftransform();

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
}

#endif
