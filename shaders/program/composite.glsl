
#include "/lib/settings.glsl"

#ifdef FSH

varying vec2 texCoord;

varying vec3 sunVec, upVec;

uniform int bedrockLevel;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int moonPhase;
uniform int worldTime;

uniform float blindFactor, darknessFactor, nightVision;
uniform float darknessLightFactor;
uniform float endFlashIntensity;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 endFlashPosition;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex3;
uniform sampler2D colortex6;

#ifdef LIGHT_SHAFT
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;
#endif


#ifdef MULTICOLORED_BLOCKLIGHT
uniform sampler3D lighttex0;
uniform sampler3D lighttex1;
#endif

#ifdef MCBL_SS
uniform vec3 previousCameraPosition;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform sampler2D colortex8;
uniform sampler2D colortex9;
#endif

#ifdef OUTLINE_ENABLED
uniform sampler2D gaux1;
#endif

#ifdef VOXY
uniform int vxRenderDistance;

uniform mat4 vxProjInv;

uniform sampler2D vxDepthTexTrans;
uniform sampler2D vxDepthTexOpaque;
#endif

#ifdef DISTANT_HORIZONS
uniform int dhRenderDistance;
uniform float dhFarPlane;

uniform mat4 dhProjection, dhProjectionInverse;

uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
#endif

const bool colortex5Clear = false;

#ifdef MCBL_SS
const bool colortex9Clear = false;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif

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

#ifdef MCBL_SS
vec2 Reprojection(vec3 pos) {
	pos = pos * 2.0 - 1.0;

	vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
	viewPosPrev /= viewPosPrev.w;
	viewPosPrev = gbufferModelViewInverse * viewPosPrev;

	vec3 cameraOffset = cameraPosition - previousCameraPosition;
	cameraOffset *= float(pos.z > 0.56);

	vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
}

vec2 OffsetDist(float x) {
	float n = fract(x * 8.0) * 6.283;
    return vec2(cos(n), sin(n)) * x * x;
}

float GetColoredBlocklightDepth(float z0, float z1, float vxZ0, float vxZ1) {
	float combinedDepth = z1 >= 1.0 ? z0 : z1;

	#ifdef VOXY
	if (combinedDepth < 1.0) {
		return GetLinearDepth(combinedDepth, gbufferProjectionInverse);
	}

	combinedDepth = vxZ1 >= 1.0 ? vxZ0 : vxZ1;

	return GetLinearDepth(combinedDepth, vxProjInv);
	#else
	return GetLinearDepth(combinedDepth, gbufferProjectionInverse);
	#endif
}

vec3 GetMultiColoredBlocklight(vec2 coord, float z0, float z1, float dither) {
	float vxZ0 = 0.0, vxZ1 = 0.0;
	#ifdef VOXY
	vxZ0 = texture2DLod(vxDepthTexTrans, coord, 0).r;
	vxZ1 = texture2DLod(vxDepthTexOpaque, coord, 0).r;
	#endif

	float linZ = GetColoredBlocklightDepth(z0, z1, vxZ0, vxZ1);
	bool useVoxy = (z1 >= 1.0 ? z0 : z1) >= 1.0;

	vec2 prevCoord = Reprojection(vec3(coord, z1));

	float distScale = clamp(linZ, 2.0, 128.0);
	float fovScale = gbufferProjection[1][1] / 1.37;
	vec2 blurstr = vec2(1.0 / aspectRatio, 1.0) * 1.25 * fovScale / distScale;

	vec3 lightAlbedo = texture2DLod(colortex8, coord, 0).rgb;
	vec3 previousColoredLight = vec3(0.0);
	float mask = clamp(2.0 - 2.0 * max(abs(prevCoord.x - 0.5), abs(prevCoord.y - 0.5)), 0.0, 1.0);

	for(int i = 0; i < 4; i++) {
		vec2 offset = OffsetDist((dither + i) * 0.25) * blurstr;
		offset = floor(offset * vec2(viewWidth, viewHeight) + 0.5) / vec2(viewWidth, viewHeight);
		vec2 samplePos = coord + offset;

		#ifdef MCBL_SS_ANTI_BLEED
		float linSampleZ;
		if (!useVoxy) {
			float sz0 = texture2DLod(depthtex0, samplePos, 0).r;
			float sz1 = texture2DLod(depthtex1, samplePos, 0).r;
			linSampleZ = GetLinearDepth(sz1 >= 1.0 ? sz0 : sz1, gbufferProjectionInverse);
		} else {
			#ifdef VOXY
			float svz0 = texture2DLod(vxDepthTexTrans, samplePos, 0).r;
			float svz1 = texture2DLod(vxDepthTexOpaque, samplePos, 0).r;
			linSampleZ = GetLinearDepth(svz1 >= 1.0 ? svz0 : svz1, vxProjInv);
			#else
			linSampleZ = 1e10;
			#endif
		}

		float sampleWeight = clamp(abs(linZ - linSampleZ) / 8.0, 0.0, 1.0);
		sampleWeight = 1.0 - sampleWeight * sampleWeight;
		#else
		float sampleWeight = 1.0;
		#endif

		previousColoredLight += texture2DLod(colortex9, prevCoord.xy + offset, 0).rgb * sampleWeight;
	}

	previousColoredLight *= 0.25;
	previousColoredLight *= previousColoredLight * mask;

	return sqrt(mix(previousColoredLight, lightAlbedo * lightAlbedo / 0.1, 0.1));
}
#endif

