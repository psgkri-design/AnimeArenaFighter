shader_type canvas_item;

uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 p = UV - vec2(0.5);
    float radial = length(p * vec2(1.0, 0.82));
    float edge = smoothstep(0.28, 0.72, radial);
    float top_bottom = smoothstep(0.18, 0.50, abs(p.y));
    float vignette = max(edge, top_bottom * 0.65);
    float alpha = vignette * danger * 0.54 + damage_flash * (0.12 + vignette * 0.28);
    vec3 color = mix(vec3(0.55, 0.015, 0.025), vec3(1.0, 0.08, 0.10), damage_flash);
    COLOR = vec4(color, clamp(alpha, 0.0, 0.72));
}
