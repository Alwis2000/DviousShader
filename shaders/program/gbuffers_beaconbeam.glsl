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

varying vec4 color;

//Uniforms//
uniform sampler2D texture;

//Includes//
#include "/lib/color/blocklightColor.glsl"

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord) * color;
	
	#ifdef EMISSIVE_RECOLOR
	if (dot(color.rgb, vec3(1.0)) > 2.66) {
		float ec = length(albedo.rgb);
		albedo.rgb = blocklightCol * (ec * 0.63 / BLOCKLIGHT_I) + ec * 0.07;
	}
	#endif
    
	albedo.rgb = pow(albedo.rgb,vec3(2.2)) * 4.0;
	
	#ifdef WHITE_WORLD
	albedo.rgb = vec3(2.0);
	#endif

	#if ALPHA_BLEND == 0
	albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
	albedo.a = sqrt(albedo.a);
	#endif
    
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;

}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec4 color;

//Uniforms//



//Includes//


//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	color = gl_Color;

	gl_Position = ftransform();
	
}

#endif