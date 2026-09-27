extends Node3D

const ProjectileScript = preload("res://scripts/projectile.gd")
const STYLES: int = 4
const PER_STYLE: int = 5

var pools: Array[Array] = []
var cursors: Array[int] = [0,0,0,0]
var quality_level: int = 1

func _ready() -> void:
    var quality_root: Node = get_tree().current_scene
    if quality_root == null:
        quality_root = get_parent()
    var quality_manager = quality_root.get_node_or_null("QualityManager") if quality_root != null else null
    if quality_manager != null:
        quality_level = int(quality_manager.current_level)
    for style in range(STYLES):
        var style_pool: Array = []
        for i in range(PER_STYLE):
            var projectile = ProjectileScript.new()
            projectile.name = "Projectile_%d_%02d" % [style,i]
            projectile.pooled = true
            projectile.style = style
            projectile.quality_level = quality_level
            projectile.configure(null,null,Color.WHITE,0.0,style)
            add_child(projectile)
            style_pool.append(projectile)
        pools.append(style_pool)

func spawn_projectile(source, target, color: Color, damage: float, style: int, position: Vector3):
    var style_index: int = clampi(style,0,STYLES-1)
    var style_pool: Array = pools[style_index]
    var selected = null
    for offset in range(style_pool.size()):
        var index: int = (cursors[style_index] + offset) % style_pool.size()
        if not style_pool[index].active:
            selected = style_pool[index]
            cursors[style_index] = (index + 1) % style_pool.size()
            break
    if selected == null:
        selected = style_pool[cursors[style_index]]
        cursors[style_index] = (cursors[style_index] + 1) % style_pool.size()
        selected.deactivate()
    selected.activate(source,target,color,damage,position)
    return selected

func set_quality(level: int) -> void:
    quality_level = clampi(level,0,2)
    for style_pool in pools:
        for projectile in style_pool:
            projectile.set_quality(quality_level)

func deactivate_all() -> void:
    for style_pool in pools:
        for projectile in style_pool:
            if projectile.active:
                projectile.deactivate()

func total_count() -> int:
    return STYLES * PER_STYLE

func active_count() -> int:
    var count: int = 0
    for style_pool in pools:
        for projectile in style_pool:
            if projectile.active:
                count += 1
    return count
