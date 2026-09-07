extends SceneTree

const G = preload("res://tools/geometry.gd")
const INTERACT = preload("res://scripts/interactable.gd")
var world: Node3D
var mats: Dictionary = {}
var rng := RandomNumberGenerator.new()
var font: Font

func _initialize() -> void:
	call_deferred("build")

func pbr(id: String, color: Color, scale_: float=.5, rough: float=1.0) -> StandardMaterial3D:
	var m := G.material(color,rough)
	m.albedo_texture = load("res://assets/textures/"+id+"/diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/"+id+"/normal.jpg")
	m.normal_scale = .7
	m.roughness_texture = load("res://assets/textures/"+id+"/rough.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*scale_
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func make_materials() -> void:
	mats.wall = pbr("damaged_plaster",Color(.67,.7,.64),.55)
	mats.blue = pbr("blue_plaster_weathered",Color(.43,.57,.51),.65)
	mats.floor = pbr("concrete_floor_worn_001",Color(.56,.6,.58),.48,.72)
	mats.tile = pbr("brown_floor_tiles",Color(.51,.57,.53),.42,.6)
	mats.rust = pbr("rusty_metal_sheet",Color(.5,.46,.38),1.2)
	mats.wood = pbr("dark_wood",Color(.55,.5,.42),1)
	mats.metal = G.material(Color(.14,.2,.2),.5,.7)
	mats.dark = G.material(Color(.024,.035,.037),.6,.3)
	mats.chrome = G.material(Color(.4,.48,.46),.27,.8)
	mats.paper = G.material(Color(.67,.64,.49),.95)
	mats.linen = pbr("damaged_plaster",Color(.48,.49,.39),2)
	mats.red = G.material(Color(.23,.032,.016),.4)
	mats.copper = G.material(Color(.27,.17,.075),.57,.75)
	mats.light = G.material(Color(.65,.64,.43),.5)
	mats.light.emission_enabled = true
	mats.light.emission = Color(1,.68,.3)
	mats.light.emission_energy_multiplier = 3
	mats.exit = G.material(Color(.06,.25,.18),.7)
	mats.exit.emission_enabled = true
	mats.exit.emission = Color(.2,1,.63)
	mats.exit.emission_energy_multiplier = .9
	mats.glass = G.material(Color(.04,.16,.19,.35),.16,.25)
	mats.glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats.water = ShaderMaterial.new()
	mats.water.shader = load("res://shaders/water.gdshader")
	for key in mats:
		ResourceSaver.save(mats[key],"res://materials/"+key+".tres")

func floor_(center: Vector3, size_: Vector2, tiled: bool=false) -> void:
	G.box(world,center-Vector3(0,.13,0),Vector3(size_.x,.26,size_.y),mats.tile if tiled else mats.floor,true)
	G.box(world,center+Vector3(0,3.45,0),Vector3(size_.x,.16,size_.y),mats.wall)

func wall_piece(a: Vector3, b: Vector3, height: float=3.4) -> void:
	var length_ := Vector2(a.x-b.x,a.z-b.z).length()
	if length_ < .01: return
	var group := Node3D.new()
	group.position = (a+b)*.5
	group.rotation.y = -atan2(b.z-a.z,b.x-a.x)
	world.add_child(group)
	G.box(group,Vector3(0,.62,0),Vector3(length_,1.24,.28),mats.blue,true)
	G.box(group,Vector3(0,(height+1.24)*.5,0),Vector3(length_,height-1.24,.28),mats.wall,true)
	G.box(group,Vector3(0,.13,0),Vector3(length_,.2,.35),mats.dark)
	G.box(group,Vector3(0,1.24,0),Vector3(length_,.07,.35),mats.metal)
	G.box(group,Vector3(0,height-.12,0),Vector3(length_,.16,.38),mats.wall)
	if length_ > 1:
		var oc := OccluderInstance3D.new()
		var quad := QuadOccluder3D.new()
		quad.size = Vector2(length_-.12,height-.12)
		oc.occluder = quad
		oc.position.y = height*.5
		group.add_child(oc)

func wall_z(x: float, start: float, end: float, gaps: Array=[], y: float=0.0) -> void:
	var cursor := start
	for gap in gaps:
		wall_piece(Vector3(x,y,cursor),Vector3(x,y,gap.x))
		var l: float = gap.y-gap.x
		G.box(world,Vector3(x,y+3.02,(gap.x+gap.y)*.5),Vector3(.3,.78,l),mats.wall,true)
		cursor = gap.y
	wall_piece(Vector3(x,y,cursor),Vector3(x,y,end))

func interact(kind_: String, id_: String, title_: String, pos: Vector3, size_: Vector3, note: String="") -> StaticBody3D:
	var n := StaticBody3D.new()
	n.set_script(INTERACT)
	n.name = id_
	n.set("kind",kind_)
	n.set("item_id",id_)
	n.set("title",title_)
	n.set("note_id",note)
	n.position = pos
	n.collision_layer = 16
	n.collision_mask = 0
	world.add_child(n)
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_
	c.shape = shape
	n.add_child(c)
	return n

func door(id_: String, title_: String, x: float, z: float, req: String="", y: float=0.0) -> void:
	for side in [-1,1]: G.box(world,Vector3(x,y+1.4,z+side*1.02),Vector3(.42,2.8,.12),mats.metal)
	G.box(world,Vector3(x,y+2.75,z),Vector3(.42,.12,2.15),mats.metal)
	var n := interact("door",id_,title_,Vector3(x,y,z+.93),Vector3(1.86,2.62,.13))
	n.rotation.y = PI*.5
	n.collision_layer = 20
	n.get_child(0).position = Vector3(.93,1.31,0)
	n.set("requirement",req)
	G.box(n,Vector3(.93,1.31,0),Vector3(1.86,2.62,.12),mats.blue)
	for sign_ in [-1,1]:
		G.box(n,Vector3(.93,1.94,.075*sign_),Vector3(.55,.55,.035),mats.dark)
		G.box(n,Vector3(.93,1.94,.1*sign_),Vector3(.4,.4,.02),mats.glass)
		G.box(n,Vector3(1.62,1.13,.09*sign_),Vector3(.09,.3,.04),mats.chrome)
		G.rod(n,Vector3(1.4,1.16,.16*sign_),Vector3(1.66,1.16,.16*sign_),.023,mats.chrome)
		G.box(n,Vector3(.93,.28,.076*sign_),Vector3(1.67,.42,.025),mats.rust)
	G.label(world,title_,Vector3(x+.23,y+2.96,z),34,.007,Color(.66,.74,.69),PI*.5)

func table(pos: Vector3, size_: Vector2=Vector2(2,1), metal: bool=false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	world.add_child(n)
	G.box(n,Vector3(0,.86,0),Vector3(size_.x,.13,size_.y),mats.chrome if metal else mats.wood,true)
	for x in [-1,1]:
		for z in [-1,1]: G.box(n,Vector3(x*(size_.x*.5-.13),.42,z*(size_.y*.5-.13)),Vector3(.07,.84,.07),mats.metal)
	return n

func model(id_: String, pos: Vector3, yaw_: float=0, scale_: float=1.0) -> Node3D:
	var file := "res://assets/models/"+id_+"/"+id_+".gltf"
	if not ResourceLoader.exists(file): return null
	var n: Node3D = load(file).instantiate()
	n.position = pos
	n.rotation.y = yaw_
	n.scale = Vector3.ONE*scale_
	world.add_child(n)
	return n

func note(id_: String, pos: Vector3, rot: float=0) -> void:
	var n := interact("note","note_"+id_,WardContent.NOTES[id_].title,pos,Vector3(.55,.2,.42),id_)
	n.rotation.y = rot
	G.box(n,Vector3.ZERO,Vector3(.3,.012,.4),mats.paper)
	for i in 8:
		G.box(n,Vector3(-.02,.007,-.15+i*.035),Vector3(.2 if i%3 else .14,.001,.003),mats.dark)
	G.cylinder(n,Vector3(.1,.008,.12),.022,.001,mats.red)
	G.label(n,"◇",Vector3(0,.2,0),32,.0028,Color(.64,.78,.7)).billboard = BaseMaterial3D.BILLBOARD_ENABLED

func supply(id_: String, kind: String, pos: Vector3, amount: int=1) -> void:
	var n := interact(kind,id_,"9mm 弹药 × "+str(amount) if kind=="ammo" else "急救敷料",pos,Vector3(.44,.36,.32))
	n.set("amount",amount)
	G.box(n,Vector3.ZERO,Vector3(.26,.15,.18),mats.paper if kind=="med" else mats.metal)
	if kind == "med":
		G.box(n,Vector3(0,.077,0),Vector3(.13,.006,.04),mats.red)
		G.box(n,Vector3(0,.078,0),Vector3(.04,.006,.13),mats.red)
	else:
		for i in 4: G.cylinder(n,Vector3(-.08+i*.05,.09,0),.017,.025,mats.copper)
	G.label(n,"◇",Vector3(0,.22,0),32,.0028,Color(.64,.78,.7)).billboard = BaseMaterial3D.BILLBOARD_ENABLED

func fixture(pos: Vector3, warm: bool=true, powered: bool=false) -> void:
	G.box(world,pos,Vector3(1.4,.11,.24),mats.metal)
	G.box(world,pos-Vector3(0,.065,0),Vector3(1.18,.035,.1),mats.light)
	var light := G.omni(world,pos-Vector3(0,.18,0),Color(1,.67,.35) if warm else Color(.4,.72,.73),2.0 if warm else 1.55,6.5)
	if powered: light.add_to_group("power_lights",true)
	light.set_meta("energy",light.light_energy)
	light.add_to_group("fixtures",true)

func window_(x: float, z: float, facing: float=PI*.5) -> void:
	var n := Node3D.new()
	n.position = Vector3(x,2,z)
	n.rotation.y = facing
	world.add_child(n)
	G.box(n,Vector3.ZERO,Vector3(2.35,2.15,.12),mats.dark)
	var glassmat := ShaderMaterial.new()
	glassmat.shader = load("res://shaders/rain_window.gdshader")
	G.box(n,Vector3(0,0,.08),Vector3(2.13,1.97,.025),glassmat)
	for a in [-1,0,1]: G.box(n,Vector3(a*1.12,0,.13),Vector3(.08,2.12,.1),mats.metal)
	for a in [-1,0,1]: G.box(n,Vector3(0,a*1.02,.13),Vector3(2.3,.07,.1),mats.metal)
	G.box(n,Vector3(0,-1.1,.2),Vector3(2.5,.12,.4),mats.wall)
	for i in 29:
		var stripe := G.box(n,Vector3(rng.randf_range(-1.01,1.01),rng.randf_range(-.9,.9),.097),Vector3(.003,rng.randf_range(.03,.4),.002),mats.glass)
		stripe.rotation.z = -.04
	var toward := Vector3(1,0,0) if facing>0 else Vector3(-1,0,0)
	var l := G.spot(world,Vector3(x,2.8,z)+toward*.4,Vector3(x,0,z)+toward*4,Color(.23,.52,.7),3.8,12,55)
	l.light_volumetric_fog_energy = 1.4
	l.add_to_group("moonlights",true)
	l.set_meta("energy",l.light_energy)

func bed(pos: Vector3, rotation_: float=0, bed_id: String="") -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rotation_
	world.add_child(n)
	var imported := model("old_bed_frame",Vector3.ZERO)
	if imported:
		world.remove_child(imported)
		n.add_child(imported)
		imported.position = Vector3.ZERO
	G.box(n,Vector3(0,.66,0),Vector3(1.03,.18,2.05),mats.linen,true)
	var pillow := G.sphere(n,Vector3(0,.81,-.65),Vector3(.72,.15,.43),mats.linen)
	pillow.rotation.y = .08
	for i in 5:
		G.rod(n,Vector3(-.51,.78,-.15+i*.24),Vector3(.51,.78+.025*sin(i),-.15+i*.24),.019,mats.linen)
	G.box(n,Vector3(0,.785,.34),Vector3(1.05,.014,1.14),mats.blue)
	if bed_id != "":
		G.box(n,Vector3(0,.94,1.08),Vector3(.36,.22,.028),mats.paper)
		G.label(n,bed_id.replace("  /  ","\n"),Vector3(0,.94,1.098),28,.0027,Color(.06,.11,.085))

func iv(pos: Vector3) -> void:
	G.rod(world,pos+Vector3(0,.1,0),pos+Vector3(0,2.2,0),.021,mats.chrome)
	for i in 4:
		var a := i*PI*.5
		var v := Vector3(cos(a)*.35,0,sin(a)*.35)
		G.rod(world,pos+Vector3(0,.16,0),pos+v+Vector3(0,.1,0),.02,mats.chrome)
		G.sphere(world,pos+v+Vector3(0,.06,0),Vector3(.08,.12,.08),mats.dark)
	G.rod(world,pos+Vector3(-.3,2.1,0),pos+Vector3(.3,2.1,0),.019,mats.chrome)
	G.box(world,pos+Vector3(.23,1.86,0),Vector3(.16,.32,.07),mats.glass)
	G.rod(world,pos+Vector3(.23,1.7,0),pos+Vector3(.3,.74,.2),.007,mats.copper)

func cabinet(pos: Vector3, yaw_: float=0, width: float=1.4) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw_
	world.add_child(n)
	G.box(n,Vector3(0,1.05,0),Vector3(width,2.1,.48),mats.metal,true)
	for side in [-1,1]:
		G.box(n,Vector3(side*width*.25,1.12,.251),Vector3(width*.47,1.85,.03),mats.blue)
		G.rod(n,Vector3(side*.065,.95,.29),Vector3(side*.065,1.24,.29),.016,mats.chrome)
		for j in 5: G.box(n,Vector3(side*width*.25,1.78-j*.055,.27),Vector3(width*.34,.012,.005),mats.dark)
	return n

func build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.012,.025,.036)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.3,.48,.52)
	env.ambient_light_energy = .26
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(.012,.025,.04)
	sky_mat.sky_horizon_color = Color(.04,.065,.075)
	sky_mat.ground_bottom_color = Color(.01,.013,.016)
	sky_mat.ground_horizon_color = Color(.04,.065,.075)
	sky.sky_material = sky_mat
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2
	env.ssil_enabled = true
	env.ssil_intensity = .7
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.glow_enabled = true
	env.glow_intensity = .45
	env.glow_bloom = .08
	env.fog_enabled = true
	env.fog_light_color = Color(.045,.085,.10)
	env.fog_light_energy = .6
	env.fog_density = .004
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = .018
	env.volumetric_fog_albedo = Color(.46,.55,.56)
	env.volumetric_fog_length = 45
	env.volumetric_fog_ambient_inject = .35
	var e := WorldEnvironment.new()
	e.name = "Atmosphere"
	e.environment = env
	world.add_child(e)
	ResourceSaver.save(env,"res://materials/atmosphere.tres")
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_color = Color(.28,.43,.61)
	sun.light_energy = .16
	sun.shadow_enabled = true
	world.add_child(sun)

