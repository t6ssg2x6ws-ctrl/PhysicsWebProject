extends "res://scripts/mission_station.gd"
## All gameplay, presentation and session records belong to this station only.
const LEVELS := 5
const MAX_ATTEMPTS := 3
const GREEN := Color(0.35, 0.95, 0.58)
const SILVER := Color(0.78, 0.86, 0.9)
const RED := Color(1.0, 0.19, 0.23)
enum Phase { CLOSED, INTRO, WATCH, INPUT, FEEDBACK, RETRY, LOST, WON }
var phase := Phase.CLOSED
var sequence: Array[int] = []
var level := 1
var cursor := 0
var score := 0
var highest := 0
var mistakes := 0
var attempts_left := MAX_ATTEMPTS
var generation := 0
var opened := false
var previous_camera: Camera3D
var previous_mouse: int
var trial_camera: Camera3D
var overlay: CanvasLayer
var dialogue: Label
var stats: Label
var action: Button
var progress: ProgressBar
var particles: CPUParticles3D
var sparks: CPUParticles3D
var feedback_light: OmniLight3D
var potion_materials: Array[StandardMaterial3D] = []
var button_materials: Array[StandardMaterial3D] = []
var potion_lights: Array[OmniLight3D] = []
var button_positions: Array[Vector3] = []
var button_tweens: Array[Tween] = []
var glow_tweens: Array[Tween] = []
@onready var potions: Array[MeshInstance3D] = [$PotionLeft, $PotionTop, $PotionRight]
@onready var caps: Array[MeshInstance3D] = [$BtnCap1, $BtnCap2, $BtnCap3]

func _ready() -> void:
	super._ready()
	for i in range(3):
		var pm := potions[i].get_surface_override_material(0).duplicate() as StandardMaterial3D
		var bm := caps[i].get_surface_override_material(0).duplicate() as StandardMaterial3D
		potions[i].set_surface_override_material(0, pm)
		caps[i].set_surface_override_material(0, bm)
		pm.emission_energy_multiplier = 0.18
		bm.emission_energy_multiplier = 0.35
		potion_materials.append(pm)
		button_materials.append(bm)
		button_positions.append(caps[i].position)
		var lamp := OmniLight3D.new()
		lamp.light_color = pm.emission
		lamp.light_energy = 0.0
		lamp.omni_range = 0.75
		potions[i].add_child(lamp)
		potion_lights.append(lamp)
		button_tweens.append(null)
		glow_tweens.append(null)
	trial_camera = Camera3D.new()
	add_child(trial_camera)
	trial_camera.position = Vector3(0, 2.45, 2.2)
	trial_camera.look_at(to_global(Vector3(0, 1.0, 0.0)))
	trial_camera.fov = 50.0
	feedback_light = OmniLight3D.new()
	add_child(feedback_light)
	feedback_light.position = Vector3(0, 1.45, 0.15)
	feedback_light.omni_range = 2.0
	feedback_light.light_energy = 0.0
	particles = _make_particles(22, false, GREEN)
	particles.position = $CauldronBrew.position + Vector3(0, 0.08, 0)
	particles.emitting = true
	sparks = _make_particles(36, true, GREEN)
	sparks.emitting = false
	_build_ui()

