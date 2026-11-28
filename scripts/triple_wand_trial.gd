extends "res://scripts/mission_station.gd"

signal trial_completed(result: Dictionary)

enum TrialState { READY, PLAYING, COMPLETED }

const TrialHUD := preload("res://scripts/triple_wand_hud.gd")
const TrialScore := preload("res://scripts/triple_wand_score.gd")
const WAND_COUNT := 3
const GOLD := Color("ffc66a")
const MAX_VOLTAGE := 5.0

@export_group("Calibration")
@export_range(0.0, 5.0, 0.01) var wand_1_target := 2.0
@export_range(0.0, 5.0, 0.01) var wand_2_target := 3.0
@export_range(0.0, 5.0, 0.01) var wand_3_target := 4.0
@export_range(0.01, 1.0, 0.01) var tolerance_volts := 0.15
@export var calibration_sound: AudioStream

@export_group("Score Benchmarks")
@export_range(0.0, 600.0, 0.1, "or_greater") var fast_time := TrialScore.DEFAULT_FAST_TIME
@export_range(0.1, 600.0, 0.1, "or_greater") var slow_time := TrialScore.DEFAULT_SLOW_TIME

@onready var booth_camera: Camera3D = $BoothCamera
@onready var console_downlight: SpotLight3D = $ConsoleDownlight

var trial_state := TrialState.READY
var _open := false
var _started_usec := 0
var _result: Dictionary = {}
var _voltages: Array[float] = [0.0, 0.0, 0.0]
var _targets: Array[float] = []
var _calibrated: Array[bool] = [false, false, false]
var _selected := 0
var _dragging := false
var _drag_voltage := 0.0
var _knobs: Array[MeshInstance3D] = []
var _dial_bases: Array[Basis] = []
var _wand_materials: Array[StandardMaterial3D] = []
var _led_materials: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []
var _sparks: Array[CPUParticles3D] = []
var _wand_tweens: Array[Tween] = [null, null, null]
var _burst: CPUParticles3D
var _success_tween: Tween
var _chime: AudioStreamPlayer
var _previous_camera: Camera3D
var _hud: TrialHUD


func _ready() -> void:
	super._ready()
	_targets.assign([wand_1_target, wand_2_target, wand_3_target])
	if slow_time <= fast_time:
		push_warning("Triple Wand Trial requires Slow Time > Fast Time. Using 20 s / 90 s for scoring.")
	for i in range(WAND_COUNT):
		var knob := get_node("Knob%d" % (i + 1)) as MeshInstance3D
		var plate := get_node("DialPlate%d" % (i + 1)) as MeshInstance3D
		var wand := get_node("Wand%d" % (i + 1)) as MeshInstance3D
		var led := get_node("Led%d" % (i + 1)) as MeshInstance3D
		_knobs.append(knob)
		_dial_bases.append(plate.basis.orthonormalized())
		_wand_materials.append(_copy_material(wand))
		_led_materials.append(_copy_material(led))
		var light := OmniLight3D.new()
		light.position = led.position + Vector3.UP * 0.08
		light.light_color = GOLD
		light.light_energy = 0.4
		light.omni_range = 0.45
		add_child(light)
		_lights.append(light)
		_sparks.append(_make_sparks(wand.position, false))
	_burst = _make_sparks(Vector3(0.0, 1.03, 0.1), true)
	if calibration_sound:
		_chime = AudioStreamPlayer.new()
		_chime.stream = calibration_sound
		_chime.volume_db = -12.0
		add_child(_chime)
	_hud = TrialHUD.new()
	add_child(_hud)
	_hud.start_requested.connect(_start_attempt)
	_hud.back_requested.connect(_close_trial)
	_hud.retry_requested.connect(_prepare_attempt)
	_hud.continue_requested.connect(_accept_result)
	_prepare_attempt()
	_hud.hide()


func interact(player: Node3D) -> void:
	if GameManager.state == GameManager.MissionState.TRAPPED_IN_ROOM2:
		super.interact(player)
		return
	if _open or GameManager.is_modal_open:
		return
	_open = true
	_previous_camera = get_viewport().get_camera_3d()
	booth_camera.make_current()
	GameManager.set_wand_trial_open(true)
	_prepare_attempt()
	_hud.show()
	_hud.focus_start()
	GameManager.mission_station_interacted.emit(station_id, step_number, station_title)


func _process(delta: float) -> void:
	if _success_tween == null or not _success_tween.is_running():
		super._process(delta)
	if trial_state == TrialState.PLAYING:
		_hud.set_elapsed(_elapsed_seconds())


func _prepare_attempt() -> void:
	if trial_state == TrialState.PLAYING:
		return
	trial_state = TrialState.READY
	console_downlight.hide()
	_started_usec = 0
	_result = {}
	_selected = 0
	_dragging = false
	if _success_tween:
		_success_tween.kill()
	_burst.emitting = false
	for i in range(WAND_COUNT):
		_voltages[i] = 0.0
		_calibrated[i] = false
		_update_knob(i)
		_set_glow(i, false)
	_hud.set_elapsed(0.0)
	_refresh_progress()
	_hud.show_instructions()


func _start_attempt() -> void:
	if not _open or trial_state != TrialState.READY or get_tree().paused:
		return
	_started_usec = Time.get_ticks_usec()
	trial_state = TrialState.PLAYING
	console_downlight.show()
	_hud.show_playing()
	_evaluate_calibration()


func _elapsed_seconds() -> float:
	# Monotonic wall time includes pauses and time spent outside the window.
	return float(Time.get_ticks_usec() - _started_usec) / 1_000_000.0


