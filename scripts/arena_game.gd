extends Node3D

const FighterScript = preload("res://scripts/fighter.gd")
const CameraScript = preload("res://scripts/combat_camera.gd")
const HUDScript = preload("res://scripts/hud.gd")

var hud
var camera_rig
var player = null
var enemy = null
var selected_player_variant: int = 0
var selected_enemy_variant: int = 2
var selected_difficulty: int = 1
var match_running: bool = false

func _ready() -> void:
    randomize()
    Engine.max_fps = 60
    if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
        DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
    _build_world()
    _build_arena()

    camera_rig = CameraScript.new()
    camera_rig.name = "CombatCamera"
    add_child(camera_rig)
    camera_rig.global_position = Vector3(0, 7, 11)

    hud = HUDScript.new()
    hud.name = "HUD"
    add_child(hud)
    hud.start_requested.connect(_start_match)
    hud.restart_requested.connect(_restart_match)
    hud.menu_requested.connect(_return_to_menu)

func _build_world() -> void:
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.012, 0.018, 0.045)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.20, 0.27, 0.43)
    environment.ambient_light_energy = 0.65
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment_node.environment = environment
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_color = Color(0.72, 0.82, 1.0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 40.0
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-25, 145, 0)
    fill.light_color = Color(1.0, 0.20, 0.32)
    fill.light_energy = 0.38
    fill.shadow_enabled = false
    add_child(fill)

func _build_arena() -> void:
    var arena_root := Node3D.new()
    arena_root.name = "Arena"
    add_child(arena_root)

    var floor_body := StaticBody3D.new()
    floor_body.name = "Floor"
    floor_body.collision_layer = 1
    floor_body.collision_mask = 2
    arena_root.add_child(floor_body)

    var floor_mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 25.0
    cylinder.bottom_radius = 25.0
    cylinder.height = 0.6
    cylinder.radial_segments = 64
    floor_mesh.mesh = cylinder
    floor_mesh.position.y = -0.3
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.045, 0.058, 0.095)
    floor_mat.metallic = 0.36
    floor_mat.roughness = 0.50
    floor_mesh.material_override = floor_mat
    floor_body.add_child(floor_mesh)

    var floor_collision := CollisionShape3D.new()
    var floor_shape := CylinderShape3D.new()
    floor_shape.radius = 25.0
    floor_shape.height = 0.6
    floor_collision.shape = floor_shape
    floor_collision.position.y = -0.3
    floor_body.add_child(floor_collision)

    _add_arena_disc(arena_root, 20.0, -0.015, Color(0.03, 0.09, 0.19), 0.03)
    _add_arena_disc(arena_root, 12.0, 0.01, Color(0.06, 0.12, 0.24), 0.025)
    _add_arena_disc(arena_root, 4.2, 0.035, Color(0.10, 0.20, 0.34), 0.02)

    for i in range(16):
        var angle := TAU * float(i) / 16.0
        var pos := Vector3(cos(angle) * 25.2, 1.75, sin(angle) * 25.2)
        _add_boundary_segment(arena_root, pos, angle)

    for i in range(12):
        var angle := TAU * float(i) / 12.0 + TAU / 24.0
        var pos := Vector3(cos(angle) * 21.8, 1.7, sin(angle) * 21.8)
        _add_pillar(arena_root, pos, i % 2 == 0)

func _add_arena_disc(parent: Node3D, radius: float, y: float, color: Color, height_value: float) -> void:
    var mesh_instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height_value
    mesh.radial_segments = 64
    mesh_instance.mesh = mesh
    mesh_instance.position.y = y
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color * 0.8
    mat.emission_energy_multiplier = 0.35
    mat.roughness = 0.4
    mesh_instance.material_override = mat
    parent.add_child(mesh_instance)

func _add_boundary_segment(parent: Node3D, pos: Vector3, angle: float) -> void:
    var wall := StaticBody3D.new()
    wall.collision_layer = 1
    wall.collision_mask = 2
    wall.position = pos
    wall.rotation.y = -angle + PI * 0.5
    parent.add_child(wall)
    var shape_node := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(10.0, 3.5, 0.8)
    shape_node.shape = box
    wall.add_child(shape_node)

