extends Node

enum Preset { LOW, MEDIUM, HIGH }

var current_level: int = Preset.MEDIUM

func apply_preset(root: Node, level: int, vfx_pool = null) -> void:
    current_level = clampi(level, Preset.LOW, Preset.HIGH)
    var viewport := get_viewport()

    match current_level:
        Preset.LOW:
            Engine.max_fps = 30
            viewport.scaling_3d_scale = 0.72
            viewport.msaa_3d = Viewport.MSAA_DISABLED
            viewport.positional_shadow_atlas_size = 0
        Preset.MEDIUM:
            Engine.max_fps = 60
            viewport.scaling_3d_scale = 0.88
            viewport.msaa_3d = Viewport.MSAA_2X
            viewport.positional_shadow_atlas_size = 1024
        Preset.HIGH:
            Engine.max_fps = 60
            viewport.scaling_3d_scale = 1.0
            viewport.msaa_3d = Viewport.MSAA_4X
            viewport.positional_shadow_atlas_size = 2048

    _apply_light_quality(root)
    _apply_environment_quality(root)
    _apply_decor_quality(root)

    if vfx_pool != null and vfx_pool.has_method("set_quality"):
        vfx_pool.set_quality(current_level)

func _apply_light_quality(root: Node) -> void:
    for child in root.get_children():
        if child is DirectionalLight3D:
            var light := child as DirectionalLight3D
            var is_key_light: bool = light.light_energy > 0.6
            if is_key_light:
                light.shadow_enabled = current_level > Preset.LOW
                light.directional_shadow_max_distance = 34.0 if current_level == Preset.MEDIUM else (46.0 if current_level == Preset.HIGH else 0.0)
        _apply_light_quality(child)

func preset_name() -> String:
    return ["LOW", "MEDIUM", "HIGH"][current_level]


func _apply_environment_quality(root: Node) -> void:
    if root is WorldEnvironment:
        var world := root as WorldEnvironment
        if world.environment != null:
            match current_level:
                Preset.LOW:
                    world.environment.glow_enabled = false
                    world.environment.fog_enabled = false
                Preset.MEDIUM:
                    world.environment.glow_enabled = true
                    world.environment.glow_bloom = 0.10
                    world.environment.glow_intensity = 0.16
                    world.environment.fog_enabled = true
                    world.environment.fog_density = 0.0026
                Preset.HIGH:
                    world.environment.glow_enabled = true
                    world.environment.glow_bloom = 0.16
                    world.environment.glow_intensity = 0.24
                    world.environment.fog_enabled = true
                    world.environment.fog_density = 0.0038
    for child in root.get_children():
        _apply_environment_quality(child)


func _apply_decor_quality(root: Node) -> void:
    var fragments := root.get_node_or_null("SkyEnergyFragments")
    if fragments != null:
        fragments.visible = current_level > Preset.LOW
    var moon := root.get_node_or_null("DistantEnergyMoon")
    if moon != null:
        moon.visible = true
