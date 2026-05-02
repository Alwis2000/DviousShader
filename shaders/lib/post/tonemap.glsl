void Tonemap(inout vec3 color) {
    color *= 1.4;

    #ifdef COLOR_GRADING
    color.r = pow(max(color.r, 0.0), CG_RC);
    color.g = pow(max(color.g, 0.0), CG_GC);
    color.b = pow(max(color.b, 0.0), CG_BC);
    vec3 cgR = vec3(CG_RR, CG_RG, CG_RB) / 255.0;
    vec3 cgG = vec3(CG_GR, CG_GG, CG_GB) / 255.0;
    vec3 cgB = vec3(CG_BR, CG_BG, CG_BB) / 255.0;
    vec3 cgT = vec3(CG_TR, CG_TG, CG_TB) / 255.0;
    vec3 newColor = color.r * cgR * CG_RI + color.g * cgG * CG_GI + color.b * cgB * CG_BI;
    color = mix(color, newColor, vec3(CG_RM, CG_GM, CG_BM));
    color = mix(color, color * cgT * CG_TI, CG_TM);
    #endif

    // BSL Main Tonemap Curve
    color = color / pow(pow(color, vec3(TONEMAP_UPPER_CURVE)) + pow(vec3(TONEMAP_WHITE_PATH), vec3(TONEMAP_UPPER_CURVE)), vec3(1.0 / TONEMAP_UPPER_CURVE));
    color = color * pow(1.0 + pow(color / vec3(TONEMAP_WHITE_CURVE), vec3(TONEMAP_UPPER_CURVE)), vec3(1.0 / TONEMAP_UPPER_CURVE));

    // BSL Lower Curve (Contrast)
    color = pow(max(color, 0.0), vec3(TONEMAP_LOWER_CURVE));

    // Saturation and Vibrance (Vibrance at 0, Saturation restored to 1.0)
    float l = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(l), color, SATURATION);
    color = max(color, 0.0);

    // Final Gamma Correction
    color = pow(color, vec3(1.0 / 2.2));
}
