extends CanvasLayer

signal start_requested(player_variant, enemy_variant, difficulty)
signal restart_requested
signal menu_requested
signal time_expired
signal quality_requested(level)

const JoystickScript = preload("res://scripts/virtual_joystick.gd")
const Roster = preload("res://scripts/character_data.gd")

var player = null
var enemy = null
var selected_player: int = 0
var selected_enemy: int = 2
var selected_difficulty: int = 1
var selected_quality: int = 1

var menu_ui: Control
var game_ui: Control
var result_ui: Control
var pause_ui: Control
var player_panel: Panel
var enemy_panel: Panel
var player_name: Label
var enemy_name: Label
var player_role: Label
var enemy_role: Label
var player_desc: Label
var enemy_desc: Label
var player_stats: Label
var enemy_stats: Label
var difficulty_button: Button
var quality_button: Button
var start_button: Button

var player_hp: ProgressBar
var enemy_hp: ProgressBar
var stamina_bar: ProgressBar
var energy_bar: ProgressBar
var ultimate_bar: ProgressBar
var combo_label: Label
var result_label: Label
var fps_label: Label
var controls_ui: Control
var combat_player_name: Label
var combat_enemy_name: Label
var round_timer_label: Label
var skill_strip_label: Label
var lock_indicator: Label
var skill_names: Array[String] = []
var round_time: float = 99.0
var timer_finished: bool = false

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
        fps_label.text = "%s  •  %d FPS" % [["LOW","MED","HIGH"][selected_quality], Engine.get_frames_per_second()]
        lock_indicator.text = "LOCK ◆" if player.lock_on else "FREE CAM"
        lock_indicator.add_theme_color_override("font_color", Color(1.0,0.84,0.28) if player.lock_on else Color(0.48,0.58,0.72))
        if skill_names.size() >= 4:
            var cooldown_parts: Array[String] = []
            for i in range(4):
                var cooldown: float = player.skill_cooldowns[i]
                var suffix: String = " %.1f" % cooldown if cooldown > 0.05 else " READY"
                cooldown_parts.append("S%d %s%s" % [i + 1, skill_names[i], suffix])
            skill_strip_label.text = "    ".join(cooldown_parts)
        if not result_ui.visible and not get_tree().paused and not timer_finished:
            round_time = maxf(0.0, round_time - _delta)
            round_timer_label.text = "%02d" % int(ceil(round_time))
            if round_time <= 0.0:
                timer_finished = true
                time_expired.emit()

func bind_fighters(p_player, p_enemy) -> void:
    player = p_player
    enemy = p_enemy
    menu_ui.visible = false
    result_ui.visible = false
    pause_ui.visible = false
    game_ui.visible = true
    controls_ui.visible = true
    get_tree().paused = false
    round_time = 99.0
    timer_finished = false
    round_timer_label.text = "99"

    var player_data: Dictionary = Roster.get_data(int(p_player.variant))
    var enemy_data: Dictionary = Roster.get_data(int(p_enemy.variant))
    combat_player_name.text = player_data.name
    combat_enemy_name.text = enemy_data.name
    combat_player_name.add_theme_color_override("font_color", player_data.color.lightened(0.24))
    combat_enemy_name.add_theme_color_override("font_color", enemy_data.color.lightened(0.24))

    var skills: Array = player_data.skills
    skill_names.clear()
    for skill in skills:
        skill_names.append(String(skill))
    skill_strip_label.text = "S1  %s    S2  %s    S3  %s    S4  %s" % [skills[0], skills[1], skills[2], skills[3]]
    set_combo(0)

func set_combo(value: int) -> void:
    combo_label.text = "" if value <= 1 else "%d HIT COMBO" % value

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
    _refresh_selection()

