
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



void ColorGrading(inout vec3 color) {
	vec3 cgColor = pow(color.r, CG_RC) * pow(vec3(CG_RR, CG_RG, CG_RB) / 255.0, vec3(2.2)) +
				   pow(color.g, CG_GC) * pow(vec3(CG_GR, CG_GG, CG_GB) / 255.0, vec3(2.2)) +
				   pow(color.b, CG_BC) * pow(vec3(CG_BR, CG_BG, CG_BB) / 255.0, vec3(2.2));
	vec3 cgMin = pow(vec3(CG_RM, CG_GM, CG_BM) / 255.0, vec3(2.2));
	color = (cgColor * (1.0 - cgMin) + cgMin) * vec3(CG_RI, CG_GI, CG_BI);

	vec3 cgTint = pow(vec3(CG_TR, CG_TG, CG_TB) / 255.0, vec3(2.2)) * GetLuminance(color) * CG_TI;
	color = mix(color, cgTint, CG_TM);
}

vec3 RGB2HSV(vec3 c){
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 HSV2RGB(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void Notorious6Test(inout vec3 color) {
	vec2 testCoord = texCoord * vec2(8.0,6.0) - vec2(3.5, 1.0);

	if (testCoord.x > -2 && testCoord.x < 3 && testCoord.y > 0 && testCoord.y < 1){
		float h = floor((1.0 - testCoord.y) * 18.0) / 18.0;
		float s = pow(floor(testCoord.x) * 0.25 + 0.5, 0.5);

		color = pow(HSV2RGB(vec3(h, s, 1.0)), vec3(2.2));
		color *= exp2(floor(fract(testCoord.x) * 20.0) - 10.0);

		color /= exp2(2.0 + 0.0);
	}
}

mat3 inverseMatrix(mat3 m) {
	float a00 = m[0][0], a01 = m[0][1], a02 = m[0][2];
	float a10 = m[1][0], a11 = m[1][1], a12 = m[1][2];
	float a20 = m[2][0], a21 = m[2][1], a22 = m[2][2];

	float b01 = a22 * a11 - a12 * a21;
	float b11 = -a22 * a10 + a12 * a20;
	float b21 = a21 * a10 - a11 * a20;

	float det = a00 * b01 + a01 * b11 + a02 * b21;

	return mat3(
		b01, (-a22 * a01 + a02 * a21), (a12 * a01 - a02 * a11),
		b11, (a22 * a00 - a02 * a20), (-a12 * a00 + a02 * a10),
		b21, (-a21 * a00 + a01 * a20), (a11 * a00 - a01 * a10)
	) / det;
}

void BSLTonemap(inout vec3 color) {
	color *= exp2(2.0 + 0.0);

	float s = TONEMAP_WHITE_PATH;

	float a = 0.03 * s;
	float b = 0.01 * s;
	float c = 1.0 - (a + b);
	float d = 1.0 - (a + a);

	mat3 desatMatrix = mat3(
		vec3(c, a, b),
		vec3(a, d, a),
		vec3(b, a, c)
	);

	mat3 satMatrix = inverseMatrix(desatMatrix);

	color *= desatMatrix;

	color = color / pow(pow(color, vec3(TONEMAP_WHITE_CURVE)) + 1.0, vec3(1.0 / TONEMAP_WHITE_CURVE));
	color = pow(color, mix(vec3(TONEMAP_LOWER_CURVE), vec3(TONEMAP_UPPER_CURVE), sqrt(color)));

	color *= satMatrix;

	color = clamp(color, vec3(0.0), vec3(1.0));
}

void ColorSaturation(inout vec3 color) {
	float grayVibrance = (color.r + color.g + color.b) / 3.0;
	float graySaturation = dot(color, vec3(0.299, 0.587, 0.114));

	float mn = min(color.r, min(color.g, color.b));
	float mx = max(color.r, max(color.g, color.b));
	float sat = (1.0 - (mx - mn)) * (1.0 - mx) * grayVibrance * 5.0;
	vec3 lightness = vec3((mn + mx) * 0.5);

	color = mix(color, mix(color, lightness, 1.0 - VIBRANCE), sat);
	color = mix(color, lightness, (1.0 - lightness) * (2.0 - VIBRANCE) / 2.0 * abs(VIBRANCE - 1.0));
	color = color * SATURATION - graySaturation * (SATURATION - 1.0);
}


#include "/lib/color/lightColor.glsl"


void main() {
    vec2 newTexCoord = texCoord;

	#ifdef UNDERWATER_DISTORTION
	if (isEyeInWater == 1.0) UnderwaterDistort(newTexCoord);
	#endif

	vec3 color = texture2D(colortex0, newTexCoord).rgb;



	color = pow(color, vec3(1.0 / 2.2));

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