func build_architecture() -> void:
	floor_(Vector3(0,0,-12),Vector2(5.2,52),true)
	floor_(Vector3(17.5,0,-11.5),Vector2(5,45),true)
	floor_(Vector3(8.8,0,8.5),Vector2(12.4,5),true)
	floor_(Vector3(8.8,0,-31.5),Vector2(12.4,5),true)
	floor_(Vector3(-7.3,0,5),Vector2(9.4,8))
	floor_(Vector3(-6.8,0,-6),Vector2(8.4,8))
	floor_(Vector3(-8.3,0,-20),Vector2(11.4,14),true)
	floor_(Vector3(-7.3,0,-34),Vector2(9.4,8),true)
	floor_(Vector3(8.8,0,-1),Vector2(12.4,12),true)
	G.box(world,Vector3(9.2,-3.33,-20),Vector3(11.6,.26,16),mats.tile,true)
	G.box(world,Vector3(9.2,.25,-24.6),Vector3(11.6,.16,6.8),mats.wall)
	G.box(world,Vector3(9.2,.25,-15.4),Vector3(11.6,.16,6.8),mats.wall)
	# Continuous hall walls with explicit door gaps; no invisible blockers at thresholds.
	wall_z(-2.6,-38,14,[Vector2(-35,-33),Vector2(-21,-19),Vector2(-7,-5),Vector2(4,6)])
	wall_z(2.6,-38,14,[Vector2(-34,-29),Vector2(-2,0),Vector2(6,11)])
	wall_z(15,-29,6,[Vector2(-21,-19),Vector2(-2,0)])
	wall_z(20,-34,11)
	wall_piece(Vector3(2.6,0,-34),Vector3(20,0,-34))
	wall_piece(Vector3(2.6,0,-29),Vector3(15,0,-29))
	wall_piece(Vector3(2.6,0,11),Vector3(20,0,11))
	wall_piece(Vector3(2.6,0,6),Vector3(15,0,6))
	wall_piece(Vector3(-2.6,0,-38),Vector3(2.6,0,-38))
	for r in [[-12.0,1.0,9.0],[-11.0,-10.0,-2.0],[-14.0,-27.0,-13.0],[-12.0,-38.0,-30.0]]:
		wall_z(r[0],r[1],r[2])
		wall_piece(Vector3(r[0],0,r[1]),Vector3(-2.6,0,r[1]))
		wall_piece(Vector3(r[0],0,r[2]),Vector3(-2.6,0,r[2]))
	wall_piece(Vector3(2.6,0,-7),Vector3(15,0,-7))
	wall_piece(Vector3(2.6,0,5),Vector3(15,0,5))
	wall_z(3.4,-28,-12,[],-3.2)
	wall_piece(Vector3(15,-3.2,-28),Vector3(15,-3.2,-21.12))
	wall_piece(Vector3(15,-3.2,-18.88),Vector3(15,-3.2,-12))
	wall_piece(Vector3(3.4,-3.2,-28),Vector3(15,-3.2,-28),6.6)
	wall_piece(Vector3(3.4,-3.2,-12),Vector3(15,-3.2,-12),6.6)
	# Enclose both sides of the stairs. Navigation must enter from the bottom tread,
	# rather than trying to climb the vertical side of the sloped collider.
	wall_piece(Vector3(9,-3.2,-21.12),Vector3(15,-3.2,-21.12),6.6)
	wall_piece(Vector3(9,-3.2,-18.88),Vector3(15,-3.2,-18.88),6.6)
	# Subterranean stairs: visible individual treads over a continuous collision ramp.
	var ramp := G.box(world,Vector3(12,-1.7,-20),Vector3(6.8,.22,1.85),mats.floor,true)
	ramp.rotation.z = atan2(3.2,6)
	for i in 16:
		G.box(world,Vector3(9+i*.4,-3.13+i*.213,-20),Vector3(.4,.2,1.9),mats.floor)
		G.box(world,Vector3(9+i*.4,-3.021+i*.213,-20),Vector3(.05,.005,1.87),mats.chrome)
	for z in [-21.06,-18.94]:
		G.rod(world,Vector3(9,-2.2,z),Vector3(15,1,z),.032,mats.chrome)
		for i in 5: G.rod(world,Vector3(9+i*1.4,-3.2+i*.747,z),Vector3(9+i*1.4,-2.2+i*.747,z),.024,mats.metal)
	door("safe_door","值班室  /  STAFF",-2.6,5)
	door("power_door","配电间  /  POWER",-2.6,-6)
	door("ward_door","留观病房  /  WARD 09",-2.6,-20)
	door("cold_door","停尸冷库  /  MORGUE",-2.6,-34,"cold_key")
	door("pharmacy_west","药房  /  PHARMACY",2.6,-1,"power")
	door("pharmacy_east","药房  /  PHARMACY",15,-1,"power")
	door("lab_door","B1  /  RESTRICTED",15,-20,"lab_card")
	# Entrance and playable exterior ending.
	wall_piece(Vector3(-2.6,0,14),Vector3(-1,0,14))
	wall_piece(Vector3(1,0,14),Vector3(2.6,0,14))
	G.box(world,Vector3(0,3.04,14),Vector3(2,.8,.3),mats.wall,true)
	G.box(world,Vector3(0,1.3,14),Vector3(1.9,2.6,.16),mats.metal).name = "ExitVisual"
	var end := interact("exit","end_exit","后院疏散门",Vector3(0,1.3,13.84),Vector3(2,2.6,.3))
	end.collision_layer = 20
	G.label(world,"E X I T  /  出口",Vector3(0,2.82,13.8),36,.009,Color(.35,.85,.62),PI)
	G.box(world,Vector3(0,2.81,13.91),Vector3(1.86,.42,.04),mats.exit)
	G.omni(world,Vector3(0,2.7,12.6),Color(.23,.7,.47),1.5,4)
	G.box(world,Vector3(0,-.16,24),Vector3(18,.3,20),mats.floor,true)
	for x in [-9,9]: wall_z(x,14,34)
	wall_piece(Vector3(-9,0,34),Vector3(9,0,34))
	for z in [18,24,30]:
		G.cylinder(world,Vector3(-5,2.7,z),.06,5.4,mats.dark)
		G.omni(world,Vector3(-5,5,z),Color(.45,.61,.6),2.0,10,true)

