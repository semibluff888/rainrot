extends Node

# Wall-clock render samples, independent of simulation delta and fixed-fps QA.
const SHOTS = [
	["corridor_smily", Vector3(0,.05,-8), 1, 0, Vector3(0,.05,-12)],
	["morgue_nurse", Vector3(-4.5,.05,-35.2), 2, 1, Vector3(-5.5,.05,-31.7)],
	["laboratory_nurse", Vector3(9,-3.1,-20), 4, 3, Vector3(9,-3.1,-24)],
	["pursuit_nurse", Vector3(17.5,.05,-13), 4, 3, Vector3(17.5,.05,-17)],
]
var game: Node
var seconds := 30.0
var repeats := 3
var quality := 1
var results: Array = []

func option(name_: String, fallback: float) -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name_+"="):
			var value: String = arg.get_slice("=",1)
			if value.is_valid_float(): return float(value)
	return fallback

func sample(duration: float, collect: bool) -> Dictionary:
	var times: Array[float] = []
	var draws: Array[int] = []
	await RenderingServer.frame_post_draw
	var previous := Time.get_ticks_usec()
	var start := previous
	while (Time.get_ticks_usec()-start)/1000000.0 < duration:
		game.state.health=100
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if collect:
			times.append((now-previous)/1000.0)
			draws.append(game.get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		previous=now
	if not collect:return {}
	times.sort();draws.sort()
	var over_50 := 0
	var total := 0.0
	for ms in times:
		total+=ms
		if ms>50:over_50+=1
	return {"frames":times.size(),"elapsed_seconds":(previous-start)/1000000.0,"median_ms":times[times.size()/2],"p95_ms":times[ceili(times.size()*.95)-1],"over_50ms":over_50,"average_ms":total/times.size(),"draw_calls_median":draws[draws.size()/2]}

func run(g: Node) -> void:
	game=g
	seconds=clampf(option("--benchmark-seconds",30),1,120)
	repeats=clampi(int(option("--benchmark-repeats",3)),1,5)
	quality=clampi(int(option("--benchmark-quality",1)),0,2)
	game.settings.quality=quality
	if not OS.has_feature("web"):
		DisplayServer.window_set_size(Vector2i(1920,1080))
	# Keep VSync unchanged: measure the shipped presentation loop.
	for repeat in repeats:
		for shot in SHOTS:
			seed(90409)
			game.start_new()
			game.state.stage=shot[2]
			game.state.collected.append("cold_event")
			game.player.position=shot[1]
			game.player.enabled=false
			for e in game.enemies:
				e.sync();e.set_physics_process(false);e.visible=false
			var featured: WardEnemy=game.enemies[shot[3]]
			featured.position=shot[4];featured.rotation.y=PI
			featured.visible=true;featured.is_active=true;featured.mode=WardEnemy.Mode.CHASE
			featured.set_physics_process(true)
			var direction: Vector3=(featured.get_aim_point("body")-game.player.camera.global_position).normalized()
			game.player.rotation.y=atan2(-direction.x,-direction.z)
			game.player.pitch=asin(direction.y);game.player.head.rotation.x=game.player.pitch
			game.apply_settings()
			game.web.report("benchmark_progress",{"scene":shot[0],"repeat":repeat+1,"phase":"warmup"})
			await sample(5,false)
			game.web.report("benchmark_progress",{"scene":shot[0],"repeat":repeat+1,"phase":"sampling"})
			var result := await sample(seconds,true)
			result.merge({"scene":shot[0],"repeat":repeat+1,"quality":quality,"viewport_size":[game.get_viewport().get_visible_rect().size.x,game.get_viewport().get_visible_rect().size.y],"scaling_3d":game.get_viewport().scaling_3d_scale})
			results.append(result)
			game.web.report("benchmark_progress",result)
			print("WEB_BENCHMARK_SAMPLE ",JSON.stringify(result))
	var report := {"passed":true,"renderer":RenderingServer.get_video_adapter_name(),"runtime":"browser" if OS.has_feature("web") else "native_compatibility","sample_seconds":seconds,"warmup_seconds":5,"repeats":repeats,"quality":quality,"results":results}
	var file := FileAccess.open("user://web_benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	game.web.report("benchmark",report)
	print("WEB_BENCHMARK_COMPLETE")
	get_tree().quit()