#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/lightSkyColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/util/encode.glsl"

#ifdef CONTACT_SHADOWS
float GetContactShadow(vec3 viewPos, vec3 lightVec, vec3 normal, float dither) {
    float shadow = 1.0;
    int steps = 16;
    float rayLength = 0.6;
    vec3 rayStep = lightVec * (rayLength / float(steps));
    
    // Start slightly off the surface to avoid self-shadowing
    vec3 currentPos = viewPos + normal * 0.02 + rayStep * (dither * 0.5 + 0.1);
    
    for(int i = 0; i < steps; i++) {
        vec4 projPos = gbufferProjection * vec4(currentPos, 1.0);
        vec3 screenPos = projPos.xyz / projPos.w * 0.5 + 0.5;
        
        if (any(greaterThan(abs(screenPos.xy - 0.5), vec2(0.5)))) break;
        
        float sampleDepth = texture2DLod(depthtex0, screenPos.xy, 0).r;
        float linearSampleDepth = GetLinearDepth(sampleDepth, gbufferProjectionInverse);
        float linearRayDepth = GetLinearDepth(screenPos.z, gbufferProjectionInverse);
        
        if (sampleDepth < screenPos.z - 0.0001) {
            float depthDiff = linearRayDepth - linearSampleDepth;
            if (depthDiff > 0.001 && depthDiff < 0.6) {
                shadow = 0.0;
                break;
            }
        }
        currentPos += rayStep;
    }
    return shadow;
}
#endif

#ifdef LIGHT_SHAFT
#ifdef MULTICOLORED_BLOCKLIGHT
#include "/lib/util/voxelMapHelper.glsl"
#endif

#endif

