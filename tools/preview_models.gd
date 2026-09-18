extends SceneTree
func _initialize():
	call_deferred("build")
func build():
	root.size = Vector2i(1200, 500)
	var world = Node3D.new()
	root.add_child(world)
	var paths = ["res://TripoModels/mecha_3d_model/mecha_3d_model.fbx", "res://TripoModels/mecha_robot_3d_model/mecha_robot_3d_model.fbx", "res://TripoModels/mecha_robot_3d_model_1/mecha_robot_3d_model_1.fbx"]
	for i in 3:
		var model = load(paths[i]).instantiate()
		world.add_child(model)
		model.position.x = (i - 1) * 1.4
	var camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.4, 4.5)
	camera.look_at(Vector3(0, 0.4, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	var light = DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-40, -30, 0)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12,0.14,0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/model_preview.png")
	quit()
