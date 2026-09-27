extends Node3D

const FighterScript = preload("res://scripts/fighter.gd")
const CameraScript = preload("res://scripts/combat_camera.gd")
const HUDScript = preload("res://scripts/hud.gd")
const VFXScript = preload("res://scripts/combat_vfx_pool.gd")
const QualityScript = preload("res://scripts/quality_manager.gd")
const AudioManagerScript = preload("res://scripts/audio_manager.gd")

signal sfx_requested(cue, position)

var hud
var camera_rig
var player = null
var enemy = null
var selected_player_variant: int = 0
var selected_enemy_variant: int = 2
var selected_difficulty: int = 1
var match_running: bool = false
var vfx_pool
var quality_manager
var audio_manager
var world_environment: WorldEnvironment
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var hit_stop_serial: int = 0
var ultimate_light_serial: int = 0
var city_body_material: StandardMaterial3D
var city_band_blue_material: StandardMaterial3D
var city_band_red_material: StandardMaterial3D
var pillar_blue_material: StandardMaterial3D
var pillar_red_material: StandardMaterial3D
var gate_blue_material: StandardMaterial3D
var gate_red_material: StandardMaterial3D

func _ready() -> void:
    randomize()
    Engine.max_fps = 60
    if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
        DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
    _build_world()
    _build_arena()

    vfx_pool = VFXScript.new()
    vfx_pool.name = "CombatVFXPool"
    add_child(vfx_pool)

    quality_manager = QualityScript.new()
    quality_manager.name = "QualityManager"
    add_child(quality_manager)

    audio_manager = AudioManagerScript.new()
    audio_manager.name = "AudioManager"
    add_child(audio_manager)
    sfx_requested.connect(audio_manager.play_sfx)

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
    hud.time_expired.connect(_on_time_expired)
    hud.quality_requested.connect(_on_quality_requested)
    quality_manager.apply_preset(self, 1, vfx_pool)

func _build_world() -> void:
    world_environment = WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ShaderMaterial.new()
    sky_mat.shader = load("res://shaders/cyber_sky.gdshader")
    sky.sky_material = sky_mat
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.20, 0.27, 0.43)
    environment.ambient_light_energy = 0.72
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.glow_enabled = true
    environment.glow_bloom = 0.12
    environment.glow_intensity = 0.20
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.08, 0.12, 0.24)
    environment.fog_light_energy = 0.52
    environment.fog_density = 0.0032
    environment.fog_depth_begin = 22.0
    environment.fog_depth_end = 95.0
    world_environment.environment = environment
    add_child(world_environment)

    key_light = DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-48, -32, 0)
    key_light.light_color = Color(0.72, 0.82, 1.0)
    key_light.light_energy = 1.3
    key_light.shadow_enabled = true
    key_light.directional_shadow_max_distance = 40.0
    add_child(key_light)

    fill_light = DirectionalLight3D.new()
    fill_light.rotation_degrees = Vector3(-25, 145, 0)
    fill_light.light_color = Color(1.0, 0.20, 0.32)
    fill_light.light_energy = 0.38
    fill_light.shadow_enabled = false
    add_child(fill_light)

    _build_sky_landmarks()

