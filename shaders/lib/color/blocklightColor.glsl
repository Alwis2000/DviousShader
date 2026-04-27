vec3 blocklightColSqrt = vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B) * BLOCKLIGHT_I / 255.0;
vec3 blocklightColRaw = blocklightColSqrt * blocklightColSqrt;
vec3 blocklightCol = mix(vec3(dot(blocklightColRaw, vec3(0.299, 0.587, 0.114))), blocklightColRaw, 1.0);

#include "/lib/util/palette.glsl"

#if defined MULTICOLORED_BLOCKLIGHT || defined MCBL_SS
vec3[50] lightColorsRGB = vec3[50] (
	PALETTE_RED,
	PALETTE_ORANGE,
	PALETTE_YELLOW,
	PALETTE_LIME,
	PALETTE_GREEN,
	PALETTE_EMERALD,
	PALETTE_CYAN,
	PALETTE_LTBLUE,
	PALETTE_BLUE,
	PALETTE_PURPLE,
	PALETTE_MAGENTA,
	PALETTE_PINK,
    
	PALETTE_RED * 0.8,
	PALETTE_ORANGE * 0.8,
	PALETTE_YELLOW * 0.8,
	PALETTE_LIME * 0.8,
	PALETTE_GREEN * 0.8,
	PALETTE_EMERALD * 0.8,
	PALETTE_CYAN * 0.8,
	PALETTE_LTBLUE * 0.8,
	PALETTE_BLUE * 0.8,
	PALETTE_PURPLE * 0.8,
	PALETTE_MAGENTA * 0.8,
	PALETTE_PINK * 0.8,

	vec3(4.00, 4.00, 4.00),
	
	PALETTE_RED * 0.25,
	PALETTE_ORANGE * 0.25,
	PALETTE_YELLOW * 0.25,
	PALETTE_LIME * 0.25,
	PALETTE_GREEN * 0.25,
	PALETTE_EMERALD * 0.25,
	PALETTE_CYAN * 0.25,
	PALETTE_LTBLUE * 0.25,
	PALETTE_BLUE * 0.25,
	PALETTE_PURPLE * 0.25,
	PALETTE_MAGENTA * 0.25,
	PALETTE_PINK * 0.25,
    
	PALETTE_RED * 0.15,
	PALETTE_ORANGE * 0.15,
	PALETTE_YELLOW * 0.15,
	PALETTE_LIME * 0.15,
	PALETTE_GREEN * 0.15,
	PALETTE_EMERALD * 0.15,
	PALETTE_CYAN * 0.15,
	PALETTE_LTBLUE * 0.15,
	PALETTE_BLUE * 0.15,
	PALETTE_PURPLE * 0.15,
	PALETTE_MAGENTA * 0.15,
	PALETTE_PINK * 0.15,

	vec3(1.00, 1.00, 1.00)
);

vec3[25] tintColorsRGB = vec3[25] (
	PALETTE_RED * 0.2,
	PALETTE_ORANGE * 0.2,
	PALETTE_YELLOW * 0.2,
	PALETTE_LIME * 0.2,
	PALETTE_GREEN * 0.2,
	PALETTE_EMERALD * 0.2,
	PALETTE_CYAN * 0.2,
	PALETTE_LTBLUE * 0.2,
	PALETTE_BLUE * 0.2,
	PALETTE_PURPLE * 0.2,
	PALETTE_MAGENTA * 0.2,
	PALETTE_PINK * 0.2,
    
	PALETTE_RED * 0.1,
	PALETTE_ORANGE * 0.1,
	PALETTE_YELLOW * 0.1,
	PALETTE_LIME * 0.1,
	PALETTE_GREEN * 0.1,
	PALETTE_EMERALD * 0.1,
	PALETTE_CYAN * 0.1,
	PALETTE_LTBLUE * 0.1,
	PALETTE_BLUE * 0.1,
	PALETTE_PURPLE * 0.1,
	PALETTE_MAGENTA * 0.1,
	PALETTE_PINK * 0.1,

	vec3(0.01, 0.01, 0.01)
);
#endif

