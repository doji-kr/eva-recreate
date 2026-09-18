extends SceneTree
func _initialize():
	call_deferred("capture")
func capture():
	root.size = Vector2i(1280,960)
	var scene = load("res://scenes/mecha_hangar.tscn").instantiate()
	root.add_child(scene)
	for i in range(60):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/hangar_preview.png")
	for camera in scene.get_node("09_Cameras").get_children():
		camera.make_current()
		for i in range(16):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/hangar_"+camera.name+".png")
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
