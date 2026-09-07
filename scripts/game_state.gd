class_name WardState
extends RefCounted

const VERSION = 1
var stage: int = 0
var health: float = 100.0
var magazine: int = 6
var inventory: Array = [{"kind":"ammo","amount":6},{"kind":"med","amount":1}]
var keys: Array = []
var notes: Array = []
var collected: Array = []
var dead_enemies: Array = []
var doors: Dictionary = {}
var breakers: Array = [false, false, false, false]
var specimens: Array = ["09", "09", "09"]
var seconds: float = 0
var shots: int = 0
var position: Vector3 = Vector3(0,0.1,10.5)
var yaw: float = 0

func reserve() -> int:
	var count := 0
	for item in inventory:
		if item.kind == "ammo": count += int(item.amount)
	return count

func add_supply(kind: String, amount: int) -> bool:
	var cap := 12 if kind == "ammo" else 1
	var free := (6 - inventory.size()) * cap
	for item in inventory:
		if item.kind == kind: free += cap - int(item.amount)
	if free < amount: return false
	for item in inventory:
		if item.kind != kind: continue
		var count := mini(cap - int(item.amount), amount)
		item.amount += count
		amount -= count
	while amount > 0:
		var count := mini(cap,amount)
		inventory.append({"kind":kind,"amount":count})
		amount -= count
	return true

func reload() -> int:
	var needed := mini(8-magazine, reserve())
	var total := needed
	for i in range(inventory.size()-1,-1,-1):
		if inventory[i].kind != "ammo": continue
		var take := mini(int(inventory[i].amount),needed)
		inventory[i].amount -= take
		needed -= take
		if inventory[i].amount == 0: inventory.remove_at(i)
	magazine += total
	return total

func heal(slot: int) -> bool:
	if slot < 0 or slot >= inventory.size() or inventory[slot].kind != "med" or health >= 100: return false
	inventory.remove_at(slot)
	health = minf(100,health+55)
	return true

func solve_power() -> bool:
	if stage != 0 or breakers != [true,false,true,true]: return false
	stage = 1
	return true

func solve_cabinet(code: String) -> bool:
	if stage != 1 or code != "417": return false
	stage = 2
	if not keys.has("cold_key"): keys.append("cold_key")
	return true

func solve_specimens() -> bool:
	if stage != 2 or specimens != ["14","09","23"]: return false
	stage = 3
	if not keys.has("lab_card"): keys.append("lab_card")
	return true

func terminate() -> bool:
	if stage != 3: return false
	stage = 4
	if not keys.has("evidence"): keys.append("evidence")
	return true

func serialize() -> Dictionary:
	return {"version":VERSION,"stage":stage,"health":health,"magazine":magazine,"inventory":inventory.duplicate(true),"keys":keys.duplicate(),"notes":notes.duplicate(),"collected":collected.duplicate(),"dead_enemies":dead_enemies.duplicate(),"doors":doors.duplicate(),"breakers":breakers.duplicate(),"specimens":specimens.duplicate(),"seconds":seconds,"shots":shots,"position":[position.x,position.y,position.z],"yaw":yaw}

static func deserialize(data: Variant) -> WardState:
	if not data is Dictionary or data.get("version",0) != VERSION: return null
	for field in ["stage","health","magazine","seconds","shots","yaw"]:
		if not data.get(field) is float and not data.get(field) is int: return null
	for field in ["inventory","keys","notes","collected","dead_enemies","breakers","specimens","position"]:
		if not data.get(field) is Array: return null
	if not data.get("doors") is Dictionary: return null
	if data.inventory.size()>6 or data.position.size()!=3 or data.breakers.size()!=4 or data.specimens.size()!=3: return null
	for n in data.position:
		if (not n is float and not n is int) or not is_finite(n): return null
	for item in data.inventory:
		if not item is Dictionary or not item.get("kind","") in ["ammo","med"]: return null
		if not item.get("amount") is float and not item.get("amount") is int: return null
		if item.amount < 1 or item.amount > (12 if item.kind=="ammo" else 1): return null
	var s := WardState.new()
	s.stage = clampi(int(data.stage),0,4)
	s.health = clampf(float(data.health),1,100)
	s.magazine = clampi(int(data.magazine),0,8)
	s.inventory = data.inventory.duplicate(true)
	s.keys = data.keys.duplicate()
	s.notes = data.notes.filter(func(v): return v is String and WardContent.NOTES.has(v))
	s.collected = data.collected.duplicate()
	s.dead_enemies = data.dead_enemies.duplicate()
	s.doors = data.doors.duplicate()
	s.breakers = data.breakers.duplicate()
	s.specimens = data.specimens.duplicate()
	s.seconds = maxf(0,data.seconds)
	s.shots = maxi(0,int(data.shots))
	s.position = Vector3(data.position[0],data.position[1],data.position[2])
	s.yaw = float(data.yaw)
	return s
