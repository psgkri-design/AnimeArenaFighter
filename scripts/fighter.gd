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

var state := State.IDLE
var is_ai := false
var ai_level := 1
var variant := 0
var target = null
var lock_on := true

var max_health := 1000.0
var health := 1000.0
var max_stamina := 100.0
var stamina := 100.0
var max_energy := 100.0
var energy := 0.0
var ultimate := 0.0
var fighter_color := Color(0.12, 0.62, 1.0)

var move_speed := 7.2
var gravity := 24.0
var jump_velocity := 9.4
var arena_radius := 23.2

var dash_timer := 0.0
var dash_cooldown := 0.0
var dodge_timer := 0.0
var iframe_timer := 0.0
var stun_timer := 0.0
var block_parry_timer := 0.0
var ai_timer := 0.0
var ai_block_timer := 0.0
var dash_dir := Vector3.ZERO

var current_attack := {}
var attack_timer := 0.0
var attack_hit_done := false
var combo_step := 0
var combo_window := 0.0
var combo_hits := 0
var skill_cooldowns := [0.0, 0.0, 0.0, 0.0]

var model_root: Node3D

func configure(p_variant: int, p_is_ai: bool, p_ai_level := 1) -> void:
    variant = p_variant
    is_ai = p_is_ai
    ai_level = p_ai_level
    if variant == 0:
        fighter_color = Color(0.12, 0.62, 1.0)
        max_health = 1000.0
        move_speed = 7.4
    else:
        fighter_color = Color(1.0, 0.22, 0.30)
        max_health = 1080.0
        move_speed = 6.9
    health = max_health

func _ready() -> void:
    collision_layer = 2
    collision_mask = 1 | 2
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
    _part(CapsuleMesh.new(), Vector3(0,1.0,0), fighter_color, Vector3(0.75,0.85,0.55))
    _part(SphereMesh.new(), Vector3(0,1.9,0), Color(1.0,0.78,0.65), Vector3(0.52,0.52,0.52))
    _part(SphereMesh.new(), Vector3(0,2.10,0.02), Color(0.05,0.06,0.10), Vector3(0.58,0.30,0.58))
    _part(CapsuleMesh.new(), Vector3(-0.55,1.15,0), fighter_color.darkened(0.10), Vector3(0.24,0.62,0.24))
    _part(CapsuleMesh.new(), Vector3(0.55,1.15,0), fighter_color.darkened(0.10), Vector3(0.24,0.62,0.24))
    _part(CapsuleMesh.new(), Vector3(-0.23,0.35,0), Color(0.05,0.06,0.10), Vector3(0.28,0.70,0.28))
    _part(CapsuleMesh.new(), Vector3(0.23,0.35,0), Color(0.05,0.06,0.10), Vector3(0.28,0.70,0.28))
    var light := OmniLight3D.new()
    light.light_color = fighter_color
    light.light_energy = 0.55
    light.omni_range = 2.8
    light.position = Vector3(0,1.1,0)
    light.shadow_enabled = false
    model_root.add_child(light)

func _part(mesh: Mesh, pos: Vector3, color: Color, scl: Vector3) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.position = pos
    mi.scale = scl
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/toon.gdshader")
    mat.set_shader_parameter("base_color", color)
    mi.material_override = mat
    model_root.add_child(mi)

func set_target(p_target) -> void:
    target = p_target

func _physics_process(delta: float) -> void:
    _tick(delta)
    if state == State.DEAD:
        _gravity(delta)
        move_and_slide()
        return
    if stun_timer > 0.0:
        state = State.STUNNED
        velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
        _gravity(delta)
        move_and_slide()
        return
    if not current_attack.is_empty():
        _process_attack(delta)
        _gravity(delta)
        move_and_slide()
        _clamp_arena()
        return
    if dash_timer > 0.0:
        state = State.DASH
        velocity.x = dash_dir.x * 20.0
        velocity.z = dash_dir.z * 20.0
        _gravity(delta)
        move_and_slide()
        _clamp_arena()
        return
    if dodge_timer > 0.0:
        state = State.DODGE
        velocity.x = dash_dir.x * 15.0
        velocity.z = dash_dir.z * 15.0
        _gravity(delta)
        move_and_slide()
        _clamp_arena()
        return

    if is_ai:
        _ai(delta)
    else:
        _player(delta)

    _gravity(delta)
    move_and_slide()
    _clamp_arena()
    _animate(delta)
    stats_changed.emit(self)

