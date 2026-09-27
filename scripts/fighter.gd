extends CharacterBody3D

signal stats_changed(fighter)
signal combo_changed(value)
signal knocked_out(fighter)
signal impact(position, strength, color)
signal ultimate_started(attacker, target)
signal perfect_evade(fighter)
signal perfect_parry(defender, attacker)

enum State { IDLE, MOVE, DASH, DODGE, ATTACK, BLOCK, STUNNED, DEAD }

const ProjectileScript = preload("res://scripts/projectile.gd")
const Roster = preload("res://scripts/character_data.gd")

var state: int = State.IDLE
var is_ai: bool = false
var ai_level: int = 1
var variant: int = 0
var target = null
var lock_on: bool = true

var max_health: float = 1000.0
var health: float = 1000.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var max_energy: float = 100.0
var energy: float = 0.0
var ultimate: float = 0.0
var fighter_color: Color = Color(0.12,0.62,1.0)
var accent_color: Color = Color(0.04,0.08,0.16)
var move_speed: float = 7.2
var power_scale: float = 1.0
var defense_scale: float = 1.0

var gravity: float = 24.0
var jump_velocity: float = 9.4
var arena_radius: float = 23.2

var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dodge_timer: float = 0.0
var iframe_timer: float = 0.0
var stun_timer: float = 0.0
var block_parry_timer: float = 0.0
var ai_timer: float = 0.0
var ai_block_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO

var current_attack: Dictionary = {}
var attack_timer: float = 0.0
var attack_hit_done: bool = false
var combo_step: int = 0
var combo_window: float = 0.0
var combo_hits: int = 0
var skill_cooldowns: Array[float] = [0.0,0.0,0.0,0.0]
var model_root: Node3D
var animation_player: AnimationPlayer = null
var last_animation: StringName = &""
var hit_reaction_toggle: bool = false
var visual_phase: float = 0.0

func configure(p_variant: int, p_is_ai: bool, p_ai_level: int = 1) -> void:
    variant = clampi(p_variant, 0, Roster.count() - 1)
    is_ai = p_is_ai
    ai_level = clampi(p_ai_level, 0, 2)
    var data: Dictionary = Roster.get_data(variant)
    fighter_color = data.color
    accent_color = data.accent
    max_health = float(data.health)
    health = max_health
    max_stamina = float(data.stamina)
    stamina = max_stamina
    move_speed = float(data.move_speed)
    power_scale = float(data.power)
    defense_scale = float(data.defense)

func _ready() -> void:
    collision_layer = 2
    collision_mask = 3
    floor_snap_length = 0.2
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.48
    cap.height = 1.85
    cs.shape = cap
    cs.position.y = 0.92
    add_child(cs)
    _build_model()
    stats_changed.emit(self)

func _build_model() -> void:
    model_root = Node3D.new()
    model_root.name = "Model"
    add_child(model_root)

    if _try_build_external_model():
        _decorate_external_model()
        _add_glow()
        return

    match variant:
        0: _build_succubus()
        1: _build_mage()
        2: _build_templar()
        3: _build_bunny()

func _try_build_external_model() -> bool:
    var paths: Array[String] = [
        "res://assets/kaykit/Rogue_Hooded.glb",
        "res://assets/kaykit/Mage.glb",
        "res://assets/kaykit/Knight.glb",
        "res://assets/kaykit/Rogue.glb"
    ]
    var path: String = paths[variant]
    if not ResourceLoader.exists(path):
        return false

    var resource: Resource = load(path)
    if not (resource is PackedScene):
        return false

    var scene: PackedScene = resource as PackedScene
    var visual: Node3D = scene.instantiate() as Node3D
    if visual == null:
        return false

    visual.name = "ExternalCharacter"
    visual.rotation.y = PI
    visual.scale = Vector3.ONE * 0.92
    visual.position = Vector3(0, 0.02, 0)
    model_root.add_child(visual)
    animation_player = _find_animation_player(visual)
    _play_animation(_idle_animation(), 0.0, 1.0, true)
    return true

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found: AnimationPlayer = _find_animation_player(child)
        if found != null:
            return found
    return null

func _idle_animation() -> StringName:
    match variant:
        2: return &"2H_Melee_Idle"
        3: return &"Unarmed_Idle"
        _: return &"Idle"

