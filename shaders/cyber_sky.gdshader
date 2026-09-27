shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.012, 0.020, 0.080);
uniform vec3 horizon_color : source_color = vec3(0.18, 0.035, 0.16);
uniform vec3 lower_color : source_color = vec3(0.010, 0.015, 0.038);

void sky() {
    float y = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
    float upper = smoothstep(0.48, 1.0, y);
    float lower = 1.0 - smoothstep(0.0, 0.50, y);
    vec3 col = mix(horizon_color, zenith_color, upper);
    col = mix(col, lower_color, lower);
    COLOR = col;
}
