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
uniform sampler2D texture;

//Program//
void main() {
	//Texture
	vec4 albedo = texture2D(texture, texCoord);

	#if ALPHA_BLEND == 1
	albedo.rgb = pow(albedo.rgb,vec3(2.2)) * 2.25;
	#endif
	
	#ifdef WHITE_WORLD
	albedo.a = 0.0;
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Uniforms//



//Includes//


//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	gl_Position = ftransform();
	
}

#endif