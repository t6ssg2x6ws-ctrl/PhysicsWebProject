@tool
extends Interactable

@export var door_title: String = "NEXT CHAMBER":
	set(value):
		door_title = value
		_update_labels()

@export var is_locked: bool = false:
	set(value):
		is_locked = value
		_update_lock_visuals()

@onready var door_pivot: Node3D = get_node_or_null("DoorPivot")
@onready var lock_plate: MeshInstance3D = get_node_or_null("DoorPivot/DoorLeaf/LockPlate")
@onready var lock_light: OmniLight3D = get_node_or_null("DoorPivot/DoorLeaf/LockLight")
@onready var label_south: Label3D = get_node_or_null("LabelSouth")
@onready var label_north: Label3D = get_node_or_null("LabelNorth")

var is_open: bool = false
var door_tween: Tween = null


func _ready() -> void:
	_update_labels()
	_update_lock_visuals()


func _update_labels() -> void:
	if label_south:
		label_south.text = door_title
	if label_north:
		label_north.text = door_title


func _update_lock_visuals() -> void:
	var glow := Color(0.95, 0.25, 0.2) if is_locked else Color(0.95, 0.78, 0.34)
	if lock_light:
		lock_light.light_color = glow
		lock_light.light_energy = 1.2 if is_locked else 0.75
	if lock_plate:
		var mat := lock_plate.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			var dup := mat.duplicate() as StandardMaterial3D
			dup.emission = glow
			lock_plate.set_surface_override_material(0, dup)


func get_prompt() -> String:
	if is_locked:
		return "[LOCKED] Complete this Chamber's Trial to unlock %s" % door_title
	return "[E] Close Door (%s)" % door_title if is_open else "[E] Open Door (%s)" % door_title


func interact(_player: Node3D) -> void:
	if is_locked:
		_rattle_door()
		GameManager.emit_signal(
			"notification_requested",
			"CHAMBER SEALED",
			"Complete the current room's trial to unseal %s." % door_title,
			Color(0.92, 0.36, 0.28)
		)
		return
	toggle_door()


func toggle_door() -> void:
	is_open = not is_open
	var target_deg := 95.0 if is_open else 0.0
	if door_tween != null and door_tween.is_running():
		door_tween.kill()
	door_tween = create_tween()
	door_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	door_tween.tween_property(door_pivot, "rotation_degrees:y", target_deg, 0.75)


func unlock_and_open() -> void:
	is_locked = false
	if not is_open:
		toggle_door()


func _rattle_door() -> void:
	if door_tween != null and door_tween.is_running():
		return
	door_tween = create_tween()
	door_tween.tween_property(door_pivot, "rotation_degrees:y", 2.5, 0.06)
	door_tween.tween_property(door_pivot, "rotation_degrees:y", -1.5, 0.06)
	door_tween.tween_property(door_pivot, "rotation_degrees:y", 0.0, 0.08)