func _build_menu() -> void:
    menu_ui = Control.new()
    menu_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(menu_ui)

    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.008, 0.012, 0.028, 1.0)
    menu_ui.add_child(bg)

    var glow_l := ColorRect.new()
    glow_l.position = Vector2(0, 0)
    glow_l.size = Vector2(620, 1080)
    glow_l.color = Color(0.04, 0.18, 0.42, 0.18)
    menu_ui.add_child(glow_l)

    var glow_r := ColorRect.new()
    glow_r.position = Vector2(1300, 0)
    glow_r.size = Vector2(620, 1080)
    glow_r.color = Color(0.42, 0.04, 0.10, 0.16)
    menu_ui.add_child(glow_r)

    var title := _label("BATTLE SETUP", Vector2(0, 45), 48, Color(0.88, 0.94, 1.0))
    title.size = Vector2(1920, 70)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_ui.add_child(title)

    var subtitle := _label("CHOOSE YOUR FIGHTER  •  CHOOSE YOUR OPPONENT", Vector2(0, 105), 20, Color(0.46, 0.58, 0.72))
    subtitle.size = Vector2(1920, 40)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_ui.add_child(subtitle)

    player_panel = _selection_panel(Vector2(105, 175), Vector2(700, 535), Color(0.08, 0.36, 0.76))
    menu_ui.add_child(player_panel)
    enemy_panel = _selection_panel(Vector2(1115, 175), Vector2(700, 535), Color(0.76, 0.08, 0.18))
    menu_ui.add_child(enemy_panel)

    var your := _label("YOUR FIGHTER", Vector2(135, 195), 24, Color(0.55, 0.80, 1.0))
    menu_ui.add_child(your)
    var foe := _label("OPPONENT", Vector2(1145, 195), 24, Color(1.0, 0.60, 0.64))
    menu_ui.add_child(foe)

    player_name = _label("", Vector2(135, 245), 38, Color.WHITE)
    player_name.size = Vector2(620, 58)
    menu_ui.add_child(player_name)
    enemy_name = _label("", Vector2(1145, 245), 38, Color.WHITE)
    enemy_name.size = Vector2(620, 58)
    menu_ui.add_child(enemy_name)

    player_role = _label("", Vector2(135, 310), 20, Color(0.55, 0.76, 1.0))
    menu_ui.add_child(player_role)
    enemy_role = _label("", Vector2(1145, 310), 20, Color(1.0, 0.62, 0.62))
    menu_ui.add_child(enemy_role)

    player_desc = _label("", Vector2(135, 365), 18, Color(0.72, 0.77, 0.84))
    player_desc.size = Vector2(600, 90)
    player_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu_ui.add_child(player_desc)
    enemy_desc = _label("", Vector2(1145, 365), 18, Color(0.72, 0.77, 0.84))
    enemy_desc.size = Vector2(600, 90)
    enemy_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu_ui.add_child(enemy_desc)

    player_stats = _label("", Vector2(135, 470), 20, Color(0.88, 0.92, 0.98))
    player_stats.size = Vector2(620, 120)
    menu_ui.add_child(player_stats)
    enemy_stats = _label("", Vector2(1145, 470), 20, Color(0.88, 0.92, 0.98))
    enemy_stats.size = Vector2(620, 120)
    menu_ui.add_child(enemy_stats)

    var vs := _label("VS", Vector2(0, 330), 72, Color(1.0, 0.82, 0.22))
    vs.size = Vector2(1920, 100)
    vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_ui.add_child(vs)

    _build_roster_buttons(true)
    _build_roster_buttons(false)

    quality_button = _menu_button("GRAPHICS: MEDIUM", Vector2(805, 555), Vector2(310, 66), Color(0.10, 0.28, 0.42))
    quality_button.add_theme_font_size_override("font_size", 20)
    quality_button.pressed.connect(_cycle_quality)
    menu_ui.add_child(quality_button)

    difficulty_button = _menu_button("AI: NORMAL", Vector2(805, 645), Vector2(310, 72), Color(0.16, 0.20, 0.30))
    difficulty_button.pressed.connect(_cycle_difficulty)
    menu_ui.add_child(difficulty_button)

    start_button = _menu_button("START BATTLE", Vector2(700, 760), Vector2(520, 105), Color(0.08, 0.46, 0.80))
    start_button.add_theme_font_size_override("font_size", 30)
    start_button.pressed.connect(func(): start_requested.emit(selected_player, selected_enemy, selected_difficulty))
    menu_ui.add_child(start_button)

    var footer := _label("Landscape 16:9  •  4 fighters  •  Touch controls  •  1v1 arena", Vector2(0, 920), 18, Color(0.38, 0.46, 0.58))
    footer.size = Vector2(1920, 40)
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    menu_ui.add_child(footer)

func _selection_panel(pos: Vector2, sz: Vector2, accent: Color) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = sz
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.035, 0.060, 0.94)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
    style.corner_radius_top_left = 22
    style.corner_radius_top_right = 22
    style.corner_radius_bottom_left = 22
    style.corner_radius_bottom_right = 22
    p.add_theme_stylebox_override("panel", style)
    return p

func _build_roster_buttons(for_player: bool) -> void:
    var x_start: float = 120.0 if for_player else 1130.0
    var y: float = 600.0
    for i in range(Roster.count()):
        var data: Dictionary = Roster.get_data(i)
        var b := _menu_button(data.short, Vector2(x_start + i * 160.0, y), Vector2(140, 92), data.color.darkened(0.45))
        b.tooltip_text = data.name
        var index := i
        if for_player:
            b.pressed.connect(func():
                selected_player = index
                _refresh_selection()
            )
        else:
            b.pressed.connect(func():
                selected_enemy = index
                _refresh_selection()
            )
        menu_ui.add_child(b)

