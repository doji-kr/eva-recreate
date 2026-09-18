extends SceneTree
# Builds and saves real editable nodes. Run again to regenerate the hangar.
var stage: Node3D
var mats: Dictionary = {}
var rng = RandomNumberGenerator.new()
var source_parts: Dictionary = {}
var part_alignment: Dictionary = {}
var source_material: StandardMaterial3D
func load_source_parts():
	var source = load("res://TripoModels/hangar_separated/hangar_loose_parts.glb").instantiate()
	stage.add_child(source)
	for mesh in source.find_children("*","MeshInstance3D",true,false):
		var index = int(String(mesh.name).split("_")[1])
		source_parts[index] = {"mesh": mesh.mesh, "transform": mesh.global_transform}
		if source_material == null:
			source_material = mesh.mesh.surface_get_material(0).duplicate()
			source_material.resource_name = "OriginalTripoAtlas_PSX"
			source_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			source_material.roughness = 1.0
			source_material.metallic = 0.0
			source_material.normal_enabled = false
			source_material.emission_enabled = false
			source_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in [7,11,17,23,24,30,76]:
		var entry = source_parts[index]
		var points: Array[Vector3] = []
		for surface in range(entry.mesh.get_surface_count()):
			for vertex in entry.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(entry.transform * vertex)
		var best = INF
		for angle in range(-90,91,2):
			var rotation = Basis(Vector3.UP,deg_to_rad(angle))
			var bounds = AABB(rotation*points[0],Vector3.ZERO)
			for point in points:
				bounds = bounds.expand(rotation*point)
			var score = bounds.size.z if index in [17,23,24] else bounds.size.x*bounds.size.z
			if score < best:
				best = score
				part_alignment[index] = deg_to_rad(angle)
	source.free()
func imported_part(parent: Node3D, label: String, index: int, pos: Vector3, size: Vector3, yaw: float = 0.0) -> MeshInstance3D:
	var entry = source_parts[index]
	var n = MeshInstance3D.new()
	n.name = label + "_TripoPart%03d" % index
	n.mesh = entry.mesh
	n.material_override = source_material
	# Most extracted modules were generated in an isometric view. Undo that
	# baked diagonal before fitting them to the architectural grid.
	var alignment: float = part_alignment.get(index,0.0)
	var oriented: Transform3D = Transform3D(Basis(Vector3.UP,yaw + alignment),Vector3.ZERO) * entry.transform
	var bounds := AABB()
	var first_vertex = true
	for surface_index in range(n.mesh.get_surface_count()):
		var vertices = n.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point: Vector3 = oriented * vertex
			if first_vertex:
				bounds = AABB(point,Vector3.ZERO)
				first_vertex = false
			else:
				bounds = bounds.expand(point)
	var fit = size / bounds.size
	oriented.origin -= bounds.get_center()
	n.transform = Transform3D(Basis.IDENTITY.scaled(fit),pos) * oriented
	parent.add_child(n)
	n.owner = stage
	n.set_meta("source_part", index)
	return n
func material(key: String, color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.roughness = 0.92
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	mats[key] = m
	return m
func group(label: String) -> Node3D:
	var n = Node3D.new()
	n.name = label
	stage.add_child(n)
	n.owner = stage
	return n
func box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: String) -> MeshInstance3D:
	var replacements = {"WallPanel":24,"RearWallPanel":24,"DeckPanel":7,"RestraintPedestal":21,"GantryArm":26,"UtilityBox":15,"RearDoor":23}
	if replacements.has(label):
		var index: int = replacements[label]
		var yaw = 0.0
		if label == "WallPanel":
			yaw = -signf(pos.x)*PI/2
			if is_equal_approx(pos.y,10.0):
				index = 17
		if label == "DeckPanel":
			size.y = 0.16
			pos.y += 0.03
		return imported_part(parent,label,index,pos,size,yaw)
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mats[mat]
	parent.add_child(n)
	n.owner = stage
	n.position = pos
	return n