func _movement_animation() -> StringName:
    if not is_on_floor():
        return &"Jump_Idle"
    var horizontal := Vector3(velocity.x, 0.0, velocity.z)
    if horizontal.length() < 0.3:
        return _idle_animation()
    var local_direction: Vector3 = global_basis.inverse() * horizontal.normalized()
    if local_direction.z > 0.45:
        return &"Walking_Backwards"
    if local_direction.x < -0.45:
        return &"Running_Strafe_Left"
    if local_direction.x > 0.45:
        return &"Running_Strafe_Right"
    return &"Running_A"

func _dodge_animation() -> StringName:
    var local_direction: Vector3 = global_basis.inverse() * dash_dir.normalized()
    if local_direction.z > 0.35:
        return &"Dodge_Backward"
    if local_direction.z < -0.35:
        return &"Dodge_Forward"
    if local_direction.x < 0.0:
        return &"Dodge_Left"
    return &"Dodge_Right"

func _attack_animation(kind: String, index: int) -> StringName:
    if kind == "ultimate":
        match variant:
            0: return &"Dualwield_Melee_Attack_Chop"
            1: return &"Spellcast_Long"
            2: return &"2H_Melee_Attack_Spinning"
            3: return &"Unarmed_Melee_Attack_Kick"
    if kind == "skill":
        match variant:
            0: return &"Dualwield_Melee_Attack_Stab"
            1: return &"Spellcast_Shoot"
            2: return &"2H_Melee_Attack_Chop"
            3: return &"Unarmed_Melee_Attack_Kick"
    if kind == "heavy":
        match variant:
            0: return &"Dualwield_Melee_Attack_Chop"
            1: return &"Unarmed_Melee_Attack_Kick"
            2: return &"2H_Melee_Attack_Chop"
            3: return &"Unarmed_Melee_Attack_Kick"

    var clips: Array[StringName] = []
    match variant:
        0:
            clips = [&"Dualwield_Melee_Attack_Slice", &"Dualwield_Melee_Attack_Chop", &"Dualwield_Melee_Attack_Stab", &"1H_Melee_Attack_Slice_Diagonal"]
        1:
            clips = [&"Unarmed_Melee_Attack_Punch_A", &"Unarmed_Melee_Attack_Punch_B", &"Unarmed_Melee_Attack_Kick", &"Spellcast_Shoot"]
        2:
            clips = [&"2H_Melee_Attack_Slice", &"2H_Melee_Attack_Chop", &"2H_Melee_Attack_Stab", &"2H_Melee_Attack_Spin"]
        3:
            clips = [&"Unarmed_Melee_Attack_Punch_A", &"Unarmed_Melee_Attack_Punch_B", &"Unarmed_Melee_Attack_Kick", &"Unarmed_Melee_Attack_Punch_A"]
    if clips.is_empty():
        return _idle_animation()
    return clips[posmod(index, clips.size())]

func _play_animation(name: StringName, blend: float = 0.12, speed: float = 1.0, force: bool = false) -> void:
    if animation_player == null:
        return
    var selected: StringName = name
    if not animation_player.has_animation(selected):
        selected = _idle_animation()
    if not animation_player.has_animation(selected):
        return
    if not force and last_animation == selected and animation_player.is_playing():
        return
    animation_player.play(selected, blend, speed)
    last_animation = selected

func _sync_animation() -> void:
    if animation_player == null:
        return
    if state == State.ATTACK:
        return
    if state == State.DEAD:
        _play_animation(&"Death_A", 0.08, 1.0)
        return
    if state == State.STUNNED:
        return
    if state == State.BLOCK:
        _play_animation(&"Blocking", 0.10, 1.0)
        return
    if state == State.DASH or state == State.DODGE:
        _play_animation(_dodge_animation(), 0.06, 1.15)
        return
    if state == State.MOVE or not is_on_floor():
        _play_animation(_movement_animation(), 0.12, 1.0)
        return
    _play_animation(_idle_animation(), 0.16, 1.0)

func _update_visuals(delta: float) -> void:
    _animate_model(delta)
    _sync_animation()

