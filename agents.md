# DviousShader Project Analysis & Reference

This document serves as a reference for the AI assistant to understand the structure, logic, and features of **DviousShader**.

## 1. Project Identity
- **Base**: Based on BSL Shaders v10 by Capt Tatsu.
- **Current State**: Heavily modified to support modern Minecraft rendering features like LODs and voxelized lighting.
- **Main Goal**: Extreme high-performance and a clean visual style. 
- **Design Philosophy**: Explicitly avoids heavy post-processing and complex material logic (No Bloom, No Depth of Field, No AO, No Advanced Materials, No Lens Flare, No Auto-Exposure, No TAA/FXAA) to maintain performance and a crisp look.

## 2. Rendering Pipeline Overview
1.  **Gbuffers**: Handles the initial drawing of geometry. Writes data to albedo, normals, and material data. **Advanced Materials (specular/normal maps) are not used.**
2.  **Shadow Pass**: Generates the shadow map. Includes support for `SHADOW_LOD` for Distant Horizons.
3.  **Deferred Passes**:
    - `deferred.glsl`: Initial setup. **Ambient Occlusion (AO) is disabled/unused.**
    - `deferred1.glsl`: Main lighting pass. Handles sun/moon lighting, sky colors, and **LOD Shadows** (ray-tracing for DH and Voxy).
4.  **Composite Passes**: Simplified post-processing. **Bloom and Depth of Field (DoF) are removed/disabled.**
5.  **Final**: Applies tonemapping and outputs to the screen.

## 3. Key Systems & Features
### Lighting & Shadows
- **Vanilla Shadows**: Standard shadow mapping for near-field geometry.
- **LOD Shadows**: Custom ray-marched shadows for Distant Horizons and Voxy geometry (found in `deferred1.glsl`).
- **Multicolored Blocklight (MCBL)**: Screen-space or voxel-based multicolored lighting from blocks.
- **Voxy Integration**: Support for voxelized global illumination and lighting via the Voxy mod.

### Materials & Look
- **Standard Materials**: Focuses on vanilla-style textures with enhanced lighting rather than PBR/Advanced Materials. Water uses simple vertex animation rather than normal maps.
- **Emissive Rendering**: Enhanced emissive properties for ores and specific blocks.
- **Clean Aesthetic**: No post-process blurring or occlusion darkening (No Bloom/DoF/AO/Lens Flare/TAA).

### Atmospherics
- **Fog System**: Dynamic density, height-based fog, and per-biome weather fog.
- **Sky Rendering**: Custom sky gradients, sun/moon shapes, stars, and aurora effects.
- **Distant Horizons Integration**: Specifically handles the transition between vanilla chunks and DH LODs, including fog and lighting consistency.

## 4. Important Files
- `/shaders/lib/settings.glsl`: The main configuration file for toggling features and tweaking values.
- `/shaders/program/deferred1.glsl`: Central logic for lighting, LOD shadows, and atmospheric effects.
- `/shaders/program/gbuffers_terrain.glsl`: Terrain rendering logic.
- `/shaders/program/shadow.glsl`: Shadow map generation.
- `/shaders/shaders.properties`: Defines buffer formats and program mappings for the shader loader (Iris).

## 5. Known Integration Hooks
- **VOXY**: Detected via `#ifdef VOXY`.
- **DISTANT_HORIZONS**: Detected via `#ifdef DISTANT_HORIZONS`.
- **IRIS**: Specific optimizations or features might be guarded by `IS_IRIS`.

---

**Note to User**: Please correct any misunderstandings or add details about your specific modifications that I might have missed!