func _tick(delta: float) -> void:
    dash_timer = maxf(0.0, dash_timer-delta)
    dash_cooldown = maxf(0.0, dash_cooldown-delta)
    dodge_timer = maxf(0.0, dodge_timer-delta)
    iframe_timer = maxf(0.0, iframe_timer-delta)
    stun_timer = maxf(0.0, stun_timer-delta)
    block_parry_timer = maxf(0.0, block_parry_timer-delta)
    ai_timer = maxf(0.0, ai_timer-delta)
    ai_block_timer = maxf(0.0, ai_block_timer-delta)
    combo_window = maxf(0.0, combo_window-delta)
    for i in range(4):
        skill_cooldowns[i] = maxf(0.0, skill_cooldowns[i]-delta)
    if state != State.BLOCK:
        stamina = minf(max_stamina, stamina + 20.0 * delta)
    if combo_window <= 0.0 and current_attack.is_empty():
        combo_step = 0

func _player(delta: float) -> void:
    if Input.is_action_just_pressed("lock_on"):
        lock_on = not lock_on
    if Input.is_action_just_pressed("dodge") and _try_dodge():
        return
    if Input.is_action_just_pressed("dash") and _try_dash():
        return
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
    if Input.is_action_just_pressed("skill_1") and _try_skill(0): return
    if Input.is_action_just_pressed("skill_2") and _try_skill(1): return
    if Input.is_action_just_pressed("skill_3") and _try_skill(2): return
    if Input.is_action_just_pressed("skill_4") and _try_skill(3): return
    if Input.is_action_just_pressed("ultimate") and _try_ultimate(): return
    if Input.is_action_just_pressed("heavy"):
        _heavy()
        return
    if Input.is_action_just_pressed("attack"):
        _light()
        return

    if Input.is_action_pressed("block") and is_on_floor():
        if state != State.BLOCK:
            block_parry_timer = 0.13
        state = State.BLOCK
        stamina = maxf(0.0, stamina - 8.0 * delta)
        velocity.x = move_toward(velocity.x, 0.0, 25.0*delta)
        velocity.z = move_toward(velocity.z, 0.0, 25.0*delta)
        _face_target(delta*14.0)
        return

    var input := Input.get_vector("move_left","move_right","move_forward","move_back")
    var direction := Vector3(input.x,0,input.y)
    var cam := get_viewport().get_camera_3d()
    if cam != null:
        var f := -cam.global_transform.basis.z
        var r := cam.global_transform.basis.x
        f.y = 0
        r.y = 0
        direction = (r.normalized()*input.x + f.normalized()*-input.y)
    if direction.length() > 1.0:
        direction = direction.normalized()
    velocity.x = move_toward(velocity.x, direction.x*move_speed, 35.0*delta)
    velocity.z = move_toward(velocity.z, direction.z*move_speed, 35.0*delta)
    state = State.MOVE if direction.length_squared() > 0.01 else State.IDLE
    if lock_on and is_instance_valid(target):
        _face_target(delta*12.0)
    elif direction.length_squared() > 0.01:
        _face_direction(direction, delta*10.0)

func _try_dash() -> bool:
    if dash_cooldown > 0.0 or stamina < 14.0:
        return false
    var input := Input.get_vector("move_left","move_right","move_forward","move_back")
    dash_dir = _input_world(input)
    if dash_dir.length_squared() < 0.01:
        dash_dir = -global_transform.basis.z
    stamina -= 14.0
    dash_timer = 0.18
    dash_cooldown = 0.38
    return true

func _try_dodge(direction := Vector3.ZERO) -> bool:
    if stamina < 20.0:
        return false
    if direction.length_squared() < 0.01:
        direction = _input_world(Input.get_vector("move_left","move_right","move_forward","move_back"))
    if direction.length_squared() < 0.01:
        direction = global_transform.basis.z
    dash_dir = direction.normalized()
    stamina -= 20.0
    dodge_timer = 0.26
    iframe_timer = 0.21
    return true

func _input_world(input: Vector2) -> Vector3:
    var cam := get_viewport().get_camera_3d()
    if cam == null:
        return Vector3(input.x,0,input.y).normalized()
    var f := -cam.global_transform.basis.z
    var r := cam.global_transform.basis.x
    f.y = 0
    r.y = 0
    return (r.normalized()*input.x + f.normalized()*-input.y).normalized()

func _light() -> void:
    var damages := [42.0,48.0,58.0,82.0]
    var ranges := [2.1,2.2,2.35,2.6]
    combo_step = combo_step if combo_window > 0.0 else 0
    combo_step = clampi(combo_step,0,3)
    var data := {
        "damage":damages[combo_step],"startup":0.08+combo_step*0.02,"active":0.10,
        "recovery":0.15+combo_step*0.05,"range":ranges[combo_step],
        "hitstun":0.20+combo_step*0.06,"knockback":2.5+combo_step*2.0,
        "launch":2.5 if combo_step==3 else 0.0,"block_damage":10.0+combo_step*2.0
    }
    combo_step = (combo_step+1)%4
    combo_window = 0.65
    _start_attack(data)