func dress_halls() -> void:
	for z in range(-35,13,6):
		for x in [-2.38,2.38]: G.box(world,Vector3(x,1.7,z),Vector3(.24,3.4,.28),mats.wall)
		G.box(world,Vector3(0,3.24,z),Vector3(5,.25,.34),mats.wall)
		fixture(Vector3(0,3.18,z+2),z%3==0,true)
		fixture(Vector3(17.5,3.17,z+2),false,true)
	for x in [-1.95,-1.65,1.95]:
		G.rod(world,Vector3(x,3.06,-37),Vector3(x,3.06,13),.045,mats.copper)
	for z in range(-34,13,4):
		for x in [-1.95,-1.65,1.95]:
			G.cylinder(world,Vector3(x,3.06,z),.066,.11,mats.metal).rotation.x = PI*.5
	for z in [-29,-16,-5,6]: window_(19.8,z,-PI*.5)
	for z in [-16,-23]: window_(-13.8,z)
	window_(-11.8,5)
	fixture(Vector3(8,3.18,8.5))
	fixture(Vector3(9,3.18,-31.5),false)
	# Repeating floor edge inlays make the circulation route readable.
	for x in [-2.12,2.12,15.5,19.5]: G.box(world,Vector3(x,.012,-12),Vector3(.09,.006,49),mats.dark)
	for z in [-11,-27]:
		G.box(world,Vector3(0,2.8,z),Vector3(2.8,.45,.12),mats.metal)
		G.label(world,"09   /   WEST WING",Vector3(0,2.81,z+.075),37,.0075)
		G.label(world,"←  SOUTH EXIT",Vector3(0,2.81,z-.075),30,.007,Color(.45,.7,.57),PI)
	G.label(world,"圣维罗妮卡疗养院",Vector3(0,2.6,-37.8),51,.008,Color(.54,.62,.57))
	G.label(world,"S T .   V E R O N I C A",Vector3(0,2.18,-37.79),25,.006)
	model("wheelchair_01",Vector3(1.43,0,1.8),-.45)
	model("wheelchair_01",Vector3(-1.4,0,-26.8),.45)
	model("wheelchair_01",Vector3(18.8,0,-12),PI*.8)
	for pos in [Vector3(1.5,0,1.8),Vector3(-1.4,0,-26.8),Vector3(18.8,0,-12)]:
		var blocker := G.box(world,pos+Vector3(0,.42,0),Vector3(.65,.84,.7),mats.dark,true)
		blocker.visible = false
	# Benches and radiator details.
	for z in [7,-9,-24]:
		G.box(world,Vector3(-1.82,.45,z),Vector3(.67,.1,2.2),mats.wood,true)
		G.box(world,Vector3(-2.07,.8,z),Vector3(.08,.6,2.2),mats.wood)
		for dz in [-.8,.8]: G.box(world,Vector3(-1.82,.23,z+dz),Vector3(.5,.46,.07),mats.metal)
	for z in [-30,-17,4]:
		for i in 13: G.box(world,Vector3(19.64,.56,z+i*.105),Vector3(.3,.75,.065),mats.wall)
	# Irregular water silhouettes avoid repeated oval shapes on the tilework.
	for i in 25:
		var x := rng.randf_range(-1.6,1.6) if i<16 else rng.randf_range(16,19)
		var z := rng.randf_range(-35,10)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points: Array[Vector3] = []
		var sx := rng.randf_range(.35,.85)
		var sz := rng.randf_range(.65,1.8)
		for j in 32:
			var angle := float(j)/32*TAU
			var r := .8+.16*sin(angle*5+i)+.13*cos(angle*3+i*.7)
			points.append(Vector3(cos(angle)*sx*r,0,sin(angle)*sz*r))
		for j in 32:
			for v in [Vector3.ZERO,points[j],points[(j+1)%32]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x,v.z))
				st.add_vertex(v)
		st.generate_tangents()
		var patch := MeshInstance3D.new()
		patch.mesh = st.commit()
		patch.material_override = mats.water
		patch.position = Vector3(x,.022,z)
		world.add_child(patch)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 55:
		var pos := Vector3(rng.randf_range(-2,2),.016,rng.randf_range(-35,10))
		var paper := G.box(world,pos,Vector3(.2,.002,.28),mats.paper)
		paper.rotation.y = rng.randf()*TAU
	for pos in [Vector3(-2.37,1.75,-3),Vector3(2.35,1.75,-17),Vector3(19.75,1.8,-8)]:
		G.box(world,pos,Vector3(.035,.72,.54),mats.paper)
		G.label(world,"请保持安静\nQUIET PLEASE",pos+Vector3(.025,0,0),24,.005,Color(.13,.19,.18),PI*.5)
	# Dust is GPU instanced, local to the corridors.
	var dust := GPUParticles3D.new()
	dust.name = "AirborneDust"
	dust.position = Vector3(0,1.7,-10)
	dust.amount = 160
	dust.lifetime = 24
	dust.preprocess = 12
	dust.visibility_aabb = AABB(Vector3(-3,-2,-28),Vector3(6,4,54))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.1,1.4,24)
	pm.direction = Vector3(.1,.2,0)
	pm.initial_velocity_min = .015
	pm.initial_velocity_max = .045
	pm.gravity = Vector3.ZERO
	pm.scale_min = .004
	pm.scale_max = .012
	dust.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.material = mats.paper
	dust.draw_pass_1 = mesh
	world.add_child(dust)