func _build_sky_landmarks() -> void:
    var moon := MeshInstance3D.new()
    moon.name = "DistantEnergyMoon"
    var sphere := SphereMesh.new()
    sphere.radius = 7.5
    sphere.height = 15.0
    sphere.radial_segments = 20
    sphere.rings = 10
    moon.mesh = sphere
    moon.position = Vector3(-48.0, 34.0, -88.0)
    var moon_mat := StandardMaterial3D.new()
    moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    moon_mat.albedo_color = Color(0.22, 0.36, 0.72)
    moon_mat.emission_enabled = true
    moon_mat.emission = Color(0.30, 0.52, 1.0)
    moon_mat.emission_energy_multiplier = 1.35
    moon.material_override = moon_mat
    add_child(moon)

    var fragments := MultiMeshInstance3D.new()
    fragments.name = "SkyEnergyFragments"
    var shard_mesh := BoxMesh.new()
    shard_mesh.size = Vector3(0.22, 1.5, 0.08)

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = shard_mesh
    multi.instance_count = 28

    for i in range(28):
        var angle: float = TAU * float(i) / 28.0 + float(i % 3) * 0.08
        var radius: float = 30.0 + float((i * 5) % 11) * 2.3
        var height: float = 8.0 + float((i * 7) % 13) * 1.65
        var origin := Vector3(cos(angle) * radius, height, sin(angle) * radius)
        var basis := Basis(Vector3.UP, angle + float(i % 5) * 0.23)
        basis = basis.rotated(Vector3.RIGHT, -0.35 + float(i % 7) * 0.10)
        basis = basis.scaled(Vector3(0.65 + float(i % 4) * 0.16, 0.8 + float(i % 5) * 0.14, 1.0))
        multi.set_instance_transform(i, Transform3D(basis, origin))

    fragments.multimesh = multi
    var shard_mat := StandardMaterial3D.new()
    shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shard_mat.albedo_color = Color(0.08, 0.40, 0.78)
    shard_mat.emission_enabled = true
    shard_mat.emission = Color(0.10, 0.58, 1.0)
    shard_mat.emission_energy_multiplier = 1.25
    fragments.material_override = shard_mat
    add_child(fragments)

func _build_arena() -> void:
    _build_shared_arena_materials()
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
    _add_floor_linework(arena_root)

    for i in range(16):
        var angle := TAU * float(i) / 16.0
        var pos := Vector3(cos(angle) * 25.2, 1.75, sin(angle) * 25.2)
        _add_boundary_segment(arena_root, pos, angle)

    for i in range(12):
        var angle := TAU * float(i) / 12.0 + TAU / 24.0
        var pos := Vector3(cos(angle) * 21.8, 1.7, sin(angle) * 21.8)
        _add_pillar(arena_root, pos, i % 2 == 0)

    _build_city_backdrop(arena_root)

func _add_floor_linework(parent: Node3D) -> void:
    var instance := MultiMeshInstance3D.new()
    instance.name = "ArenaLinework"

    var line_mesh := BoxMesh.new()
    line_mesh.size = Vector3(1.0, 0.025, 1.0)

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = line_mesh

    var transforms: Array[Transform3D] = []
    var radial_count: int = 16
    for i in range(radial_count):
        var angle: float = TAU * float(i) / float(radial_count)
        var basis := Basis(Vector3.UP, -angle)
        basis = basis.scaled(Vector3(0.045, 1.0, 20.5))
        var origin := Vector3(cos(angle) * 10.0, 0.055, sin(angle) * 10.0)
        transforms.append(Transform3D(basis, origin))

    var ring_radii: Array[float] = [5.0, 11.5, 18.0, 22.7]
    var ring_segments: int = 24
    for radius in ring_radii:
        var segment_length: float = TAU * radius / float(ring_segments) * 0.90
        for i in range(ring_segments):
            var angle: float = TAU * float(i) / float(ring_segments)
            var tangent_rotation: float = -angle
            var basis := Basis(Vector3.UP, tangent_rotation)
            basis = basis.scaled(Vector3(segment_length * 0.5, 1.0, 0.055))
            var origin := Vector3(cos(angle) * radius, 0.06, sin(angle) * radius)
            transforms.append(Transform3D(basis, origin))

    multi.instance_count = transforms.size()
    for i in range(transforms.size()):
        multi.set_instance_transform(i, transforms[i])

    instance.multimesh = multi
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0.06, 0.34, 0.72)
    mat.emission_enabled = true
    mat.emission = Color(0.08, 0.54, 1.0)
    mat.emission_energy_multiplier = 1.45
    instance.material_override = mat
    parent.add_child(instance)

