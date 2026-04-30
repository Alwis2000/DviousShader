#if defined OVERWORLD
float fogDensity = FOG_DENSITY;
#elif defined NETHER
float fogDensity = FOG_DENSITY_NETHER;
#elif defined END
float fogDensity = FOG_DENSITY_END;
#else
float fogDensity = FOG_DENSITY;
#endif