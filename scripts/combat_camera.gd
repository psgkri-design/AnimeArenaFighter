extends Node3D

var camera: Camera3D
var player = null
var target = null
var yaw: float = 0.0
var pitch: float = deg_to_rad(-12.0)
var free_distance: float = 6.15
var height: float = 1.55
var look_sensitivity: float = 0.006
var shake_strength: float = 0.0
var shake_time: float = 0.0
var cinematic_timer: float = 0.0
var cinematic_duration: float = 0.0
var cinematic_elapsed: float = 0.0
var cinematic_side_sign: float = 1.0
var cinematic_attacker = null
var cinematic_target = null
var ko_timer: float = 0.0
var ko_duration: float = 0.0
var ko_elapsed: float = 0.0
var ko_winner = null
var ko_loser = null
var active_touch: int = -1
var fov_impulse: float = 0.0

func _ready() -> void:
    camera = Camera3D.new()
    camera.name = "MainCamera"
    camera.current = true
    camera.fov = 58.0
    camera.near = 0.08
    camera.far = 220.0
    add_child(camera)

func set_subjects(p_player, p_target) -> void:
    player = p_player
    target = p_target

func add_shake(amount: float) -> void:
    shake_strength = maxf(shake_strength, amount)
    shake_time = maxf(shake_time, 0.12 + amount * 0.05)
    fov_impulse = maxf(fov_impulse, clampf(amount * 1.15, 0.0, 3.5))

func play_ultimate(attacker, victim) -> void:
    cinematic_attacker = attacker
    cinematic_target = victim
    cinematic_duration = 0.96
    cinematic_timer = cinematic_duration
    cinematic_elapsed = 0.0
    cinematic_side_sign = -1.0 if int(attacker.variant) in [0, 3] else 1.0
    add_shake(1.4)

func play_ko(winner, loser) -> void:
    ko_winner = winner
    ko_loser = loser
    ko_duration = 1.15
    ko_timer = ko_duration
    ko_elapsed = 0.0
    cinematic_timer = 0.0
    add_shake(1.7)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var view_size: Vector2 = get_viewport().get_visible_rect().size
        if event.pressed and event.position.x > view_size.x * 0.46 and event.position.y < view_size.y * 0.70:
            active_touch = event.index
        elif not event.pressed and event.index == active_touch:
            active_touch = -1
    elif event is InputEventScreenDrag and event.index == active_touch:
        yaw -= event.relative.x * look_sensitivity
        pitch -= event.relative.y * look_sensitivity
        pitch = clampf(pitch, deg_to_rad(-48.0), deg_to_rad(22.0))
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        yaw -= event.relative.x * look_sensitivity
        pitch -= event.relative.y * look_sensitivity
        pitch = clampf(pitch, deg_to_rad(-48.0), deg_to_rad(22.0))

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return

    if ko_timer > 0.0 and is_instance_valid(ko_winner) and is_instance_valid(ko_loser):
        ko_timer -= delta
        ko_elapsed += delta
        _update_ko(delta)
        return

    if cinematic_timer > 0.0 and is_instance_valid(cinematic_attacker) and is_instance_valid(cinematic_target):
        cinematic_timer -= delta
        cinematic_elapsed += delta
        _update_cinematic(delta)
        return

    var focus: Vector3 = player.global_position + Vector3.UP * 1.28
    var desired: Vector3 = Vector3.ZERO

    if player.lock_on and is_instance_valid(target):
        var target_focus: Vector3 = target.global_position + Vector3.UP * 1.22
        var separation: float = player.global_position.distance_to(target.global_position)
        var center: Vector3 = focus.lerp(target_focus, 0.34)
        var away: Vector3 = player.global_position - target.global_position
        away.y = 0.0
        if away.length_squared() < 0.01:
            away = Vector3.BACK
        away = away.normalized()
        var side: Vector3 = away.cross(Vector3.UP).normalized()
        var distance: float = clampf(5.05 + separation * 0.115, 5.15, 8.25)
        desired = center + away * distance + side * 0.72 + Vector3.UP * (1.72 + separation * 0.030)
        focus = center + Vector3.UP * 0.28
    else:
        var orbit: Vector3 = Vector3(0,0,free_distance)
        orbit = orbit.rotated(Vector3.RIGHT,pitch)
        orbit = orbit.rotated(Vector3.UP,yaw)
        desired = focus + orbit + Vector3.UP * height

    desired = _camera_collision(focus, desired)
    global_position = global_position.lerp(desired, clampf(delta * 8.5, 0.0, 1.0))
    camera.look_at(focus, Vector3.UP)

    if shake_time > 0.0:
        shake_time -= delta
        var offset: Vector3 = Vector3(randf_range(-1.0,1.0),randf_range(-1.0,1.0),0.0) * shake_strength * 0.06
        camera.position = offset
        shake_strength = move_toward(shake_strength, 0.0, delta * 7.0)
    else:
        camera.position = camera.position.lerp(Vector3.ZERO, clampf(delta * 15.0, 0.0, 1.0))

    var player_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
    var movement_fov: float = clampf(player_speed * 0.20, 0.0, 4.0)
    var target_fov: float = 58.0 + movement_fov + fov_impulse
    fov_impulse = move_toward(fov_impulse, 0.0, delta * 10.0)
    camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 6.5, 0.0, 1.0))

