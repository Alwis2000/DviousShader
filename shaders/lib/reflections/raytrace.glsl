vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 1.85;
}

#if REFLECTION_MODE == 0
float errMult = 1.0;
#elif REFLECTION_MODE == 1
float errMult = 1.8;
#else
float errMult = 2.2;
#endif

vec4 Raytrace(sampler2D depthtex, vec3 viewPos, vec3 normal, float dither, out float border, 
			  int maxf, float stp, float ref, float inc) {
	vec3 pos = vec3(0.0);
	float dist = 0.0;
	

	vec3 start = viewPos + normal * 0.075;

    vec3 vector = stp * reflect(normalize(viewPos), normalize(normal));
    viewPos += vector;
	vec3 tvector = vector;

    int sr = 0;

	// Pre-extract projection constants for fast math
	float p00 = gbufferProjection[0][0];
	float p11 = gbufferProjection[1][1];
	float p22 = gbufferProjection[2][2];
	float p32 = gbufferProjection[3][2];

	float ip00 = gbufferProjectionInverse[0][0];
	float ip11 = gbufferProjectionInverse[1][1];
	float ip22 = gbufferProjectionInverse[2][2];
	float ip32 = gbufferProjectionInverse[3][2];
	float ip23 = gbufferProjectionInverse[2][3];
	float ip33 = gbufferProjectionInverse[3][3];

    for(int i = 0; i < 6; i++) {
		// FAST PROJECTION
		float invW = 1.0 / (-viewPos.z);
		pos.x = (p00 * viewPos.x) * invW * 0.5 + 0.5;
		pos.y = (p11 * viewPos.y) * invW * 0.5 + 0.5;
		pos.z = (p22 * viewPos.z + p32) * invW * 0.5 + 0.5;

		if (any(greaterThan(abs(pos.xy - 0.5), vec2(0.55)))) break;

		float sampleDepth = texture2DLod(depthtex, pos.xy, 0).r;
		
		// FAST INVERSE PROJECTION
		vec3 ndc = vec3(pos.xy, sampleDepth) * 2.0 - 1.0;
		float invW2 = 1.0 / (ip23 * ndc.z + ip33);
        vec3 rfragpos = vec3(ip00 * ndc.x, ip11 * ndc.y, ip22 * ndc.z + ip32) * invW2;

		#if REFLECTION_LOD == 1
		if (sampleDepth >= 1.0) {
			#ifdef VOXY
			sampleDepth = texture2DLod(vxDepthTexOpaque, pos.xy, 0).r;
			if (sampleDepth < 1.0) {
				vec3 ndcVX = vec3(pos.xy, sampleDepth) * 2.0 - 1.0;
				float invWVX = 1.0 / (vxProjInv[2][3] * ndcVX.z + vxProjInv[3][3]);
				rfragpos = vec3(vxProjInv[0][0] * ndcVX.x, vxProjInv[1][1] * ndcVX.y, vxProjInv[2][2] * ndcVX.z + vxProjInv[3][2]) * invWVX;
			}
			#ifdef DISTANT_HORIZONS
			else {
				sampleDepth = texture2DLod(dhDepthTex1, pos.xy, 0).r;
				if (sampleDepth < 1.0) {
					vec3 ndcDH = vec3(pos.xy, sampleDepth) * 2.0 - 1.0;
					float invWDH = 1.0 / (dhProjectionInverse[2][3] * ndcDH.z + dhProjectionInverse[3][3]);
					rfragpos = vec3(dhProjectionInverse[0][0] * ndcDH.x, dhProjectionInverse[1][1] * ndcDH.y, dhProjectionInverse[2][2] * ndcDH.z + dhProjectionInverse[3][2]) * invWDH;
				}
			}
			#endif
			#elif defined DISTANT_HORIZONS
			sampleDepth = texture2DLod(dhDepthTex1, pos.xy, 0).r;
			if (sampleDepth < 1.0) {
				vec3 ndcDH = vec3(pos.xy, sampleDepth) * 2.0 - 1.0;
				float invWDH = 1.0 / (dhProjectionInverse[2][3] * ndcDH.z + dhProjectionInverse[3][3]);
				rfragpos = vec3(dhProjectionInverse[0][0] * ndcDH.x, dhProjectionInverse[1][1] * ndcDH.y, dhProjectionInverse[2][2] * ndcDH.z + dhProjectionInverse[3][2]) * invWDH;
			}
			#endif
		}
		#endif

		dist = abs(dot(normalize(start - rfragpos), normal));

        float err = length(viewPos - rfragpos);
		float lVector = length(vector) * pow(length(tvector), 0.1) * errMult;
		if (err < lVector) {
			sr++;
			if (sr >= maxf) break;
			tvector -= vector;
			vector *= ref;
		}
        vector *= inc;
        tvector += vector;
		viewPos = start + tvector;
    }

	border = cdist(pos.st);

	#if defined REFLECTION_PREVIOUS || defined VOXY_PATCH
	vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos * 2.0 - 1.0, 1.0);
	viewPosPrev /= viewPosPrev.w;
	
	viewPosPrev = gbufferModelViewInverse * viewPosPrev;

	vec4 previousPosition = viewPosPrev + vec4(cameraPosition - previousCameraPosition, 0.0);
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	pos.xy = previousPosition.xy / previousPosition.w * 0.5 + 0.5;
	#endif

	return vec4(pos, dist);
}

vec4 BasicReflect(vec3 viewPos, vec3 normal, out float border) {
	vec3 reflectedViewPos = reflect(viewPos, normal) + normal * dot(viewPos, normal) * 0.5;

	vec3 pos = nvec3(gbufferProjection * nvec4(reflectedViewPos)) * 0.5 + 0.5;

	border = cdist(pos.st);

	return vec4(pos, 0.0);
}