func dress_rooms() -> void:
	# Reception and the warm refuge.
	table(Vector3(1.1,0,9),Vector2(1.5,1.0))
	note("arrival",Vector3(1.1,.945,9))
	table(Vector3(-8.5,0,3),Vector2(3.5,1.3))
	model("desk_lamp_arm_01",Vector3(-9.6,.94,3),.4)
	G.omni(world,Vector3(-9.3,1.44,3),Color(1,.62,.28),2,5,true)
	note("rounds",Vector3(-8.5,.945,3))
	model("portable_cassette_player",Vector3(-7.1,.95,3),PI)
	interact("save","save_recorder","值班录音机",Vector3(-7.1,1.05,3),Vector3(.55,.38,.45))
	G.label(world,"记录 / SAVE",Vector3(-7.1,1.38,3),24,.005,Color(.73,.7,.46))
	fixture(Vector3(-7.2,3.18,5))
	cabinet(Vector3(-10.8,0,8.4),PI,2)
	cabinet(Vector3(-8.5,0,8.4),PI,2)
	table(Vector3(-4.2,0,2.4),Vector2(1.1,.8))
	supply("safe_med","med",Vector3(-4.2,1.0,2.4))
	supply("safe_ammo","ammo",Vector3(-4.5,1.0,2.4),8)
	note("last_shift",Vector3(-7,.945,7.8))
	table(Vector3(-7,0,7.8),Vector2(1.5,.8))
	# Power room; the 3D panel mirrors its interactive circuitry UI.
	model("portable_generator",Vector3(-9,0,-8),.3)
	var panel := interact("power","power_panel","配电控制盘",Vector3(-9.8,1.5,-5.0),Vector3(.4,1.5,1.8))
	G.box(panel,Vector3.ZERO,Vector3(.25,1.45,1.75),mats.metal)
	for i in 4:
		G.box(panel,Vector3(.16,-.2,-.58+i*.38),Vector3(.06,.36,.19),mats.dark)
		G.box(panel,Vector3(.23,-.1,-.58+i*.38),Vector3(.18,.07,.16),mats.copper)
	G.label(world,"应急回路 / 220V",Vector3(-9.62,2.03,-5),28,.0055,Color(.75,.66,.42),PI*.5)
	table(Vector3(-6.2,0,-8.6),Vector2(2,1))
	note("power",Vector3(-6.2,.945,-8.6))
	fixture(Vector3(-6.4,3.15,-6),true)
	# Observation ward, three readable patient beds and abandoned treatment equipment.
	for i in 3:
		bed(Vector3(-10.8,0,-15.5-i*4.2),PI*.5,["04  /  退热","11  /  镇痛","07  /  镇静"][i])
		iv(Vector3(-10,0,-16.6-i*4.2))
		G.rod(world,Vector3(-8.8,2.7,-17.4-i*4.2),Vector3(-13,2.7,-17.4-i*4.2),.022,mats.chrome)
		# Hanging curtain made from corrugated cloth strips with uneven hems.
		for s in 12:
			var curtain := G.box(world,Vector3(-12.8+s*.13,1.65,-17.4-i*4.2+sin(s*1.5)*.05),Vector3(.145,1.92+sin(s)*.06,.015),mats.linen)
			curtain.rotation.y = .15*sin(s)
	bed(Vector3(-5.8,0,-24.9),0,"—")
	table(Vector3(-5.2,0,-14.2),Vector2(2,1),true)
	note("ward",Vector3(-5.3,.95,-14.2))
	note("diary",Vector3(-13.58,.962,-22.7))
	note("empty_bed",Vector3(-5.8,.81,-24.9))
	supply("ward_med","med",Vector3(-4.7,.99,-14.2))
	fixture(Vector3(-7,3.17,-16),false,true)
	fixture(Vector3(-7,3.17,-24),false,true)
	# Pharmacy shelves with instanced bottles.
	for z in [-6.5,4.5]:
		for x in [5,8,11,13.8]:
			for y in [.4,1.1,1.8]:
				G.box(world,Vector3(x,y,z),Vector3(2,.05,.4),mats.metal)
				for i in 6:
					var b := G.cylinder(world,Vector3(x-.8+i*.3,y+.12,z),.058,.21,mats.glass if i%2 else mats.paper)
					G.cylinder(b,Vector3(0,.12,0),.045,.03,mats.dark)
			for side in [-1,1]: G.box(world,Vector3(x+side,.99,z),Vector3(.04,2,.4),mats.metal)
	table(Vector3(8,0,-2),Vector2(4,1.1),true)
	var locker := interact("cabinet","medicine_lock","护士药柜",Vector3(8,1.25,-6.0),Vector3(1.7,1.3,.6))
	G.box(locker,Vector3.ZERO,Vector3(1.65,1.2,.55),mats.blue)
	G.box(locker,Vector3(.46,0,.29),Vector3(.42,.46,.06),mats.dark)
	G.label(locker,"•  •  •",Vector3(.46,.1,.33),32,.004,Color(.59,.84,.68))
	G.label(world,"受控药品  /  STAFF ONLY",Vector3(8,2.15,-5.75),30,.006)
	supply("pharmacy_ammo","ammo",Vector3(7.3,.97,-2),10)
	supply("pharmacy_med","med",Vector3(8.7,.97,-2))
	fixture(Vector3(8,3.15,-1),false,true)
	# Morgue drawers, examination table and three specimen jars.
	for z in [-37.5,-30.5]:
		for x in [-10.5,-8.0,-5.5]:
			G.box(world,Vector3(x,1.4,z),Vector3(2.35,2.8,.6),mats.metal,true)
			for y in [.55,1.42,2.29]:
				var sign_ := 1 if z < -34 else -1
				G.box(world,Vector3(x,y,z+sign_*.32),Vector3(2.13,.77,.055),mats.chrome)
				G.rod(world,Vector3(x-.24,y,z+sign_*.39),Vector3(x+.24,y,z+sign_*.39),.023,mats.dark)
				G.box(world,Vector3(x-.73,y+.17,z+sign_*.36),Vector3(.27,.11,.018),mats.paper)
	table(Vector3(-8,0,-34),Vector2(2.6,1.2),true)
	note("autopsy",Vector3(-8.7,.945,-34))
	var station := interact("specimen","specimen_terminal","标本归档终端",Vector3(-10.8,1.15,-34),Vector3(1.0,.6,1.8))
	G.box(station,Vector3(0,-.28,0),Vector3(.7,.08,1.7),mats.metal)
	for i in 3:
		var jar := G.cylinder(station,Vector3(0,0,-.55+i*.55),.14,.42,mats.glass)
		G.cylinder(jar,Vector3(0,.23,0),.145,.06,mats.metal)
		G.sphere(jar,Vector3.ZERO,Vector3(.16,.25,.16),mats.red if i==1 else mats.linen)
	fixture(Vector3(-6.5,3.15,-34),false,true)
	supply("morgue_ammo","ammo",Vector3(-7.2,.97,-34),6)
	# Underground laboratory: containment columns, consoles and overhead cables.
	for z in [-25.6,-14.2]:
		for x in [5.7,10.6,13.1]:
			G.cylinder(world,Vector3(x,-3.0,z),.72,.35,mats.metal)
			G.cylinder(world,Vector3(x,-1.6,z),.6,2.6,mats.glass)
			var collision := StaticBody3D.new()
			collision.position=Vector3(x,-1.6,z)
			collision.collision_layer=1
			collision.collision_mask=0
			var collider := CollisionShape3D.new()
			var cylinder_shape := CylinderShape3D.new()
			cylinder_shape.radius=.66
			cylinder_shape.height=3.0
			collider.shape=cylinder_shape
			collision.add_child(collider)
			world.add_child(collision)
			G.cylinder(world,Vector3(x,-.27,z),.73,.25,mats.metal)
			for a in 4:
				var v := Vector3(cos(a*PI*.5)*.63,0,sin(a*PI*.5)*.63)
				G.rod(world,Vector3(x,-2.9,z)+v,Vector3(x,-.35,z)+v,.036,mats.chrome)
			if x==5.7 or x==13.1:
				var suspended: Node3D=load("res://scenes/enemies/smily_specimen.tscn").instantiate()
				suspended.position=Vector3(x,-2.85,z)
				suspended.scale=Vector3(.40,.65,.40)
				suspended.rotation.z=.09
				world.add_child(suspended)
			else:
				G.sphere(world,Vector3(x,-1.6,z),Vector3(.45,1.6,.39),mats.linen)
			G.omni(world,Vector3(x,-1.8,z),Color(.22,.69,.53),.75,3)
	var desk := table(Vector3(5.0,-3.2,-20),Vector2(2.6,1.3),true)
	desk.rotation.y = PI*.5
	var terminal := interact("terminal","lab_terminal","培养循环 · 紧急停止",Vector3(4.9,-1.93,-20),Vector3(1.0,1.0,1.4))
	G.box(terminal,Vector3.ZERO,Vector3(.6,.68,1.25),mats.dark)
	var screen := G.box(terminal,Vector3(.31,0,0),Vector3(.02,.48,.89),mats.exit)
	G.label(terminal,"WARD 09\nCULTURE ACTIVE",Vector3(.325,.03,0),28,.004,Color(.01,.08,.06),PI*.5)
	G.cylinder(terminal,Vector3(.52,-.24,.47),.11,.08,mats.red)
	note("lab",Vector3(5.1,-2.255,-20.85))
	supply("lab_med","med",Vector3(5,-2.21,-19.1))
	G.label(world,"第 九 病 区\nBIOLOGICAL CONTAINMENT",Vector3(8.8,-.55,-27.78),54,.009,Color(.4,.7,.58))
	G.spot(world,Vector3(8.8,1,-23),Vector3(8.8,-3,-24),Color(.28,.62,.56),3.5,9,65)
	G.omni(world,Vector3(11,-.5,-18),Color(.9,.25,.09),1.5,7,true)
	for x in [5,8,11,14]: G.rod(world,Vector3(x,.7,-27),Vector3(x,.7,-12),.07,mats.dark)
	G.label(world,"B1 ↓",Vector3(15.24,1.5,-22.2),55,.008,Color(.7,.66,.44),PI*.5)

