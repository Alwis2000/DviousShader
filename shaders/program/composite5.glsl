
#include "/lib/settings.glsl"

#ifdef FSH

varying vec2 texCoord;

varying vec3 sunVec, upVec;

uniform int isEyeInWater;
uniform int moonPhase;
uniform int worldTime;

uniform float blindFactor, darknessFactor;
uniform float frameTime, frameTimeCounter;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;

#ifdef DIRTY_LENS
uniform sampler2D colortex7;
#endif


#ifdef SKY_UNDERGROUND
uniform vec3 cameraPosition;
#endif

#ifdef MCBL_SS
uniform sampler2D colortex9;
#endif

const bool colortex2Clear = false;


#ifdef MCBL_SS
const bool colortex9MipmapEnabled = true;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float moonVisibility = clamp(dot(-sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void UnderwaterDistort(inout vec2 texCoord) {
	vec2 originalTexCoord = texCoord;

	texCoord += vec2(
		cos(texCoord.y * 32.0 + frameTimeCounter * 3.0),
		sin(texCoord.x * 32.0 + frameTimeCounter * 1.7)
	) * 0.0005;

	float mask = float(
		texCoord.x > 0.0 && texCoord.x < 1.0 &&
	    texCoord.y > 0.0 && texCoord.y < 1.0
	)
	;
	if (mask < 0.5) texCoord = originalTexCoord;
}






#include "/lib/color/lightColor.glsl"


#include "/lib/post/tonemap.glsl"

void main() {
    vec2 newTexCoord = texCoord;

	#ifdef UNDERWATER_DISTORTION
	if (isEyeInWater == 1.0) UnderwaterDistort(newTexCoord);
	#endif

	vec3 color = texture2D(colortex0, newTexCoord).rgb;



	Tonemap(color);

	#ifdef MCBL_SS
	vec3 coloredLight = texture2DLod(colortex9, texCoord.xy, 2).rgb;
	coloredLight *= 0.99;
	#endif

	/* DRAWBUFFERS:12 */
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);

	#ifdef MCBL_SS
		/*DRAWBUFFERS:129*/
		gl_FragData[2] = vec4(coloredLight, 1.0);
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