func _make_particles(count: int, burst: bool, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = count
	p.lifetime = 0.85 if burst else 1.8
	p.one_shot = burst
	p.explosiveness = 0.9 if burst else 0.0
	p.direction = Vector3.UP
	p.spread = 75.0 if burst else 24.0
	p.gravity = Vector3(0, -0.25 if burst else 0.08, 0)
	p.initial_velocity_min = 0.18
	p.initial_velocity_max = 0.85 if burst else 0.35
	p.scale_amount_min = 0.45
	p.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.036
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mesh.material = mat
	p.mesh = mesh
	p.color = color
	add_child(p)
	return p

func interact(player: Node3D) -> void:
	if GameManager.state == GameManager.MissionState.TRAPPED_IN_ROOM2:
		super.interact(player)
		return
	if opened or GameManager.is_modal_open:
		return
	# Preserve the original interaction signal, without changing mission state or relics.
	GameManager.emit_signal("mission_station_interacted", station_id, step_number, station_title)
	previous_camera = get_viewport().get_camera_3d()
	previous_mouse = Input.get_mouse_mode()
	opened = true
	GameManager.is_modal_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	trial_camera.make_current()
	overlay.show()
	_new_attempt()

func _new_attempt() -> void:
	generation += 1
	_reset_glows()
	sequence.clear()
	level = 1
	cursor = 0
	score = 0
	mistakes = 0
	attempts_left = MAX_ATTEMPTS
	phase = Phase.INTRO
	_say("Observe the potions, then repeat their order using the rune keys. Five rounds, each with a fresh, longer and faster sequence. Three mistakes end the trial. Try not to embarrass yourself.")
	_set_action("Begin trial")
	_refresh()

func _generate_sequence() -> void:
	# Fresh patterns, not an extension of the previous round or retry.
	var previous: Array[int] = sequence.duplicate()
	var length := level + 2
	while true:
		sequence.clear()
		for i in range(length):
			sequence.append(randi_range(0, 2))
		# Require at least two distinct potions and reject the old prefix.
		var varied := false
		for i in range(1, length):
			if sequence[i] != sequence[0]:
				varied = true
				break
		if varied and (previous.is_empty() or sequence.slice(0, previous.size()) != previous):
			return

func _start_round() -> void:
	phase = Phase.WATCH
	cursor = 0
	_generate_sequence()
	_refresh()
	_set_action("")
	_say("Round %d. %s" % [level, ["Observe carefully.", "A little concentration, if you please.", "Now, without hesitation.", "The brew grows impatient.", "Your final examination."][level - 1]])
	var token := generation
	await get_tree().create_timer(1.15, false).timeout
	if not _valid(token):
		return
	var duration := maxf(0.28, 0.72 - (level - 1) * 0.11)
	for index in sequence:
		_glow(index, true, 0.10)
		await get_tree().create_timer(duration, false).timeout
		if not _valid(token):
			return
		_glow(index, false, 0.12)
		await get_tree().create_timer(maxf(0.18, duration * 0.42), false).timeout
		if not _valid(token):
			return
	phase = Phase.INPUT
	_say("Your turn. Click the original rune keys, or press 1 (left), 2 (top), 3 (right). In the exact order, naturally.")
	_refresh()

func _valid(token: int) -> bool:
	return opened and token == generation and is_inside_tree()

func _input(event: InputEvent) -> void:
	if not opened or get_tree().paused:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index := -1
		match event.physical_keycode:
			KEY_1, KEY_KP_1: index = 0
			KEY_2, KEY_KP_2: index = 1
			KEY_3, KEY_KP_3: index = 2
		if index >= 0:
			get_viewport().set_input_as_handled()
			_choose(index)

func _unhandled_input(event: InputEvent) -> void:
	if not opened or phase != Phase.INPUT:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Pick the existing 3D caps in screen space; no replacement buttons or shared collision edits.
		var closest := -1
		var distance := 44.0
		for i in range(3):
			var d := trial_camera.unproject_position(caps[i].global_position).distance_to(event.position)
			if d < distance:
				distance = d
				closest = i
		if closest >= 0:
			get_viewport().set_input_as_handled()
			_choose(closest)

func _choose(index: int) -> void:
	if phase != Phase.INPUT:
		return
	phase = Phase.FEEDBACK
	_press(index)
	var token := generation
	if index != sequence[cursor]:
		mistakes += 1
		attempts_left -= 1
		_say("Wrong. A remarkable talent for remembering absolutely nothing. Chances remaining: %d." % attempts_left)
		_flash(RED, 1.7)
		_burst(caps[index].position, RED)
		_refresh()
		await get_tree().create_timer(0.65, false).timeout
		if not _valid(token):
			return
		if attempts_left > 0:
			phase = Phase.RETRY
			_say("Again. A different sequence awaits. You have %d chances left; do not squander them." % attempts_left)
			_set_action("Retry round")
		else:
			phase = Phase.LOST
			_say("Three mistakes. Class dismissed. Final score: %d. Levels completed: %d/%d. Best level: %d." % [score, level - 1, LEVELS, highest])
			_set_action("Replay trial")
		_refresh()
		return
	cursor += 1
	_glow(index, true, 0.08)
	_burst(caps[index].position, GREEN)
	_say("Correct. Even a stopped clock is right twice a day.")
	_refresh()
	await get_tree().create_timer(0.24, false).timeout
	if not _valid(token):
		return
	_glow(index, false, 0.13)
	if cursor < sequence.size():
		phase = Phase.INPUT
		return
	# Credit a round only once, and award its bonus only if the attempt was clean.
	var bonus := 50 if mistakes == 0 else 0
	score += level * 100 + bonus
	highest = maxi(highest, level)
	_refresh()
	if level == LEVELS:
		phase = Phase.WON
		_say("Impressive. Five rounds, and not a single cauldron exploded. Final score: %d. Chances left: %d. Slytherin would approve. Quietly." % [score, attempts_left])
		_set_action("Replay trial")
		_victory(token)
	else:
		_say("Adequate. Round complete: +%d points. Prepare for a longer sequence." % (level * 100 + bonus))
		await get_tree().create_timer(1.25, false).timeout
		if not _valid(token):
			return
		level += 1
		mistakes = 0
		_start_round()

func _retry() -> void:
	if phase != Phase.RETRY or attempts_left <= 0:
		return
	generation += 1
	_reset_glows()
	_start_round()

func _glow(index: int, active: bool, duration: float) -> void:
	if glow_tweens[index] != null:
		glow_tweens[index].kill()
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	glow_tweens[index] = t
	t.tween_property(potion_materials[index], "emission_energy_multiplier", 5.0 if active else 0.18, duration)
	t.tween_property(potion_lights[index], "light_energy", 0.85 if active else 0.0, duration)

func _press(index: int) -> void:
	if button_tweens[index] != null:
		button_tweens[index].kill()
	var t := create_tween()
	button_tweens[index] = t
	t.tween_property(caps[index], "position", button_positions[index] - Vector3(0, 0.015, 0), 0.07)
	t.parallel().tween_property(button_materials[index], "emission_energy_multiplier", 4.0, 0.07)
	t.tween_property(caps[index], "position", button_positions[index], 0.15)
	t.parallel().tween_property(button_materials[index], "emission_energy_multiplier", 0.35, 0.15)

var flash_tween: Tween
func _flash(color: Color, energy: float) -> void:
	if flash_tween != null:
		flash_tween.kill()
	feedback_light.light_color = color
	feedback_light.light_energy = energy
	flash_tween = create_tween()
	flash_tween.tween_property(feedback_light, "light_energy", 0.0, 0.65)

func _burst(at: Vector3, color: Color) -> void:
	sparks.position = at + Vector3(0, 0.12, 0)
	sparks.color = color
	sparks.restart()
	sparks.emitting = true

func _victory(token: int) -> void:
	for i in range(3):
		if not _valid(token):
			return
		_glow(i, true, 0.2)
		_flash(GREEN if i % 2 == 0 else SILVER, 2.0)
		_burst(potions[i].position, SILVER if i % 2 == 0 else GREEN)
		await get_tree().create_timer(0.32, false).timeout
	if _valid(token):
		for i in range(3):
			_glow(i, false, 0.5)

func _reset_glows() -> void:
	for i in range(3):
		if glow_tweens[i] != null:
			glow_tweens[i].kill()
		if button_tweens[i] != null:
			button_tweens[i].kill()
		potion_materials[i].emission_energy_multiplier = 0.18
		potion_lights[i].light_energy = 0.0
		button_materials[i].emission_energy_multiplier = 0.35
		caps[i].position = button_positions[i]
	if flash_tween != null:
		flash_tween.kill()
	feedback_light.light_energy = 0.0
	sparks.emitting = false

func _close() -> void:
	generation += 1
	opened = false
	phase = Phase.CLOSED
	_reset_glows()
	overlay.hide()
	if is_instance_valid(previous_camera):
		previous_camera.make_current()
	GameManager.is_modal_open = false
	Input.set_mouse_mode(previous_mouse)

func _exit_tree() -> void:
	if opened:
		GameManager.is_modal_open = false
		Input.set_mouse_mode(previous_mouse)

func _say(line: String) -> void:
	dialogue.text = line

func _refresh() -> void:
	var status := "WATCH" if phase == Phase.WATCH else "REPEAT" if phase == Phase.INPUT else "RETRY" if phase == Phase.RETRY else "FAILED" if phase == Phase.LOST else "VICTORY" if phase == Phase.WON else "READY" if phase == Phase.INTRO else "FEEDBACK"
	stats.text = "%s   |   LEVEL %d/%d   |   SCORE %d   |   BEST LEVEL %d\nCHANCES %d/%d   |   STEPS %d/%d" % [status, level, LEVELS, score, highest, attempts_left, MAX_ATTEMPTS, cursor, sequence.size()]
	stats.modulate = RED if phase == Phase.LOST or phase == Phase.RETRY else GREEN if phase == Phase.WON else SILVER
	progress.max_value = maxi(1, sequence.size())
	progress.value = cursor

func _set_action(label: String) -> void:
	action.text = label
	action.visible = not label.is_empty()

func _action_pressed() -> void:
	match phase:
		Phase.INTRO: _start_round()
		Phase.RETRY: _retry()
		Phase.LOST, Phase.WON: _new_attempt()

func _build_ui() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	var root := Control.new()
	overlay.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 180
	panel.offset_right = -180
	panel.offset_top = -250
	panel.offset_bottom = -22
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.065, 0.045, 0.96)
	style.border_color = Color(0.55, 0.72, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PROFESSOR SNAPE  •  THE MEMORY TRIAL"
	title.add_theme_color_override("font_color", GREEN)
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	stats = Label.new()
	stats.add_theme_font_size_override("font_size", 18)
	box.add_child(stats)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 9
	progress.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = GREEN
	progress.add_theme_stylebox_override("fill", fill)
	box.add_child(progress)
	dialogue = Label.new()
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.add_theme_font_size_override("font_size", 21)
	dialogue.custom_minimum_size.y = 55
	box.add_child(dialogue)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	action = Button.new()
	action.focus_mode = Control.FOCUS_NONE
	action.pressed.connect(_action_pressed)
	controls.add_child(action)
	var close := Button.new()
	close.text = "Leave [Esc]"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close)
	controls.add_child(close)
	overlay.hide()