func _heavy() -> void:
    if stamina < 15.0:
        return
    stamina -= 15.0
    _start_attack({"damage":105.0,"startup":0.25,"active":0.14,"recovery":0.38,"range":2.8,"hitstun":0.48,"knockback":11.0,"launch":2.8,"block_damage":25.0})

func _start_attack(data: Dictionary) -> void:
    current_attack = data
    attack_timer = 0.0
    attack_hit_done = false
    state = State.ATTACK
    _face_target(1.0)

func _process_attack(delta: float) -> void:
    attack_timer += delta
    var startup := float(current_attack.get("startup",0.1))
    var active := float(current_attack.get("active",0.1))
    var recovery := float(current_attack.get("recovery",0.2))
    if attack_timer >= startup and attack_timer <= startup+active and not attack_hit_done:
        _attempt_hit()
    if attack_timer >= startup+active+recovery:
        current_attack = {}
        attack_timer = 0.0
        state = State.IDLE

func _attempt_hit() -> void:
    attack_hit_done = true
    if not is_instance_valid(target):
        return
    var range_v := float(current_attack.get("range",2.3))
    if global_position.distance_to(target.global_position) > range_v:
        return
    if not _is_facing(target):
        return
    target.receive_hit(self,current_attack)
    combo_hits += 1
    combo_changed.emit(combo_hits)
    energy = minf(max_energy, energy + float(current_attack.get("damage",40.0))*0.11)
    ultimate = minf(100.0, ultimate + float(current_attack.get("damage",40.0))*0.09)
    impact.emit(target.global_position+Vector3.UP*1.1, clampf(float(current_attack.get("damage",40.0))/90.0,0.5,2.0), fighter_color)

func receive_hit(attacker, data: Dictionary) -> void:
    if state == State.DEAD:
        return
    if iframe_timer > 0.0:
        energy = minf(max_energy,energy+12.0)
        ultimate = minf(100.0,ultimate+8.0)
        perfect_evade.emit(self)
        return

    var dmg := float(data.get("damage",40.0))
    var blocking := state == State.BLOCK or ai_block_timer > 0.0
    if blocking and _is_facing(attacker):
        if block_parry_timer > 0.0:
            if is_instance_valid(attacker):
                attacker.stun_timer = 0.60
                attacker.current_attack = {}
            energy = minf(max_energy,energy+15.0)
            ultimate = minf(100.0,ultimate+10.0)
            perfect_parry.emit(self,attacker)
            return
        stamina -= float(data.get("block_damage",dmg*0.3))
        health -= dmg*0.05
        if stamina <= 0.0:
            stamina = 0.0
            stun_timer = 1.1
        _check_ko()
        stats_changed.emit(self)
        return

    health -= dmg
    energy = minf(max_energy,energy+dmg*0.08)
    ultimate = minf(100.0,ultimate+dmg*0.07)
    stun_timer = float(data.get("hitstun",0.25))
    var dir := global_position-attacker.global_position if is_instance_valid(attacker) else global_transform.basis.z
    dir.y = 0
    if dir.length_squared() < 0.01:
        dir = Vector3.BACK
    velocity = dir.normalized()*float(data.get("knockback",3.0))
    velocity.y = float(data.get("launch",0.0))
    stats_changed.emit(self)
    _check_ko()

func register_external_hit(_other, damage, pos, strength) -> void:
    energy = minf(max_energy,energy+float(damage)*0.10)
    ultimate = minf(100.0,ultimate+float(damage)*0.08)
    impact.emit(pos,strength,fighter_color)

