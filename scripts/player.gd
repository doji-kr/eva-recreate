extends Node3D
## A billboard character on the front bridge and adjoining maintenance aisles.
@export var move_speed := 2.4
@export var run_speed := 4.2
const DIRECTIONS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
var facing := Vector3.FORWARD * -1.0
@onready var sprite: AnimatedSprite3D = $Sprite

func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var down := Vector3(-right.z, 0.0, right.x)
	var input := Vector2.ZERO
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		input = Vector2(
			float(_held(KEY_D, KEY_RIGHT)) - float(_held(KEY_A, KEY_LEFT)),
			float(_held(KEY_S, KEY_DOWN)) - float(_held(KEY_W, KEY_UP))).limit_length()
	var previous_position := position
	var direction := right * input.x + down * input.y
	if not direction.is_zero_approx():
		facing = direction
		var speed := run_speed if Input.is_physical_key_pressed(KEY_SHIFT) else move_speed
		var step := direction * speed * delta
		# Axis-separated movement slides along the walkway edges. Substeps prevent
		# crossing the dock opening at low frame rates or with high custom speeds.
		var steps := maxi(1, ceili(step.length() / 0.1))
		for i in range(steps):
			var candidate := position + Vector3(step.x / steps, 0.0, 0.0)
			if _on_walkway(candidate):
				position = candidate
			candidate = position + Vector3(0.0, 0.0, step.z / steps)
			if _on_walkway(candidate):
				position = candidate
	var angle := atan2(facing.dot(down), facing.dot(right))
	var direction_index := posmod(roundi(angle / (PI / 4.0)), 8)
	var moving := not position.is_equal_approx(previous_position)
	var animation_name: String = DIRECTIONS[direction_index]
	if moving:
		animation_name = "walk_" + animation_name
	sprite.speed_scale = run_speed / move_speed if moving and Input.is_physical_key_pressed(KEY_SHIFT) and move_speed > 0.0 else 1.0
	sprite.play(animation_name)

func _held(primary: Key, alternate: Key) -> bool:
	return Input.is_physical_key_pressed(primary) or Input.is_physical_key_pressed(alternate)

func _on_walkway(point: Vector3) -> bool:
	# Keep clear of the railings, dock opening and rear restraint pedestals.
	var bridge := absf(point.x) <= 8.55 and point.z >= 5.05 and point.z <= 6.15
	var aisle := absf(point.x) >= 5.9 and absf(point.x) <= 8.55 and point.z >= -1.4 and point.z <= 12.3
	return bridge or aisle
