shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.2, 0.55, 1.0, 1.0);
uniform float bands : hint_range(2.0, 5.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;

void fragment() {
    ALBEDO = base_color.rgb;
    ROUGHNESS = 0.8;
}

void light() {
    float ndl = max(dot(NORMAL, LIGHT), 0.0);
    float stepped = floor(ndl * bands) / max(bands - 1.0, 1.0);
    float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0) * rim_strength;
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * (0.25 + stepped * 0.75 + rim);
}
