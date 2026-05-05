/* 
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/ 

#define DISTANT_HORIZONS
#define SHADOW_PASS

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varying
varying float mat;
varying vec2 texCoord;
varying vec4 color;

//Uniforms
uniform sampler2D tex;

//Program//
void main() {
    vec4 albedo = color;

    // DH LODs are mostly untextured, just vertex colors.
    // We only need to handle basic transparency if needed.
    float water = float(mat > 0.98 && mat < 1.02);
    
    if (water > 0.5) {
        #if !defined WATER_SHADOW_COLOR && !defined WATER_CAUSTICS
            discard;
        #else
            albedo.a = 0.5; // Simplistic alpha for DH water shadows
        #endif
    }

    if (albedo.a < 0.1) discard;

    // Write opaque shadow for non-water, and semi-transparent for water
    gl_FragData[0] = vec4(0.0, 0.0, 0.0, albedo.a);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varying
varying float mat;
varying vec2 texCoord;
varying vec4 color;

//Attributes
attribute int dhMaterialId;

//Program//
void main() {
    texCoord = gl_MultiTexCoord0.xy;
    color = gl_Color;

    mat = 0.0;
    if (dhMaterialId == DH_BLOCK_WATER) mat = 1.0;
    if (dhMaterialId == DH_BLOCK_LEAVES) mat = 3.0;

    // Iris sets up the correct ModelViewProjection for the DH shadow pass.
    // ftransform() gives us the correct clip-space coordinate without matrix gymnastics.
    gl_Position = ftransform();

    // Apply distortion
    float r = length(gl_Position.xy);
    float rCenter = 48.0 / shadowDistance;
    float densityRatio = (16.0 * 2.0 * shadowDistance) / float(shadowMapResolution);
    densityRatio = min(densityRatio, 0.95 / rCenter);

    if (r > 0.0001) {
        float distortedR;
        if (r < rCenter) {
            distortedR = r * densityRatio;
        } else {
            float r1 = (r - rCenter) / (1.0 - rCenter);
            float k = SHADOW_DISTORTION;
            float distorted = r1 / (1.0 - k + k * r1);
            float start = rCenter * densityRatio;
            distortedR = mix(start, 1.0, distorted);
        }
        gl_Position.xy *= (distortedR / r);
    }

    gl_Position.z = gl_Position.z * 0.2;
}

#endif
