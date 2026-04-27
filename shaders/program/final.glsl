/* 
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform sampler2D colortex1;

uniform float viewWidth, viewHeight;
uniform float aspectRatio, frameTimeCounter;

//Optifine Constants//
/*
const int colortex0Format = R11F_G11F_B10F; //main scene
const int colortex1Format = RGB8; //raw translucent, vl, bloom, final scene
const int colortex2Format = RGBA16; //temporal data
const int colortex3Format = RGB8; //smoothness, sky occlusion, entity mask
const int gaux1Format = R8; //cloud distance, ao
const int gaux2Format = RGB10_A2; //reflection image
const int gaux3Format = RGBA16; //opaque normals, refraction vector
const int gaux4Format = RGBA16; //fresnel, dirty lens
const int colortex8Format = RGB8; //colored light
const int colortex9Format = RGB16F; //colored light

const int colortex16Format = RGBA16F;
*/

const bool shadowHardwareFiltering = true;
const float shadowDistanceRenderMul = 1.0;
const float voxelDistance = 32.0;

const int noiseTextureResolution = 512;

const float drynessHalflife = 5.0;
const float wetnessHalflife = 30.0;

//Common Functions//


#ifdef SHADOW
#endif

//Program//
void main() {
    vec2 newTexCoord = texCoord;
	


	vec3 color = texture2DLod(colortex1, newTexCoord, 0).rgb;

	#if CHROMATIC_ABERRATION > 0
	float caStrength = 0.002 * CHROMATIC_ABERRATION;
	
	vec2 caScale = vec2(1.0 / aspectRatio, 1.0);
	color *= vec3(0.0,1.0,0.0);
	color += texture2DLod(colortex1, mix(newTexCoord, vec2(0.5), caScale * -caStrength), 0).rgb * vec3(1.0,0.0,0.0);
	color += texture2DLod(colortex1, mix(newTexCoord, vec2(0.5), caScale * -caStrength * 0.5), 0).rgb * vec3(0.5,0.5,0.0);
	color += texture2DLod(colortex1, mix(newTexCoord, vec2(0.5), caScale * caStrength * 0.5), 0).rgb * vec3(0.0,0.5,0.5);
	color += texture2DLod(colortex1, mix(newTexCoord, vec2(0.5), caScale* caStrength), 0).rgb * vec3(0.0,0.0,1.0);

	color /= vec3(1.5,2.0,1.5);
	#endif
	


	gl_FragColor = vec4(color, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif