extends Node

const MainScene := preload("res://scenes/main.tscn")
const Trial := preload("res://scripts/triple_wand_trial.gd")
const Score := preload("res://scripts/triple_wand_score.gd")

var _failures := 0
var _completed := 0
var _accepted := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	var trial := main.get_node("RoomMission1_Dumbledore/Station1_WandTrial") as Trial
	var common_room = trial.get_parent()
	var player := main.get_node("Player") as Node3D
	var castle_hud = main.get_node("HUD")
	var player_camera := player.get_node("Head/Camera3D") as Camera3D
	_check(get_viewport().get_camera_3d() == player_camera, "the first-person camera owns the view at startup")
	_check(not common_room.revealed and not common_room.hearth_light.visible, "the room starts with the hearth unlit")
	_check(common_room.has_node("CommonRoomFurnishings/ScarletSettle") and common_room.has_node("CommonRoomFurnishings/LionfrontCabinet"), "both new pieces of common-room furniture are installed")
	_check(not common_room.has_node("BookshelfNW") and not common_room.has_node("BookshelfNE"), "both original Game 1 bookshelves are removed")
	_check(not trial.console_downlight.visible, "the console light is off during exploration")
	_check(trial.console_downlight.light_cull_mask == 2 and trial.console_downlight.light_volumetric_fog_energy == 0.0, "the downlight targets the console layer without lighting room fog")
	for i in range(1, 4):
		var dial := trial.get_node("Knob%d" % i) as MeshInstance3D
		_check(dial.get_layer_mask_value(2), "each knob receives the console-only light")
	_check(castle_hud.control_rows.get_child_count() == 7, "the exploration guide separates the seven controls")
	_check(castle_hud.controls_panel.visible and castle_hud.controls_intro_timer.wait_time == 10.0, "the controls guide opens with a ten-second introduction")
	castle_hud.controls_intro_timer.start(0.03)
	await castle_hud.controls_intro_timer.timeout
	_check(not castle_hud.controls_panel.visible and castle_hud.controls_toggle.visible, "the intro timeout hides the guide and leaves the controls sign")
	var controls_key := InputEventKey.new()
	controls_key.physical_keycode = KEY_H
	controls_key.pressed = true
	get_viewport().push_input(controls_key)
	_check(castle_hud.controls_panel.visible and castle_hud.controls_intro_timer.is_stopped(), "H reopens the guide without another countdown")
	castle_hud.controls_toggle.pressed.emit()
	_check(not castle_hud.controls_panel.visible, "the controls sign can close the reopened guide")
	for fixture in common_room._fixtures:
		_check(not fixture.visible, "the room starts with each main fixture unlit")
	var lumos := InputEventAction.new()
	lumos.action = "lumos"
	lumos.pressed = true
	get_viewport().push_input(lumos)
	_check(player.get_node("Head/Camera3D/WandPivot/LumosSpot").visible, "the F action turns on Lumos during exploration")
	_check(castle_hud._lumos_state_pill.text == "ON", "the guide shows Lumos is on")
	get_viewport().push_input(lumos)
	_check(castle_hud._lumos_state_pill.text == "OFF", "the guide shows Lumos is off")
	trial.trial_completed.connect(func(_result: Dictionary): _completed += 1)
	GameManager.wand_trial_result_accepted.connect(func(_result: Dictionary): _accepted += 1)

	GameManager.trigger_room2_lockdown()
	_check(castle_hud.toast_panel.visible and castle_hud.toast_title.text == "THE DOOR IS SEALED", "lockdown presents the sealed-door warning")
	_check(castle_hud.toast_title.get_theme_font_size("font_size") > castle_hud.toast_action.get_theme_font_size("font_size") and castle_hud.toast_action.get_theme_font_size("font_size") > castle_hud.toast_body.get_theme_font_size("font_size"), "the warning headline, action, and supporting text have descending sizes")
	_check(not castle_hud.objective_panel.visible or castle_hud.toast_panel.get_rect().position.x >= castle_hud.objective_panel.get_rect().end.x + castle_hud.NOTICE_GAP - 1.0, "the warning and objective scrolls never crowd each other")
	trial.interact(player)
	_check(not GameManager.wand_trial_open, "locked chamber requires the lectern")
	GameManager.request_mission_modal()
	var briefing := castle_hud.get_node("Root/MissionModal/Panel/Margin/VBox/TrialList") as VBoxContainer
	_check(castle_hud.mission_modal.visible and briefing.get_child_count() == 4, "the briefing renders one row per trial")
	for card in briefing.get_children():
		_check(card.get_child(0).get_child_count() == 2, "briefing rows contain only number and game name")
	_check(castle_hud.toast_title.get_theme_font("font") == trial._hud._elapsed.get_theme_font("font"), "the castle and trial share the same UI font")
	var mission_panel := castle_hud.mission_modal.get_node("Panel") as PanelContainer
	var start_panel := trial._hud._start.get_child(0) as PanelContainer
	_check(mission_panel.get_theme_stylebox("panel") == start_panel.get_theme_stylebox("panel"), "the mission and trial use the same scroll frame")
	GameManager.accept_mission()
	_check(castle_hud.toast_title.text == "Mission Accepted" and castle_hud.toast_steps.visible and castle_hud.toast_steps.get_child_count() == 3, "accepting the mission reveals three separate steps")
	_check(not castle_hud.objective_panel.visible or castle_hud.toast_panel.get_rect().position.x >= castle_hud.objective_panel.get_rect().end.x + castle_hud.NOTICE_GAP - 1.0, "the accepted notice and objective scrolls keep a visible gap")
	var spawn := player.global_position
	var chambers := ["RoomMission1_Dumbledore", "RoomMission2_Snape", "RoomMission3_Flitwick", "RoomMission4_Guess"]
	for i in range(chambers.size()):
		var room := main.get_node(chambers[i]) as Node3D
		player.global_position = room.global_position
		main._update_current_chamber()
		for row in range(chambers.size()):
			_check((castle_hud._objective_markers[row].modulate.a == 1.0) == (row == i), "exactly the current room has the objective pointer")
		_check(castle_hud._objective_titles[i].text == castle_hud.TRIALS[i], "objective rows use only the game name")
	player.global_position = spawn
	main._update_current_chamber()
	_check(castle_hud._objective_markers[3].modulate.a == 0.0, "leaving the trial rooms clears the pointer")
	var locked_door := main.get_node("EnchantedDoor") as Interactable
	castle_hud.set_interact_prompt(locked_door.get_prompt())
	_check(castle_hud.locked_heading.visible and castle_hud.prompt_label.text == "Complete the 4 Chamber Trials first", "the locked door shows its own warning heading and requirement")
	var stations := [
		trial,
		main.get_node("RoomMission2_Snape/Station2_SnapeMemory"),
		main.get_node("RoomMission3_Flitwick/Station3_FlitwickMaze"),
		main.get_node("RoomMission4_Guess/Station4_GuessSpell"),
	]
	for station in stations:
		var prompt: String = station.get_prompt()
		_check(prompt == "[E] " + station.station_title, "the hover prompt shows only the key and trial title")
	castle_hud.set_interact_prompt(trial.get_prompt())
	_check(not castle_hud.locked_heading.visible and castle_hud.prompt_label.get_theme_font_size("font_size") == 24, "normal prompts restore the larger single-line style")
	trial.interact(player)
	_check(GameManager.wand_trial_open and trial.booth_camera.current, "station opens the booth view")
	trial._hud.back_requested.emit()
	_check(player_camera.current and not GameManager.is_modal_open, "Back restores the first-person camera and controls")
	trial.interact(player)
	trial._set_voltage(0, 2.0)
	_check(trial._voltages[0] == 0.0 and trial._started_usec == 0, "READY blocks controls and timer")
	trial._hud.start_requested.emit()
	var started := trial._started_usec
	_check(trial.console_downlight.visible, "a focused overhead light illuminates the active dials")
	trial._hud.start_requested.emit()
	_check(started > 0 and started == trial._started_usec, "repeated Begin keeps the original start")
	await get_tree().create_timer(0.3).timeout

	var knob := trial.get_node("Knob1") as Node3D
	var knob_center := trial.booth_camera.unproject_position(knob.global_position)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = knob_center
	get_viewport().push_input(wheel, true)
	_check(is_equal_approx(trial._voltages[0], 0.1), "mouse wheel over the in-world knob adjusts voltage")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = knob_center
	get_viewport().push_input(press, true)
	var drag := InputEventMouseMotion.new()
	drag.position = knob_center + Vector2(25, 0)
	drag.relative = Vector2(25, 0)
	get_viewport().push_input(drag, true)
	press.pressed = false
	press.position = drag.position
	get_viewport().push_input(press, true)
	_check(is_equal_approx(trial._voltages[0], 0.35) and not trial._dragging, "dragging turns the 3D knob and releasing stops it")
	var select_second := InputEventKey.new()
	select_second.physical_keycode = KEY_2
	select_second.pressed = true
	get_viewport().push_input(select_second)
	var right := InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	get_viewport().push_input(right)
	_check(is_equal_approx(trial._voltages[1], 0.1), "keyboard selects and turns the second dial")

	var pause := InputEventAction.new()
	pause.action = "pause"
	pause.pressed = true
	get_viewport().push_input(pause)
	_check(get_tree().paused, "the castle pause menu still opens")
	var elapsed_before := trial._elapsed_seconds()
	await get_tree().create_timer(0.06, true).timeout
	trial._set_voltage(0, 2.0)
	_check(trial._elapsed_seconds() > elapsed_before and trial._voltages[0] < 1.0, "pausing counts and blocks input")
	get_viewport().push_input(pause)
	_check(not get_tree().paused, "the castle pause menu resumes the trial")

	trial._set_voltage(0, 1.85)
	trial._set_voltage(1, 3.0)
	_check(trial._calibrated[0] and _completed == 0, "tolerance boundary counts, two wands do not finish")
	trial._set_voltage(0, 1.84)
	trial._set_voltage(2, 4.0)
	_check(not trial._calibrated[0] and _completed == 0, "moving out of tolerance deactivates a wand")
	_check(not common_room.revealed, "partial calibration leaves the common room dim")
	trial._set_voltage(0, 2.0)
	_check(common_room.revealed and common_room.hearth_flames.visible, "finishing the trial ignites the hearth")
	_check(not trial.console_downlight.visible, "room lighting takes over after completion")
	for fixture in common_room._fixtures:
		_check(fixture.visible, "finishing the trial ignites each main fixture")
	var final: Dictionary = trial._result.duplicate()
	trial._set_voltage(0, 0.0)
	trial._finish_attempt()
	_check(_completed == 1 and trial._result == final, "three wands finish once and freeze the result")
	_check(float(final.get("completion_time_seconds", 0.0)) >= 0.06, "result stores fractional elapsed time")
	_check(GameManager.get_wand_trial_result().is_empty(), "completion remains unaccepted until Continue")
	await get_tree().create_timer(0.9).timeout
	_check(trial._hud._finish.visible and trial._hud._final_wands.text == "3 / 3", "completion panel shows the wand count")
	_check(trial._hud._final_time.text.contains(".") and trial._hud._final_score.text.ends_with(" / 100"), "completion shows time and score in separate readouts")
	trial._hud.retry_requested.emit()
	_check(trial.trial_state == Trial.TrialState.READY and trial._voltages == [0.0, 0.0, 0.0], "Retry resets the dials and state")
	_check(common_room.hearth_light.visible and common_room.hearth_light.light_energy > 3.0, "the room stays lit on retry")
	_finish_and_accept(trial)
	var accepted := GameManager.get_wand_trial_result()
	_check(_accepted == 1 and accepted.get("completed", false), "Continue accepts exactly one result")
	var door = main.get_node("Door2_ToSnape")
	_check(door.is_open and player_camera.current, "Continue restores the player view and opens Game 2's door")
	trial.interact(player)
	_finish_and_accept(trial)
	_check(_accepted == 2 and GameManager.get_wand_trial_result().size() == accepted.size(), "replay replaces the previous result")

	_check(Score.calculate(20.0, 20.0, 90.0).performance_score == 100.0, "fast benchmark earns 100")
	_check(Score.calculate(120.0, 20.0, 90.0).performance_score == 0.0, "slow attempts clamp to zero")
	var mid := Score.calculate(55.0, 20.0, 90.0)
	_check(mid.performance_score == 50.0, "midpoint earns 50")
	_check(mid.gryffindor_points == 20.0 and mid.slytherin_points == 10.0 and mid.ravenclaw_points == 7.5 and mid.hufflepuff_points == 12.5, "house points use the four Game 1 weights")
	_check(Score.calculate(55.0, 90.0, 20.0) == mid, "invalid benchmarks fall back to defaults")
	print("Triple Wand Trial checks finished with %d failure(s)." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _finish_and_accept(trial: Trial) -> void:
	trial._hud.start_requested.emit()
	trial._set_voltage(0, 2.0)
	trial._set_voltage(1, 3.0)
	trial._set_voltage(2, 4.0)
	trial._hud.continue_requested.emit()
	trial._hud.continue_requested.emit()


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)
