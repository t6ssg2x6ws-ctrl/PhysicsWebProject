extends Interactable

@onready var scroll_mesh: MeshInstance3D = $ScrollMesh
@onready var scroll_light: OmniLight3D = $ScrollLight

var time_accum: float = 0.0
var base_y: float = 0.0


func _ready() -> void:
	base_y = scroll_mesh.position.y


func _process(delta: float) -> void:
	time_accum += delta
	scroll_mesh.position.y = base_y + sin(time_accum * 1.9) * 0.025
	if GameManager.state == GameManager.MissionState.TRAPPED_IN_ROOM2:
		scroll_light.light_energy = 1.15 + sin(time_accum * 3.5) * 0.25
	else:
		scroll_light.light_energy = 0.45


func get_prompt() -> String:
	match GameManager.state:
		GameManager.MissionState.TRAPPED_IN_ROOM2:
			return "[E] Read Enchanted Mission Scroll"
		GameManager.MissionState.MISSION_ACTIVE:
			return "[E] Check Mission Progress (%d/%d Relics)" % [GameManager.collected_parts.size(), GameManager.TOTAL_PARTS]
		GameManager.MissionState.PARTS_COLLECTED:
			return "[E] Scroll: Forge the Seal at the Arcane Crucible"
		GameManager.MissionState.SEAL_FORGED:
			return "[E] Scroll: Return to Door & Cast Reparo"
		GameManager.MissionState.DOOR_FIXED:
			return "[E] Mission Completed — Ward Restored"
	return "[E] Enchanted Lectern"


func interact(_player: Node3D) -> void:
	if GameManager.state == GameManager.MissionState.TRAPPED_IN_ROOM2:
		GameManager.request_mission_modal()
	else:
		GameManager.emit_signal(
			"notification_requested",
			"LECTERN INSCRIPTION",
			GameManager.get_objective_text(),
			Color(0.95, 0.78, 0.35)
		)
