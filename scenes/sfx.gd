class_name Sfx
extends Node
## Plays the bundled generated WAVs (res://audio, made by tools/gen_sfx.gd).

static var _inst: Sfx
var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var next: int = 0


static func ensure(parent: Node) -> void:
	if _inst != null and is_instance_valid(_inst):
		return
	_inst = Sfx.new()
	parent.add_child(_inst)


static func play(name: String, pitch: float = 1.0) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	_inst._play(name, pitch)


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	for name in Data.load_json("sfx"):
		var path := "res://audio/%s.wav" % name
		if ResourceLoader.exists(path):
			streams[name] = load(path)


func _play(name: String, pitch: float) -> void:
	if not streams.has(name):
		return
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = streams[name]
	p.pitch_scale = pitch
	p.play()
