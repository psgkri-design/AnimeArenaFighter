extends Node3D

const POOL_SIZE: int = 24

var effect_nodes: Array[Node3D] = []
var effect_materials: Array[ShaderMaterial] = []
var timers: Array[float] = []
var durations: Array[float] = []
var start_scales: Array[Vector3] = []
var target_scales: Array[Vector3] = []
var effect_kinds: Array[String] = []
var cursor: int = 0
var quality_level: int = 1
var dust_material: StandardMaterial3D

func _ready() -> void:
    dust_material = StandardMaterial3D.new()
    dust_material.albedo_color = Color(0.30,0.25,0.22,0.72)
    dust_material.roughness = 1.0
    dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    for i in range(POOL_SIZE):
        var root := Node3D.new()
        root.name = "PooledFX_%02d" % i
        root.visible = false
        add_child(root)

        var material := ShaderMaterial.new()
        material.shader = load("res://shaders/energy.gdshader")
        material.set_shader_parameter("energy_color", Color(0.2,0.8,1.0,0.92))

        var core := MeshInstance3D.new()
        core.name = "Core"
        var sphere := SphereMesh.new()
        sphere.radius = 0.24
        sphere.height = 0.48
        core.mesh = sphere
        core.material_override = material
        root.add_child(core)

        for ray_index in range(6):
            var ray := MeshInstance3D.new()
            ray.name = "Ray_%d" % ray_index
            var ray_mesh := BoxMesh.new()
            ray_mesh.size = Vector3(0.035, 0.035, 1.25)
            ray.mesh = ray_mesh
            ray.material_override = material
            ray.rotation = Vector3(
                -0.55 + float(ray_index % 3) * 0.52,
                TAU * float(ray_index) / 6.0,
                -0.35 + float(ray_index % 2) * 0.70
            )
            ray.position = -ray.transform.basis.z * 0.40
            root.add_child(ray)

        var ground_disc := MeshInstance3D.new()
        ground_disc.name = "GroundDisc"
        var disc_mesh := CylinderMesh.new()
        disc_mesh.top_radius = 0.62
        disc_mesh.bottom_radius = 0.62
        disc_mesh.height = 0.018
        disc_mesh.radial_segments = 24
        ground_disc.mesh = disc_mesh
        ground_disc.material_override = material
        root.add_child(ground_disc)

        for dust_index in range(4):
            var dust := MeshInstance3D.new()
            dust.name = "Dust_%d" % dust_index
            var dust_mesh := SphereMesh.new()
            dust_mesh.radius = 0.095
            dust_mesh.height = 0.18
            dust.mesh = dust_mesh
            dust.material_override = dust_material
            var angle: float = TAU * float(dust_index) / 4.0
            dust.position = Vector3(cos(angle) * 0.36, 0.08 + float(dust_index % 2) * 0.05, sin(angle) * 0.36)
            dust.scale = Vector3(1.4, 0.46, 1.4)
            root.add_child(dust)

        effect_nodes.append(root)
        effect_materials.append(material)
        timers.append(0.0)
        durations.append(0.0)
        start_scales.append(Vector3.ONE)
        target_scales.append(Vector3.ONE)
        effect_kinds.append("")
        _configure_visuals(root, "")

func _process(delta: float) -> void:
    for i in range(effect_nodes.size()):
        if timers[i] <= 0.0:
            continue
        timers[i] = maxf(0.0, timers[i] - delta)
        var duration: float = maxf(durations[i], 0.001)
        var progress: float = 1.0 - timers[i] / duration
        var eased: float = 1.0 - pow(1.0 - progress, 3.0)
        var root: Node3D = effect_nodes[i]
        root.scale = start_scales[i].lerp(target_scales[i], eased)
        match effect_kinds[i]:
            "slash", "dual_slash", "cleave":
                root.rotation.z += delta * (7.2 if effect_kinds[i] == "dual_slash" else 4.2)
            "arcane":
                root.rotation.x += delta * 4.4
                root.rotation.y += delta * 6.0
            "plasma":
                root.rotation.y += delta * 8.0
            "aura":
                root.rotation.y += delta * 2.4
            "dust":
                root.rotation.y += delta * 0.7
            "shockwave":
                pass
            _:
                root.rotation.y += delta * 1.2
        if timers[i] <= 0.0:
            root.visible = false

