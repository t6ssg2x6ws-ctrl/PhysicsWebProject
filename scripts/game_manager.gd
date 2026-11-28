extends Node

enum MissionState {
	EXPLORING_ROOM1,
	TRAPPED_IN_ROOM2,
	MISSION_ACTIVE,
	PARTS_COLLECTED,
	SEAL_FORGED,
	DOOR_FIXED,
}

signal state_changed(new_state: int)
signal quest_progress_changed(collected_count: int, total_count: int)
signal notification_requested(title: String, message: String, accent: Color)
signal chamber_sealed_warning_requested
signal mission_accepted
signal mission_modal_requested(visible: bool)
signal camera_shake_requested(intensity: float, duration: float)
signal mission_station_interacted(station_id: String, step_number: int, station_title: String)
signal wand_trial_visibility_changed(open: bool)
signal wand_trial_result_accepted(result: Dictionary)

const TOTAL_PARTS := 3

var state: MissionState = MissionState.EXPLORING_ROOM1
var collected_parts: Array[String] = []
var is_modal_open: bool = false
var wand_trial_open: bool = false
var _wand_trial_result: Dictionary = {}


func _ready() -> void:
	_ensure_input_actions()


func _ensure_input_actions() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"lumos": [KEY_F],
		"toggle_controls": [KEY_H],
		"pause": [KEY_ESCAPE],
	}
	for action_name in bindings.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		if InputMap.action_get_events(action_name).is_empty():
			for keycode in bindings[action_name]:
				var ev := InputEventKey.new()
				ev.physical_keycode = keycode
				InputMap.action_add_event(action_name, ev)


func reset_game() -> void:
	state = MissionState.EXPLORING_ROOM1
	collected_parts.clear()
	is_modal_open = false
	_wand_trial_result.clear()
	if wand_trial_open:
		set_wand_trial_open(false)
	emit_signal("state_changed", state)
	emit_signal("quest_progress_changed", 0, TOTAL_PARTS)


func set_wand_trial_open(open: bool) -> void:
	wand_trial_open = open
	is_modal_open = open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED)
	wand_trial_visibility_changed.emit(open)


func accept_wand_trial_result(result: Dictionary) -> void:
	_wand_trial_result = result.duplicate()
	wand_trial_result_accepted.emit(_wand_trial_result.duplicate())


func get_wand_trial_result() -> Dictionary:
	return _wand_trial_result.duplicate()


func trigger_room2_lockdown() -> void:
	if state != MissionState.EXPLORING_ROOM1:
		return
	state = MissionState.TRAPPED_IN_ROOM2
	emit_signal("state_changed", state)
	chamber_sealed_warning_requested.emit()


func request_mission_modal() -> void:
	if state != MissionState.TRAPPED_IN_ROOM2:
		return
	is_modal_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	emit_signal("mission_modal_requested", true)


func accept_mission() -> void:
	is_modal_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("mission_modal_requested", false)
	if state == MissionState.TRAPPED_IN_ROOM2:
		state = MissionState.MISSION_ACTIVE
		emit_signal("state_changed", state)
		emit_signal("quest_progress_changed", collected_parts.size(), TOTAL_PARTS)
		mission_accepted.emit()


func close_mission_modal() -> void:
	is_modal_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("mission_modal_requested", false)


func collect_part(part_title: String) -> void:
	if state != MissionState.MISSION_ACTIVE:
		return
	if part_title in collected_parts:
		return
	collected_parts.append(part_title)
	emit_signal("quest_progress_changed", collected_parts.size(), TOTAL_PARTS)

	if collected_parts.size() >= TOTAL_PARTS:
		state = MissionState.PARTS_COLLECTED
		emit_signal("state_changed", state)
		emit_signal(
			"notification_requested",
			"ALL RELICS RECOVERED (3/3)",
			"Bring the 3 components to the Arcane Crucible to forge the Reparo Runic Seal.",
			Color(0.45, 0.88, 0.65)
		)
	else:
		emit_signal(
			"notification_requested",
			"RELIC RECOVERED (%d/%d)" % [collected_parts.size(), TOTAL_PARTS],
			"Collected: %s" % part_title,
			Color(0.95, 0.82, 0.42)
		)


func forge_seal() -> void:
	if state != MissionState.PARTS_COLLECTED:
		return
	state = MissionState.SEAL_FORGED
	emit_signal("state_changed", state)
	emit_signal(
		"notification_requested",
		"REPARO RUNIC SEAL FORGED",
		"Return to the broken Iron-Oak Door and cast Reparo [E] to mend its lock.",
		Color(0.98, 0.84, 0.36)
	)


func complete_door_repair() -> void:
	if state != MissionState.SEAL_FORGED:
		return
	state = MissionState.DOOR_FIXED
	emit_signal("state_changed", state)
	emit_signal(
		"notification_requested",
		"MISSION COMPLETE — DOOR REPAIRED",
		"The ancient ward lock is restored. You may pass freely between the chambers.",
		Color(0.42, 0.92, 0.56)
	)


func get_objective_text() -> String:
	match state:
		MissionState.EXPLORING_ROOM1:
			return "Explore the Hogwarts Antechamber and open the Serpent Arch Door ahead."
		MissionState.TRAPPED_IN_ROOM2:
			return "The door locked behind you! Read the Enchanted Lectern [E] to begin the trials."
		MissionState.MISSION_ACTIVE:
			return "Complete the 4 Chamber Trials step by step, then visit the Sorting Hat."
		MissionState.PARTS_COLLECTED:
			return "Proceed to the Sorting Hat Dais at the North Altar."
		MissionState.SEAL_FORGED:
			return "Return to the Iron-Oak Door and cast Reparo [E] to open it."
		MissionState.DOOR_FIXED:
			return "Mission Complete! The Chamber Door is open."
	return ""
