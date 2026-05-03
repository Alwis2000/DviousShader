#ifndef PALETTE_GLSL
#define PALETTE_GLSL

// Global Tribe Totems //
// Global Tribe Totems //
const vec3 PALETTE_RED     = vec3(255.0,  32.0,   0.0) * (4.0 / 255.0);
const vec3 PALETTE_ORANGE  = vec3(255.0, 160.0,  64.0) * (4.0 / 255.0);
const vec3 PALETTE_YELLOW  = vec3(255.0, 255.0,  64.0) * (4.0 / 255.0);
const vec3 PALETTE_LIME    = vec3(160.0, 255.0,  64.0) * (4.0 / 255.0);
const vec3 PALETTE_GREEN   = vec3( 64.0, 255.0,  64.0) * (4.0 / 255.0);
const vec3 PALETTE_EMERALD = vec3( 64.0, 255.0, 160.0) * (4.0 / 255.0);
const vec3 PALETTE_CYAN    = vec3( 64.0, 255.0, 255.0) * (4.0 / 255.0);
const vec3 PALETTE_LTBLUE  = vec3( 64.0, 160.0, 255.0) * (4.0 / 255.0);
const vec3 PALETTE_BLUE    = vec3( 64.0,  64.0, 255.0) * (4.0 / 255.0);
const vec3 PALETTE_PURPLE  = vec3(160.0,  64.0, 255.0) * (4.0 / 255.0);
const vec3 PALETTE_MAGENTA = vec3(255.0,  64.0, 255.0) * (4.0 / 255.0);
const vec3 PALETTE_PINK    = vec3(255.0,  64.0, 160.0) * (4.0 / 255.0);

const vec3 PALETTE[12] = vec3[12](
	PALETTE_RED, PALETTE_ORANGE, PALETTE_YELLOW, PALETTE_LIME,
	PALETTE_GREEN, PALETTE_EMERALD, PALETTE_CYAN, PALETTE_LTBLUE,
	PALETTE_BLUE, PALETTE_PURPLE, PALETTE_MAGENTA, PALETTE_PINK
);

vec3 GetNearestPaletteColor(vec3 color) {
	float maxDot = -1.0;
	vec3 nearest = PALETTE[1]; // Default to Orange
	vec3 nColor = normalize(color + 1e-5);
	
	for(int i = 0; i < 12; i++) {
		float d = dot(nColor, normalize(PALETTE[i] + 1e-5));
		if (d > maxDot) {
			maxDot = d;
			nearest = PALETTE[i];
		}
	}
	return nearest;
}

#endif