func _decorate_external_model() -> void:
    match variant:
        0:
            _cone(Vector3(-0.27, 2.30, 0.02), Vector3(0.24,0.48,0.24), Color(0.02,0.02,0.035), Vector3(0,0,-0.48))
            _cone(Vector3(0.27, 2.30, 0.02), Vector3(0.24,0.48,0.24), Color(0.02,0.02,0.035), Vector3(0,0,0.48))
            _box(Vector3(-0.68,1.40,0.24), Vector3(0.08,0.52,0.62), Color(0.025,0.025,0.045), Vector3(0.08,0,-0.58))
            _box(Vector3(0.68,1.40,0.24), Vector3(0.08,0.52,0.62), Color(0.025,0.025,0.045), Vector3(0.08,0,0.58))
            _cylinder(Vector3(0,0.72,0.52), Vector3(0.07,0.65,0.07), accent_color, Vector3(1.25,0,0))
        1:
            _sphere(Vector3(0.64,1.60,0.10), Vector3(0.13,0.13,0.13), Color(0.25,0.90,1.0))
            _sphere(Vector3(-0.62,1.42,0.16), Vector3(0.09,0.09,0.09), Color(1.0,0.35,0.15))
        2:
            _box(Vector3(0,1.30,-0.28), Vector3(0.80,1.05,0.05), Color(0.84,0.79,0.68))
            _box(Vector3(0,1.35,0.34), Vector3(0.09,0.58,0.05), Color(0.62,0.025,0.04))
            _box(Vector3(0,1.48,0.34), Vector3(0.30,0.08,0.05), Color(0.62,0.025,0.04))
        3:
            _capsule(Vector3(-0.20,2.48,0), Vector3(0.13,0.58,0.12), Color(0.88,0.90,0.95), Vector3(0,0,-0.08))
            _capsule(Vector3(0.20,2.48,0), Vector3(0.13,0.58,0.12), Color(0.88,0.90,0.95), Vector3(0,0,0.08))
            _box(Vector3(0,1.05,0.34), Vector3(0.12,0.62,0.04), accent_color)
            _box(Vector3(-0.52,1.30,0.05), Vector3(0.09,0.25,0.34), accent_color)
            _box(Vector3(0.52,1.30,0.05), Vector3(0.09,0.25,0.34), accent_color)

func _mat(color: Color) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/toon.gdshader")
    mat.set_shader_parameter("base_color", color)
    return mat

