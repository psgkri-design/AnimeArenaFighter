shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.18, 0.58, 0.96);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.88, 1.0);
uniform vec3 lower_color : source_color = vec3(0.40, 0.58, 0.78);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.84);

void sky() {
    vec3 dir = normalize(EYEDIR);
    float y = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
    float upper = smoothstep(0.42, 0.96, y);
    float lower = 1.0 - smoothstep(0.08, 0.50, y);
    vec3 col = mix(horizon_color, zenith_color, upper);
    col = mix(col, lower_color, lower * 0.42);

    vec3 sun_dir = normalize(vec3(-0.48, 0.56, -0.66));
    float sun = pow(max(dot(dir, sun_dir), 0.0), 180.0);
    float haze = pow(max(dot(dir, sun_dir), 0.0), 16.0);

    float band = 1.0 - smoothstep(0.02, 0.46, abs(dir.y - 0.14));
    float cloud_wave = sin(dir.x * 17.0 + dir.z * 11.0) * 0.52
        + sin(dir.x * 31.0 - dir.z * 19.0) * 0.28
        + sin((dir.x + dir.z) * 47.0) * 0.16;
    float clouds = smoothstep(0.34, 0.78, cloud_wave) * band;
    clouds *= smoothstep(-0.06, 0.16, dir.y);

    col = mix(col, vec3(0.93, 0.97, 1.0), clouds * 0.58);
    col += sun_color * sun * 1.7;
    col += sun_color * haze * 0.12;
    COLOR = col;
}
