extends SceneTree
func _initialize():
	call_deferred("inspect")
func inspect():
	for path in ["res://TripoModels/mecha_3d_model/mecha_3d_model.fbx", "res://TripoModels/mecha_robot_3d_model/mecha_robot_3d_model.fbx", "res://TripoModels/mecha_robot_3d_model_1/mecha_robot_3d_model_1.fbx"]:
		var node = load(path).instantiate()
		root.add_child(node)
		print(path)
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			print(mesh.name, " bounds=", mesh.get_aabb(), " transform=", mesh.global_transform)
		node.free()
	quit()
