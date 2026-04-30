/* 
BSL Shaders v10 Series by Capt Tatsu 
https://capttatsu.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Compute Shader////////////////////////////////////////////////////////////////////////////////////
#ifdef CSH

// Workgroup size optimized for 32-thread (NVIDIA) and 64-thread (AMD) hardware
layout (local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

#ifdef MCBL_HALF_HEIGHT
#if MCBL_DISTANCE == 128
const ivec3 workGroups = ivec3(32, 16, 32);
#elif MCBL_DISTANCE == 192
const ivec3 workGroups = ivec3(48, 24, 48);
#elif MCBL_DISTANCE == 256
const ivec3 workGroups = ivec3(64, 32, 64);
#elif MCBL_DISTANCE == 384
const ivec3 workGroups = ivec3(96, 48, 96);
#elif MCBL_DISTANCE == 512
const ivec3 workGroups = ivec3(128, 64, 128);
#endif
#else
#if MCBL_DISTANCE == 128
const ivec3 workGroups = ivec3(32, 32, 32);
#elif MCBL_DISTANCE == 192
const ivec3 workGroups = ivec3(48, 48, 48);
#elif MCBL_DISTANCE == 256
const ivec3 workGroups = ivec3(64, 64, 64);
#elif MCBL_DISTANCE == 384
const ivec3 workGroups = ivec3(96, 64, 96);
#elif MCBL_DISTANCE == 512
const ivec3 workGroups = ivec3(128, 64, 128);
#endif
#endif

//Uniforms
uniform int frameCounter;
uniform vec3 cameraPosition, previousCameraPosition;

uniform usampler3D voxeltex;
uniform sampler3D lighttex0;
uniform sampler3D lighttex1;

writeonly uniform image3D lightimg0;
writeonly uniform image3D lightimg1;

// Position alias removed from global scope to comply with constant-initialization rules

// Shared memory cache (4x4x4 block + 1 voxel halo on all sides = 6x6x6)
shared vec3 localLight[6][6][6];

//Common Functions
vec3 HSV2RGB(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

//Includes
#include "/lib/color/blocklightColor.glsl"
#include "/lib/util/voxelMapHelper.glsl"
#include "/lib/lighting/voxelColorFetch.glsl"

//Program
void main() {
    int iFrameMod2 = int(frameCounter % 2);

    // Position derived from gl_GlobalInvocationID and gl_LocalInvocationID
    ivec3 pos = ivec3(gl_GlobalInvocationID);
    ivec3 lPos = ivec3(gl_LocalInvocationID);
    int lIdx = int(lPos.x + lPos.y * 4 + lPos.z * 16);

    // Identify the 6x6x6 halo region in the previous frame's world space
    ivec3 blockBase = pos - lPos;
    ivec3 prevHaloBase = (blockBase - ivec3(1)) + ivec3(floor(cameraPosition) - floor(previousCameraPosition));

    // Collaborative Fetch: 64 threads loading 216 voxels into shared memory
    for (int i = 0; i < 216; i += 64) {
        int idx = lIdx + i;
        if (idx < 216) {
            int lz = idx / 36;
            int ly = (idx % 36) / 6;
            int lx = idx % 6;
            
            ivec3 fetchPos = prevHaloBase + ivec3(lx, ly, lz);
            if (iFrameMod2 == 0) localLight[lx][ly][lz] = texelFetch(lighttex1, fetchPos, 0).rgb;
            else localLight[lx][ly][lz] = texelFetch(lighttex0, fetchPos, 0).rgb;
        }
    }

    // Strict synchronization to ensure all 64 threads have populated the cache
    memoryBarrierShared();
    barrier();

    uint voxelData = texelFetch(voxeltex, pos, 0).r;

    // Optimization: Branchless void check (replaces 'if (voxelData == 99)')
    float isNotVoid = 1.0 - (step(98.5, float(voxelData)) * step(float(voxelData), 99.5));

    vec3 emission = GetEmission(voxelData);

    #ifdef MCBL_RANDOM
    // Random emission logic - maintained with minimal branching for stability
    if (dot(emission, emission) > 0.0001) {
        vec3 randomPos = vec3(pos) + floor(cameraPosition) - vec3(voxelMapSize) * 0.5;
        emission = HSV2RGB(GetRandomEmissionHSV(randomPos, voxelData));
    }
    #endif

    vec3 tint = GetTint(voxelData);
    
    // Neighborhood lookup from fast local cache (offset by 1 due to halo padding)
    int x = lPos.x + 1;
    int y = lPos.y + 1;
    int z = lPos.z + 1;

    vec3 neighborSum = vec3(0.0);
    neighborSum += localLight[x + 1][y][z];
    neighborSum += localLight[x - 1][y][z];
    neighborSum += localLight[x][y + 1][z];
    neighborSum += localLight[x][y - 1][z];
    neighborSum += localLight[x][y][z + 1];
    neighborSum += localLight[x][y][z - 1];

    // Optimization: FMA Math for decay (avgLight * 0.995)
    vec3 light = fma(neighborSum, vec3(0.1658333), vec3(0.0));

    // Optimization: Branchless light masking (replaces 'if (emission == vec3(0.0))')
    light = mix(light, vec3(0.0), step(0.0001, dot(emission, emission)));

    vec4 color = vec4(fma(light, tint, emission), 1.0);

    // Apply void mask
    color *= isNotVoid;

    // Final storage
    if (iFrameMod2 == 0) imageStore(lightimg0, pos, color);
    else imageStore(lightimg1, pos, color);
}

#endif
