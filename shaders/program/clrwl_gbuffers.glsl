#include "/lib/settings.glsl"

// Fragment Shader
#ifdef FSH

// Removed layout specifiers, using gl_FragData.
varying vec2 texCoord;
varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

uniform sampler2D texture;
uniform sampler2D noisetex;

uniform int frameCounter;
uniform int moonPhase;
uniform int worldTime;
uniform float frameTimeCounter;
uniform float near, far;
uniform float timeAngle, timeBrightness;
#include "/lib/common_uniforms.glsl"
uniform float shadowFade;
uniform float nightVision;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 cameraPosition;
uniform vec3 relativeEyePosition;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

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

// Common Variables
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);
float moonVisibility = clamp(dot(-sunVec, upVec) * 10.0 + 0.5, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float time = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float time = frameTimeCounter * ANIMATION_SPEED;
#endif

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

// Includes
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/lightSkyColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"

#ifdef MULTICOLORED_BLOCKLIGHT
#include "/lib/util/voxelMapHelper.glsl"
#endif

#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
#include "/lib/lighting/coloredBlocklight.glsl"
#endif

// Colorwheel function is automatically injected by Iris/Flywheel

void main() {
    vec4 albedo = texture2D(texture, texCoord);
    
    vec2 lightmap;
    float ao;
    vec4 overlayColor;
    
    // Process color and lightmap with Colorwheel (handles gl_Color, AO, and material logic)
    clrwl_computeFragment(albedo, albedo, lightmap, ao, overlayColor);
    
    if (albedo.a < 0.1) discard;

    // Apply hit/overlay color
    albedo.rgb = mix(albedo.rgb, overlayColor.rgb, overlayColor.a);

    // Setup positions for lighting
    vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
    vec3 viewPos = ToNDC(screenPos);
    vec3 worldPos = ToWorld(viewPos);

    // DviousShader lighting pipeline
    albedo.rgb = pow(albedo.rgb, vec3(2.2));

    #ifndef HALF_LAMBERT
    float dotNL = clamp(dot(normal, lightVec), 0.0, 1.0);
    #else
    float dotNL = clamp(dot(normal, lightVec) * 0.5 + 0.5, 0.0, 1.0);
    dotNL = dotNL * dotNL;
    #endif

    #if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
    blocklightCol = ApplyMultiColoredBlocklight(blocklightCol, screenPos, worldPos, normal, 0.0, lightmap.x);
    #endif

    vec3 shadow = vec3(0.0);
    GetLighting(albedo.rgb, shadow, viewPos, worldPos, normal, lightmap, 1.0, dotNL, 
                1.0, 1.0, 0.0, 0.0);

    #if ALPHA_BLEND == 0
    albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));
    #endif

    /* DRAWBUFFERS:08 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(albedo.rgb, 1.0); // For MCBL
}
#endif

// Vertex Shader
#ifdef VSH

varying vec2 texCoord;
varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

uniform float timeAngle;
uniform mat4 gbufferModelView;

void main() {
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    normal   = normalize(gl_NormalMatrix * gl_Normal);

    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
    float ang = fract(timeAngle - 0.25);
    ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
    sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

    upVec = normalize(gbufferModelView[1].xyz);
    eastVec = normalize(gbufferModelView[0].xyz);

    gl_Position = ftransform();
}
#endif
