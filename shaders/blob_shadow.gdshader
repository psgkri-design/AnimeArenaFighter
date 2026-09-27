shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;

uniform vec3 shadow_color : source_color = vec3(0.004, 0.006, 0.012);
uniform float strength : hint_range(0.0, 0.6) = 0.18;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.12);
    float radius = length(p);
    float soft = 1.0 - smoothstep(0.16, 0.50, radius);
    ALBEDO = shadow_color;
    ALPHA = soft * strength;
}
