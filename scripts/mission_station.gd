extends Interactable

@export var step_number: int = 1
@export var station_id: String = "wand_trial"
@export var station_title: String = "Dumbledore's Triple Wand Trial"
@export var house_name: String = "Gryffindor"
@export var station_hint: String = "Calibrate the 3 wand dials to awaken the trial."
@export var accent_color: Color = Color(0.95, 0.75, 0.32)

@onready var accent_light: OmniLight3D = get_node_or_null("AccentLight")

var time_accum: float = 0.0
var base_energy: float = 1.0


func _ready() -> void:
	if accent_light:
		base_energy = accent_light.light_energy


func _process(delta: float) -> void:
	time_accum += delta
	if accent_light:
		var pulse := 0.14 * sin(time_accum * 2.6 + float(step_number))
		accent_light.light_energy = max(0.2, base_energy + pulse)


func get_prompt() -> String:
	if GameManager.state == GameManager.MissionState.EXPLORING_ROOM1:
		return "%s (%s)" % [station_title, house_name]
	if GameManager.state == GameManager.MissionState.TRAPPED_IN_ROOM2:
		return "Step %d: %s — Read the Enchanted Lectern first" % [step_number, station_title]
	return "[E] Step %d: %s (%s)" % [step_number, station_title, house_name]


func interact(_player: Node3D) -> void:
	if GameManager.state == GameManager.MissionState.TRAPPED_IN_ROOM2:
		GameManager.emit_signal(
			"notification_requested",
			"CHAMBER TRIALS SEALED",
			"Inspect the Enchanted Lectern in the center of the chamber to begin the step-by-step trials.",
			Color(0.92, 0.45, 0.32)
		)
		return

	GameManager.emit_signal("mission_station_interacted", station_id, step_number, station_title)
	GameManager.emit_signal(
		"notification_requested",
		"STEP %d — %s" % [step_number, station_title.to_upper()],
		station_hint,
		accent_color
	)
