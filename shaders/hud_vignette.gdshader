shader_type canvas_item;

uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float speed_lines : hint_range(0.0, 1.0) = 0.0;
uniform float line_phase = 0.0;
uniform vec3 speed_color : source_color = vec3(0.52, 0.82, 1.0);

void fragment() {
    vec2 p = UV - vec2(0.5);
    vec2 aspect_p = p * vec2(1.0, 0.82);
    float radial = length(aspect_p);
    float edge = smoothstep(0.28, 0.72, radial);
    float top_bottom = smoothstep(0.18, 0.50, abs(p.y));
    float vignette = max(edge, top_bottom * 0.65);

    float angle = atan(aspect_p.y, aspect_p.x);
    float spokes = pow(abs(sin(angle * 18.0 + line_phase)), 18.0);
    float radial_gate = smoothstep(0.18, 0.34, radial) * (1.0 - smoothstep(0.66, 0.82, radial));
    float broken = 0.58 + 0.42 * smoothstep(-0.15, 0.65, sin(radial * 88.0 - line_phase * 2.6));
    float line_alpha = spokes * radial_gate * broken * speed_lines * 0.36;

    float damage_alpha = vignette * danger * 0.54 + damage_flash * (0.12 + vignette * 0.28);
    vec3 damage_color = mix(vec3(0.55, 0.015, 0.025), vec3(1.0, 0.08, 0.10), damage_flash);

    float combined_alpha = clamp(damage_alpha + line_alpha, 0.0, 0.76);
    float speed_mix = line_alpha / max(combined_alpha, 0.0001);
    vec3 final_color = mix(damage_color, speed_color, clamp(speed_mix, 0.0, 1.0));
    COLOR = vec4(final_color, combined_alpha);
}
