extends CanvasLayer

signal start_requested(variant)
signal restart_requested
signal menu_requested

const JoystickScript = preload("res://scripts/virtual_joystick.gd")

var player = null
var enemy = null
var menu_ui: Control
var game_ui: Control
var result_ui: Control
var pause_ui: Control
var player_hp: ProgressBar
var enemy_hp: ProgressBar
var stamina_bar: ProgressBar
var energy_bar: ProgressBar
var ultimate_bar: ProgressBar
var combo_label: Label
var result_label: Label
var fps_label: Label
var controls_ui: Control

func _ready() -> void:
    _build_menu()
    _build_game_ui()
    _build_result()
    _build_pause()
    show_main_menu()

func _process(_delta: float) -> void:
    if game_ui.visible and is_instance_valid(player) and is_instance_valid(enemy):
        player_hp.max_value = player.max_health
        player_hp.value = player.health
        enemy_hp.max_value = enemy.max_health
        enemy_hp.value = enemy.health
        stamina_bar.max_value = player.max_stamina
        stamina_bar.value = player.stamina
        energy_bar.max_value = player.max_energy
        energy_bar.value = player.energy
        ultimate_bar.max_value = 100.0
        ultimate_bar.value = player.ultimate
        fps_label.text = "%d FPS" % Engine.get_frames_per_second()

func bind_fighters(p_player, p_enemy) -> void:
    player = p_player
    enemy = p_enemy
    menu_ui.visible = false
    result_ui.visible = false
    pause_ui.visible = false
    game_ui.visible = true
    get_tree().paused = false
    set_combo(0)

func set_combo(value: int) -> void:
    if value <= 1:
        combo_label.text = ""
    else:
        combo_label.text = "%d HIT COMBO" % value

func show_result(text_value: String) -> void:
    result_label.text = text_value
    result_ui.visible = true
    controls_ui.visible = false

func show_main_menu() -> void:
    player = null
    enemy = null
    menu_ui.visible = true
    game_ui.visible = false
    result_ui.visible = false
    pause_ui.visible = false
    get_tree().paused = false

func _build_menu() -> void:
    menu_ui = Control.new()
    menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(menu_ui)

    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.01,0.015,0.04,0.96)
    menu_ui.add_child(bg)

    var title := _label("ANIME ARENA\nFIGHTER", Vector2(0,115), 64, Color(0.65,0.86,1.0))
    title.size = Vector2(1920,180)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_ui.add_child(title)

    var subtitle := _label("ANDROID 3D ARENA BATTLE", Vector2(0,285), 22, Color(0.62,0.68,0.78))
    subtitle.size = Vector2(1920,40)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_ui.add_child(subtitle)

    var choose := _label("SELECT FIGHTER", Vector2(0,405), 30, Color.WHITE)
    choose.size = Vector2(1920,50)
    choose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_ui.add_child(choose)

    var azure := _menu_button("AZURE FANG", Vector2(525,500), Vector2(390,105), Color(0.08,0.34,0.72))
    azure.pressed.connect(func(): start_requested.emit(0))
    menu_ui.add_child(azure)

    var crimson := _menu_button("CRIMSON EDGE", Vector2(1005,500), Vector2(390,105), Color(0.65,0.08,0.16))
    crimson.pressed.connect(func(): start_requested.emit(1))
    menu_ui.add_child(crimson)

    var hint := _label("Touch controls • Lock-on • Combos • Skills • Ultimate", Vector2(0,690), 22, Color(0.52,0.60,0.72))
    hint.size = Vector2(1920,40)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_ui.add_child(hint)

    var fps30 := _menu_button("30 FPS", Vector2(720,790), Vector2(220,70), Color(0.14,0.18,0.26))
    fps30.pressed.connect(func(): Engine.max_fps = 30)
    menu_ui.add_child(fps30)
    var fps60 := _menu_button("60 FPS", Vector2(980,790), Vector2(220,70), Color(0.14,0.18,0.26))
    fps60.pressed.connect(func(): Engine.max_fps = 60)
    menu_ui.add_child(fps60)

func _build_game_ui() -> void:
    game_ui = Control.new()
    game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(game_ui)

    player_hp = _bar(Vector2(70,55), Vector2(680,34), Color(0.10,0.62,1.0))
    game_ui.add_child(player_hp)
    enemy_hp = _bar(Vector2(1170,55), Vector2(680,34), Color(1.0,0.18,0.25))
    game_ui.add_child(enemy_hp)

    var p_name := _label("PLAYER",Vector2(70,18),24,Color(0.72,0.88,1.0))
    game_ui.add_child(p_name)
    var e_name := _label("ENEMY",Vector2(1740,18),24,Color(1.0,0.72,0.74))
    game_ui.add_child(e_name)

    stamina_bar = _bar(Vector2(70,98),Vector2(420,22),Color(0.35,1.0,0.45))
    game_ui.add_child(stamina_bar)
    energy_bar = _bar(Vector2(70,130),Vector2(420,22),Color(0.15,0.72,1.0))
    game_ui.add_child(energy_bar)
    ultimate_bar = _bar(Vector2(70,162),Vector2(420,22),Color(1.0,0.72,0.08))
    game_ui.add_child(ultimate_bar)

    combo_label = _label("",Vector2(0,170),34,Color(1.0,0.88,0.35))
    combo_label.size = Vector2(1920,55)
    combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_ui.add_child(combo_label)

    fps_label = _label("",Vector2(1780,100),18,Color(0.65,0.70,0.78))
    game_ui.add_child(fps_label)

    var pause_button := _action_button("Ⅱ","",Vector2(1815,145),Vector2(65,65))
    pause_button.pressed.connect(_toggle_pause)
    game_ui.add_child(pause_button)

    controls_ui = Control.new()
    controls_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    game_ui.add_child(controls_ui)

    var joystick = JoystickScript.new()
    joystick.position = Vector2(95,740)
    joystick.size = Vector2(230,230)
    controls_ui.add_child(joystick)

    _add_action("ATK","attack",Vector2(1570,770),Vector2(145,110))
    _add_action("HVY","heavy",Vector2(1730,660),Vector2(135,100))
    _add_action("DODGE","dodge",Vector2(1410,840),Vector2(140,95))
    _add_action("DASH","dash",Vector2(1260,865),Vector2(125,85))
    _add_action("JUMP","jump",Vector2(1735,880),Vector2(130,88))
    _add_action("BLOCK","block",Vector2(1420,690),Vector2(135,95),true)

    _add_action("S1","skill_1",Vector2(1110,690),Vector2(105,82))
    _add_action("S2","skill_2",Vector2(1218,610),Vector2(105,82))
    _add_action("S3","skill_3",Vector2(1328,585),Vector2(105,82))
    _add_action("S4","skill_4",Vector2(1438,595),Vector2(105,82))
    _add_action("ULT","ultimate",Vector2(1585,545),Vector2(150,95))
    _add_action("LOCK","lock_on",Vector2(1040,835),Vector2(145,82))

