#include "/lib/settings.glsl"

// Fragment Shader
#ifdef FSH

// Removed layout specifiers, using gl_FragData.

varying vec2 texCoord;
varying vec4 glColor;

uniform int frameCounter;
uniform int worldTime;
uniform float frameTimeCounter;
uniform float near, far;
uniform float timeAngle, timeBrightness;
uniform vec3 cameraPosition;
uniform vec3 relativeEyePosition;
uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

uniform sampler2D tex;

// Colorwheel function is automatically injected by Iris/Flywheel

void main() {
    vec4 albedo = texture2D(tex, texCoord);
    
    vec2 lightmap;
    float ao;
    vec4 overlayColor;
    
    clrwl_computeFragment(albedo, albedo, lightmap, ao, overlayColor);
    
    if (albedo.a < 0.1) discard;

    // Shadow color for colored shadows (if supported by Dvious)
    // Dvious usually simplifies shadow colors
    albedo.rgb = mix(vec3(1.0), albedo.rgb, 1.0 - pow(1.0 - albedo.a, 1.5));
    albedo.rgb *= 1.0 - pow(albedo.a, 96.0);

    gl_FragData[0] = albedo;
}
#endif

// Vertex Shader
#ifdef VSH

varying vec2 texCoord;
varying vec4 glColor;

void main() {
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glColor = gl_Color;
    
    gl_Position = ftransform();

    // Dvious shadow distortion
    float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
    float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
    
    gl_Position.xy *= 1.0 / distortFactor;
    gl_Position.z = gl_Position.z * 0.2;
}
#endif
