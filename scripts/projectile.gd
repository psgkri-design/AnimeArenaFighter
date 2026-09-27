extends Area3D

signal recycle_requested(projectile)

var source = null
var target = null
var style: int = 0
var pooled: bool = false
var active: bool = true
var quality_level: int = 1
var speed: float = 20.0
var damage: float = 85.0
var life: float = 3.5
var knockback: float = 8.0
var launch: float = 1.5
var hitstun: float = 0.42
var block_damage: float = 22.0
var homing_strength: float = 3.2
var impact_strength: float = 0.8
var color := Color(0.15, 0.75, 1.0)
var velocity := Vector3.ZERO
var visual_root: Node3D
var orbit_a: MeshInstance3D
var orbit_b: MeshInstance3D
var projectile_material: ShaderMaterial
var glow_light: OmniLight3D
var trail_segments: Array[MeshInstance3D] = []

func configure(p_source, p_target, p_color: Color, p_damage: float = 85.0, p_style: int = 0) -> void:
    source = p_source
    target = p_target
    color = p_color
    damage = p_damage
    style = clampi(p_style, 0, 3)
    _configure_stats()

func _configure_stats() -> void:
    match style:
        0:
            speed = 23.0; life = 3.0; knockback = 6.0; launch = 0.8; hitstun = 0.36; block_damage = 18.0; homing_strength = 4.2; impact_strength = 0.75
        1:
            speed = 16.5; life = 4.4; knockback = 8.5; launch = 1.8; hitstun = 0.48; block_damage = 24.0; homing_strength = 3.0; impact_strength = 1.0
        2:
            speed = 19.0; life = 3.7; knockback = 11.5; launch = 2.4; hitstun = 0.54; block_damage = 31.0; homing_strength = 2.1; impact_strength = 1.18
        3:
            speed = 27.0; life = 2.8; knockback = 7.0; launch = 1.0; hitstun = 0.34; block_damage = 20.0; homing_strength = 4.8; impact_strength = 0.86

func _ready() -> void:
    collision_layer = 16
    collision_mask = 4
    monitoring = true
    monitorable = true

    visual_root = Node3D.new()
    add_child(visual_root)

    projectile_material = ShaderMaterial.new()
    projectile_material.shader = load("res://shaders/energy.gdshader")
    projectile_material.set_shader_parameter("energy_color", color)

    var core := MeshInstance3D.new()
    core.name = "ProjectileCore"
    match style:
        2:
            var lance := BoxMesh.new()
            lance.size = Vector3(0.20,0.20,1.30)
            core.mesh = lance
        3:
            var plasma := BoxMesh.new()
            plasma.size = Vector3(0.18,0.18,0.78)
            core.mesh = plasma
        _:
            var sphere := SphereMesh.new()
            sphere.radius = 0.26 if style == 0 else 0.40
            sphere.height = 0.52 if style == 0 else 0.80
            core.mesh = sphere
    core.material_override = projectile_material
    visual_root.add_child(core)

    orbit_a = MeshInstance3D.new()
    var ring_mesh_a := CylinderMesh.new()
    ring_mesh_a.top_radius = 0.42 if style == 0 else 0.56
    ring_mesh_a.bottom_radius = ring_mesh_a.top_radius
    ring_mesh_a.height = 0.028
    ring_mesh_a.radial_segments = 16
    orbit_a.mesh = ring_mesh_a
    orbit_a.material_override = projectile_material
    orbit_a.rotation_degrees = Vector3(90,0,0)
    orbit_a.visible = style in [0,1,3]
    visual_root.add_child(orbit_a)

    orbit_b = MeshInstance3D.new()
    var ring_mesh_b := CylinderMesh.new()
    ring_mesh_b.top_radius = 0.48
    ring_mesh_b.bottom_radius = 0.48
    ring_mesh_b.height = 0.022
    ring_mesh_b.radial_segments = 12
    orbit_b.mesh = ring_mesh_b
    orbit_b.material_override = projectile_material
    orbit_b.rotation_degrees = Vector3(0,0,90)
    orbit_b.visible = style == 1
    visual_root.add_child(orbit_b)

    for i in range(3):
        var segment := MeshInstance3D.new()
        var segment_mesh := SphereMesh.new()
        segment_mesh.radius = 0.13 - float(i) * 0.025
        segment_mesh.height = 0.26 - float(i) * 0.05
        segment.mesh = segment_mesh
        segment.material_override = projectile_material
        segment.position = Vector3(0,0,0.38 + float(i) * 0.28)
        segment.scale = Vector3.ONE * (1.0 - float(i) * 0.18)
        add_child(segment)
        trail_segments.append(segment)

    glow_light = OmniLight3D.new()
    glow_light.shadow_enabled = false
    add_child(glow_light)
    _apply_color()

    var quality_root: Node = get_tree().current_scene
    if quality_root == null:
        quality_root = get_parent()
    var quality_manager = quality_root.get_node_or_null("QualityManager") if quality_root != null else null
    if quality_manager != null:
        quality_level = int(quality_manager.current_level)
    _apply_quality_profile()

    var shape := CollisionShape3D.new()
    var sphere_shape := SphereShape3D.new()
    var collision_sizes: Array[float] = [0.32,0.47,0.36,0.30]
    sphere_shape.radius = collision_sizes[style]
    shape.shape = sphere_shape
    add_child(shape)

    area_entered.connect(_on_area_entered)
    if pooled:
        deactivate()
    else:
        _initialize_velocity()

