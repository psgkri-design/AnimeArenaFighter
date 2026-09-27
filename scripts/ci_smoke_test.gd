extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    if condition:
        print("SMOKE PASS: ", label)
    else:
        failures.append(label)
        push_error("SMOKE FAIL: " + label)

func _collect_animation_names(node: Node, output: Array[String]) -> void:
    if node is AnimationPlayer:
        var player := node as AnimationPlayer
        for animation_name in player.get_animation_list():
            var name_text := String(animation_name)
            if not output.has(name_text):
                output.append(name_text)
    for child in node.get_children():
        _collect_animation_names(child, output)

func _audit_animations(fighter, label: String) -> void:
    var names: Array[String] = []
    _collect_animation_names(fighter, names)
    print("ANIM_AUDIT ", label, ": ", ", ".join(names))
    _check(not names.is_empty(), label + " has imported AnimationPlayer clips")

func _run() -> void:
    var scene_resource := load("res://scenes/main.tscn") as PackedScene
    _check(scene_resource != null, "main scene loads")
    if scene_resource == null:
        _finish()
        return

    var game = scene_resource.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    _check(game.hud != null, "HUD created")
    _check(game.camera_rig != null, "combat camera created")
    _check(game.hud.menu_ui.visible, "character select visible on boot")

    game.hud.quality_requested.emit(0)
    await process_frame
    _check(Engine.max_fps == 30, "LOW graphics preset applies 30 FPS cap")
    game.hud.quality_requested.emit(1)
    await process_frame
    _check(Engine.max_fps == 60, "MEDIUM graphics preset restores 60 FPS cap")

    for variant in range(4):
        var enemy_variant: int = (variant + 1) % 4
        game.hud.start_requested.emit(variant, enemy_variant, 1)
        await process_frame
        await physics_frame

        _check(is_instance_valid(game.player), "player spawned for variant %d" % variant)
        _check(is_instance_valid(game.enemy), "enemy spawned for variant %d" % enemy_variant)
        if not is_instance_valid(game.player) or not is_instance_valid(game.enemy):
            continue

        _check(game.match_running, "match running for variant %d" % variant)
        _check(not game.hud.menu_ui.visible and game.hud.game_ui.visible, "battle HUD active")
        _check(game.player.variant == variant, "selected player data propagated")
        _check(game.enemy.variant == enemy_variant, "selected enemy data propagated")
        _audit_animations(game.player, "fighter_%d" % variant)

        game.player.is_ai = false
        game.enemy.is_ai = false
        game.player.global_position = Vector3(0.0, 0.05, 0.0)
        game.enemy.global_position = Vector3(0.0, 0.05, -1.55)
        game.player.set_target(game.enemy)
        game.enemy.set_target(game.player)
        game.player._face_target(1.0)
        game.enemy._face_target(1.0)

        var hp_before: float = game.enemy.health
        game.player._light_attack()
        for _frame in range(28):
            await physics_frame
        _check(game.enemy.health < hp_before, "light attack deals damage")

        game.enemy.receive_hit(game.player, {
            "damage": 99999.0,
            "hitstun": 0.1,
            "knockback": 0.0,
            "launch": 0.0,
            "block_damage": 0.0
        })
        await process_frame
        _check(not game.match_running, "KO ends match")
        _check(game.hud.result_ui.visible, "result screen shown")

        game.hud.restart_requested.emit()
        await process_frame
        await physics_frame
        _check(game.match_running, "rematch restarts battle")

        game.hud.menu_requested.emit()
        await process_frame
        _check(game.hud.menu_ui.visible, "return to character select works")

    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("SMOKE RESULT: PASS")
        quit(0)
    else:
        push_error("SMOKE RESULT: FAIL -> " + ", ".join(failures))
        quit(1)