func _add_pillar(parent: Node3D, pos: Vector3, blue: bool) -> void:
    var pillar := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.55
    mesh.bottom_radius = 0.85
    mesh.height = 3.4
    mesh.radial_segments = 8
    pillar.mesh = mesh
    pillar.position = pos
    var color := Color(0.08, 0.5, 1.0) if blue else Color(1.0, 0.12, 0.26)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.035, 0.045, 0.075)
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 1.75
    pillar.material_override = mat
    parent.add_child(pillar)

func _start_match(player_variant: int, enemy_variant: int, difficulty: int) -> void:
    selected_player_variant = player_variant
    selected_enemy_variant = enemy_variant
    selected_difficulty = difficulty
    _destroy_fighters()

    player = FighterScript.new()
    player.name = "Player"
    player.configure(selected_player_variant, false, selected_difficulty)
    add_child(player)
    player.global_position = Vector3(0, 0.05, 5.0)

    enemy = FighterScript.new()
    enemy.name = "EnemyAI"
    enemy.configure(selected_enemy_variant, true, selected_difficulty)
    add_child(enemy)
    enemy.global_position = Vector3(0, 0.05, -5.0)

    player.set_target(enemy)
    enemy.set_target(player)
    player._face_target(1.0)
    enemy._face_target(1.0)

    _connect_fighter(player)
    _connect_fighter(enemy)
    player.combo_changed.connect(hud.set_combo)
    camera_rig.set_subjects(player, enemy)
    hud.bind_fighters(player, enemy)
    match_running = true

func _connect_fighter(fighter) -> void:
    fighter.knocked_out.connect(_on_knocked_out)
    fighter.impact.connect(_on_impact)
    fighter.ultimate_started.connect(_on_ultimate_started)
    fighter.perfect_evade.connect(_on_perfect_evade)
    fighter.perfect_parry.connect(_on_perfect_parry)

func _restart_match() -> void:
    _start_match(selected_player_variant, selected_enemy_variant, selected_difficulty)

func _return_to_menu() -> void:
    match_running = false
    _destroy_fighters()
    camera_rig.set_subjects(null, null)
    hud.show_main_menu()

func _destroy_fighters() -> void:
    if is_instance_valid(player):
        player.queue_free()
    if is_instance_valid(enemy):
        enemy.queue_free()
    player = null
    enemy = null

func _on_knocked_out(loser) -> void:
    if not match_running:
        return
    match_running = false
    camera_rig.add_shake(2.0)
    hud.show_result("K.O.\nVICTORY" if loser == enemy else "K.O.\nDEFEAT")

func _on_impact(position: Vector3, strength: float, color: Color) -> void:
    camera_rig.add_shake(strength)
    _spawn_impact_vfx(position, strength, color)

func _on_ultimate_started(attacker, victim) -> void:
    camera_rig.play_ultimate(attacker, victim)
    _spawn_impact_vfx(attacker.global_position + Vector3.UP * 1.2, 2.0, attacker.fighter_color)

func _on_perfect_evade(fighter) -> void:
    camera_rig.add_shake(0.55)
    _spawn_impact_vfx(fighter.global_position + Vector3.UP, 0.9, Color(0.7, 0.9, 1.0))

func _on_perfect_parry(defender, _attacker) -> void:
    camera_rig.add_shake(1.2)
    _spawn_impact_vfx(defender.global_position + Vector3.UP * 1.2, 1.4, Color(1.0, 0.85, 0.25))

func _spawn_impact_vfx(position: Vector3, strength: float, color: Color) -> void:
    var root := Node3D.new()
    root.global_position = position
    add_child(root)
    var core := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.25
    sphere.height = 0.5
    core.mesh = sphere
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/energy.gdshader")
    mat.set_shader_parameter("energy_color", color)
    core.material_override = mat
    root.add_child(core)
    for i in range(7):
        var ray := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(0.045, 0.045, 1.4 + strength * 0.35)
        ray.mesh = box
        ray.material_override = mat
        ray.rotation = Vector3(randf_range(-0.8, 0.8), randf_range(0.0, TAU), randf_range(-0.8, 0.8))
        ray.position = -ray.transform.basis.z * 0.45
        root.add_child(ray)
    root.scale = Vector3.ONE * 0.25
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(root, "scale", Vector3.ONE * (0.8 + strength * 0.38), 0.10)
    tween.tween_property(root, "rotation:y", randf_range(-1.0, 1.0), 0.18)
    tween.set_parallel(false)
    tween.tween_interval(0.08)
    tween.tween_callback(root.queue_free)
