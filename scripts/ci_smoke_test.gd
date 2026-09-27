extends SceneTree

const ProjectileScript = preload("res://scripts/projectile.gd")

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

func _print_skeleton_bones(node: Node) -> bool:
    if node is Skeleton3D:
        var skeleton := node as Skeleton3D
        var names: Array[String] = []
        for bone_index in range(skeleton.get_bone_count()):
            names.append(String(skeleton.get_bone_name(bone_index)))
        print("BONE_AUDIT: ", ", ".join(names))
        return true
    for child in node.get_children():
        if _print_skeleton_bones(child):
            return true
    return false

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
    _check(absf(game.camera_rig.camera.fov - 58.0) < 0.5, "adult camera base FOV is 58")
    _check(game.camera_rig.free_distance < 6.5, "free camera moved closer to full-height fighter")
    _check(game.projectile_pool != null, "projectile pool created")
    if game.projectile_pool != null:
        _check(game.projectile_pool.total_count() == 20, "20 projectiles preallocated")
    _check(game.audio_manager != null, "audio manager created")
    if game.audio_manager != null:
        _check(game.audio_manager.streams.size() >= 6, "procedural combat SFX loaded")
    _check(game.hud.menu_ui.visible, "character select visible on boot")
    _check(is_instance_valid(game.hud.preview_fighter), "3D character preview created")
    _check(game.hud.preview_platform_root != null, "preview platform created")
    _check(game.hud.skill_buttons.size() == 4, "four mobile skill buttons created")
    _check(game.hud.ultimate_button != null, "ultimate mobile button created")
    _check(game.hud.damage_overlay_material != null, "combined HUD feedback material created")
    if game.hud.damage_overlay_material != null:
        game.hud.damage_overlay_material.set_shader_parameter("speed_lines", 0.5)
        _check(absf(float(game.hud.damage_overlay_material.get_shader_parameter("speed_lines")) - 0.5) < 0.01, "speed-line shader parameter available")
        game.hud.damage_overlay_material.set_shader_parameter("speed_lines", 0.0)
    _check(game.hud.heavy_button != null and game.hud.dodge_button != null and game.hud.dash_button != null, "combat state mobile buttons created")
    _check(game.hud.block_button != null and game.hud.lock_button != null, "block and lock mobile buttons created")
    if is_instance_valid(game.hud.preview_fighter):
        _check(game.hud.preview_fighter.animation_player != null, "3D preview uses rigged animated model")

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
        _check(game.hud.round_active, "round timer active after FIGHT gate")
        _check(not game.hud.menu_ui.visible and game.hud.game_ui.visible, "battle HUD active")
        _check(game.player.variant == variant, "selected player data propagated")
        print("ADULT_DIAGNOSTIC variant=",variant," active=",game.player.adult_rig," verified=",game.player.adult_animation_verified," reason=",game.player.adult_failure_reason," matched=",game.player.adult_track_matched,"/",game.player.adult_track_checked)
        _check(game.player.adult_rig, "adult-proportion Quaternius rig active for variant %d" % variant)
        _check(game.player.adult_animation_verified, "adult animation library drives skeleton for variant %d" % variant)
        _check(game.player.animation_player != null and game.player.animation_player.has_animation("Idle_Loop"), "adult Idle_Loop available")
        _check(game.player.animation_player.has_animation("Sword_Attack"), "adult Sword_Attack available")
        _check(game.enemy.variant == enemy_variant, "selected enemy data propagated")
        _check(game.player.weapon_attachment_count >= 1, "fighter %d has bone-attached weapon asset" % variant)
        _audit_animations(game.player, "fighter_%d" % variant)
        var projectile = game.projectile_pool.spawn_projectile(game.player, game.enemy, game.player.fighter_color, 100.0, variant, Vector3(0.0,18.0,0.0))
        _check(projectile.style == variant, "pooled projectile style propagated for variant %d" % variant)
        _check(projectile.trail_segments.size() == 3, "pooled projectile trail built for variant %d" % variant)
        _check(projectile.quality_level == 1, "MEDIUM pooled projectile quality profile active")
        _check(projectile.glow_light != null and projectile.glow_light.visible, "MEDIUM pooled projectile glow enabled")
        _check(game.projectile_pool.active_count() >= 1, "projectile pool activates projectile")
        projectile._recycle()
        await process_frame
        _check(game.projectile_pool.active_count() == 0, "projectile returns to pool")
        if variant == 0:
            _check(_print_skeleton_bones(game.player), "imported humanoid skeleton found")
            _check(game.player.head_bone >= 0, "head bone resolved for combat look-at")
            _check(game.player.chest_bone >= 0, "chest bone resolved for combat look-at")
            _check(game.player.hand_bone >= 0, "right hand slot resolved for combat VFX")
            _check(game.player.left_foot_bone >= 0 and game.player.right_foot_bone >= 0, "left/right foot bones resolved")
            _check(game.player.left_foot_ik != null and game.player.right_foot_ik != null, "foot IK chains created")
            _check(game.player.left_foot_target != null and game.player.right_foot_target != null, "foot IK targets created")
            _check(game.player.ground_shadow != null, "ground contact shadow created")
            _check(game.player.visual_quality == 1, "fighter visual quality synced to MEDIUM")

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

        game.enemy.health = game.enemy.max_health
        game.enemy.receive_hit(game.player, {
            "damage": 155.0,
            "hitstun": 0.5,
            "knockback": 16.0,
            "launch": 4.5,
            "block_damage": 40.0,
            "anim_kind": "heavy"
        })
        await physics_frame
        _check(game.enemy.knockdown_timer > 0.0, "heavy reaction enters knockdown")
        _check(game.enemy.state == game.enemy.State.STUNNED, "knockdown locks normal control")
        for _knockdown_frame in range(95):
            await physics_frame
        _check(game.enemy.knockdown_timer <= 0.0, "knockdown recovers into get-up flow")

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
        _check(game.player.victory_pose, "winner enters victory pose")

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
