extends Node3D

const POOL_SIZE: int = 10
const CUE_PATHS := {
    "swing": "res://assets/generated_sfx/swing.wav",
    "impact": "res://assets/generated_sfx/impact.wav",
    "dash": "res://assets/generated_sfx/dash.wav",
    "energy": "res://assets/generated_sfx/energy.wav",
    "parry": "res://assets/generated_sfx/parry.wav",
    "ultimate": "res://assets/generated_sfx/ultimate.wav"
}

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer3D] = []
var cursor: int = 0

func _ready() -> void:
    for cue in CUE_PATHS.keys():
        var path: String = CUE_PATHS[cue]
        if ResourceLoader.exists(path):
            streams[cue] = load(path)

    for i in range(POOL_SIZE):
        var player := AudioStreamPlayer3D.new()
        player.name = "SFX_%02d" % i
        player.max_distance = 42.0
        player.unit_size = 5.0
        add_child(player)
        players.append(player)

func play_sfx(cue: String, position: Vector3) -> void:
    if not streams.has(cue) or players.is_empty():
        return
    var player := _next_player()
    player.stop()
    player.stream = streams[cue]
    player.global_position = position
    player.volume_db = _volume_for(cue)
    player.pitch_scale = _pitch_for(cue)
    player.play()

func _next_player() -> AudioStreamPlayer3D:
    for offset in range(players.size()):
        var index: int = (cursor + offset) % players.size()
        if not players[index].playing:
            cursor = (index + 1) % players.size()
            return players[index]
    var fallback := players[cursor]
    cursor = (cursor + 1) % players.size()
    return fallback

func _volume_for(cue: String) -> float:
    match cue:
        "impact": return -2.0
        "ultimate": return -1.0
        "parry": return -2.5
        "energy": return -4.0
        "dash": return -6.0
        _: return -5.0

func _pitch_for(cue: String) -> float:
    match cue:
        "impact": return 0.96
        "ultimate": return 0.92
        "parry": return 1.04
        "energy": return 1.02
        "dash": return 1.04
        _: return 1.0
