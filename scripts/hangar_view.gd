extends Node3D
# 1/2/3: composed views. Right mouse + WASD/QE: fly. Shift: faster. R: reset.
var cameras: Array[Camera3D] = []
var original_transforms: Array[Transform3D] = []
var active_index := 0
func _ready() -> void:
	for child in $"09_Cameras".get_children():
		cameras.append(child as Camera3D)
		original_transforms.append(child.transform)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			active_index = event.keycode - KEY_1
			cameras[active_index].make_current()
		if event.keycode == KEY_P:
			$"10_PSXPresentation".visible = not $"10_PSXPresentation".visible
		if event.keycode == KEY_T:
			$"11_TiltShift".visible = not $"11_TiltShift".visible
		if event.keycode == KEY_R:
			cameras[active_index].transform = original_transforms[active_index]
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var cam = cameras[active_index]
		cam.rotation.y -= event.relative.x * 0.003
		cam.rotation.x = clampf(cam.rotation.x - event.relative.y * 0.003,-1.5,1.5)
func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var cam = cameras[active_index]
	cam.position += cam.basis * direction.normalized() * delta * (18.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 7.0)
