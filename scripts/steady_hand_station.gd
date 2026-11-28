extends "res://scripts/mission_station.gd"
## Game 3: makes Flitwick's Steady Hand table playable. Press E to play.

## Sent when the player finishes, so the door logic can listen for it.
signal trial_completed(step: int, hit_count: int)

const RING_RADIUS := 0.075
const RING_TUBE := 0.01
const WIRE_RADIUS := 0.014
const SAMPLES := 600
const MOUSE_SPEED := 0.001
# The joints of the wire already on the table.
const WIRE: Array[Vector3] = [
	Vector3(-0.46, 1.18, -0.05), Vector3(-0.24, 1.46, -0.05), Vector3(0.0, 1.14, -0.05),
	Vector3(0.24, 1.48, -0.05), Vector3(0.46, 1.18, -0.05)]

var points := PackedVector3Array()
var ring: MeshInstance3D
var ring_material: StandardMaterial3D
var game_camera: Camera3D
var hud: CanvasLayer
var info: Label
var sound: AudioStreamPlayer

var player: Node3D = null
var active := false
var finished := false
var touching := false
var progress := 0
var hits := 0


func _ready() -> void:
	super()
	$ProbeRing.visible = false
	$ProbeHandle.visible = false
	_build_points()
	_build_ring()
	_build_decorations()
	_build_screen()
	_reset_ring()


# ---------- Interaction ----------
func get_prompt() -> String:
	if GameManager.state == GameManager.MissionState.TRAPPED_IN_ROOM2:
		return super()
	return "[E] Play Flitwick's Steady Hand Test"


func interact(who: Node3D) -> void:
	if active:
		return
	if GameManager.state == GameManager.MissionState.TRAPPED_IN_ROOM2:
		super(who)  # "read the lectern first" message
		return
	GameManager.emit_signal("mission_station_interacted", station_id, step_number, station_title)
	player = who
	active = true
	GameManager.is_modal_open = true  # freezes player movement
	player.set("velocity", Vector3.ZERO)
	player.emit_signal("interactable_changed", "")
	player.visible = false
	game_camera.make_current()
	hud.visible = true
	_reset_ring()
	# Stops this same E press from closing the game again.
	get_viewport().set_input_as_handled()


func _leave() -> void:
	active = false
	GameManager.is_modal_open = false
	hud.visible = false
	player.visible = true
	var player_camera: Camera3D = player.get_node("Head/Camera3D")
	player_camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("interact"):
		_leave()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		_reset_ring()
	elif event is InputEventMouseMotion:
		_move_ring(Vector3(event.relative.x, -event.relative.y, 0.0) * MOUSE_SPEED)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_ring(Vector3(0.0, 0.0, -0.01))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_ring(Vector3(0.0, 0.0, 0.01))


func _process(delta: float) -> void:
	super(delta)
	if not active:
		return
	var depth := Input.get_axis("move_forward", "move_backward")
	if depth != 0.0:
		_move_ring(Vector3(0.0, 0.0, depth * 0.12 * delta))


# ---------- Game rules ----------
func _reset_ring() -> void:
	progress = 0
	hits = 0
	touching = false
	finished = false
	ring.position = points[0]
	ring_material.albedo_color = Color(1.0, 0.78, 0.2)
	_face_wire()
	_update_info()
	if active:
		_play([523.0, 784.0], 0.14)


func _move_ring(step: Vector3) -> void:
	if finished:
		return
	# Small steps only, so the ring cannot jump through the wire.
	ring.position += step.limit_length(0.02)

	# Search near the current spot only, so there are no shortcuts.
	var best := progress
	var distance := INF
	for i in range(maxi(0, progress - 30), mini(SAMPLES, progress + 30) + 1):
		var d := ring.position.distance_to(points[i])
		if d < distance:
			distance = d
			best = i
	progress = best
	_face_wire()

	var now_touching := distance > RING_RADIUS - RING_TUBE - WIRE_RADIUS
	if now_touching and not touching:
		hits += 1
		_play([110.0], 0.2)
	touching = now_touching
	ring_material.albedo_color = Color(1.0, 0.15, 0.15) if touching else Color(1.0, 0.78, 0.2)

	# Completely off the wire: put the ring back on.
	if distance > RING_RADIUS:
		ring.position = points[progress]

	if progress >= SAMPLES - 5:
		finished = true
		trial_completed.emit(step_number, hits)
		_play([523.0, 659.0, 784.0, 1047.0], 0.18)
	_update_info()


