vec3 lightMorning    = vec3(LIGHT_MR,   LIGHT_MG,   LIGHT_MB)   * LIGHT_MI / 255.0;
vec3 lightDay        = vec3(LIGHT_DR,   LIGHT_DG,   LIGHT_DB)   * LIGHT_DI / 255.0;
vec3 lightEvening    = vec3(LIGHT_ER,   LIGHT_EG,   LIGHT_EB)   * LIGHT_EI / 255.0;

vec3 ambientMorning  = vec3(AMBIENT_MR, AMBIENT_MG, AMBIENT_MB) * AMBIENT_MI / 255.0;
vec3 ambientDay      = vec3(AMBIENT_DR, AMBIENT_DG, AMBIENT_DB) * AMBIENT_DI / 255.0;
vec3 ambientEvening  = vec3(AMBIENT_ER, AMBIENT_EG, AMBIENT_EB) * AMBIENT_EI / 255.0;

float moonPhaseMultiplier[8] = float[8](
    1.0,
    0.875,
    0.75,
    0.625,
    0.5,
    0.625,
    0.75,
    0.875
);

#ifdef NIGHT_MOON_PHASE
float nightMult = 0.3 * moonPhaseMultiplier[moonPhase];
vec3 lightNight      = vec3(LIGHT_NR,   LIGHT_NG,   LIGHT_NB)   * LIGHT_NI * nightMult / 255.0;
vec3 ambientNight    = vec3(AMBIENT_NR, AMBIENT_NG, AMBIENT_NB) * AMBIENT_NI * nightMult / 255.0;
#else
vec3 lightNight      = vec3(LIGHT_NR,   LIGHT_NG,   LIGHT_NB)   * LIGHT_NI * 0.3 / 255.0;
vec3 ambientNight    = vec3(AMBIENT_NR, AMBIENT_NG, AMBIENT_NB) * AMBIENT_NI * 0.3 / 255.0;
#endif

vec4 weatherCol = vec4(vec3(WEATHER_RR, WEATHER_RG, WEATHER_RB) / 255.0, 1.0) * WEATHER_RI;

float mefade = 1.0 - clamp(abs(timeAngle - 0.5) * 8.0 - 1.5, 0.0, 1.0);
float dfade = 1.0 - pow(1.0 - timeBrightness, 1.5);

vec3 CalcSunColor(vec3 morning, vec3 day, vec3 evening) {
	vec3 me = mix(morning, evening, mefade);
	return mix(me, day, dfade);
}

vec3 CalcLightColor(vec3 sun, vec3 night, vec3 weatherCol) {
	vec3 c = mix(night, sun, sunVisibility);
	c = mix(c, dot(c, vec3(0.299, 0.587, 0.114)) * weatherCol, rainStrength);
	return c * c;
}

vec3 lightSun = mix(mix(lightMorning, lightEvening, mefade), lightDay, dfade);

vec3 ambientSun = mix(mix(ambientMorning, ambientEvening, mefade), ambientDay, dfade);

vec3 lightColRaw = mix(lightNight, lightSun, sunVisibility);
vec3 lightColSqrt = mix(lightColRaw, dot(lightColRaw, vec3(0.299, 0.587, 0.114)) * weatherCol.rgb, rainStrength);
vec3 lightCol = lightColSqrt * lightColSqrt;

vec3 ambientColRaw = mix(ambientNight, ambientSun, sunVisibility);
vec3 ambientColSqrt = mix(ambientColRaw, dot(ambientColRaw, vec3(0.299, 0.587, 0.114)) * weatherCol.rgb, rainStrength);
vec3 ambientCol = ambientColSqrt * ambientColSqrt;

// vec3 lightSun   = CalcSunColor(lightMorning, lightDay, lightEvening);
// vec3 ambientSun = CalcSunColor(ambientMorning, ambientDay, ambientEvening);

// vec3 lightCol   = CalcLightColor(lightSun, lightNight, weatherCol.rgb);
// vec3 ambientCol = CalcLightColor(ambientSun, ambientNight, weatherCol.rgb);