func make_patient() -> void:
	var n := Node3D.new()
	n.name = "PatientVisual"
	var fabric_shader := load("res://shaders/aged_fabric.gdshader")
	var skin := ShaderMaterial.new()
	skin.shader=fabric_shader
	skin.set_shader_parameter("base_color",Color(.34,.35,.29))
	skin.set_shader_parameter("skin",1.0)
	var cloth := ShaderMaterial.new()
	cloth.shader=fabric_shader
	cloth.set_shader_parameter("base_color",Color(.29,.33,.3))
	var gauze := ShaderMaterial.new()
	gauze.shader=fabric_shader
	gauze.set_shader_parameter("base_color",Color(.43,.43,.36))
	var flesh := G.material(Color(.18,.042,.028),.57)
	var bone := G.material(Color(.26,.24,.18),.9)
	var buckles := G.material(Color(.12,.145,.135),.83,.3)
	var torso := Node3D.new()
	torso.name = "Torso"
	n.add_child(torso)
	var body := G.organic(torso,[Vector2(.58,.25),Vector2(.70,.27),Vector2(.83,.265),Vector2(.98,.245),Vector2(1.1,.24),Vector2(1.24,.27),Vector2(1.36,.31),Vector2(1.44,.32),Vector2(1.50,.285),Vector2(1.55,.16),Vector2(1.58,.09)],cloth,9,.68,.006)
	body.rotation.z = -.06
	for y in [1.02,1.2,1.4]:
		var strap := G.organic(torso,[Vector2(y,.29),Vector2(y+.046,.3)],mats.dark,2,.72,.005)
		G.box(strap,Vector3(.04,y+.02,-.227),Vector3(.052,.042,.012),buckles)
	for i in 8:
		var t := G.organic(torso,[Vector2(.53-rng.randf()*.05,.018),Vector2(.73,.036)],cloth,i,.3,.004)
		t.position.x = -.2+i*.055
		t.position.z = -.13
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(.035,1.59,-.05)
	head.rotation.z = .15
	torso.add_child(head)
	G.cylinder(head,Vector3(0,-.04,0),.07,.22,skin)
	G.organic(head,[Vector2(-.01,.048),Vector2(.04,.087),Vector2(.09,.111),Vector2(.15,.127),Vector2(.21,.138),Vector2(.28,.141),Vector2(.33,.115),Vector2(.36,.07),Vector2(.37,.01)],skin,34,.94,.003)
	# Stained overlapping gauze hides most of the face; one recessed eye remains.
	for i in 7:
		var y := .10+i*.035
		var radius := .134 if y<.30 else .122
		var wrap := G.organic(head,[Vector2(y,radius),Vector2(y+.027,radius+.004)],gauze,45+i,.96,.002)
		wrap.rotation.z = .045*sin(i*1.7)
		wrap.rotation.x = -.07
	for side in [-1,1]:
		G.sphere(head,Vector3(side*.055,.215,-.134),Vector3(.058,.026,.009),mats.dark)
	G.sphere(head,Vector3(.056,.214,-.14),Vector3(.009,.009,.004),bone)
	G.sphere(head,Vector3(0,.087,-.104),Vector3(.047,.043,.013),flesh)
	for i in 4: G.box(head,Vector3(-.02+i*.011,.1,-.114),Vector3(.005,.008,.005),bone)
	for i in 6: G.rod(head,Vector3(-.058+i*.019,.298,-.126),Vector3(-.05+i*.019,.311,-.125),.002,mats.dark)
	for side in [-1,1]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side<0 else "ArmR"
		arm.position = Vector3(side*.31,1.42,-.015)
		arm.rotation.z = side*.13
		torso.add_child(arm)
		G.sphere(arm,Vector3(0,-.03,0),Vector3(.19,.22,.17),cloth)
		G.organic(arm,[Vector2(-.48,.061),Vector2(-.34,.085),Vector2(-.11,.102),Vector2(.01,.088)],cloth,13+side,.85,.005)
		var forearm := Node3D.new()
		forearm.position = Vector3(0,-.45,0)
		forearm.rotation.x = -.17
		arm.add_child(forearm)
		G.organic(forearm,[Vector2(-.39,.032),Vector2(-.31,.038),Vector2(-.20,.051),Vector2(-.08,.062),Vector2(.015,.062)],skin,34+side,.8,.004)
		G.sphere(forearm,Vector3(0,-.43,0),Vector3(.10,.16,.062),skin)
		for j in 4:
			var a := Vector3(-.035+j*.021,-.49,-.02)
			var b := a+Vector3((j-1.5)*.006,-.10-rng.randf()*.04,-.025)
			G.rod(forearm,a,b,.012,skin)
			G.rod(forearm,b,b+Vector3(0,-.027,-.038),.008,bone)
		var leg := Node3D.new()
		leg.name = "LegL" if side<0 else "LegR"
		leg.position = Vector3(side*.14,.82,0)
		n.add_child(leg)
		G.organic(leg,[Vector2(-.76,.055),Vector2(-.56,.072),Vector2(-.38,.077),Vector2(-.27,.103),Vector2(.02,.113)],cloth,22+side,.85,.005)
		G.sphere(leg,Vector3(0,-.76,-.066),Vector3(.16,.15,.29),mats.dark)
	store_scene(n,"res://scenes/props/patient.tscn")
	n.free()