func activate(p_source, p_target, p_color: Color, p_damage: float, p_position: Vector3) -> void:
    configure(p_source,p_target,p_color,p_damage,style)
    global_position = p_position
    rotation = Vector3.ZERO
    visual_root.rotation = Vector3.ZERO
    visual_root.scale = Vector3.ONE
    _apply_color()
    _apply_quality_profile()
    active = true
    visible = true
    monitoring = true
    set_physics_process(true)
    _initialize_velocity()

func deactivate() -> void:
    active = false
    source = null
    target = null
    velocity = Vector3.ZERO
    visible = false
    set_physics_process(false)
    set_deferred("monitoring", false)

func set_quality(level: int) -> void:
    quality_level = clampi(level,0,2)
    _apply_quality_profile()

func _apply_color() -> void:
    if projectile_material != null:
        projectile_material.set_shader_parameter("energy_color", color)
    if glow_light != null:
        glow_light.light_color = color

func _apply_quality_profile() -> void:
    if glow_light == null:
        return
    var base_energy: Array[float] = [1.65,2.45,2.10,1.85]
    var base_range: Array[float] = [2.4,3.4,3.0,2.6]
    match quality_level:
        0:
            glow_light.visible = false
            glow_light.light_energy = base_energy[style] * 0.50
            glow_light.omni_range = base_range[style] * 0.65
            if orbit_b != null:
                orbit_b.visible = false
            for i in range(trail_segments.size()):
                trail_segments[i].visible = i == 0
        1:
            glow_light.visible = true
            glow_light.light_energy = base_energy[style] * 0.72
            glow_light.omni_range = base_range[style] * 0.82
            if orbit_b != null:
                orbit_b.visible = style == 1
            for i in range(trail_segments.size()):
                trail_segments[i].visible = i < 2
        _:
            glow_light.visible = true
            glow_light.light_energy = base_energy[style]
            glow_light.omni_range = base_range[style]
            if orbit_b != null:
                orbit_b.visible = style == 1
            for segment in trail_segments:
                segment.visible = true

func _initialize_velocity() -> void:
    if is_instance_valid(target):
        velocity = (target.global_position + Vector3.UP - global_position).normalized() * speed
    else:
        velocity = -global_transform.basis.z * speed

func _physics_process(delta: float) -> void:
    if pooled and not active:
        return
    life -= delta
    if life <= 0.0:
        _recycle()
        return
    if is_instance_valid(target):
        var desired: Vector3 = (target.global_position + Vector3.UP - global_position).normalized() * speed
        velocity = velocity.lerp(desired, clampf(delta * homing_strength, 0.0, 1.0))
    global_position += velocity * delta
    if velocity.length_squared() > 0.01:
        var direction: Vector3 = velocity.normalized()
        if absf(direction.dot(Vector3.UP)) < 0.96:
            look_at(global_position + direction, Vector3.UP)
    if visual_root != null:
        visual_root.rotation.z += delta * (8.8 if style in [0,3] else 5.4)
        visual_root.rotation.x += delta * (4.0 if style == 1 else 2.2)
        var pulse_speed: float = 0.024 if style == 3 else 0.018
        var pulse_amount: float = 0.11 if style == 1 else 0.07
        visual_root.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * pulse_speed) * pulse_amount)

func _on_area_entered(area: Area3D) -> void:
    if pooled and not active:
        return
    var other = area.get_meta("fighter", null)
    if other == null or other == source or not is_instance_valid(other):
        return
    other.receive_hit(source, {
        "damage": damage,
        "hitstun": hitstun,
        "knockback": knockback,
        "launch": launch,
        "block_damage": block_damage,
        "kind": "projectile"
    })
    if is_instance_valid(source):
        source.register_external_hit(other, damage, global_position, impact_strength)
    _recycle()

func _recycle() -> void:
    if pooled:
        active = false
        visible = false
        set_physics_process(false)
        set_deferred("monitoring", false)
        recycle_requested.emit(self)
    else:
        queue_free()
