extends Interactable

@onready var door_pivot: Node3D = $DoorPivot
@onready var lock_plate: MeshInstance3D = $DoorPivot/DoorLeaf/LockPlate
@onready var lock_light: OmniLight3D = $DoorPivot/DoorLeaf/LockLight
@onready var spark_particles: CPUParticles3D = $DoorPivot/DoorLeaf/SparkParticles
@onready var repair_particles: CPUParticles3D = $DoorPivot/DoorLeaf/RepairParticles

var is_open: bool = false
var is_broken: bool = false
var door_tween: Tween = null


func _ready() -> void:
	_update_lock_visuals(Color(0.95, 0.76, 0.32), 0.7)
	var trigger := get_node_or_null("Room2LockTrigger")
	if trigger is Area3D:
		trigger.body_entered.connect(_on_room2_lock_trigger_body_entered)


func get_prompt() -> String:
	match GameManager.state:
		GameManager.MissionState.EXPLORING_ROOM1, GameManager.MissionState.DOOR_FIXED:
			return "[E] Close Iron-Oak Door" if is_open else "[E] Open Iron-Oak Door"
		GameManager.MissionState.TRAPPED_IN_ROOM2:
			return "[LOCKED] Ward Seal Broken — Read the Enchanted Lectern"
		GameManager.MissionState.MISSION_ACTIVE:
			return "[LOCKED] Broken Lock — Collect Relics (%d/%d)" % [GameManager.collected_parts.size(), GameManager.TOTAL_PARTS]
		GameManager.MissionState.PARTS_COLLECTED:
			return "[LOCKED] Forge the Reparo Seal at the Crucible first"
		GameManager.MissionState.SEAL_FORGED:
			return "[E] Cast Reparo — Repair & Unlock Door"
	return ""


func interact(_player: Node3D) -> void:
	match GameManager.state:
		GameManager.MissionState.EXPLORING_ROOM1, GameManager.MissionState.DOOR_FIXED:
			_toggle_door()
		GameManager.MissionState.TRAPPED_IN_ROOM2:
			_rattle_locked_door()
			GameManager.emit_signal(
				"notification_requested",
				"WARD LOCK SHATTERED",
				"The door won't budge. Inspect the Enchanted Lectern in the center of the chamber.",
				Color(0.92, 0.36, 0.28)
			)
		GameManager.MissionState.MISSION_ACTIVE:
			_rattle_locked_door()
			GameManager.emit_signal(
				"notification_requested",
				"LOCK STILL BROKEN",
				"You still need %d/3 Arcane Relics before you can forge the Reparo Seal." % [GameManager.collected_parts.size()],
				Color(0.92, 0.55, 0.28)
			)
		GameManager.MissionState.PARTS_COLLECTED:
			_rattle_locked_door()
			GameManager.emit_signal(
				"notification_requested",
				"SEAL NOT YET FORGED",
				"Take the 3 Relics to the Arcane Crucible in the East alcove first.",
				Color(0.95, 0.78, 0.32)
			)
		GameManager.MissionState.SEAL_FORGED:
			_repair_and_open_door()


func _toggle_door() -> void:
	is_open = not is_open
	var target_deg := 95.0 if is_open else 0.0
	_tween_door_angle(target_deg, 0.75, Tween.TRANS_CUBIC, Tween.EASE_OUT)


func slam_and_break_lock() -> void:
	if is_broken:
		return
	is_broken = true
	is_open = false
	_tween_door_angle(0.0, 0.2, Tween.TRANS_EXPO, Tween.EASE_IN)
	spark_particles.restart()
	spark_particles.emitting = true
	_update_lock_visuals(Color(0.96, 0.22, 0.16), 1.4)
	GameManager.emit_signal("camera_shake_requested", 0.13, 0.45)
	GameManager.trigger_room2_lockdown()


func _repair_and_open_door() -> void:
	is_broken = false
	repair_particles.restart()
	repair_particles.emitting = true
	_update_lock_visuals(Color(0.35, 0.96, 0.58), 1.6)
	GameManager.emit_signal("camera_shake_requested", 0.05, 0.25)
	GameManager.complete_door_repair()
	is_open = true
	_tween_door_angle(95.0, 1.0, Tween.TRANS_CUBIC, Tween.EASE_OUT)


func _rattle_locked_door() -> void:
	if door_tween != null and door_tween.is_running():
		return
	spark_particles.restart()
	spark_particles.emitting = true
	door_tween = create_tween()
	door_tween.tween_property(door_pivot, "rotation_degrees:y", 2.8, 0.06)
	door_tween.tween_property(door_pivot, "rotation_degrees:y", -1.5, 0.06)
	door_tween.tween_property(door_pivot, "rotation_degrees:y", 0.0, 0.08)


func _tween_door_angle(target_deg: float, duration: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if door_tween != null and door_tween.is_running():
		door_tween.kill()
	door_tween = create_tween()
	door_tween.set_trans(trans).set_ease(ease_type)
	door_tween.tween_property(door_pivot, "rotation_degrees:y", target_deg, duration)


func _update_lock_visuals(glow_color: Color, energy: float) -> void:
	lock_light.light_color = glow_color
	lock_light.light_energy = energy
	var mat := lock_plate.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = 2.2 if energy > 1.0 else 0.9


func _on_room2_lock_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and GameManager.state == GameManager.MissionState.EXPLORING_ROOM1:
		slam_and_break_lock()