func own_tree(n: Node, root_: Node) -> void:
	for c in n.get_children():
		c.owner = root_
		if not c.scene_file_path.is_empty(): continue
		own_tree(c,root_)

func store_scene(n: Node, path: String) -> void:
	own_tree(n,n)
	var scene := PackedScene.new()
	var err := scene.pack(n)
	assert(err==OK,"Scene packing failed")
	err = ResourceSaver.save(scene,path)
	assert(err==OK,"Scene saving failed")

func build() -> void:
	rng.seed = 909
	for dir in ["res://materials","res://scenes/props","res://captures","res://logs"]: DirAccess.make_dir_recursive_absolute(dir)
	world = Node3D.new()
	world.name = "SaintVeronica"
	root.add_child(world)
	make_materials()
	build_environment()
	build_architecture()
	dress_halls()
	dress_rooms()
	# Laboratory emergency fixtures participate in the same chapter alarm circuit.
	for pos in [Vector3(8,-.65,-23),Vector3(13,-.65,-24)]:
		var emergency := G.omni(world,pos,Color(.35,.6,.63),2.1,7)
		emergency.add_to_group("power_lights",true)
		emergency.set_meta("energy",2.1)
	# Bake navigation from static collision geometry, excluding movable doors and items.
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	var mesh := NavigationMesh.new()
	mesh.agent_radius = .4
	mesh.agent_height = 2.2
	mesh.agent_max_climb = .3
	mesh.agent_max_slope = 42
	mesh.cell_size = .2
	mesh.cell_height = .1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh,source,world)
	NavigationServer3D.bake_from_source_geometry_data(mesh,source)
	nav.navigation_mesh = mesh
	world.add_child(nav)
	ResourceSaver.save(mesh,"res://materials/navigation.tres")
	store_scene(world,"res://scenes/hospital.tscn")
	print("BUILD_OK nodes=",world.find_children("*","",true,false).size()," navigation_polygons=",mesh.get_polygon_count())
	quit()