func beam(parent: Node3D, label: String, a: Vector3, b: Vector3, width: float, mat: String):
	var n = box(parent, label, (a+b)/2, Vector3(width, a.distance_to(b), width), mat)
	n.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
func cylinder(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, mat: String) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	n.mesh = mesh
	n.material_override = mats[mat]
	parent.add_child(n)
	n.owner = stage
	n.position = pos
	return n
func sign_text(parent: Node3D, text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var n = Label3D.new()
	n.name = "Marking"
	n.text = text
	n.font_size = size
	n.pixel_size = 0.012
	n.modulate = color
	n.outline_size = 0
	parent.add_child(n)
	n.owner = stage
	n.position = pos
	return n
func hazard(parent: Node3D, pos: Vector3, width: float, height: float):
	box(parent, "HazardBacking", pos, Vector3(width, height, 0.08), "black")
	# Clipped parallelograms keep warning stripes inside their backing plate.
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x = -width/2
	while x < width/2 - 0.3:
		var points = [Vector3(x,-height/2,0.046),Vector3(x+0.3,-height/2,0.046),Vector3(x+0.3+height*0.6,height/2,0.046),Vector3(x+height*0.6,height/2,0.046)]
		for i in [0,2,1,0,3,2]:
			mesh.set_normal(Vector3.BACK)
			mesh.add_vertex(Vector3(minf(points[i].x,width/2),points[i].y,points[i].z))
		x += 0.62
	var n = MeshInstance3D.new()
	n.mesh = mesh.commit()
	n.material_override = mats["red"]
	parent.add_child(n)
	n.owner = stage
	n.position = pos
func omni(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float):
	var n = OmniLight3D.new()
	parent.add_child(n)
	n.owner = stage
	n.position = pos
	n.light_color = color
	n.light_energy = energy
	n.light_volumetric_fog_energy = 0.15
	n.omni_range = radius
func _initialize():
	call_deferred("build")
func build():
	rng.seed = 1709
	stage = Node3D.new()
	stage.name = "MechaHangar"
	root.add_child(stage)
	load_source_parts()
	material("olive",Color("535e4d"))
	material("panel",Color("65705a"))
	material("panel_dark",Color("444f45"))
	material("edge",Color("78806a"))
	material("black",Color("151d1b"))
	material("red",Color("922e31"))
	material("rust",Color("704936"))
	material("pit",Color("593647"))
	material("rail",Color("a29867"))
	material("cyan",Color("a9eae0"),2.5)
	material("alarm",Color("ff3432"),3.0)
	material("screen",Color("53a1b4"),1.4)
	# Texture the remaining structural primitives using selected areas of the
	# original atlas. World-space mapping avoids stretching on long columns.
	for key_name in ["olive","panel","panel_dark","edge","black","red","rust","pit","rail"]:
		var old_material: StandardMaterial3D = mats[key_name]
		var textured = ShaderMaterial.new()
		textured.resource_name = "TripoAtlas_" + key_name
		textured.shader = load("res://shaders/atlas_surface.gdshader")
		textured.set_shader_parameter("original_atlas",source_material.albedo_texture)
		textured.set_shader_parameter("paint_color",old_material.albedo_color)
		if key_name == "pit":
			textured.set_shader_parameter("atlas_region",Vector4(0.625,0.220,0.085,0.022))
			textured.set_shader_parameter("tiles_per_meter",0.18)
			textured.set_shader_parameter("texture_strength",0.55)
		elif key_name in ["black","rail","red"]:
			textured.set_shader_parameter("texture_strength",0.4)
			textured.set_shader_parameter("tiles_per_meter",1.2)
		mats[key_name] = textured
	var water = ShaderMaterial.new()
	water.resource_name = "DockWater"
	water.shader = load("res://shaders/pit_water.gdshader")
	mats["pit"] = water
	var floor_group = group("01_RecessedDock")
	box(floor_group,"PurplePitFloor",Vector3(0,-0.3,0),Vector3(20,0.6,32),"pit")
	for x in [-5.4,5.4]:
		box(floor_group,"DockGuide",Vector3(x,0.01,0),Vector3(0.1,0.025,27),"red")
	box(floor_group,"RobotDockPlinth",Vector3(0,0.15,-2),Vector3(6,0.3,4),"panel_dark")
	var wall = group("02_ModularWalls")
	for side in [-1,1]:
		box(wall,"WallBacking",Vector3(side*10.1,10,-0.5),Vector3(0.5,20,31),"panel_dark")
		for zi in range(8):
			var z = -14.0 + zi*4
			for yi in range(5):
				var y = 2.0+yi*4
				box(wall,"WallPanel",Vector3(side*9.83,y,z),Vector3(0.35,3.9,3.86),"panel" if (zi+yi)%3 else "panel_dark")
				box(wall,"PanelSeam",Vector3(side*9.61,y+0.85,z),Vector3(0.12,0.10,3.8),"edge")
				for dz in [-1.62,1.62]:
					for dy in [-1.65,1.65]:
						box(wall,"Fastener",Vector3(side*9.60,y+dy,z+dz),Vector3(0.13,0.14,0.14),"black")
				for chip in range(3):
					box(wall,"PaintWear",Vector3(side*9.635,y+rng.randf_range(-1.7,1.7),z+rng.randf_range(-1.7,1.7)),Vector3(0.035,rng.randf_range(0.06,0.3),0.06),"rust")
			box(wall,"StructuralColumn",Vector3(side*9.25,10,z-1.93),Vector3(0.62,20,0.4),"olive")
			for y in [4.0,8.0,12.0,16.0]:
				box(wall,"ColumnCollar",Vector3(side*9.25,y,z-1.93),Vector3(0.79,0.34,0.62),"edge")
			if zi%2 == 0:
				box(wall,"BeaconHousing",Vector3(side*8.88,12.4,z-1.9),Vector3(0.26,0.85,0.55),"black")
				box(wall,"RedBeacon",Vector3(side*8.7,12.4,z-1.9),Vector3(0.15,0.36,0.25),"alarm")
				omni(wall,Vector3(side*8.3,12.4,z-1.9),Color("ff342c"),0.65,3)
		for z in [-12,-8,-4,0,4,8,12]:
			imported_part(wall,"ContinuousPipeModule",10,Vector3(side*9.2,9.85,z),Vector3(0.35,0.35,3.96),PI/2)
		for y in [3.2,14.5,17.6]:
			var p = cylinder(wall,"ServicePipe",Vector3(side*9.1,y,0),0.11,29,"black")
			p.rotation_degrees.x = 90
		for z in [-11,-3,5,13]:
			beam(wall,"DiagonalBrace",Vector3(side*8.95,14,z),Vector3(side*8.95,18,z-4),0.25,"black")
	for xi in range(5):
		for yi in range(5):
			box(wall,"RearWallPanel",Vector3(-8+xi*4,2+yi*4,-15),Vector3(3.9,3.88,0.45),"panel" if xi%2 else "panel_dark")
	for x in [-9,-5,5,9]:
		box(wall,"RearVerticalRib",Vector3(x,10,-14.55),Vector3(0.35,20,0.6),"olive")
	box(wall,"RearDoor",Vector3(0,7,-14.5),Vector3(8,13,0.3),"panel_dark")
	box(wall,"DoorSeam",Vector3(0,7,-14.31),Vector3(0.10,13,0.07),"black")
	hazard(wall,Vector3(0,0.6,-14.25),8,0.55)
	sign_text(wall,"拘束庫  /  CONTAINMENT",Vector3(0,16.1,-14.35),52,Color("b4bda2"))
	sign_text(wall,"01",Vector3(0,12.8,-14.27),170,Color("899781"))
	var deck = group("03_MaintenancePlatforms")
	for side in [-1,1]:
		for i in range(7):
			var z = -10.0 + i*3.5
			box(deck,"WalkwayModule",Vector3(side*7.35,5.6,z),Vector3(3.6,0.6,3.46),"olive")
			for tx in [-0.84,0.84]:
				for tz in [-0.84,0.84]:
					imported_part(deck,"FloorTile",76,Vector3(side*7.35+tx,5.96,z+tz),Vector3(1.72,0.10,1.72))
			for dz in [-1.42,1.42]:
				box(deck,"DeckJoint",Vector3(side*7.35,5.98,z+dz),Vector3(3.35,0.035,0.06),"edge")
			for bolt_x in [-1.45,1.45]:
				for bolt_z in [-1.4,1.4]:
					cylinder(deck,"DeckBolt",Vector3(side*7.35+bolt_x,6.01,z+bolt_z),0.055,0.035,"black")
			box(deck,"InnerEdge",Vector3(side*5.53,5.85,z),Vector3(0.13,0.3,3.5),"edge")
			box(deck,"SupportLeg",Vector3(side*8,2.7,z),Vector3(0.6,5.4,0.7),"panel_dark")
			# Outer rail preserves the open view of the mecha from the reference camera.
			for dz in [-1.6,1.6]:
				cylinder(deck,"RailPost",Vector3(side*8.87,6.52,z+dz),0.045,1.1,"rail")
			beam(deck,"TopRail",Vector3(side*8.87,7.07,z-1.7),Vector3(side*8.87,7.07,z+1.7),0.07,"rail")
			beam(deck,"MiddleRail",Vector3(side*8.87,6.57,z-1.7),Vector3(side*8.87,6.57,z+1.7),0.045,"rail")
		box(deck,"RestraintPedestal",Vector3(side*6.5,7.0,-3.5),Vector3(2.4,2.2,3),"olive")
		box(deck,"PedestalCap",Vector3(side*6.5,8.18,-3.5),Vector3(2.6,0.28,3.2),"panel")
		hazard(deck,Vector3(side*6.5,7.6,-1.95),2.4,0.48)
		box(deck,"RestraintPiston",Vector3(side*5.1,8,-3.5),Vector3(1.0,0.4,0.65),"edge")
	# Foreground bridge screens the lower body, retaining the portrait-like reference composition.
	box(deck,"FrontCrossBridge",Vector3(0,5.65,5.6),Vector3(11.2,0.58,1.8),"olive")
	box(deck,"BridgeWalkingSurface",Vector3(0,5.97,5.6),Vector3(11.2,0.07,1.7),"panel")
	for module_x in [-4.2,-1.4,1.4,4.2]:
		imported_part(deck,"BridgeDeck",76,Vector3(module_x,6.015,5.6),Vector3(2.80,0.10,1.8))
	hazard(deck,Vector3(0,5.52,6.54),11.2,0.43)
	for x in [-5,-3,-1,1,3,5]:
		box(deck,"BridgePlateSeam",Vector3(x,6.02,5.6),Vector3(0.045,0.03,1.7),"black")
		box(deck,"BridgeBracket",Vector3(x,5.14,5.6),Vector3(0.20,0.4,1.85),"panel_dark")
	var gantry = group("04_OverheadGantry")
	for side in [-1,1]:
		for z in [-9,-1,7]:
			box(gantry,"WallRailCarriage",Vector3(side*8.65,11.7,z),Vector3(1.4,1.8,1.35),"olive")
			box(gantry,"GantryArm",Vector3(side*6.55,11.7,z),Vector3(3.9,0.55,0.72),"panel")
			box(gantry,"GantryUnderRail",Vector3(side*6.55,11.26,z),Vector3(3.9,0.15,0.42),"black")
			beam(gantry,"ArmBrace",Vector3(side*8.7,13.9,z),Vector3(side*5.3,12,z),0.22,"black")
			box(gantry,"ArmEnd",Vector3(side*4.7,11.55,z),Vector3(0.45,0.95,1.02),"olive")
			if z == -1:
				var cable = cylinder(gantry,"ServiceCable",Vector3(side*5,9.65,z),0.065,3.2,"black")
		for z in [-11,2,13]:
			box(gantry,"CeilingCrossBeam",Vector3(0,19.4,z),Vector3(20,0.65,0.65),"olive")
	var robot_group = group("05_TripoRobot")
	var robot = load("res://TripoModels/mecha_robot_3d_model/mecha_robot_3d_model.fbx").instantiate()
	robot.name = "CurrentRobot"
	robot_group.add_child(robot)
	robot.owner = stage
	robot.scale = Vector3.ONE * 13.3
	robot.position = Vector3(0,-1.2,0)
	# Keep robot geometry and its own texture, applying only matte nearest filtering.
	for mesh in robot.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var mat = mesh.get_active_material(surface).duplicate()
			if mat is StandardMaterial3D:
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.roughness = 1.0
				mat.metallic = 0.0
			mesh.set_surface_override_material(surface,mat)
			# Mark imported overrides for serialization in the saved scene.
		stage.set_editable_instance(robot,true)
	var props = group("06_ServiceDetails")
	for side in [-1,1]:
		for i in range(3):
			imported_part(props,"StorageDrum",8+i%2,Vector3(side*7.6,6.7,-7.4+i*1.15),Vector3(0.72,1.35,0.72))
		imported_part(props,"SupplyCrate",18,Vector3(side*7.6,6.65,2),Vector3(1.15,1.25,1.1))
		imported_part(props,"ServiceCabinet",15,Vector3(side*8.6,7.2,-10),Vector3(0.9,2.4,0.85))
		for z in [-9,-1,7]:
			imported_part(props,"GantryBeacon",16,Vector3(side*8.55,12.9,z),Vector3(0.4,0.65,0.4))
			imported_part(props,"HangingHose",0,Vector3(side*9,9,z),Vector3(0.6,2.5,1.3),side*PI/2)
	for side in [-1,1]:
		box(props,"ConsoleBase",Vector3(side*7.4,6.45,8.8),Vector3(1.1,1,0.7),"panel_dark")
		var panel = box(props,"ConsoleTop",Vector3(side*7.4,7.04,8.7),Vector3(1.25,0.18,0.9),"olive")
		panel.rotation_degrees.x = 16
		var screen = box(props,"ConsoleScreen",Vector3(side*7.4,7.17,8.55),Vector3(0.75,0.035,0.37),"screen")
		screen.rotation_degrees.x = 16
		for i in range(3):
			box(props,"ConsoleSwitch",Vector3(side*7.4-0.35+i*0.28,7.11,8.98),Vector3(0.1,0.04,0.08),"alarm" if i==0 else "edge")
		for y in range(6):
			box(props,"UtilityBox",Vector3(side*9.0,7+y*0.8,-12),Vector3(0.65,0.55,0.7),"panel_dark")
	# A maintenance technician makes the mecha scale legible.
	var human = group("07_ScaleTechnician")
	box(human,"Coveralls",Vector3(0.9,6.96,5.6),Vector3(0.38,0.65,0.25),"edge")
	cylinder(human,"Helmet",Vector3(0.9,7.43,5.6),0.16,0.25,"rail")
	for side in [-1,1]:
		box(human,"BootLeg",Vector3(0.9+side*0.115,6.36,5.6),Vector3(0.14,0.6,0.17),"black")
		beam(human,"Arm",Vector3(0.9+side*0.25,7.14,5.6),Vector3(0.9+side*0.30,6.68,5.6),0.13,"edge")
	var lighting = group("08_Lighting")
	for y in [10.5,18]:
		box(lighting,"RearLightHousing",Vector3(0,y,-14.1),Vector3(5.7,0.5,0.5),"black")
		box(lighting,"RearFluorescent",Vector3(0,y,-13.8),Vector3(5.25,0.24,0.15),"cyan")
		omni(lighting,Vector3(0,y,-11.5),Color("a8ffe3"),2.0,15)
	for x in [-7,7]:
		box(lighting,"OverheadStrip",Vector3(x,17,-1),Vector3(0.35,0.12,8),"cyan")
		omni(lighting,Vector3(x,14,0),Color("bedbd1"),1.1,15)
	omni(lighting,Vector3(0,12,9),Color("bbcbd8"),1.2,18)
	var key = DirectionalLight3D.new()
	key.name = "SoftFrontKey"
	lighting.add_child(key)
	key.owner = stage
	key.rotation_degrees = Vector3(-42,-22,0)
	key.light_color = Color("cbd5ba")
	key.light_energy = 0.65
	key.shadow_enabled = true
	key.light_volumetric_fog_energy = 0.15
	for side in [-1, 1]:
		var shaft = SpotLight3D.new()
		shaft.name = "GodRayLeft" if side == -1 else "GodRayRight"
		lighting.add_child(shaft)
		shaft.owner = stage
		shaft.position = Vector3(side * 4.8, 16.5, 2)
		shaft.rotation_degrees = Vector3(-65, side * 25, 0)
		shaft.light_color = Color(0.68, 0.86, 0.82)
		shaft.light_energy = 3.0
		shaft.light_volumetric_fog_energy = 80.0
		shaft.spot_range = 24.0
		shaft.spot_angle = 16.0
		shaft.spot_angle_attenuation = 0.7
		shaft.shadow_enabled = true
	var env = WorldEnvironment.new()
	env.name = "HangarAtmosphere"
	env.environment = Environment.new()
	var e = env.environment
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("182420")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("7a948a")
	e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("718e7f")
	e.fog_light_energy = 0.35
	e.fog_density = 0.002
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.018
	e.volumetric_fog_albedo = Color(0.62, 0.73, 0.69)
	e.volumetric_fog_anisotropy = 0.35
	e.volumetric_fog_length = 64.0
	e.volumetric_fog_detail_spread = 1.5
	e.volumetric_fog_ambient_inject = 0.15
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.2
	e.glow_enabled = false
	stage.add_child(env)
	env.owner = stage
	var cameras = group("09_Cameras")
	var positions = [Vector3(0,13.5,22),Vector3(7,16,22),Vector3(0,18.2,14)]
	for i in range(3):
		var cam = Camera3D.new()
		cam.name = ["ReferenceFront","AssemblyPerspective","TopView"][i]
		cameras.add_child(cam)
		cam.owner = stage
		cam.position = positions[i]
		cam.look_at(Vector3(0,6.6,-1))
		cam.fov = 46 if i == 0 else 55
		cam.current = i == 0
		cam.far = 150
	var presentation = CanvasLayer.new()
	presentation.name = "10_PSXPresentation"
	stage.add_child(presentation)
	presentation.owner = stage
	var screen = ColorRect.new()
	screen.name = "PixelGridAndDither"
	presentation.add_child(screen)
	screen.owner = stage
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen_material = ShaderMaterial.new()
	screen_material.shader = load("res://shaders/psx_display.gdshader")
	screen.material = screen_material
	var lens = CanvasLayer.new()
	lens.name = "11_TiltShift"
	lens.layer = 2
	stage.add_child(lens)
	lens.owner = stage
	# Refresh the screen texture after PSX processing, including when PSX is hidden.
	var capture = BackBufferCopy.new()
	capture.name = "CapturePresentation"
	capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	lens.add_child(capture)
	capture.owner = stage
	var focus = ColorRect.new()
	focus.name = "LensBlur"
	lens.add_child(focus)
	focus.owner = stage
	focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lens_material = ShaderMaterial.new()
	lens_material.shader = load("res://shaders/tilt_shift.gdshader")
	focus.material = lens_material
	var player = load("res://scenes/player.tscn").instantiate()
	stage.add_child(player)
	player.owner = stage
	player.position = Vector3(-1.5, 6.08, 5.6)
	stage.set_script(load("res://scripts/hangar_view.gd"))
	var packed = PackedScene.new()
	var result = packed.pack(stage)
	if result == OK:
		result = ResourceSaver.save(packed,"res://scenes/mecha_hangar.tscn")
	print("Hangar scene saved: ", result, " / nodes: ",stage.find_children("*","",true,false).size())
	quit(result)