func _try_skill(index: int) -> bool:
    var costs := [24.0,30.0,36.0,45.0]
    if skill_cooldowns[index] > 0.0 or energy < costs[index]:
        return false
    energy -= costs[index]
    if index == 0:
        skill_cooldowns[index] = 4.0
        var p = ProjectileScript.new()
        p.configure(self,target,fighter_color,92.0)
        get_tree().current_scene.add_child(p)
        p.global_position = global_position+Vector3.UP*1.25-global_transform.basis.z*0.8
    elif index == 1:
        skill_cooldowns[index] = 6.0
        if is_instance_valid(target) and global_position.distance_to(target.global_position) < 18.0:
            var d := target.global_transform.basis.z.normalized()
            global_position = target.global_position+d*1.6
            _face_target(1.0)
            _start_attack({"damage":120.0,"startup":0.06,"active":0.12,"recovery":0.28,"range":2.5,"hitstun":0.55,"knockback":10.0,"launch":2.0,"block_damage":28.0})
    elif index == 2:
        skill_cooldowns[index] = 8.0
        _start_attack({"damage":155.0,"startup":0.20,"active":0.18,"recovery":0.35,"range":3.1,"hitstun":0.62,"knockback":12.0,"launch":3.0,"block_damage":32.0})
    else:
        skill_cooldowns[index] = 10.0
        _start_attack({"damage":185.0,"startup":0.34,"active":0.20,"recovery":0.45,"range":4.5,"hitstun":0.72,"knockback":15.0,"launch":4.0,"block_damage":38.0})
    return true

func _try_ultimate() -> bool:
    if ultimate < 100.0 or not is_instance_valid(target):
        return false
    ultimate = 0.0
    ultimate_started.emit(self,target)
    _start_attack({"damage":320.0,"startup":0.62,"active":0.22,"recovery":0.75,"range":4.8,"hitstun":0.95,"knockback":20.0,"launch":6.0,"block_damage":70.0})
    return true

func _ai(delta: float) -> void:
    if not is_instance_valid(target):
        return
    lock_on = true
    var dist := global_position.distance_to(target.global_position)
    if ai_block_timer > 0.0:
        state = State.BLOCK
        _face_target(delta*14.0)
        velocity.x = move_toward(velocity.x,0.0,25.0*delta)
        velocity.z = move_toward(velocity.z,0.0,25.0*delta)
        return
    if ai_timer <= 0.0:
        ai_timer = [0.50,0.30,0.19][clampi(ai_level,0,2)] + randf_range(0.02,0.12)
        if not target.current_attack.is_empty() and dist < 3.0 and randf() < (0.30+ai_level*0.18):
            if randf() < 0.48:
                _try_dodge((global_position-target.global_position).normalized())
            else:
                ai_block_timer = randf_range(0.35,0.65)
                block_parry_timer = 0.10 if ai_level >= 2 else 0.0
            return
        if ultimate >= 100.0 and dist < 5.0:
            _try_ultimate()
            return
        if energy >= 30.0 and randf() < 0.22:
            _try_skill(randi_range(0,3))
            return
        if dist < 2.7:
            if randf() < 0.72:
                _light()
            else:
                _heavy()
            return

    var dir := target.global_position-global_position
    dir.y = 0
    if dist > 3.1:
        dir = dir.normalized()
        velocity.x = dir.x*move_speed
        velocity.z = dir.z*move_speed
        state = State.MOVE
    else:
        var side := dir.normalized().cross(Vector3.UP)
        velocity.x = side.x*move_speed*0.45
        velocity.z = side.z*move_speed*0.45
        state = State.MOVE
    _face_target(delta*12.0)

func _check_ko() -> void:
    if health > 0.0:
        return
    health = 0.0
    state = State.DEAD
    current_attack = {}
    knocked_out.emit(self)

func _is_facing(other) -> bool:
    if not is_instance_valid(other):
        return false
    var d := other.global_position-global_position
    d.y = 0
    if d.length_squared() < 0.01:
        return true
    var f := -global_transform.basis.z
    f.y = 0
    return f.normalized().dot(d.normalized()) > 0.05

func _face_target(weight: float) -> void:
    if not is_instance_valid(target):
        return
    var d := target.global_position-global_position
    d.y = 0
    _face_direction(d,weight)

func _face_direction(direction: Vector3, weight: float) -> void:
    if direction.length_squared() < 0.001:
        return
    var desired := Basis.looking_at(direction.normalized(),Vector3.UP)
    global_basis = global_basis.slerp(desired,clampf(weight,0.0,1.0)).orthonormalized()

func _gravity(delta: float) -> void:
    if is_on_floor():
        if velocity.y < 0.0:
            velocity.y = -0.5
    else:
        velocity.y -= gravity*delta

func _clamp_arena() -> void:
    var p := Vector2(global_position.x,global_position.z)
    if p.length() > arena_radius:
        p = p.normalized()*arena_radius
        global_position.x = p.x
        global_position.z = p.y

func _animate(delta: float) -> void:
    if model_root == null:
        return
    var speed := Vector2(velocity.x,velocity.z).length()
    model_root.rotation.x = lerpf(model_root.rotation.x,-clampf(speed/80.0,0.0,0.12),delta*8.0)
    model_root.rotation.z = lerpf(model_root.rotation.z,0.10 if state==State.BLOCK else 0.0,delta*10.0)
