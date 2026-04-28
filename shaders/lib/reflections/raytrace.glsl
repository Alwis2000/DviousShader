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

    int sr = 0;
    float currentStp = stp * clamp(-viewPos.z * 0.06, 1.0, 8.0);
    vec3 vector = currentStp * reflect(normalize(viewPos), normalize(normal));
    viewPos += vector * (dither * 0.5 + 0.25);
	vec3 tvector = vector * (dither * 0.5 + 0.25);

    for(int i = 0; i < 12; i++) {
		vec4 projPos = gbufferProjection * vec4(viewPos, 1.0);
		if (projPos.w <= 0.0) break;
		pos = projPos.xyz / projPos.w * 0.5 + 0.5;

		if (any(greaterThan(abs(pos.xy - 0.5), vec2(0.55)))) break;

		float sampleDepth = texture2DLod(depthtex, pos.xy, 0).r;
		
		vec3 ndc = vec3(pos.xy, sampleDepth) * 2.0 - 1.0;
		vec4 rfragpos4 = gbufferProjectionInverse * vec4(ndc, 1.0);
        vec3 rfragpos = rfragpos4.xyz / rfragpos4.w;

		#if REFLECTION_LOD == 1
		if (sampleDepth >= 1.0) {
			#ifdef VOXY
			sampleDepth = texture2DLod(vxDepthTexOpaque, pos.xy, 0).r;
			if (sampleDepth < 1.0) {
				vec3 ndcVX = vec3(pos.xy, sampleDepth) * 2.0 - 1.0;
				vec4 rfragposVX = vxProjInv * vec4(ndcVX, 1.0);
				rfragpos = rfragposVX.xyz / rfragposVX.w;
			}
			#ifdef DISTANT_HORIZONS
			else {
				sampleDepth = texture2DLod(dhDepthTex1, pos.xy, 0).r;
				if (sampleDepth < 1.0) {
					vec3 ndcDH = vec3(pos.xy, sampleDepth) * 2.0 - 1.0;
					vec4 rfragposDH = dhProjectionInverse * vec4(ndcDH, 1.0);
					rfragpos = rfragposDH.xyz / rfragposDH.w;
				}
			}
			#endif
			#elif defined DISTANT_HORIZONS
			sampleDepth = texture2DLod(dhDepthTex1, pos.xy, 0).r;
			if (sampleDepth < 1.0) {
				vec3 ndcDH = vec3(pos.xy, sampleDepth) * 2.0 - 1.0;
				vec4 rfragposDH = dhProjectionInverse * vec4(ndcDH, 1.0);
				rfragpos = rfragposDH.xyz / rfragposDH.w;
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

	if (sr == 0) border = 1.0;
	else border = cdist(pos.st);

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

	vec4 projPos = gbufferProjection * vec4(reflectedViewPos, 1.0);
	vec3 pos = (projPos.xyz / projPos.w) * 0.5 + 0.5;

	border = cdist(pos.st);
	if (projPos.w <= 0.0) border = 1.0;

	return vec4(pos, 0.0);
}