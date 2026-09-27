extends Node3D

var camera: Camera3D
var player = null
var target = null
var yaw: float = 0.0
var pitch: float = deg_to_rad(-12.0)
var free_distance: float = 8.5
var height: float = 2.2
var look_sensitivity: float = 0.006
var shake_strength: float = 0.0
var shake_time: float = 0.0
var cinematic_timer: float = 0.0
var cinematic_attacker = null
var cinematic_target = null
var active_touch: int = -1

func _ready() -> void:
    camera = Camera3D.new()
    camera.name = "MainCamera"
    camera.current = true
    camera.fov = 68.0
    camera.near = 0.08
    camera.far = 220.0
    add_child(camera)

func set_subjects(p_player, p_target) -> void:
    player = p_player
    target = p_target

func add_shake(amount: float) -> void:
    shake_strength = maxf(shake_strength, amount)
    shake_time = maxf(shake_time, 0.12 + amount * 0.05)

func play_ultimate(attacker, victim) -> void:
    cinematic_attacker = attacker
    cinematic_target = victim
    cinematic_timer = 0.72
    add_shake(1.4)

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

    if cinematic_timer > 0.0 and is_instance_valid(cinematic_attacker) and is_instance_valid(cinematic_target):
        cinematic_timer -= delta
        _update_cinematic(delta)
        return

    var focus: Vector3 = player.global_position + Vector3.UP * 1.15
    var desired: Vector3 = Vector3.ZERO

    if player.lock_on and is_instance_valid(target):
        var target_focus: Vector3 = target.global_position + Vector3.UP * 1.05
        var separation: float = player.global_position.distance_to(target.global_position)
        var center: Vector3 = focus.lerp(target_focus, 0.34)
        var away: Vector3 = player.global_position - target.global_position
        away.y = 0.0
        if away.length_squared() < 0.01:
            away = Vector3.BACK
        away = away.normalized()
        var side: Vector3 = away.cross(Vector3.UP).normalized()
        var distance: float = clampf(7.0 + separation * 0.17, 7.0, 12.0)
        desired = center + away * distance + side * 1.2 + Vector3.UP * (2.6 + separation * 0.045)
        focus = center + Vector3.UP * 0.35
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

    camera.fov = lerpf(camera.fov, 68.0, clampf(delta * 5.0, 0.0, 1.0))

func _update_cinematic(delta: float) -> void:
    var a_pos: Vector3 = cinematic_attacker.global_position + Vector3.UP * 1.25
    var b_pos: Vector3 = cinematic_target.global_position + Vector3.UP * 1.15
    var center: Vector3 = a_pos.lerp(b_pos, 0.5)
    var direction: Vector3 = b_pos - a_pos
    direction.y = 0.0
    if direction.length_squared() < 0.01:
        direction = Vector3.FORWARD
    var side: Vector3 = direction.normalized().cross(Vector3.UP)
    var desired: Vector3 = a_pos - direction.normalized() * 2.8 + side * 3.0 + Vector3.UP * 1.45
    global_position = global_position.lerp(desired, clampf(delta * 14.0, 0.0, 1.0))
    camera.look_at(center, Vector3.UP)
    camera.fov = lerpf(camera.fov, 54.0, clampf(delta * 12.0, 0.0, 1.0))

func _camera_collision(from: Vector3, desired: Vector3) -> Vector3:
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, desired, 1)
    if is_instance_valid(player):
        query.exclude = [player.get_rid()]
    var result: Dictionary = space.intersect_ray(query)
    if result.is_empty():
        return desired
    return result.position + result.normal * 0.32
