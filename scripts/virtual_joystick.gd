extends Control

var touch_id := -1
var mouse_active := false
var output := Vector2.ZERO
var radius := 105.0
var knob_radius := 42.0

func _ready() -> void:
    custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()

func _exit_tree() -> void:
    _release_actions()

func _draw() -> void:
    var c := size * 0.5
    draw_circle(c, radius, Color(0.05, 0.08, 0.14, 0.42))
    draw_circle(c, radius - 5.0, Color(0.15, 0.25, 0.45, 0.18), false, 5.0)
    draw_circle(c + output * (radius - knob_radius), knob_radius, Color(0.55, 0.8, 1.0, 0.72))
    draw_circle(c + output * (radius - knob_radius), knob_radius - 5.0, Color(0.1, 0.25, 0.55, 0.35), false, 4.0)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_id == -1:
            touch_id = event.index
            _update_from_local(event.position)
            accept_event()
        elif not event.pressed and event.index == touch_id:
            touch_id = -1
            _set_output(Vector2.ZERO)
            accept_event()
    elif event is InputEventScreenDrag and event.index == touch_id:
        _update_from_local(event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        mouse_active = event.pressed
        if mouse_active:
            _update_from_local(event.position)
        else:
            _set_output(Vector2.ZERO)
        accept_event()
    elif event is InputEventMouseMotion and mouse_active:
        _update_from_local(event.position)
        accept_event()

func _update_from_local(local_pos: Vector2) -> void:
    var center := size * 0.5
    var delta := local_pos - center
    var max_len := radius - knob_radius * 0.35
    var normalized := delta / max_len
    if normalized.length() > 1.0:
        normalized = normalized.normalized()
    if normalized.length() < 0.12:
        normalized = Vector2.ZERO
    _set_output(normalized)

func _set_output(value: Vector2) -> void:
    output = value
    _push_actions()
    queue_redraw()

func _push_actions() -> void:
    _set_action_strength("move_left", maxf(-output.x, 0.0))
    _set_action_strength("move_right", maxf(output.x, 0.0))
    _set_action_strength("move_forward", maxf(-output.y, 0.0))
    _set_action_strength("move_back", maxf(output.y, 0.0))

func _set_action_strength(action: StringName, strength: float) -> void:
    if strength > 0.001:
        Input.action_press(action, strength)
    else:
        Input.action_release(action)

func _release_actions() -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    Input.action_release("move_forward")
    Input.action_release("move_back")