func _refresh_selection() -> void:
    if player_name == null:
        return
    var pd: Dictionary = Roster.get_data(selected_player)
    var ed: Dictionary = Roster.get_data(selected_enemy)
    player_name.text = pd.name
    enemy_name.text = ed.name
    player_role.text = pd.role
    enemy_role.text = ed.role
    player_desc.text = pd.description
    enemy_desc.text = ed.description
    player_stats.text = _stats_text(pd)
    enemy_stats.text = _stats_text(ed)

func _stats_text(data: Dictionary) -> String:
    return "SPEED   %s\nPOWER   %s\nRANGE   %s\nDEFENSE %s\n\n%s" % [
        _pips(int(data.speed)),
        _pips(int(data.power_stat)),
        _pips(int(data.range)),
        _pips(int(data.defense_stat)),
        " • ".join(data.skills)
    ]

func _pips(value: int) -> String:
    var out := ""
    for i in range(5):
        out += "◆" if i < value else "◇"
    return out

func _cycle_difficulty() -> void:
    selected_difficulty = (selected_difficulty + 1) % 3
    difficulty_button.text = ["AI: EASY", "AI: NORMAL", "AI: HARD"][selected_difficulty]

func _cycle_quality() -> void:
    selected_quality = (selected_quality + 1) % 3
    quality_button.text = "GRAPHICS: %s" % ["LOW", "MEDIUM", "HIGH"][selected_quality]
    quality_requested.emit(selected_quality)

func _build_game_ui() -> void:
    game_ui = Control.new()
    game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(game_ui)

    player_hp = _bar(Vector2(70,55), Vector2(680,34), Color(0.10,0.62,1.0))
    game_ui.add_child(player_hp)
    enemy_hp = _bar(Vector2(1170,55), Vector2(680,34), Color(1.0,0.18,0.25))
    game_ui.add_child(enemy_hp)

    combat_player_name = _label("PLAYER",Vector2(70,15),24,Color(0.72,0.88,1.0))
    combat_player_name.size = Vector2(680,36)
    game_ui.add_child(combat_player_name)

    combat_enemy_name = _label("ENEMY",Vector2(1170,15),24,Color(1.0,0.72,0.74))
    combat_enemy_name.size = Vector2(680,36)
    combat_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    game_ui.add_child(combat_enemy_name)

    round_timer_label = _label("99",Vector2(860,24),42,Color(1.0,0.90,0.42))
    round_timer_label.size = Vector2(200,58)
    round_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_ui.add_child(round_timer_label)

    stamina_bar = _bar(Vector2(70,98),Vector2(420,22),Color(0.35,1.0,0.45))
    game_ui.add_child(stamina_bar)
    energy_bar = _bar(Vector2(70,130),Vector2(420,22),Color(0.15,0.72,1.0))
    game_ui.add_child(energy_bar)
    ultimate_bar = _bar(Vector2(70,162),Vector2(420,22),Color(1.0,0.72,0.08))
    game_ui.add_child(ultimate_bar)

    skill_strip_label = _label("",Vector2(70,198),16,Color(0.68,0.78,0.92))
    skill_strip_label.size = Vector2(1220,30)
    game_ui.add_child(skill_strip_label)

    lock_indicator = _label("LOCK ◆",Vector2(860,92),18,Color(1.0,0.84,0.28))
    lock_indicator.size = Vector2(200,34)
    lock_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_ui.add_child(lock_indicator)

    combo_label = _label("",Vector2(0,235),34,Color(1.0,0.88,0.35))
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
    _add_action("BLOCK","block",Vector2(1420,690),Vector2(135,95))
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
    var menu := _menu_button("CHARACTER SELECT",Vector2(980,610),Vector2(360,90),Color(0.24,0.25,0.30))
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
    var menu := _menu_button("CHARACTER SELECT",Vector2(760,585),Vector2(400,85),Color(0.24,0.25,0.30))
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

func _style(color: Color, alpha: float = 0.82) -> StyleBoxFlat:
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

func _action_button(text_value: String, action: String, pos: Vector2, sz: Vector2) -> Button:
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

func _add_action(text_value: String, action: String, pos: Vector2, sz: Vector2) -> void:
    controls_ui.add_child(_action_button(text_value,action,pos,sz))

func _menu_button(text_value: String, pos: Vector2, sz: Vector2, color: Color) -> Button:
    var b := Button.new()
    b.text=text_value
    b.position=pos
    b.size=sz
    b.focus_mode=Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size",24)
    b.add_theme_stylebox_override("normal",_style(color,0.86))
    b.add_theme_stylebox_override("hover",_style(color.lightened(0.10),0.94))
    b.add_theme_stylebox_override("pressed",_style(color.lightened(0.18),1.0))
    return b