/*
vec3[50] lightColorsHSV = vec3[50] (
	vec3(0.000, 0.75, 4.00),
	vec3(0.083, 0.75, 4.00),
	vec3(0.167, 0.75, 4.00),
	vec3(0.250, 0.75, 4.00),
	vec3(0.333, 0.75, 4.00),
	vec3(0.417, 0.75, 4.00),
	vec3(0.500, 0.75, 4.00),
	vec3(0.583, 0.75, 4.00),
	vec3(0.667, 0.75, 4.00),
	vec3(0.750, 0.75, 4.00),
	vec3(0.833, 0.75, 4.00),
	vec3(0.917, 0.75, 4.00),

	vec3(0.000, 0.33, 4.00),
	vec3(0.083, 0.33, 4.00),
	vec3(0.167, 0.33, 4.00),
	vec3(0.250, 0.33, 4.00),
	vec3(0.333, 0.33, 4.00),
	vec3(0.417, 0.33, 4.00),
	vec3(0.500, 0.33, 4.00),
	vec3(0.583, 0.33, 4.00),
	vec3(0.667, 0.33, 4.00),
	vec3(0.750, 0.33, 4.00),
	vec3(0.833, 0.33, 4.00),
	vec3(0.917, 0.33, 4.00),

	vec3(0.000, 0.00, 4.00),
	
	vec3(0.000, 0.75, 1.00),
	vec3(0.083, 0.75, 1.00),
	vec3(0.167, 0.75, 1.00),
	vec3(0.250, 0.75, 1.00),
	vec3(0.333, 0.75, 1.00),
	vec3(0.417, 0.75, 1.00),
	vec3(0.500, 0.75, 1.00),
	vec3(0.583, 0.75, 1.00),
	vec3(0.667, 0.75, 1.00),
	vec3(0.750, 0.75, 1.00),
	vec3(0.833, 0.75, 1.00),
	vec3(0.917, 0.75, 1.00),

	vec3(0.000, 0.33, 1.00),
	vec3(0.083, 0.33, 1.00),
	vec3(0.167, 0.33, 1.00),
	vec3(0.250, 0.33, 1.00),
	vec3(0.333, 0.33, 1.00),
	vec3(0.417, 0.33, 1.00),
	vec3(0.500, 0.33, 1.00),
	vec3(0.583, 0.33, 1.00),
	vec3(0.667, 0.33, 1.00),
	vec3(0.750, 0.33, 1.00),
	vec3(0.833, 0.33, 1.00),
	vec3(0.917, 0.33, 1.00),

	vec3(0.000, 0.00, 1.00)
);

vec3[25] tintColorsHSV = vec3[25] (
	vec3(0.000, 0.50, 1.00),
	vec3(0.083, 0.50, 1.00),
	vec3(0.167, 0.50, 1.00),
	vec3(0.250, 0.50, 1.00),
	vec3(0.333, 0.50, 1.00),
	vec3(0.417, 0.50, 1.00),
	vec3(0.500, 0.50, 1.00),
	vec3(0.583, 0.50, 1.00),
	vec3(0.667, 0.50, 1.00),
	vec3(0.750, 0.50, 1.00),
	vec3(0.833, 0.50, 1.00),
	vec3(0.917, 0.50, 1.00),

	vec3(0.000, 0.25, 1.00),
	vec3(0.083, 0.25, 1.00),
	vec3(0.167, 0.25, 1.00),
	vec3(0.250, 0.25, 1.00),
	vec3(0.333, 0.25, 1.00),
	vec3(0.417, 0.25, 1.00),
	vec3(0.500, 0.25, 1.00),
	vec3(0.583, 0.25, 1.00),
	vec3(0.667, 0.25, 1.00),
	vec3(0.750, 0.25, 1.00),
	vec3(0.833, 0.25, 1.00),
	vec3(0.917, 0.25, 1.00),
	vec3(0.000, 0.00, 0.01)
);
*/