extends CharacterBody3D

@export var walk_speed: float = 4.3
@export var sprint_speed: float = 6.7
@export var jump_velocity: float = 4.4
@export var mouse_sensitivity: float = 0.0022
@export var bob_frequency: float = 2.1
@export var bob_amplitude: float = 0.045

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var wand_pivot: Node3D = $Head/Camera3D/WandPivot
@onready var lumos_spot: SpotLight3D = $Head/Camera3D/WandPivot/LumosSpot
@onready var lumos_omni: OmniLight3D = $Head/Camera3D/WandPivot/LumosOmni
@onready var wand_tip_mesh: MeshInstance3D = $Head/Camera3D/WandPivot/WandTipMesh

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var bob_time: float = 0.0
var lumos_on: bool = false
var current_interactable: Interactable = null
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var base_cam_pos: Vector3
var base_wand_pos: Vector3

signal interactable_changed(prompt: String)
signal lumos_toggled(enabled: bool)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	base_cam_pos = camera.position
	base_wand_pos = wand_pivot.position
	_apply_lumos_state(false)
	GameManager.camera_shake_requested.connect(_on_camera_shake_requested)


func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	shake_intensity = max(shake_intensity, intensity)
	shake_timer = max(shake_timer, duration)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_modal_open or get_tree().paused:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82.0), deg_to_rad(82.0))

	if event.is_action_pressed("lumos"):
		_apply_lumos_state(not lumos_on)

	if event.is_action_pressed("interact") and current_interactable != null:
		current_interactable.interact(self)


func _physics_process(delta: float) -> void:
	if GameManager.is_modal_open or get_tree().paused:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction != Vector3.ZERO:
		var accel := 11.0 if is_on_floor() else 3.5
		velocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta * target_speed * 0.45)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, accel * delta * target_speed * 0.45)
	else:
		var decel := 14.0 if is_on_floor() else 1.5
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	move_and_slide()
	_update_head_bob_and_shake(delta)
	_update_interact_ray()


func _update_head_bob_and_shake(delta: float) -> void:
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_speed > 0.2:
		bob_time += delta * horiz_speed * bob_frequency
	else:
		bob_time = 0.0

	var bob_offset := Vector3(
		cos(bob_time * 0.5) * bob_amplitude * 0.5,
		sin(bob_time) * bob_amplitude,
		0.0
	)
	var shake_offset := Vector3.ZERO
	if shake_timer > 0.0:
		shake_timer = max(0.0, shake_timer - delta)
		shake_offset = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			0.0
		) * shake_intensity
		if shake_timer <= 0.0:
			shake_intensity = 0.0

	var speed_factor := clampf(horiz_speed / sprint_speed, 0.0, 1.0)
	camera.position = camera.position.lerp(base_cam_pos + bob_offset * speed_factor + shake_offset, delta * 14.0)
	wand_pivot.position = wand_pivot.position.lerp(
		base_wand_pos + Vector3(bob_offset.x * 0.35, -bob_offset.y * 0.4, 0.0) * speed_factor,
		delta * 10.0
	)


func _update_interact_ray() -> void:
	var found: Interactable = null
	if interact_ray.is_colliding():
		var collider := interact_ray.get_collider()
		if collider is Node:
			found = _find_interactable_ancestor(collider)

	if found != current_interactable:
		current_interactable = found

	if current_interactable != null and current_interactable.can_interact():
		emit_signal("interactable_changed", current_interactable.get_prompt())
	else:
		emit_signal("interactable_changed", "")


func _find_interactable_ancestor(node: Node) -> Interactable:
	var cur := node
	while cur != null:
		if cur is Interactable:
			return cur
		cur = cur.get_parent()
	return null


func _apply_lumos_state(enabled: bool) -> void:
	lumos_on = enabled
	lumos_spot.visible = enabled
	lumos_omni.visible = enabled
	var mat := wand_tip_mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.emission_enabled = enabled
		mat.emission_energy_multiplier = 4.5 if enabled else 0.0
	emit_signal("lumos_toggled", lumos_on)