func _update_cinematic(delta: float) -> void:
    var a_pos: Vector3 = cinematic_attacker.global_position + Vector3.UP * 1.30
    var b_pos: Vector3 = cinematic_target.global_position + Vector3.UP * 1.15
    var center: Vector3 = a_pos.lerp(b_pos, 0.48)
    var direction: Vector3 = b_pos - a_pos
    direction.y = 0.0
    if direction.length_squared() < 0.01:
        direction = Vector3.FORWARD
    direction = direction.normalized()

    var side: Vector3 = direction.cross(Vector3.UP).normalized()
    var progress: float = clampf(cinematic_elapsed / maxf(cinematic_duration, 0.001), 0.0, 1.0)
    var arc: float = sin(progress * PI)
    var side_distance: float = lerpf(2.3, 3.8, arc) * cinematic_side_sign
    var back_distance: float = lerpf(3.3, 2.4, arc)
    var height_offset: float = lerpf(1.1, 1.8, sin(progress * PI * 0.75))
    var desired: Vector3 = a_pos - direction * back_distance + side * side_distance + Vector3.UP * height_offset
    desired = _camera_collision(center, desired)

    global_position = global_position.lerp(desired, clampf(delta * 13.5, 0.0, 1.0))
    camera.look_at(center + Vector3.UP * 0.08, Vector3.UP)

    var cinematic_fov: float = lerpf(46.0, 52.0, progress)
    if progress > 0.72:
        cinematic_fov = lerpf(cinematic_fov, 58.0, (progress - 0.72) / 0.28)
    camera.fov = lerpf(camera.fov, cinematic_fov, clampf(delta * 12.0, 0.0, 1.0))

func _update_ko(delta: float) -> void:
    var winner_pos: Vector3 = ko_winner.global_position + Vector3.UP * 1.25
    var loser_pos: Vector3 = ko_loser.global_position + Vector3.UP * 0.82
    var center: Vector3 = winner_pos.lerp(loser_pos, 0.40)
    var direction: Vector3 = loser_pos - winner_pos
    direction.y = 0.0
    if direction.length_squared() < 0.01:
        direction = Vector3.FORWARD
    direction = direction.normalized()
    var side: Vector3 = direction.cross(Vector3.UP).normalized()
    var progress: float = clampf(ko_elapsed / maxf(ko_duration,0.001),0.0,1.0)
    var side_sign: float = -1.0 if int(ko_winner.variant) in [0,3] else 1.0
    var desired: Vector3 = winner_pos - direction * lerpf(3.0,2.4,progress) + side * (2.8 * side_sign) + Vector3.UP * lerpf(0.85,1.25,progress)
    desired = _camera_collision(center, desired)
    global_position = global_position.lerp(desired, clampf(delta * 12.0,0.0,1.0))
    camera.look_at(center + Vector3.UP * 0.10, Vector3.UP)
    camera.fov = lerpf(camera.fov, lerpf(49.0,54.0,progress), clampf(delta*10.0,0.0,1.0))

    if shake_time > 0.0:
        shake_time -= delta
        camera.position = Vector3(randf_range(-1.0,1.0),randf_range(-1.0,1.0),0.0) * shake_strength * 0.045
        shake_strength = move_toward(shake_strength,0.0,delta*8.0)
    else:
        camera.position = camera.position.lerp(Vector3.ZERO,clampf(delta*14.0,0.0,1.0))

func _camera_collision(from: Vector3, desired: Vector3) -> Vector3:
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, desired, 1)
    var exclusions: Array[RID] = []
    if is_instance_valid(player):
        exclusions.append(player.get_rid())
    if is_instance_valid(target):
        exclusions.append(target.get_rid())
    query.exclude = exclusions
    var result: Dictionary = space.intersect_ray(query)
    if result.is_empty():
        return desired
    return result.position + result.normal * 0.32
