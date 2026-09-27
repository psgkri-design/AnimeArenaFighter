extends Area3D

var source = null
var target = null
var speed := 20.0
var damage := 85.0
var life := 3.5
var knockback := 8.0
var color := Color(0.15, 0.75, 1.0)
var velocity := Vector3.ZERO
var visual_root: Node3D
var orbit_a: MeshInstance3D
var orbit_b: MeshInstance3D

func configure(p_source, p_target, p_color: Color, p_damage := 85.0) -> void:
    source = p_source
    target = p_target
    color = p_color
    damage = p_damage

func _ready() -> void:
    collision_layer = 16
    collision_mask = 4
    monitoring = true
    monitorable = true

    visual_root = Node3D.new()
    add_child(visual_root)

    var mesh_instance := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.32
    sphere.height = 0.64
    mesh_instance.mesh = sphere
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/energy.gdshader")
    material.set_shader_parameter("energy_color", color)
    mesh_instance.material_override = material
    visual_root.add_child(mesh_instance)

    orbit_a = MeshInstance3D.new()
    var ring_mesh_a := CylinderMesh.new()
    ring_mesh_a.top_radius = 0.52
    ring_mesh_a.bottom_radius = 0.52
    ring_mesh_a.height = 0.035
    ring_mesh_a.radial_segments = 16
    orbit_a.mesh = ring_mesh_a
    orbit_a.material_override = material
    orbit_a.rotation_degrees = Vector3(90,0,0)
    visual_root.add_child(orbit_a)

    orbit_b = MeshInstance3D.new()
    var ring_mesh_b := CylinderMesh.new()
    ring_mesh_b.top_radius = 0.44
    ring_mesh_b.bottom_radius = 0.44
    ring_mesh_b.height = 0.025
    ring_mesh_b.radial_segments = 12
    orbit_b.mesh = ring_mesh_b
    orbit_b.material_override = material
    orbit_b.rotation_degrees = Vector3(0,0,90)
    visual_root.add_child(orbit_b)

    var glow := OmniLight3D.new()
    glow.light_color = color
    glow.light_energy = 2.2
    glow.omni_range = 3.0
    glow.shadow_enabled = false
    add_child(glow)

    var shape := CollisionShape3D.new()
    var sphere_shape := SphereShape3D.new()
    sphere_shape.radius = 0.4
    shape.shape = sphere_shape
    add_child(shape)

    area_entered.connect(_on_area_entered)

    if is_instance_valid(target):
        velocity = (target.global_position + Vector3.UP - global_position).normalized() * speed
    else:
        velocity = -global_transform.basis.z * speed

func _physics_process(delta: float) -> void:
    life -= delta
    if life <= 0.0:
        queue_free()
        return

    if is_instance_valid(target):
        var desired: Vector3 = (target.global_position + Vector3.UP - global_position).normalized() * speed
        velocity = velocity.lerp(desired, clampf(delta * 3.2, 0.0, 1.0))

    global_position += velocity * delta
    rotate_y(delta * 7.0)
    if visual_root != null:
        visual_root.rotation.x += delta * 7.5
        visual_root.rotation.z += delta * 5.2
        var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.08
        visual_root.scale = Vector3.ONE * pulse

func _on_area_entered(area: Area3D) -> void:
    var other = area.get_meta("fighter", null)
    if other == null or other == source:
        return
    if not is_instance_valid(other):
        return

    var hit := {
        "damage": damage,
        "hitstun": 0.42,
        "knockback": knockback,
        "launch": 1.5,
        "block_damage": 22.0,
        "kind": "projectile"
    }
    other.receive_hit(source, hit)
    if is_instance_valid(source):
        source.register_external_hit(other, damage, global_position, 0.8)
    queue_free()