func _mesh_part(mesh: Mesh, pos: Vector3, scale_v: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.position = pos
    mi.scale = scale_v
    mi.rotation = rot
    mi.material_override = _mat(color)
    model_root.add_child(mi)
    return mi

func _box(pos: Vector3, scale_v: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
    _mesh_part(BoxMesh.new(), pos, scale_v, color, rot)

func _capsule(pos: Vector3, scale_v: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
    _mesh_part(CapsuleMesh.new(), pos, scale_v, color, rot)

func _sphere(pos: Vector3, scale_v: Vector3, color: Color) -> void:
    _mesh_part(SphereMesh.new(), pos, scale_v, color)

func _cylinder(pos: Vector3, scale_v: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.4
    mesh.bottom_radius = 0.4
    mesh.height = 2.0
    _mesh_part(mesh, pos, scale_v, color, rot)

func _cone(pos: Vector3, scale_v: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.0
    mesh.bottom_radius = 0.7
    mesh.height = 1.2
    _mesh_part(mesh, pos, scale_v, color, rot)

func _base_face(skin: Color, hair: Color) -> void:
    _sphere(Vector3(0,1.92,0), Vector3(0.48,0.52,0.46), skin)
    _sphere(Vector3(0,2.08,0.04), Vector3(0.54,0.30,0.52), hair)

func _limbs(body_color: Color, boot_color: Color) -> void:
    _capsule(Vector3(-0.50,1.12,0), Vector3(0.22,0.58,0.22), body_color)
    _capsule(Vector3(0.50,1.12,0), Vector3(0.22,0.58,0.22), body_color)
    _capsule(Vector3(-0.22,0.37,0), Vector3(0.26,0.70,0.26), boot_color)
    _capsule(Vector3(0.22,0.37,0), Vector3(0.26,0.70,0.26), boot_color)

func _add_glow() -> void:
    var light := OmniLight3D.new()
    light.light_color = fighter_color
    light.light_energy = 0.75
    light.omni_range = 3.0
    light.position = Vector3(0,1.15,0)
    light.shadow_enabled = false
    model_root.add_child(light)

func _build_succubus() -> void:
    var skin := Color(0.96,0.63,0.62)
    _capsule(Vector3(0,1.05,0), Vector3(0.66,0.82,0.48), fighter_color.darkened(0.42))
    _base_face(skin, Color(0.20,0.09,0.20))
    _limbs(accent_color, Color(0.03,0.025,0.05))
    _cone(Vector3(-0.30,2.45,0), Vector3(0.32,0.62,0.32), Color(0.02,0.025,0.04), Vector3(0,0,-0.50))
    _cone(Vector3(0.30,2.45,0), Vector3(0.32,0.62,0.32), Color(0.02,0.025,0.04), Vector3(0,0,0.50))
    _box(Vector3(-0.72,1.35,0.24), Vector3(0.10,0.68,0.78), Color(0.025,0.03,0.05), Vector3(0.10,0,-0.58))
    _box(Vector3(0.72,1.35,0.24), Vector3(0.10,0.68,0.78), Color(0.025,0.03,0.05), Vector3(0.10,0,0.58))
    _cylinder(Vector3(0,0.72,0.56), Vector3(0.10,0.80,0.10), accent_color, Vector3(1.25,0,0))
    _sphere(Vector3(0,0.30,0.95), Vector3(0.14,0.14,0.14), fighter_color)
    _add_glow()

func _build_mage() -> void:
    var skin := Color(0.92,0.70,0.57)
    _capsule(Vector3(0,1.02,0), Vector3(0.72,0.90,0.52), fighter_color.darkened(0.18))
    _base_face(skin, Color(0.11,0.06,0.16))
    _limbs(fighter_color.darkened(0.48), Color(0.08,0.045,0.06))
    _cone(Vector3(0,2.55,0), Vector3(0.86,0.82,0.86), Color(0.14,0.07,0.20), Vector3(0,0,0.08))
    _box(Vector3(0,2.22,0), Vector3(1.18,0.08,1.18), Color(0.12,0.055,0.18))
    _box(Vector3(0,1.16,0.32), Vector3(0.86,0.06,0.58), Color(0.55,0.12,0.12), Vector3(-0.18,0,0))
    _cylinder(Vector3(0.78,1.00,0), Vector3(0.09,1.15,0.09), Color(0.30,0.13,0.07))
    _sphere(Vector3(0.78,2.18,0), Vector3(0.22,0.22,0.22), Color(0.20,0.90,1.0))
    _add_glow()

func _build_templar() -> void:
    var skin := Color(0.80,0.58,0.47)
    _capsule(Vector3(0,1.05,0), Vector3(0.82,0.90,0.60), Color(0.16,0.17,0.18))
    _base_face(skin, Color(0.10,0.06,0.045))
    _limbs(Color(0.15,0.16,0.17), Color(0.09,0.055,0.04))
    _box(Vector3(0,1.20,0.34), Vector3(0.96,1.20,0.08), Color(0.80,0.76,0.64), Vector3(-0.08,0,0))
    _box(Vector3(0,1.20,-0.36), Vector3(0.96,1.35,0.08), Color(0.86,0.82,0.72))
    _box(Vector3(-0.60,1.48,0), Vector3(0.38,0.18,0.56), Color(0.35,0.34,0.31), Vector3(0,0,-0.18))
    _box(Vector3(0.60,1.48,0), Vector3(0.38,0.18,0.56), Color(0.35,0.34,0.31), Vector3(0,0,0.18))
    _cylinder(Vector3(0.86,1.08,0), Vector3(0.08,1.20,0.08), Color(0.17,0.10,0.06))
    _box(Vector3(0.86,2.20,0), Vector3(0.12,0.42,0.42), Color(0.72,0.74,0.70), Vector3(0,0,0.55))
    _box(Vector3(0,1.30,0.42), Vector3(0.11,0.78,0.06), Color(0.64,0.03,0.05))
    _box(Vector3(0,1.50,0.42), Vector3(0.38,0.10,0.06), Color(0.64,0.03,0.05))
    _add_glow()

func _build_bunny() -> void:
    var skin := Color(0.95,0.76,0.67)
    _capsule(Vector3(0,1.03,0), Vector3(0.70,0.88,0.52), Color(0.74,0.77,0.82))
    _base_face(skin, Color(0.67,0.72,0.76))
    _limbs(Color(0.78,0.81,0.86), Color(0.09,0.09,0.10))
    _capsule(Vector3(-0.22,2.72,0), Vector3(0.18,0.78,0.16), Color(0.74,0.78,0.84), Vector3(0,0,-0.10))
    _capsule(Vector3(0.22,2.72,0), Vector3(0.18,0.78,0.16), Color(0.74,0.78,0.84), Vector3(0,0,0.10))
    _box(Vector3(0,1.05,0.36), Vector3(0.17,0.72,0.06), accent_color)
    _box(Vector3(-0.63,1.31,0), Vector3(0.12,0.34,0.44), accent_color)
    _box(Vector3(0.63,1.31,0), Vector3(0.12,0.34,0.44), accent_color)
    _box(Vector3(0,1.48,-0.34), Vector3(0.72,0.62,0.08), Color(0.92,0.94,0.98))
    _sphere(Vector3(0,0.92,-0.60), Vector3(0.30,0.30,0.30), Color(0.93,0.94,0.96))
    _add_glow()

func set_target(p_target) -> void:
    target = p_target

func _physics_process(delta: float) -> void:
    _tick(delta)
    if state == State.DEAD:
        _apply_gravity(delta)
        move_and_slide()
        _update_visuals(delta)
        return
    if stun_timer > 0.0:
        state = State.STUNNED
        velocity.x = move_toward(velocity.x,0.0,18.0*delta)
        velocity.z = move_toward(velocity.z,0.0,18.0*delta)
        _apply_gravity(delta)
        move_and_slide()
        _update_visuals(delta)
        return
    if not current_attack.is_empty():
        _process_attack(delta)
        _apply_gravity(delta)
        move_and_slide()
        _clamp_arena()
        _update_visuals(delta)
        return
    if dash_timer > 0.0:
        state = State.DASH
        velocity.x = dash_dir.x * (22.0 if variant in [0,3] else 19.0)
        velocity.z = dash_dir.z * (22.0 if variant in [0,3] else 19.0)
        _apply_gravity(delta)
        move_and_slide()
        _clamp_arena()
        _update_visuals(delta)
        return
    if dodge_timer > 0.0:
        state = State.DODGE
        velocity.x = dash_dir.x * 16.0
        velocity.z = dash_dir.z * 16.0
        _apply_gravity(delta)
        move_and_slide()
        _clamp_arena()
        _update_visuals(delta)
        return
    if is_ai:
        _process_ai(delta)
    else:
        _process_player(delta)
    _apply_gravity(delta)
    move_and_slide()
    _clamp_arena()
    _update_visuals(delta)
    stats_changed.emit(self)

func _tick(delta: float) -> void:
    dash_timer=maxf(0.0,dash_timer-delta); dash_cooldown=maxf(0.0,dash_cooldown-delta)
    dodge_timer=maxf(0.0,dodge_timer-delta); iframe_timer=maxf(0.0,iframe_timer-delta)
    stun_timer=maxf(0.0,stun_timer-delta); block_parry_timer=maxf(0.0,block_parry_timer-delta)
    ai_timer=maxf(0.0,ai_timer-delta); ai_block_timer=maxf(0.0,ai_block_timer-delta)
    combo_window=maxf(0.0,combo_window-delta)
    for i in range(4): skill_cooldowns[i]=maxf(0.0,skill_cooldowns[i]-delta)
    if state != State.BLOCK: stamina=minf(max_stamina,stamina+20.0*delta)
    if combo_window<=0.0 and current_attack.is_empty(): combo_step=0

func _process_player(delta: float) -> void:
    if Input.is_action_just_pressed("lock_on"): lock_on = not lock_on
    if Input.is_action_just_pressed("dodge") and _try_dodge(): return
    if Input.is_action_just_pressed("dash") and _try_dash(): return
    if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y=jump_velocity
    if Input.is_action_just_pressed("skill_1") and _try_skill(0): return
    if Input.is_action_just_pressed("skill_2") and _try_skill(1): return
    if Input.is_action_just_pressed("skill_3") and _try_skill(2): return
    if Input.is_action_just_pressed("skill_4") and _try_skill(3): return
    if Input.is_action_just_pressed("ultimate") and _try_ultimate(): return
    if Input.is_action_just_pressed("heavy"): _heavy_attack(); return
    if Input.is_action_just_pressed("attack"): _light_attack(); return
    if Input.is_action_pressed("block") and is_on_floor():
        if state != State.BLOCK: block_parry_timer=0.13
        state=State.BLOCK
        stamina=maxf(0.0,stamina-8.0*delta)
        velocity.x=move_toward(velocity.x,0.0,25.0*delta)
        velocity.z=move_toward(velocity.z,0.0,25.0*delta)
        _face_target(delta*14.0)
        return
    var input:=Input.get_vector("move_left","move_right","move_forward","move_back")
    var direction:=_input_world(input)
    velocity.x=move_toward(velocity.x,direction.x*move_speed,35.0*delta)
    velocity.z=move_toward(velocity.z,direction.z*move_speed,35.0*delta)
    state=State.MOVE if direction.length_squared()>0.01 else State.IDLE
    if lock_on and is_instance_valid(target): _face_target(delta*12.0)
    elif direction.length_squared()>0.01: _face_direction(direction,delta*10.0)

func _input_world(input: Vector2) -> Vector3:
    var cam:=get_viewport().get_camera_3d()
    if cam==null: return Vector3(input.x,0,input.y).normalized()
    var f:Vector3=-cam.global_transform.basis.z; var r:Vector3=cam.global_transform.basis.x
    f.y=0; r.y=0
    var d:Vector3=r.normalized()*input.x+f.normalized()*-input.y
    return d.normalized() if d.length()>1.0 else d

func _try_dash() -> bool:
    if dash_cooldown>0.0 or stamina<14.0: return false
    dash_dir=_input_world(Input.get_vector("move_left","move_right","move_forward","move_back"))
    if dash_dir.length_squared()<0.01: dash_dir=-global_transform.basis.z
    stamina-=14.0; dash_timer=0.18; dash_cooldown=0.34 if variant in [0,3] else 0.42
    return true

func _try_dodge(direction: Vector3=Vector3.ZERO) -> bool:
    if stamina<20.0: return false
    if direction.length_squared()<0.01: direction=_input_world(Input.get_vector("move_left","move_right","move_forward","move_back"))
    if direction.length_squared()<0.01: direction=global_transform.basis.z
    dash_dir=direction.normalized(); stamina-=20.0; dodge_timer=0.26; iframe_timer=0.21
    return true

func _light_attack() -> void:
    var damages:Array[float]=[42.0,48.0,58.0,82.0]
    var ranges:Array[float]=[2.1,2.2,2.35,2.6]
    if variant==2:
        damages=[48.0,56.0,66.0,96.0]; ranges=[2.2,2.3,2.5,2.8]
    if combo_window<=0.0: combo_step=0
    combo_step=clampi(combo_step,0,3)
    var data:Dictionary={"damage":damages[combo_step]*power_scale,"startup":0.08+combo_step*0.02,"active":0.10,"recovery":0.15+combo_step*0.05,"range":ranges[combo_step],"hitstun":0.20+combo_step*0.06,"knockback":2.5+combo_step*2.0,"launch":2.5 if combo_step==3 else 0.0,"block_damage":10.0+combo_step*2.0,"anim_kind":"light","anim_index":combo_step,"anim_speed":1.08+combo_step*0.03}
    combo_step=(combo_step+1)%4; combo_window=0.65; _start_attack(data)

func _heavy_attack() -> void:
    if stamina<15.0:return
    stamina-=15.0
    _start_attack({"damage":105.0*power_scale,"startup":0.25,"active":0.14,"recovery":0.38,"range":2.9 if variant==2 else 2.7,"hitstun":0.48,"knockback":11.0,"launch":2.8,"block_damage":28.0,"anim_kind":"heavy","anim_index":0,"anim_speed":0.98})

func _start_attack(data:Dictionary)->void:
    current_attack=data
    attack_timer=0.0
    attack_hit_done=false
    state=State.ATTACK
    _face_target(1.0)
    var anim_kind: String = String(data.get("anim_kind","light"))
    var anim_index: int = int(data.get("anim_index",0))
    var anim_speed: float = float(data.get("anim_speed",1.0))
    _play_animation(_attack_animation(anim_kind, anim_index), 0.06, anim_speed, true)

func _process_attack(delta:float)->void:
    attack_timer+=delta
    var startup:float=float(current_attack.get("startup",0.1))
    var active:float=float(current_attack.get("active",0.1))
    var recovery:float=float(current_attack.get("recovery",0.2))
    if attack_timer>=startup and attack_timer<=startup+active and not attack_hit_done:_attempt_hit()
    if attack_timer>=startup+active+recovery: current_attack={}; attack_timer=0.0; state=State.IDLE

func _attempt_hit()->void:
    attack_hit_done=true
    if not is_instance_valid(target):return
    var attack_range:float=float(current_attack.get("range",2.3))
    if global_position.distance_to(target.global_position)>attack_range or not _is_facing(target):return
    target.receive_hit(self,current_attack)
    combo_hits+=1; combo_changed.emit(combo_hits)
    var damage:float=float(current_attack.get("damage",40.0))
    energy=minf(max_energy,energy+damage*0.11); ultimate=minf(100.0,ultimate+damage*0.09)
    impact.emit(target.global_position+Vector3.UP*1.1,clampf(damage/90.0,0.5,2.0),fighter_color)

func receive_hit(attacker,data:Dictionary)->void:
    if state==State.DEAD:return
    if iframe_timer>0.0:
        energy=minf(max_energy,energy+12.0); ultimate=minf(100.0,ultimate+8.0); perfect_evade.emit(self); return
    var damage:float=float(data.get("damage",40.0))/defense_scale
    var blocking:bool=state==State.BLOCK or ai_block_timer>0.0
    if blocking and _is_facing(attacker):
        if block_parry_timer>0.0:
            if is_instance_valid(attacker): attacker.stun_timer=0.60; attacker.current_attack={}
            energy=minf(max_energy,energy+15.0); ultimate=minf(100.0,ultimate+10.0); perfect_parry.emit(self,attacker); return
        stamina-=float(data.get("block_damage",damage*0.3))/defense_scale; health-=damage*0.05
        _play_animation(&"Block_Hit", 0.04, 1.0, true)
        if stamina<=0.0:stamina=0.0; stun_timer=1.1
        _check_ko(); stats_changed.emit(self); return
    health-=damage; energy=minf(max_energy,energy+damage*0.08); ultimate=minf(100.0,ultimate+damage*0.07)
    stun_timer=float(data.get("hitstun",0.25))
    var direction:Vector3=global_transform.basis.z
    if is_instance_valid(attacker):direction=global_position-attacker.global_position
    direction.y=0
    if direction.length_squared()<0.01:direction=Vector3.BACK
    velocity=direction.normalized()*float(data.get("knockback",3.0)); velocity.y=float(data.get("launch",0.0))
    hit_reaction_toggle = not hit_reaction_toggle
    _play_animation(&"Hit_B" if hit_reaction_toggle else &"Hit_A", 0.03, 1.0, true)
    stats_changed.emit(self); _check_ko()

func register_external_hit(_other,damage,pos,strength)->void:
    energy=minf(max_energy,energy+float(damage)*0.10); ultimate=minf(100.0,ultimate+float(damage)*0.08); impact.emit(pos,strength,fighter_color)

func _try_skill(index:int)->bool:
    var costs:Array[float]=[24.0,30.0,36.0,45.0]
    if skill_cooldowns[index]>0.0 or energy<costs[index]:return false
    energy-=costs[index]
    var skill_damage: Array[float] = [90.0,120.0,150.0,185.0]
    match variant:
        1: skill_damage = [125.0,90.0,165.0,210.0]
        2: skill_damage = [95.0,145.0,190.0,240.0]
        3: skill_damage = [110.0,115.0,160.0,205.0]
    match index:
        0:
            skill_cooldowns[index]=4.0
            _play_animation(_attack_animation("skill", index), 0.06, 1.08, true)
            var projectile=ProjectileScript.new()
            projectile.configure(self,target,fighter_color,float(skill_damage[0])*power_scale)
            get_tree().current_scene.add_child(projectile)
            projectile.global_position=global_position+Vector3.UP*1.25-global_transform.basis.z*0.8
        1:
            skill_cooldowns[index]=5.5
            if is_instance_valid(target) and global_position.distance_to(target.global_position)<18.0:
                var behind:Vector3=target.global_transform.basis.z.normalized()
                global_position=target.global_position+behind*1.7; _face_target(1.0)
                _start_attack({"damage":float(skill_damage[1])*power_scale,"startup":0.06,"active":0.12,"recovery":0.28,"range":2.7,"hitstun":0.55,"knockback":10.0,"launch":2.0,"block_damage":30.0,"anim_kind":"skill","anim_index":1,"anim_speed":1.12})
        2:
            skill_cooldowns[index]=7.5
            _start_attack({"damage":float(skill_damage[2])*power_scale,"startup":0.18,"active":0.18,"recovery":0.35,"range":3.4 if variant==1 else 3.1,"hitstun":0.62,"knockback":12.0,"launch":3.0,"block_damage":34.0,"anim_kind":"skill","anim_index":2,"anim_speed":1.02})
        3:
            skill_cooldowns[index]=9.5
            _start_attack({"damage":float(skill_damage[3])*power_scale,"startup":0.32,"active":0.22,"recovery":0.45,"range":4.8,"hitstun":0.72,"knockback":15.0,"launch":4.0,"block_damage":40.0,"anim_kind":"skill","anim_index":3,"anim_speed":0.95})
    return true

func _try_ultimate()->bool:
    if ultimate<100.0 or not is_instance_valid(target):return false
    ultimate=0.0; ultimate_started.emit(self,target)
    var damages:Array[float]=[315.0,340.0,390.0,330.0]
    _start_attack({"damage":damages[variant]*power_scale,"startup":0.62,"active":0.22,"recovery":0.75,"range":5.0,"hitstun":0.95,"knockback":20.0,"launch":6.0,"block_damage":75.0,"anim_kind":"ultimate","anim_index":0,"anim_speed":0.90})
    return true

func _process_ai(delta:float)->void:
    if not is_instance_valid(target):return
    lock_on=true
    var distance:float=global_position.distance_to(target.global_position)
    if ai_block_timer>0.0:
        state=State.BLOCK; _face_target(delta*14.0); velocity.x=move_toward(velocity.x,0.0,25.0*delta); velocity.z=move_toward(velocity.z,0.0,25.0*delta); return
    if ai_timer<=0.0:
        var reaction:Array[float]=[0.52,0.31,0.19]
        ai_timer=reaction[ai_level]+randf_range(0.02,0.12)
        if not target.current_attack.is_empty() and distance<3.2 and randf()<(0.26+ai_level*0.20):
            if randf()<0.52:
                var evade:Vector3=global_position-target.global_position; evade.y=0; _try_dodge(evade.normalized())
            else:
                ai_block_timer=randf_range(0.35,0.68); block_parry_timer=0.10 if ai_level>=2 else 0.0
            return
        if ultimate>=100.0 and distance<5.2:_try_ultimate();return
        if energy>=30.0 and randf()<(0.14+ai_level*0.07):_try_skill(randi_range(0,3));return
        if distance<2.9:
            if randf()<0.72:_light_attack()
            else:_heavy_attack()
            return
    var direction:Vector3=target.global_position-global_position; direction.y=0
    if distance>3.2:
        direction=direction.normalized(); velocity.x=direction.x*move_speed; velocity.z=direction.z*move_speed
    else:
        var side:Vector3=direction.normalized().cross(Vector3.UP); velocity.x=side.x*move_speed*0.45; velocity.z=side.z*move_speed*0.45
    state=State.MOVE; _face_target(delta*12.0)

func _check_ko()->void:
    if health>0.0:return
    health=0.0
    state=State.DEAD
    current_attack={}
    _play_animation(&"Death_A", 0.04, 1.0, true)
    knocked_out.emit(self)

func _is_facing(other)->bool:
    if not is_instance_valid(other):return false
    var direction:Vector3=other.global_position-global_position; direction.y=0
    if direction.length_squared()<0.01:return true
    var forward:Vector3=-global_transform.basis.z; forward.y=0
    return forward.normalized().dot(direction.normalized())>0.05

func _face_target(weight:float)->void:
    if not is_instance_valid(target):return
    var direction:Vector3=target.global_position-global_position; direction.y=0; _face_direction(direction,weight)

func _face_direction(direction:Vector3,weight:float)->void:
    if direction.length_squared()<0.001:return
    var desired:=Basis.looking_at(direction.normalized(),Vector3.UP)
    global_basis=global_basis.slerp(desired,clampf(weight,0.0,1.0)).orthonormalized()

func _apply_gravity(delta:float)->void:
    if is_on_floor():
        if velocity.y<0.0:velocity.y=-0.5
    else:velocity.y-=gravity*delta

func _clamp_arena()->void:
    var flat:=Vector2(global_position.x,global_position.z)
    if flat.length()>arena_radius:
        flat=flat.normalized()*arena_radius; global_position.x=flat.x; global_position.z=flat.y

func _animate_model(delta:float)->void:
    if model_root==null:return
    visual_phase += delta
    var speed:=Vector2(velocity.x,velocity.z).length()
    var target_pitch: float = -clampf(speed/80.0,0.0,0.12)
    var target_roll: float = 0.10 if state==State.BLOCK else 0.0
    var target_yaw: float = 0.0
    if state==State.DASH or state==State.DODGE:
        target_pitch = -0.20
    elif state==State.ATTACK and not current_attack.is_empty():
        var total: float = float(current_attack.get("startup",0.1)) + float(current_attack.get("active",0.1)) + float(current_attack.get("recovery",0.2))
        var phase: float = clampf(attack_timer / maxf(total,0.01),0.0,1.0)
        var swing: float = sin(phase * PI)
        var attack_index: int = int(current_attack.get("anim_index",0))
        target_yaw = swing * (0.20 if attack_index % 2 == 0 else -0.20)
        target_roll = -swing * 0.08
    model_root.rotation.x=lerpf(model_root.rotation.x,target_pitch,clampf(delta*10.0,0.0,1.0))
    model_root.rotation.y=lerpf(model_root.rotation.y,target_yaw,clampf(delta*14.0,0.0,1.0))
    model_root.rotation.z=lerpf(model_root.rotation.z,target_roll,clampf(delta*12.0,0.0,1.0))
    var idle_bob: float = sin(visual_phase * 3.0) * 0.012 if state==State.IDLE else 0.0
    model_root.position.y=lerpf(model_root.position.y,idle_bob,clampf(delta*8.0,0.0,1.0))
