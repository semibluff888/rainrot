class_name WardInteractable
extends StaticBody3D

@export var item_id: String = ""
@export var kind: String = "note"
@export var title: String = ""
@export var note_id: String = ""
@export var requirement: String = ""
@export var amount: int = 1
var game: Node
var opened := false
var busy := false
var motion: Tween
var closed_rotation := 0.0

func _ready() -> void:
	add_to_group("interactables")
	closed_rotation = rotation.y

func prompt() -> String:
	if kind == "door":
		if not allowed(): return title + " · " + {"power":"需要恢复供电","cold_key":"需要冷库钥匙","lab_card":"需要地下通行卡","escape":"隔离中：从地下解除封锁"}.get(requirement,"已上锁")
		return ("关闭 · " if opened else "打开 · ") + title
	return {"note":"阅读 · ","ammo":"拾取 · ","med":"拾取 · ","save":"记录进度 · ","power":"操作 · ","cabinet":"检查 · ","specimen":"归档 · ","terminal":"操作 · ","exit":"离开 · "}.get(kind,"检查 · ") + title

func allowed() -> bool:
	if not is_instance_valid(game): return false
	match requirement:
		"power": return game.state.stage >= 1
		"cold_key": return game.state.keys.has("cold_key")
		"lab_card": return game.state.keys.has("lab_card")
		"escape": return game.state.stage == 4
	return true

func sync() -> void:
	if motion and motion.is_valid(): motion.kill()
	busy=false
	if game.state.collected.has(item_id):
		visible = false
		collision_layer = 0
	if kind == "door":
		opened = game.state.doors.get(item_id,false)
		rotation.y = closed_rotation + (deg_to_rad(95) if opened else 0.0)

func interact() -> void:
	if busy or not is_instance_valid(game): return
	if game.state.collected.has(item_id): return
	if not allowed():
		game.hud.toast(prompt())
		game.audio.one("click",-9,.7)
		return
	match kind:
		"door":
			# Opening away from the doorway leaves a generous, navigable clear width.
			opened = not opened
			game.state.doors[item_id] = opened
			if item_id=="cold_door" and opened and not game.state.collected.has("cold_event"):
				game.state.collected.append("cold_event")
				game.audio.one("sting",-13,.6)
				game.hud.toast("冷气涌了出来。身后的灯一盏接一盏熄灭。",6)
				for e in game.enemies: e.sync()
			busy = true
			motion = create_tween()
			motion.tween_property(self,"rotation:y",closed_rotation + (deg_to_rad(95) if opened else 0.0),.72).set_trans(Tween.TRANS_SINE)
			motion.tween_callback(func(): busy = false)
			game.audio.one("door",-14,randf_range(.85,1.05),global_position)
		"note": game.read_note(note_id)
		"ammo", "med":
			if game.state.add_supply(kind,amount):
				game.state.collected.append(item_id)
				visible = false
				collision_layer = 0
				game.audio.one("pickup",-14)
				game.hud.toast(title + " 已放入背包")
			else: game.hud.toast("背包已满 · 使用补给或换弹后再拾取")
		"save":
			game.save_game()
			game.hud.toast("已记录 · 这里暂时是安全的")
		"exit":
			if game.state.stage == 4: game.finish()
			else: game.hud.toast("隔离锁仍在工作 · 需要从地下解除封锁")
		_: game.hud.show_puzzle(kind)