void main() {
    vec4 color = texture2D(colortex0, texCoord);
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;

	#ifdef VOXY
	float vxZ0 = texture2D(vxDepthTexTrans, texCoord).r;
	float vxZ1 = texture2D(vxDepthTexOpaque, texCoord).r;
	#endif

	#ifdef DISTANT_HORIZONS
	float dhZ0 = texture2D(dhDepthTex0, texCoord).r;
	float dhZ1 = texture2D(dhDepthTex1, texCoord).r;
	#endif

	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	#if defined DISTANT_HORIZONS || defined VOXY
	if (z0 < 1.0) {
	#endif
	#ifdef VOXY
	} else if (vxZ0 < 1.0) {
		screenPos = vec4(texCoord.x, texCoord.y, vxZ0, 1.0);
		viewPos = vxProjInv * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;
	#endif
	#ifdef DISTANT_HORIZONS
	} else if (dhZ0 < 1.0) {
		screenPos = vec4(texCoord.x, texCoord.y, dhZ0, 1.0);
		viewPos = dhProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;
	#endif
	#if defined DISTANT_HORIZONS || defined VOXY
	}
	#endif

	#if REFRACTION > 0
	if (z1 > z0) {
		vec3 distort = texture2D(colortex6, texCoord).xyz;
		float fovScale = gbufferProjection[1][1] / 1.37;
		distort.xy = distort.xy * 2.0 - 1.0;
		distort.xy *= vec2(1.0 / aspectRatio, 1.0) * fovScale / max(length(viewPos.xyz), 8.0);

		vec2 newCoord = texCoord + distort.xy;
		#if MC_VERSION > 10800
		float distortMask = texture2D(colortex6, newCoord).b * distort.b;
		#else
		float distortMask = texture2DLod(colortex6, newCoord, 0).b * distort.b;
		#endif

		if (distortMask == 1.0 && z0 > 0.56) {
			z0 = texture2D(depthtex0, newCoord).r;
			z1 = texture2D(depthtex1, newCoord).r;
			#if MC_VERSION > 10800
			color.rgb = texture2D(colortex0, newCoord).rgb;
			#else
			color.rgb = texture2DLod(colortex0, newCoord, 0).rgb;
			#endif
		}

		screenPos = vec4(newCoord.x, newCoord.y, z0, 1.0);
		viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;
	}
	#endif

	#if ALPHA_BLEND == 0
	color.rgb *= color.rgb;
	#endif

	if (isEyeInWater == 1.0) {
		vec4 waterFog = GetWaterFog(viewPos.xyz, vec3(0.0));
		waterFog.a = mix(waterAlpha * 0.5, 1.0, waterFog.a);
		color.rgb = mix(sqrt(color.rgb), sqrt(waterFog.rgb), waterFog.a);
		color.rgb *= color.rgb;
	}

	vec3 vl = vec3(0.0);

	color.rgb *= clamp(1.0 - 2.0 * darknessLightFactor, 0.0, 1.0);

	vec3 reflectionColor = pow(color.rgb, vec3(0.125)) * 0.5;

	#ifdef MCBL_SS
	float dither = Bayer8(gl_FragCoord.xy);
	vec3 coloredLight = GetMultiColoredBlocklight(texCoord, z0, z1, dither);
	#else
	float dither = Bayer8(gl_FragCoord.xy);
	#endif

    #ifdef CONTACT_SHADOWS
    if (z0 < 1.0) {
        vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
        vec3 normal = DecodeNormal(texture2D(colortex3, texCoord).xy);
        
        if (dot(normal, lightVec) > 0.01) {
            float contactShadow = GetContactShadow(viewPos.xyz, lightVec, normal, dither);
            color.rgb *= mix(0.4, 1.0, contactShadow);
        }
    }
    #endif

	#ifdef REFLECTION_PREVIOUS
	float reflectionMask = float(z0 < 1.0);

	#ifdef VOXY
	float vxZ = texture2D(vxDepthTexTrans, texCoord.xy).r;
	reflectionMask = max(reflectionMask, float(vxZ < 1.0));
	#endif

	#ifdef DISTANT_HORIZONS
	float dhZ = texture2D(dhDepthTex0, texCoord.xy).r;
	reflectionMask = max(reflectionMask, float(dhZ < 1.0));
	#endif
	#endif

    /*DRAWBUFFERS:01*/
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(vl, 1.0);

	#ifdef MCBL_SS
		/*DRAWBUFFERS:019*/
		gl_FragData[2] = vec4(coloredLight, 1.0);

		#ifdef REFLECTION_PREVIOUS
		/*DRAWBUFFERS:0195*/
		gl_FragData[3] = vec4(reflectionColor, reflectionMask);
		#endif
	#else
		#ifdef REFLECTION_PREVIOUS
		/*DRAWBUFFERS:015*/
		gl_FragData[2] = vec4(reflectionColor, reflectionMask);
		#endif
	#endif
}

#endif

#ifdef VSH

varying vec2 texCoord;

varying vec3 sunVec, upVec;

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
}

#endif