func _face_wire() -> void:
	var a := points[maxi(0, progress - 3)]
	var b := points[mini(SAMPLES, progress + 3)]
	var normal := ((b - a).normalized() + Vector3(0.0, 0.0, 0.6)).normalized()
	ring.quaternion = Quaternion(Vector3.UP, normal)


func _update_info() -> void:
	var text := "STEADY HAND TEST    Hits: %d\n" % hits
	if finished:
		text += "Success!  R: play again   E: leave"
	else:
		text += "Mouse: move ring   W/S or scroll: depth   R: restart   E: leave"
	info.text = text


# ---------- Sound ----------
func _play(notes: Array, length: float) -> void:
	var rate := 22050
	var count := int(rate * length)
	var data := PackedByteArray()
	data.resize(count * notes.size() * 2)
	var offset := 0
	for pitch in notes:
		for i in count:
			var fade := 1.0 - float(i) / count
			var value := sin(TAU * pitch * i / rate) * fade * 0.35
			data.encode_s16(offset, int(value * 32767.0))
			offset += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	sound.stream = wav
	sound.play()


# ---------- Building ----------
func _build_points() -> void:
	var total := 0.0
	for i in WIRE.size() - 1:
		total += WIRE[i].distance_to(WIRE[i + 1])
	for s in SAMPLES + 1:
		var left := total * s / SAMPLES
		var segment := 0
		while segment < WIRE.size() - 2 and left > WIRE[segment].distance_to(WIRE[segment + 1]):
			left -= WIRE[segment].distance_to(WIRE[segment + 1])
			segment += 1
		var length := WIRE[segment].distance_to(WIRE[segment + 1])
		points.append(WIRE[segment].lerp(WIRE[segment + 1], clampf(left / length, 0.0, 1.0)))


func _add_mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


func _flat(color: Color, glow := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _build_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - RING_TUBE
	torus.outer_radius = RING_RADIUS + RING_TUBE
	ring_material = _flat(Color(1.0, 0.78, 0.2))
	ring_material.metallic = 0.6
	ring_material.roughness = 0.3
	ring = _add_mesh(torus, ring_material, points[0])


func _build_decorations() -> void:
	# Hanging bulbs and a warning card.
	var bulb := _flat(Color(1.0, 0.65, 0.25), 3.0)
	var cord := _flat(Color(0.05, 0.04, 0.03))
	for x in [-0.6, 0.0, 0.6]:
		var wire_mesh := BoxMesh.new()
		wire_mesh.size = Vector3(0.008, 0.8, 0.008)
		_add_mesh(wire_mesh, cord, Vector3(x, 2.65, -0.1))
		var sphere := SphereMesh.new()
		sphere.radius = 0.04
		sphere.height = 0.1
		_add_mesh(sphere, bulb, Vector3(x, 2.2, -0.1))
	var label := Label3D.new()
	label.text = "Try not to touch the wire!"
	label.font_size = 40
	label.pixel_size = 0.0016
	label.modulate = Color(1.0, 0.9, 0.65)
	label.position = Vector3(0.0, 1.68, -0.1)
	add_child(label)


func _build_screen() -> void:
	game_camera = Camera3D.new()
	game_camera.fov = 60.0
	game_camera.near = 0.05
	game_camera.position = Vector3(0.0, 1.52, 0.9)
	game_camera.rotation.x = -atan2(0.21, 0.95)
	add_child(game_camera)

	hud = CanvasLayer.new()
	hud.layer = 0
	hud.visible = false
	info = Label.new()
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_top = -190.0
	info.offset_bottom = -135.0
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 22)
	info.add_theme_constant_override("outline_size", 6)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_child(info)
	add_child(hud)

	sound = AudioStreamPlayer.new()
	add_child(sound)
