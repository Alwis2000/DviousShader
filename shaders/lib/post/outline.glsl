float SampleFullLinearDepth(vec2 coord) {
    float z = texture2DLod(depthtex0, coord, 0).r;
    if (z < 1.0) return GetLinearDepth(z, gbufferProjectionInverse);

	#ifdef VOXY
    float vz = texture2DLod(vxDepthTexTrans, coord, 0).r;
    if (vz < 1.0) return GetLinearDepth(vz, vxProjInv);
	#endif

	#ifdef DISTANT_HORIZONS
    float dz = texture2DLod(dhDepthTex0, coord, 0).r;
    if (dz < 1.0) return GetLinearDepth(dz, dhProjectionInverse);
	#endif

    return 1e10;
}

// Optimized version for offset sampling - assumes we likely stay in the same buffer
float SampleFullLinearDepthOffset(vec2 coord, float currentLinZ) {
	// If current pixel is very close, only check the near buffer
	if (currentLinZ < 256.0) {
		float z = texture2DLod(depthtex0, coord, 0).r;
		return z < 1.0 ? GetLinearDepth(z, gbufferProjectionInverse) : 1e10;
	}

    float z = texture2DLod(depthtex0, coord, 0).r;
    if (z < 1.0) return GetLinearDepth(z, gbufferProjectionInverse);

	#ifdef VOXY
    float vz = texture2DLod(vxDepthTexTrans, coord, 0).r;
    if (vz < 1.0) return GetLinearDepth(vz, vxProjInv);
	#endif

	#ifdef DISTANT_HORIZONS
    float dz = texture2DLod(dhDepthTex0, coord, 0).r;
    if (dz < 1.0) return GetLinearDepth(dz, dhProjectionInverse);
	#endif

    return 1e10;
}

void Outline(vec3 color, bool secondPass, out vec4 innerOutline, out float minLinZ) {
	float ph = (OUTLINE_WIDTH * ceil(viewHeight / 1600.0)) / viewHeight;
	float pw = ph / aspectRatio;

	float iOutlineMask = 1.0;
	vec3 iOutlineColor = color;

	float linZ = SampleFullLinearDepth(texCoord);
	minLinZ = linZ;

    // Optimized: Reduced sample count for performance. 4 iterations (8 samples) is usually enough.
    int sampleCount = 2; 

	for (int i = 0; i < sampleCount; i++) {
		vec2 offset = vec2(pw, ph) * outlineOffsets[i];

        float linSampleZ1 = SampleFullLinearDepthOffset(texCoord + offset, linZ);
        float linSampleZ2 = SampleFullLinearDepthOffset(texCoord - offset, linZ);

        minLinZ = min(minLinZ, min(linSampleZ1, linSampleZ2));

        #ifdef OUTLINE_INNER
        float linSampleZSum = linSampleZ1 + linSampleZ2;
        linSampleZSum -= abs(linSampleZ1 - linSampleZ2) * 0.5;
        iOutlineMask *= clamp(1.125 + (linZ * 2.0 - linSampleZSum) * 64.0, 0.0, 1.0);
        #endif
	}

    iOutlineColor *= 1.4;
    iOutlineMask = 1.0 - iOutlineMask;

    innerOutline = vec4(iOutlineColor, iOutlineMask);
}