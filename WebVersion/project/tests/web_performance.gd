extends Node

var game: Node
var checks: Array = []
func check(ok: bool, label_: String) -> void:
	checks.append({"passed":ok,"name":label_})
	if not ok:push_error("WEB_PERFORMANCE_FAIL "+label_)

func shadow_count() -> int:
	var count:=0
	for light in game.hospital.find_children("*","Light3D",true,false):
		if light.shadow_enabled:count+=1
	if game.player.torch.shadow_enabled:count+=1
	return count

func run(g: Node) -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Web performance controls require an actual renderer; run Test_Web.ps1 -Rendered")
		get_tree().quit(1)
		return
	game=g;game.start_new()
	var web: WardWebPlatform=game.web
	web.set_process(false)
	for q in [0,1,2,0,2,1]:
		game.settings.quality=q;game.apply_settings()
		check(shadow_count()==[0,3,4][q],"Quality "+str(q)+" bounds all scene and torch shadows")
		check(game.player.torch.shadow_enabled==(q>0),"Torch shadow follows quality "+str(q))
		check(is_equal_approx(game.get_viewport().scaling_3d_scale,[.65,.82,1.0][q]),"3D scale retained "+str(q))
	var original_spots:=web.shadow_spots.duplicate()
	var a:=SpotLight3D.new();var b:=SpotLight3D.new()
	game.add_child(a);game.add_child(b)
	a.position=Vector3(0,1,0);b.position=Vector3(10,1,0)
	web.shadow_spots.assign([a,b])
	game.player.position=Vector3(4,1,0);web.update_shadow_lights(true)
	check(web.selected_spots==[a],"Nearest spotlight selected initially")
	game.player.position=Vector3(5.5,1,0);web.update_shadow_lights()
	check(web.selected_spots==[a],"One metre improvement does not switch shadows")
	game.player.position=Vector3(6.1,1,0);web.update_shadow_lights()
	check(web.selected_spots==[b],"More than two metres improvement switches shadows")
	game.player.position=Vector3(4.8,1,0);web.update_shadow_lights()
	check(web.selected_spots==[b],"Returning near midpoint does not flicker")
	web.shadow_spots.assign(original_spots);web.selected_spots.clear()
	a.free();b.free();web.update_shadow_lights(true)
	game.player.position=Vector3(0,.1,11)
	web.dust_time=0;web.dust_timer=0;web.update_dust()
	var before:=web.dust.multimesh.get_instance_transform(0)
	web._process(.02)
	check(web.dust.multimesh.get_instance_transform(0)==before,"Dust does not upload every frame")
	web._process(.03)
	check(web.dust.multimesh.get_instance_transform(0)!=before,"Dust updates at 50 ms")
	check(is_equal_approx(web.dust_time,.05),"Dust movement keeps accumulated time")
	game.hud.show_pause()
	before=web.dust.multimesh.get_instance_transform(0)
	var time_before:=web.dust_time
	web._process(.5)
	check(web.dust.multimesh.get_instance_transform(0)==before and web.dust_time==time_before,"Pause freezes dust")
	game.hud.close();web._browser_event(["hidden"]);web._process(.5)
	check(web.dust_time==time_before,"Background freezes dust")
	web._browser_event(["visible"]);web._process(.05)
	check(web.dust_time>time_before,"Returning to visible page restores effects")
	web.diagnostic=false;web.telemetry_timer=0;web._process(2)
	check(web.telemetry_timer==0,"Normal play does not sample diagnostics")

	# The bridge must never unpause before a confirmed pointer lock.
	game.hud.show_pause();web.pointer_locked=false;web.page_visible=true
	web._browser_event(["resume"])
	check(game.hud.modal=="pause","Resume without confirmed lock keeps pause")
	web._browser_event(["lock"]);web._browser_event(["resume"])
	check(game.hud.modal=="","Confirmed lock then resume closes pause once")
	game.hud.show_pause();web.pointer_locked=true;web.page_visible=false
	web._browser_event(["resume"])
	check(game.hud.modal=="pause","Background cannot resume despite stale lock")
	web.page_visible=true;game.hud.show_inventory();web._browser_event(["resume"])
	check(game.hud.modal=="inventory","Late resume does not close another menu")
	game.hud.close()
	var cycles_ok:=true
	for cycle in 20:
		game.hud.show_pause();web._browser_event(["unlock"]);web._browser_event(["resume"])
		cycles_ok=cycles_ok and game.hud.modal=="pause"
		web._browser_event(["lock"]);web._browser_event(["resume"])
		cycles_ok=cycles_ok and game.hud.modal==""
	check(cycles_ok,"Twenty pause cycles each resume after exactly one confirmed lock")

	var failed:=checks.filter(func(c):return not c.passed).size()
	var result: Dictionary={"passed":checks.size()-failed,"failed":failed,"checks":checks}
	var f:=FileAccess.open("user://web_performance_test.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"));f.close()
	game.web.report("performance",result)
	print("WEB_PERFORMANCE_RESULT ",JSON.stringify(result))
	get_tree().quit(0 if failed==0 else 1)