func _build_shared_arena_materials() -> void:
    city_body_material = StandardMaterial3D.new()
    city_body_material.albedo_color = Color(0.018,0.025,0.052)
    city_body_material.metallic = 0.48
    city_body_material.roughness = 0.42

    city_band_blue_material = _make_shared_emissive(Color(0.08,0.48,1.0),1.7,0.34)
    city_band_red_material = _make_shared_emissive(Color(1.0,0.08,0.34),1.7,0.34)
    pillar_blue_material = _make_shared_emissive(Color(0.08,0.50,1.0),1.75,0.40)
    pillar_red_material = _make_shared_emissive(Color(1.0,0.12,0.26),1.75,0.40)
    gate_blue_material = _make_shared_emissive(Color(0.10,0.58,1.0),1.9,0.30)
    gate_red_material = _make_shared_emissive(Color(1.0,0.10,0.36),1.9,0.30)

func _make_shared_emissive(color: Color, energy: float, roughness_value: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color.darkened(0.45)
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    mat.roughness = roughness_value
    return mat

func _build_city_backdrop(parent: Node3D) -> void:
    for i in range(16):
        var angle := TAU * float(i) / 16.0
        var radius := 35.0 + float((i * 7) % 5) * 2.6
        var height := 7.0 + float((i * 11) % 9) * 1.25
        var width := 3.6 + float(i % 3) * 0.7
        var accent := Color(0.08,0.48,1.0) if i % 2 == 0 else Color(1.0,0.08,0.34)
        var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        _add_city_tower(parent, pos, height, width, accent)

    for i in range(4):
        var angle := TAU * float(i) / 4.0 + PI * 0.25
        var pos := Vector3(cos(angle) * 29.0, 0.0, sin(angle) * 29.0)
        _add_neon_gate(parent, pos, -angle + PI * 0.5, i % 2 == 0)

func _add_city_tower(parent: Node3D, pos: Vector3, height: float, width: float, accent: Color) -> void:
    var body := MeshInstance3D.new()
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(width, height, width * 0.82)
    body.mesh = body_mesh
    body.position = pos + Vector3.UP * (height * 0.5 - 0.25)

    body.material_override = city_body_material
    parent.add_child(body)
    body.look_at(Vector3(0, body.position.y, 0), Vector3.UP)

    for band_index in range(2):
        var band := MeshInstance3D.new()
        var band_mesh := BoxMesh.new()
        band_mesh.size = Vector3(width * 1.04, 0.13, width * 0.86)
        band.mesh = band_mesh
        band.position = pos + Vector3.UP * (height * (0.35 + band_index * 0.34))
        band.rotation.y = body.rotation.y
        band.material_override = city_band_blue_material if accent.b > accent.r else city_band_red_material
        parent.add_child(band)

func _add_neon_gate(parent: Node3D, pos: Vector3, rot_y: float, blue: bool) -> void:
    var accent := Color(0.10,0.58,1.0) if blue else Color(1.0,0.10,0.36)
    var gate := Node3D.new()
    gate.position = pos
    gate.rotation.y = rot_y
    parent.add_child(gate)

    for x in [-2.4, 2.4]:
        var post := MeshInstance3D.new()
        var post_mesh := BoxMesh.new()
        post_mesh.size = Vector3(0.32, 5.6, 0.42)
        post.mesh = post_mesh
        post.position = Vector3(x,2.8,0)
        post.material_override = gate_blue_material if blue else gate_red_material
        gate.add_child(post)

    var beam := MeshInstance3D.new()
    var beam_mesh := BoxMesh.new()
    beam_mesh.size = Vector3(5.2,0.32,0.42)
    beam.mesh = beam_mesh
    beam.position = Vector3(0,5.45,0)
    beam.material_override = gate_blue_material if blue else gate_red_material
    gate.add_child(beam)

func _neon_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color.darkened(0.45)
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 1.9
    mat.roughness = 0.30
    return mat

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
    pillar.material_override = pillar_blue_material if blue else pillar_red_material
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
    _start_round_intro()

func _start_round_intro() -> void:
    if not is_instance_valid(player) or not is_instance_valid(enemy):
        return
    if DisplayServer.get_name() == "headless":
        player.controls_enabled = true
        enemy.controls_enabled = true
        return
    player.controls_enabled = false
    enemy.controls_enabled = false
    hud.play_round_banner("READY", Color(0.62,0.84,1.0))
    await get_tree().create_timer(0.58, false).timeout
    if not is_instance_valid(player) or not is_instance_valid(enemy) or not match_running:
        return
    hud.play_round_banner("FIGHT!", Color(1.0,0.76,0.20))
    camera_rig.add_shake(0.28)
    player.controls_enabled = true
    enemy.controls_enabled = true
    await get_tree().create_timer(0.42, false).timeout
    hud.hide_round_banner()

func _connect_fighter(fighter) -> void:
    fighter.knocked_out.connect(_on_knocked_out)
    fighter.impact.connect(_on_impact)
    fighter.ultimate_started.connect(_on_ultimate_started)
    fighter.perfect_evade.connect(_on_perfect_evade)
    fighter.perfect_parry.connect(_on_perfect_parry)
    fighter.combat_fx.connect(_on_combat_fx)

func _restart_match() -> void:
    if is_instance_valid(player):
        player.set_victory_pose(false)
    if is_instance_valid(enemy):
        enemy.set_victory_pose(false)
    _start_match(selected_player_variant, selected_enemy_variant, selected_difficulty)

func _return_to_menu() -> void:
    match_running = false
    hit_stop_serial += 1
    Engine.time_scale = 1.0
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
    var winner = player if loser == enemy else enemy
    if is_instance_valid(player):
        player.controls_enabled = false
    if is_instance_valid(enemy):
        enemy.controls_enabled = false
    if is_instance_valid(winner):
        winner.set_victory_pose(true)
    camera_rig.play_ko(winner, loser)
    _mobile_haptic(2.0)

    var result_text: String = "K.O.\nVICTORY" if loser == enemy else "K.O.\nDEFEAT"
    if DisplayServer.get_name() == "headless":
        hud.show_result(result_text)
        return
    await get_tree().create_timer(0.72,false).timeout
    hud.show_result(result_text)

func _on_time_expired() -> void:
    if not match_running or not is_instance_valid(player) or not is_instance_valid(enemy):
        return
    match_running = false
    var player_ratio: float = player.health / maxf(1.0, player.max_health)
    var enemy_ratio: float = enemy.health / maxf(1.0, enemy.max_health)
    if absf(player_ratio - enemy_ratio) < 0.001:
        hud.show_result("TIME\nDRAW")
    elif player_ratio > enemy_ratio:
        hud.show_result("TIME\nVICTORY")
    else:
        hud.show_result("TIME\nDEFEAT")

func _on_impact(position: Vector3, strength: float, color: Color) -> void:
    camera_rig.add_shake(strength)
    _spawn_impact_vfx(position, strength, color)
    if strength >= 1.0 and vfx_pool != null:
        vfx_pool.spawn_effect("shockwave", Vector3(position.x, 0.075, position.z), Vector3.UP, color, strength)
    _mobile_haptic(strength)
    sfx_requested.emit("impact", position)
    _request_hit_stop(clampf(0.018 + strength * 0.020, 0.022, 0.065))

func _on_combat_fx(kind: String, position: Vector3, direction: Vector3, color: Color, strength: float) -> void:
    if vfx_pool != null:
        vfx_pool.spawn_effect(kind, position, direction, color, strength)
    if kind in ["slash","dual_slash","cleave","plasma"]:
        sfx_requested.emit("swing", position)
    elif kind == "dash":
        if vfx_pool != null:
            vfx_pool.spawn_effect("dust", Vector3(position.x,0.07,position.z), direction, Color(0.42,0.34,0.28), strength)
        sfx_requested.emit("dash", position)
    elif kind in ["aura","charge","arcane"]:
        sfx_requested.emit("energy", position)

func _on_ultimate_started(attacker, victim) -> void:
    camera_rig.play_ultimate(attacker, victim)
    if vfx_pool != null:
        vfx_pool.spawn_effect("aura", attacker.global_position + Vector3.UP * 1.2, -attacker.global_transform.basis.z, attacker.fighter_color, 2.0)
        vfx_pool.spawn_effect("shockwave", Vector3(attacker.global_position.x,0.08,attacker.global_position.z), Vector3.UP, attacker.fighter_color, 1.8)
    _pulse_ultimate_lighting(attacker.fighter_color)
    _mobile_haptic(1.8)
    sfx_requested.emit("ultimate", attacker.global_position)

func _on_perfect_evade(fighter) -> void:
    camera_rig.add_shake(0.55)
    if vfx_pool != null:
        vfx_pool.spawn_effect("dash", fighter.global_position + Vector3.UP, fighter.velocity, Color(0.7, 0.9, 1.0), 0.9)

func _on_perfect_parry(defender, _attacker) -> void:
    camera_rig.add_shake(1.2)
    if vfx_pool != null:
        vfx_pool.spawn_effect("impact", defender.global_position + Vector3.UP * 1.2, Vector3.UP, Color(1.0, 0.85, 0.25), 1.4)
    sfx_requested.emit("parry", defender.global_position)
    _request_hit_stop(0.055)

func _spawn_impact_vfx(position: Vector3, strength: float, color: Color) -> void:
    if vfx_pool != null:
        vfx_pool.spawn_effect("impact", position, Vector3.UP, color, strength)

func _request_hit_stop(duration: float) -> void:
    if DisplayServer.get_name() == "headless":
        return
    hit_stop_serial += 1
    var serial: int = hit_stop_serial
    Engine.time_scale = 0.08
    await get_tree().create_timer(duration, true, false, true).timeout
    if serial == hit_stop_serial:
        Engine.time_scale = 1.0


func _mobile_haptic(strength: float) -> void:
    if OS.get_name() != "Android":
        return
    var duration_ms: int = clampi(int(10.0 + strength * 10.0), 10, 32)
    var amplitude: float = clampf(0.32 + strength * 0.18, 0.32, 0.82)
    Input.vibrate_handheld(duration_ms, amplitude)

func _pulse_ultimate_lighting(color: Color) -> void:
    if DisplayServer.get_name() == "headless":
        return
    ultimate_light_serial += 1
    var serial: int = ultimate_light_serial
    if fill_light != null:
        fill_light.light_color = color.lerp(Color.WHITE, 0.16)
        fill_light.light_energy = 1.05
    if key_light != null:
        key_light.light_energy = 1.55
    if world_environment != null and world_environment.environment != null:
        world_environment.environment.ambient_light_color = color.darkened(0.45)
        world_environment.environment.ambient_light_energy = 0.92
        if world_environment.environment.glow_enabled:
            world_environment.environment.glow_intensity += 0.10
    await get_tree().create_timer(0.46, false).timeout
    if serial != ultimate_light_serial:
        return
    if fill_light != null:
        fill_light.light_color = Color(1.0,0.20,0.32)
        fill_light.light_energy = 0.38
    if key_light != null:
        key_light.light_energy = 1.3
    if world_environment != null and world_environment.environment != null:
        world_environment.environment.ambient_light_color = Color(0.20,0.27,0.43)
        world_environment.environment.ambient_light_energy = 0.72
    if quality_manager != null:
        quality_manager.apply_preset(self, quality_manager.current_level, vfx_pool)

func _on_quality_requested(level: int) -> void:
    if quality_manager != null:
        quality_manager.apply_preset(self, level, vfx_pool)