func spawn_effect(kind: String, position: Vector3, direction: Vector3, color: Color, strength: float = 1.0) -> void:
    var index: int = _next_slot()
    var root: Node3D = effect_nodes[index]
    root.visible = true
    root.global_position = position
    root.rotation = Vector3.ZERO

    if direction.length_squared() > 0.001 and kind not in ["shockwave","aura"]:
        root.look_at(position + direction.normalized(), Vector3.UP)

    var duration: float = 0.20
    var start_scale := Vector3.ONE * 0.16
    var target_scale := Vector3.ONE * (0.85 + strength * 0.30)

    match kind:
        "slash":
            duration = 0.18
            start_scale = Vector3(0.18, 0.05, 0.32)
            target_scale = Vector3(2.2 + strength * 0.55, 0.16, 1.15 + strength * 0.20)
            root.rotation.z = -0.45
        "dual_slash":
            duration = 0.14
            start_scale = Vector3(0.12, 0.035, 0.26)
            target_scale = Vector3(1.65 + strength * 0.42, 0.10, 0.78 + strength * 0.14)
            root.rotation.z = -0.72 if index % 2 == 0 else 0.72
        "arcane":
            duration = 0.27
            start_scale = Vector3.ONE * 0.12
            target_scale = Vector3.ONE * (1.20 + strength * 0.34)
            root.rotation = Vector3(0.55, 0.25, -0.35)
        "cleave":
            duration = 0.22
            start_scale = Vector3(0.24, 0.06, 0.34)
            target_scale = Vector3(2.85 + strength * 0.70, 0.24, 1.30 + strength * 0.26)
            root.rotation.z = -0.28
        "plasma":
            duration = 0.16
            start_scale = Vector3(0.12, 0.06, 0.42)
            target_scale = Vector3(1.35 + strength * 0.38, 0.18, 2.15 + strength * 0.55)
            root.rotation.z = 0.18
        "dash":
            duration = 0.24
            start_scale = Vector3(0.22, 0.22, 0.30)
            target_scale = Vector3(0.58, 0.58, 2.7 + strength * 0.45)
        "charge":
            duration = 0.34
            start_scale = Vector3.ONE * 0.10
            target_scale = Vector3.ONE * (1.45 + strength * 0.35)
        "aura":
            duration = 0.52
            start_scale = Vector3.ONE * 0.45
            target_scale = Vector3.ONE * (2.35 + strength * 0.55)
        "shockwave":
            duration = 0.24
            start_scale = Vector3(0.18, 0.04, 0.18)
            target_scale = Vector3(2.7 + strength * 0.85, 0.055, 2.7 + strength * 0.85)
        "dust":
            duration = 0.30
            start_scale = Vector3(0.34, 0.24, 0.34)
            target_scale = Vector3(2.2 + strength * 0.45, 0.60, 2.2 + strength * 0.45)
        _:
            duration = 0.18
            start_scale = Vector3.ONE * 0.18
            target_scale = Vector3.ONE * (0.80 + strength * 0.38)

    var fx_color := color
    fx_color.a = 0.90
    effect_materials[index].set_shader_parameter("energy_color", fx_color)
    timers[index] = duration
    durations[index] = duration
    start_scales[index] = start_scale
    target_scales[index] = target_scale
    effect_kinds[index] = kind
    root.scale = start_scale
    _configure_visuals(root, kind)

func _configure_visuals(root: Node3D, kind: String) -> void:
    var ray_limit: int = 2 if quality_level <= 0 else (4 if quality_level == 1 else 6)
    var dust_limit: int = 1 if quality_level <= 0 else (2 if quality_level == 1 else 4)
    for child in root.get_children():
        var child_name: String = String(child.name)
        if child_name == "Core":
            child.visible = kind in ["impact","charge","aura","arcane"]
        elif child_name.begins_with("Ray_"):
            var ray_index: int = int(child_name.trim_prefix("Ray_"))
            child.visible = kind in ["impact","slash","dual_slash","cleave","plasma","dash","charge","arcane"] and ray_index < ray_limit
        elif child_name == "GroundDisc":
            child.visible = kind in ["shockwave","aura"]
        elif child_name.begins_with("Dust_"):
            var dust_index: int = int(child_name.trim_prefix("Dust_"))
            child.visible = kind == "dust" and dust_index < dust_limit

func set_quality(level: int) -> void:
    quality_level = clampi(level, 0, 2)
    for i in range(effect_nodes.size()):
        _configure_visuals(effect_nodes[i], effect_kinds[i])

func _next_slot() -> int:
    for offset in range(effect_nodes.size()):
        var index: int = (cursor + offset) % effect_nodes.size()
        if timers[index] <= 0.0:
            cursor = (index + 1) % effect_nodes.size()
            return index
    var fallback: int = cursor
    cursor = (cursor + 1) % effect_nodes.size()
    return fallback
