extends Node3D
## Presentation only: the closed display contains no hidden item nodes or prices.
var display_root: Node3D
var spin := 0.0
var opened := false
var colors := {"gold": Color("e8b953"), "vase": Color("65c9bc"), "clock": Color("ab744d"), "radio": Color("6591a6"), "gem": Color("b890ed")}

func material(color: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, metal := 0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color, metal)
	n.position = pos
	parent.add_child(n)
	return n

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top := -1.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 32
	n.mesh = mesh
	n.material_override = material(color, 0.35)
	n.position = pos
	parent.add_child(n)
	return n

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("111d28")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9ebac8")
	e.ambient_light_energy = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(10, 8.5, 14)
	add_child(cam)
	cam.look_at(Vector3(0, 1.6, 0))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 19.5
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -28, 0)
	sun.light_color = Color("ffe1a5")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	box(self, Vector3(0,-0.2,0), Vector3(35,0.4,25), Color("24323a"))
	for x in range(-15,16,2):
		box(self, Vector3(x,0.005,0), Vector3(0.025,0.01,24), Color("35454b"))
	for z in range(-12,13,2):
		box(self, Vector3(0,0.008,z), Vector3(34,0.01,0.025), Color("35454b"))
	box(self, Vector3(0,4,-7), Vector3(32,8,0.3), Color("1c2d37"))
	for x in range(-14,15,3):
		box(self, Vector3(x,4,-6.78), Vector3(0.15,8,0.15), Color("344a53"),0.4)
	for side in [-1,1]:
		for z in [-4,-1,2]:
			var rack := Node3D.new()
			rack.position = Vector3(side*8,0,z)
			add_child(rack)
			for x in [-1.3,1.3]:
				box(rack, Vector3(x,2,0), Vector3(0.12,4,1.8),Color("263e49"),0.7)
			for h in [0.3,2.0,3.8]:
				box(rack,Vector3(0,h,0),Vector3(2.8,0.14,1.8),Color("53616a"),0.6)
				for x in [-0.7,0.6]:
					box(rack,Vector3(x,h+0.48,0),Vector3(1.0,0.85,1.3),Color("6d6352"))
	for x in [-5,5]:
		cylinder(self,Vector3(x,6,-3),0.35,0.18,Color("e6bf67"),0.15)
		box(self,Vector3(x,7,-3),Vector3(0.035,2,0.035),Color("677580"))
		var light := OmniLight3D.new()
		light.position = Vector3(x,5.5,-2)
		light.light_color = Color("ffd995")
		light.light_energy = 2
		light.omni_range = 8
		add_child(light)
	# Auction stage and its gold trim.
	cylinder(self,Vector3(0,0.2,0),3.2,0.4,Color("263d49"))
	cylinder(self,Vector3(0,0.42,0),3.15,0.04,Color("c9a65b"))
	display_root = Node3D.new()
	add_child(display_root)
	show_closed()

func clear_display() -> void:
	for child in display_root.get_children():
		child.queue_free()

func show_closed() -> void:
	opened = false
	clear_display()
	box(display_root,Vector3(0,1.45,0),Vector3(4.1,2.0,2.9),Color("416478"),0.45)
	for x in [-2.05,2.05]:
		box(display_root,Vector3(x,1.45,0),Vector3(0.1,2.1,3.05),Color("70838a"),0.75)
	for x in [-1.9,-1.45,-1,-0.55,0,0.55,1,1.45,1.9]:
		box(display_root,Vector3(x,1.45,1.47),Vector3(0.06,1.9,0.05),Color("658392"),0.6)
	box(display_root,Vector3(0,1.45,1.53),Vector3(0.2,2,0.1),Color("b7b2a0"),0.7)
	box(display_root,Vector3(0,1.35,1.65),Vector3(0.55,0.55,0.14),Color("e3b855"),0.7)
	box(display_root,Vector3(0,1.35,1.74),Vector3(0.08,0.18,0.02),Color("273544"))
	for x in [-1.6,1.6]:
		box(display_root,Vector3(x,0.5,0),Vector3(0.4,0.13,3.2),Color("9e8256"))

func show_items(items: Array) -> void:
	opened = true
	clear_display()
	for i in items.size():
		var obj := Node3D.new()
		display_root.add_child(obj)
		var angle := TAU*float(i)/items.size()
		obj.position = Vector3(cos(angle)*1.65,0.5,sin(angle)*1.35)
		cylinder(obj,Vector3(0,0.12,0),0.7,0.24,Color("354e5b"))
		var kind: String = items[i].get("kind","gold")
		var color: Color = colors.get(kind,Color("e8b953"))
		match kind:
			"vase":
				cylinder(obj,Vector3(0,0.7,0),0.42,0.9,color,0.2)
				cylinder(obj,Vector3(0,1.25,0),0.16,0.3,color,0.25)
				cylinder(obj,Vector3(0,1.41,0),0.26,0.05,Color("deb860"))
			"clock":
				box(obj,Vector3(0,0.8,0),Vector3(0.85,1.1,0.4),color)
				var face := cylinder(obj,Vector3(0,0.9,0.24),0.32,0.04,Color("f3e2b0"))
				face.rotation_degrees.x = 90
				box(obj,Vector3(0,0.98,0.28),Vector3(0.035,0.18,0.03),Color("273544"))
				box(obj,Vector3(0.07,0.9,0.28),Vector3(0.17,0.035,0.03),Color("273544"))
			"radio":
				box(obj,Vector3(0,0.65,0),Vector3(1.1,0.7,0.55),color)
				for x in [-0.36,-0.25,-0.14,-0.03]:
					box(obj,Vector3(x,0.65,0.29),Vector3(0.045,0.5,0.04),Color("24323a"))
				box(obj,Vector3(0.3,1.25,0),Vector3(0.03,0.75,0.03),Color("c6c8b4"))
			"gem":
				var gem := MeshInstance3D.new()
				var mesh := PrismMesh.new()
				mesh.size=Vector3(0.85,1.1,0.85)
				gem.mesh=mesh
				gem.material_override=material(color,0.55,0.15)
				gem.position.y=0.8
				obj.add_child(gem)
			_:
				for j in 3:
					box(obj,Vector3((j%2)*0.3-0.15,0.4+j*0.17,0),Vector3(0.75,0.18,0.45),color,0.8)

func _process(delta: float) -> void:
	if opened:
		display_root.rotation.y += delta*0.08
	else:
		display_root.rotation.y = lerpf(display_root.rotation.y,0,delta*5)