func _build_result() -> void:
    result_ui = Control.new()
    result_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(result_ui)
    var fade := ColorRect.new()
    fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fade.color = Color(0,0,0,0.62)
    result_ui.add_child(fade)
    result_label = _label("",Vector2(0,275),76,Color.WHITE)
    result_label.size = Vector2(1920,220)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_ui.add_child(result_label)
    var retry := _menu_button("REMATCH",Vector2(660,610),Vector2(280,90),Color(0.08,0.36,0.70))
    retry.pressed.connect(func():
        result_ui.visible=false
        controls_ui.visible=true
        restart_requested.emit()
    )
    result_ui.add_child(retry)
    var menu := _menu_button("MENU",Vector2(980,610),Vector2(280,90),Color(0.24,0.25,0.30))
    menu.pressed.connect(func(): menu_requested.emit())
    result_ui.add_child(menu)

func _build_pause() -> void:
    pause_ui = Control.new()
    pause_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    add_child(pause_ui)
    var fade := ColorRect.new()
    fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fade.color = Color(0,0,0,0.72)
    pause_ui.add_child(fade)
    var title := _label("PAUSED",Vector2(0,320),58,Color.WHITE)
    title.size = Vector2(1920,90)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_ui.add_child(title)
    var resume := _menu_button("RESUME",Vector2(790,470),Vector2(340,85),Color(0.08,0.36,0.70))
    resume.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    resume.pressed.connect(_toggle_pause)
    pause_ui.add_child(resume)
    var menu := _menu_button("MAIN MENU",Vector2(790,585),Vector2(340,85),Color(0.24,0.25,0.30))
    menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    menu.pressed.connect(func():
        get_tree().paused=false
        menu_requested.emit()
    )
    pause_ui.add_child(menu)

func _toggle_pause() -> void:
    var next := not get_tree().paused
    get_tree().paused = next
    pause_ui.visible = next

func _bar(pos: Vector2, sz: Vector2, color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.position = pos
    bar.size = sz
    bar.min_value = 0
    bar.max_value = 100
    bar.value = 100
    bar.show_percentage = false
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.04,0.05,0.08,0.86)
    bg.corner_radius_top_left=8
    bg.corner_radius_top_right=8
    bg.corner_radius_bottom_left=8
    bg.corner_radius_bottom_right=8
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.corner_radius_top_left=8
    fill.corner_radius_top_right=8
    fill.corner_radius_bottom_left=8
    fill.corner_radius_bottom_right=8
    bar.add_theme_stylebox_override("background",bg)
    bar.add_theme_stylebox_override("fill",fill)
    return bar

func _label(text_value: String, pos: Vector2, font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text_value
    l.position = pos
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color",color)
    return l

func _style(color: Color, alpha := 0.82) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(color.r,color.g,color.b,alpha)
    s.corner_radius_top_left=18
    s.corner_radius_top_right=18
    s.corner_radius_bottom_left=18
    s.corner_radius_bottom_right=18
    s.border_width_left=2
    s.border_width_top=2
    s.border_width_right=2
    s.border_width_bottom=2
    s.border_color=color.lightened(0.25)
    return s

func _action_button(text_value: String, action: String, pos: Vector2, sz: Vector2, hold := false) -> Button:
    var b := Button.new()
    b.text=text_value
    b.position=pos
    b.size=sz
    b.focus_mode=Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size",20)
    b.add_theme_stylebox_override("normal",_style(Color(0.08,0.18,0.36),0.72))
    b.add_theme_stylebox_override("pressed",_style(Color(0.18,0.55,1.0),0.95))
    if action != "":
        b.button_down.connect(func(): Input.action_press(action))
        b.button_up.connect(func(): Input.action_release(action))
    return b

func _add_action(text_value: String, action: String, pos: Vector2, sz: Vector2, hold := false) -> void:
    var b := _action_button(text_value,action,pos,sz,hold)
    controls_ui.add_child(b)

func _menu_button(text_value: String, pos: Vector2, sz: Vector2, color: Color) -> Button:
    var b := Button.new()
    b.text=text_value
    b.position=pos
    b.size=sz
    b.focus_mode=Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size",25)
    b.add_theme_stylebox_override("normal",_style(color,0.86))
    b.add_theme_stylebox_override("pressed",_style(color.lightened(0.18),1.0))
    return b
