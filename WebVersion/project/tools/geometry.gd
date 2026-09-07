class_name WardGeometry
extends RefCounted

static func material(color: Color, rough: float=.8, metal: float=0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

static func box(parent: Node, pos: Vector3, size_: Vector3, mat: Material, solid: bool=false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	if solid:
		var b := StaticBody3D.new()
		b.collision_layer = 1
		b.collision_mask = 0
		n.add_child(b)
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_
		c.shape = shape
		b.add_child(c)
	return n

static func cylinder(parent: Node, pos: Vector3, radius: float, height: float, mat: Material, top: float=-1.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

static func sphere(parent: Node, pos: Vector3, size_: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1
	mesh.radial_segments = 20
	mesh.rings = 12
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.scale = size_
	parent.add_child(n)
	return n

static func rod(parent: Node, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var n := cylinder(parent,(a+b)*.5,radius,a.distance_to(b),mat)
	var up := (b-a).normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < .1: right = Vector3.RIGHT
	n.basis = Basis(right,up,right.cross(up)).orthonormalized()
	return n

static func label(parent: Node, text_: String, pos: Vector3, font_size: int=48, scale_: float=.01, color: Color=Color(.7,.79,.76), rot: float=0) -> Label3D:
	var l := Label3D.new()
	l.text = text_
	l.font = load("res://assets/fonts/regular.tres")
	l.font_size = font_size
	l.pixel_size = scale_
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation.y = rot
	l.no_depth_test = false
	l.shaded = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	return l

static func omni(parent: Node, pos: Vector3, color: Color, energy: float, range_: float, shadow: bool=false) -> OmniLight3D:
	var n := OmniLight3D.new()
	n.position = pos
	n.light_color = color
	n.light_energy = energy
	n.omni_range = range_
	n.omni_attenuation = 1.3
	n.shadow_enabled = shadow
	n.light_size = .18
	n.light_specular = .22
	n.distance_fade_enabled = true
	n.distance_fade_begin = 30
	n.distance_fade_length = 12
	parent.add_child(n)
	return n

static func spot(parent: Node, pos: Vector3, target: Vector3, color: Color, energy: float, range_: float, angle: float=50) -> SpotLight3D:
	var n := SpotLight3D.new()
	n.position = pos
	n.light_color = color
	n.light_energy = energy
	n.spot_range = range_
	n.spot_angle = angle
	n.spot_attenuation = .9
	n.shadow_enabled = true
	n.light_size = .12
	n.light_specular = .25
	parent.add_child(n)
	if n.is_inside_tree(): n.look_at(target)
	else: n.basis = Basis.looking_at(target-pos)
	return n

# Ring mesh used for the original patient's torn cloth, misshapen skin and mask.
static func organic(parent: Node, profile: Array, mat: Material, seed_: int=1, depth: float=.7, jagged: float=.02) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 40
	st.set_smooth_group(0)
	for j in profile.size():
		for i in sides+1:
			var angle := float(i)/sides*TAU
			var r: float = profile[j].y
			var rough := rng.randf_range(-jagged,jagged) if i < sides else 0.0
			st.set_uv(Vector2(float(i)/sides,float(j)/maxi(profile.size()-1,1)))
			st.add_vertex(Vector3(cos(angle)*(r+rough),profile[j].x+rough,sin(angle)*(r+rough)*depth))
	for j in profile.size()-1:
		for i in sides:
			var a := j*(sides+1)+i
			var b := a+sides+1
			for idx in [a,a+1,b,b,a+1,b+1]: st.add_index(idx)
	st.generate_normals()
	st.generate_tangents()
	var n := MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = mat
	parent.add_child(n)
	return n

static func bevel_box(parent: Node, pos: Vector3, dimensions: Vector3, bevel: float, mat: Material) -> MeshInstance3D:
	# Eight-point chamfered cross-section extruded along the barrel axis.
	var x := dimensions.x*.5
	var y := dimensions.y*.5
	var z := dimensions.z*.5
	var b := minf(bevel,minf(x,y)*.8)
	var profile := [Vector2(-x+b,-y),Vector2(x-b,-y),Vector2(x,-y+b),Vector2(x,y-b),Vector2(x-b,y),Vector2(-x+b,y),Vector2(-x,y-b),Vector2(-x,-y+b)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a: Vector2 = profile[i]
		var c: Vector2 = profile[(i+1)%8]
		for v in [Vector3(a.x,a.y,-z),Vector3(a.x,a.y,z),Vector3(c.x,c.y,-z),Vector3(a.x,a.y,z),Vector3(c.x,c.y,z),Vector3(c.x,c.y,-z)]:
			st.set_uv(Vector2(v.z/dimensions.z,v.y/dimensions.y))
			st.add_vertex(v)
		for v in [Vector3(0,0,-z),Vector3(a.x,a.y,-z),Vector3(c.x,c.y,-z),Vector3(0,0,z),Vector3(c.x,c.y,z),Vector3(a.x,a.y,z)]:
			st.set_uv(Vector2(v.x/dimensions.x+.5,v.y/dimensions.y+.5))
			st.add_vertex(v)
	st.generate_normals()
	st.generate_tangents()
	var n := MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n