func _set_voltage(index: int, volts: float) -> void:
	if trial_state != TrialState.PLAYING or get_tree().paused:
		return
	_voltages[index] = snappedf(clampf(volts, 0.0, MAX_VOLTAGE), 0.01)
	_update_knob(index)
	_evaluate_calibration()


func _evaluate_calibration() -> void:
	for i in range(WAND_COUNT):
		var in_range := absf(_voltages[i] - _targets[i]) <= tolerance_volts + 0.000001
		if _calibrated[i] != in_range:
			_calibrated[i] = in_range
			_set_glow(i, in_range)
	_refresh_progress()
	if _calibrated.count(true) == WAND_COUNT:
		_finish_attempt()


func _finish_attempt() -> void:
	if trial_state != TrialState.PLAYING:
		return
	var elapsed := _elapsed_seconds()
	trial_state = TrialState.COMPLETED
	console_downlight.hide()
	_dragging = false
	_result = TrialScore.calculate(elapsed, fast_time, slow_time)
	_hud.set_elapsed(elapsed)
	_hud.show_completion(_result)
	_burst.restart()
	_burst.emitting = true
	_success_tween = create_tween()
	_success_tween.tween_property(accent_light, "light_energy", base_energy * 2.6, 0.16)
	_success_tween.tween_property(accent_light, "light_energy", base_energy, 0.75)
	trial_completed.emit(_result.duplicate())


func _accept_result() -> void:
	if not _open or trial_state != TrialState.COMPLETED or get_tree().paused:
		return
	var accepted := _result.duplicate()
	_close_trial()
	GameManager.accept_wand_trial_result(accepted)


func _close_trial() -> void:
	if not _open or trial_state == TrialState.PLAYING:
		return
	_open = false
	_hud.hide()
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	else:
		booth_camera.clear_current()
	GameManager.set_wand_trial_open(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if not _open or trial_state != TrialState.PLAYING:
		return
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				_selected = event.physical_keycode - KEY_1
				_dragging = false
				_refresh_progress()
			KEY_LEFT, KEY_DOWN:
				_set_voltage(_selected, _voltages[_selected] - 0.1)
			KEY_RIGHT, KEY_UP:
				_set_voltage(_selected, _voltages[_selected] + 0.1)
			_:
				return
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _dragging:
			_dragging = false
		elif event.pressed:
			var index := _knob_at(event.position)
			if index < 0:
				return
			_selected = index
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_dragging = true
					_drag_voltage = _voltages[index]
					_refresh_progress()
				MOUSE_BUTTON_WHEEL_UP:
					_set_voltage(index, _voltages[index] + 0.1)
				MOUSE_BUTTON_WHEEL_DOWN:
					_set_voltage(index, _voltages[index] - 0.1)
				_:
					return
		else:
			return
	elif event is InputEventMouseMotion and _dragging:
		_drag_voltage = clampf(_drag_voltage + event.relative.x * 0.01, 0.0, MAX_VOLTAGE)
		_set_voltage(_selected, _drag_voltage)
	else:
		return
	get_viewport().set_input_as_handled()


func _knob_at(point: Vector2) -> int:
	var nearest := -1
	var best_distance := INF
	for i in range(WAND_COUNT):
		var knob_position := _knobs[i].global_position
		var center := booth_camera.unproject_position(knob_position)
		var edge := booth_camera.unproject_position(knob_position + booth_camera.global_basis.x * 0.105)
		var distance := center.distance_to(point)
		if distance <= center.distance_to(edge) and distance < best_distance:
			nearest = i
			best_distance = distance
	return nearest


func _refresh_progress() -> void:
	_hud.set_wands(_voltages, _calibrated, _selected)


func _update_knob(index: int) -> void:
	var angle := lerpf(135.0, -135.0, _voltages[index] / MAX_VOLTAGE)
	_knobs[index].basis = _dial_bases[index] * Basis(Vector3.UP, deg_to_rad(angle))


func _copy_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	var material := mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
	material.emission = GOLD
	mesh.set_surface_override_material(0, material)
	return material


func _set_glow(index: int, active: bool) -> void:
	if _wand_tweens[index]:
		_wand_tweens[index].kill()
	var wand_material := _wand_materials[index]
	var led_material := _led_materials[index]
	wand_material.emission_enabled = active
	led_material.emission_enabled = active
	led_material.albedo_color = GOLD if active else Color("38251b")
	led_material.emission_energy_multiplier = 1.5
	wand_material.emission_energy_multiplier = 0.0
	_lights[index].visible = active
	_sparks[index].emitting = active
	if active:
		if _chime:
			_chime.play()
		var pulse := create_tween().set_trans(Tween.TRANS_SINE)
		pulse.tween_property(wand_material, "emission_energy_multiplier", 1.4, 0.18)
		pulse.tween_property(wand_material, "emission_energy_multiplier", 0.65, 0.4)
		_wand_tweens[index] = pulse


func _make_sparks(at: Vector3, burst: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.008 if burst else 0.005
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GOLD
	mesh.material = material
	particles.mesh = mesh
	particles.amount = 24 if burst else 7
	particles.lifetime = 0.8 if burst else 1.1
	particles.one_shot = burst
	particles.explosiveness = 0.9 if burst else 0.0
	particles.direction = Vector3.UP
	particles.spread = 65.0 if burst else 30.0
	particles.gravity = Vector3(0.0, -0.36 if burst else 0.035, 0.0)
	particles.initial_velocity_min = 0.2 if burst else 0.02
	particles.initial_velocity_max = 1.1 if burst else 0.16
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.4 if burst else 0.14, 0.01, 0.04)
	particles.position = at + Vector3.UP * 0.03
	particles.emitting = false
	add_child(particles)
	return particles
