extends SceneTree
## Generates the bundled sfxr-style WAVs in res://audio from data/sfx.json.
## godot --headless -s tools/gen_sfx.gd

const RATE := 22050


func _init() -> void:
	var defs: Dictionary = Data.load_json("sfx")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio"))
	for name in defs:
		var wav := synth(defs[name], hash(name))
		var path := "res://audio/%s.wav" % name
		wav.save_to_wav(path)
		print("wrote ", path)
	quit()


static func synth(d: Dictionary, seed_value: int) -> AudioStreamWAV:
	var rng := SeededRng.new(seed_value)
	var dur := float(d.get("dur", 0.2))
	var n := int(dur * RATE)
	var f0 := float(d.get("freq", 440.0))
	var f1 := float(d.get("freq_end", f0))
	var wave := String(d.get("wave", "square"))
	var attack := float(d.get("attack", 0.005))
	var vol := float(d.get("vol", 0.5))
	var vib := float(d.get("vibrato", 0.0))
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var noise := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		var f := lerpf(f0, f1, k) * (1.0 + vib * sin(t * 40.0))
		phase += f / RATE
		var ph := fmod(phase, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if ph < 0.5 else -1.0
			"saw":
				s = ph * 2.0 - 1.0
			"sine":
				s = sin(ph * TAU)
			"noise":
				if ph < f / RATE * 2.0 or i % maxi(1, int(RATE / maxf(f, 1.0))) == 0:
					noise = rng.randf() * 2.0 - 1.0
				s = noise
		var env := minf(1.0, t / maxf(attack, 0.0001)) * pow(1.0 - k, 2.0)
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
