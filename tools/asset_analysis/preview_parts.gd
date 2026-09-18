extends SceneTree
func _initialize():
	call_deferred("build")
func build():
	root.size = Vector2i(1500,1100)
	var world = Node3D.new()
	world.name = "ExtractedPartsInspection"
	root.add_child(world)
	var source = load("res://TripoModels/hangar_separated/hangar_loose_parts.glb").instantiate()
	world.add_child(source)
	var meshes = source.find_children("*","MeshInstance3D",true,false)
	meshes.sort_custom(func(a,b): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	for i in mini(30,meshes.size()):
		var original = meshes[i]
		var pivot = Node3D.new()
		world.add_child(pivot)
		pivot.position = Vector3((i%6-2.5)*3.2,(2-i/6)*3.0,0)
		var copy = MeshInstance3D.new()
		copy.name = original.name
		copy.mesh = original.mesh
		pivot.add_child(copy)
		copy.transform = original.global_transform
		var bounds = copy.transform * copy.mesh.get_aabb()
		var factor = 2.35/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		copy.position -= bounds.get_center()
		copy.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),Vector3.ZERO) * copy.transform
		pivot.rotation_degrees = Vector3(12,-18,0)
		var label = Label3D.new()
		world.add_child(label)
		label.position = pivot.position+Vector3(0,-1.35,1.5)
		label.text = original.name
		label.font_size = 24
		label.pixel_size = 0.006
		label.no_depth_test = true
		label.modulate = Color.WHITE
	source.queue_free()
	var cam = Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0,0,30)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 20
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("20272c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var light = DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-35,-25,0)
	for i in range(5): await process_frame
	for child in world.find_children("*","",true,false):
		child.owner = world
	var packed = PackedScene.new()
	packed.pack(world)
	ResourceSaver.save(packed,"res://TripoModels/hangar_separated/parts_inspection.tscn")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/asset_analysis/parts_preview.png")
	quit()
