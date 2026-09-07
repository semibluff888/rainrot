class_name WardAudio
extends Node

var loops: Dictionary = {}
var streams: Dictionary = {}
var game: Node
var thunder_timer := 19.0

func _exit_tree() -> void:
	# Explicitly release live WAV playback before the audio server shuts down.
	for voice in get_children():
		if voice is AudioStreamPlayer or voice is AudioStreamPlayer3D:
			voice.stop()
			voice.stream = null
	loops.clear()
	streams.clear()

func _ready() -> void:
	for file in ["rain","roomtone","safe","threat","step0","step1","step2","step3","shot","hit","click","pickup","door","breath","sting","thunder","alarm", "smily_breath", "smily_step", "smily_alert", "smily_strike", "nurse_breath", "nurse_step", "nurse_joint", "nurse_stab"]:
		var stream := load("res://assets/audio/"+file+".wav") as AudioStreamWAV
		if file in ["rain","roomtone","safe","threat","alarm"]:
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length()*stream.mix_rate)
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.volume_db = -50
			add_child(p)
			p.play()
			loops[file] = p
		streams[file] = stream

func one(name_: String, db: float=-8, pitch: float=1.0, where: Variant=null, enemy_voice: bool=false) -> void:
	if not streams.has(name_): return
	if where is Vector3:
		var p := AudioStreamPlayer3D.new()
		p.stream = streams[name_]
		p.volume_db = db
		p.pitch_scale = pitch
		p.unit_size = 5
		p.max_distance = 32
		add_child(p)
		p.global_position = where
		p.finished.connect(p.queue_free)
		if enemy_voice: p.add_to_group("enemy_audio")
		p.play()
	else:
		var p := AudioStreamPlayer.new()
		p.stream = streams[name_]
		p.volume_db = db
		p.pitch_scale = pitch
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	for voice in get_tree().get_nodes_in_group("enemy_audio"):
		voice.stream_paused = not game.started or game.finished or game.hud.modal != "" or game.web.input_suspended()
	var safe: bool = game.is_safe()
	var danger: float = game.danger
	var target := {"rain":-18.0,"roomtone":-23.0,"safe":-19.0 if safe or not game.started else -65.0,"threat":lerpf(-65,-13,danger),"alarm":-33.0 if game.state.stage==4 else -65.0}
	for key in loops: loops[key].volume_db = lerpf(loops[key].volume_db,target[key],delta*1.7)
	thunder_timer -= delta
	if thunder_timer < 0:
		thunder_timer = randf_range(23,45)
		one("thunder",-20)
		game.lightning = 1.0
