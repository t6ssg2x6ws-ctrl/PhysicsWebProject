extends Interactable

@onready var crucible_light: OmniLight3D = $CrucibleLight
@onready var forge_particles: CPUParticles3D = $ForgeParticles
@onready var seal_orb: MeshInstance3D = $SealOrb

var time_accum: float = 0.0


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	_refresh_visuals()


func _process(delta: float) -> void:
	time_accum += delta
	if GameManager.state == GameManager.MissionState.PARTS_COLLECTED:
		crucible_light.light_energy = 1.5 + sin(time_accum * 4.5) * 0.4
	elif GameManager.state >= GameManager.MissionState.SEAL_FORGED:
		crucible_light.light_energy = 1.8 + sin(time_accum * 2.5) * 0.2
		seal_orb.rotate_y(delta * 1.4)
	else:
		crucible_light.light_energy = 0.55 + sin(time_accum * 3.0) * 0.12


func _on_state_changed(_new_state: int) -> void:
	_refresh_visuals()


func _refresh_visuals() -> void:
	seal_orb.visible = GameManager.state == GameManager.MissionState.SEAL_FORGED
	if GameManager.state >= GameManager.MissionState.SEAL_FORGED:
		crucible_light.light_color = Color(0.98, 0.84, 0.34)
	elif GameManager.state == GameManager.MissionState.PARTS_COLLECTED:
		crucible_light.light_color = Color(0.42, 0.92, 0.68)
	else:
		crucible_light.light_color = Color(0.95, 0.48, 0.18)


func get_prompt() -> String:
	match GameManager.state:
		GameManager.MissionState.TRAPPED_IN_ROOM2:
			return "Arcane Crucible — Accept Mission at Lectern first"
		GameManager.MissionState.MISSION_ACTIVE:
			return "Arcane Crucible — Collect all 3 Relics (%d/3)" % GameManager.collected_parts.size()
		GameManager.MissionState.PARTS_COLLECTED:
			return "[E] Forge Reparo Runic Seal (3/3 Relics)"
		GameManager.MissionState.SEAL_FORGED:
			return "Reparo Seal Forged — Return to the Door!"
		GameManager.MissionState.DOOR_FIXED:
			return "Arcane Crucible (Ward Restored)"
	return "Arcane Crucible"


func interact(_player: Node3D) -> void:
	if GameManager.state == GameManager.MissionState.PARTS_COLLECTED:
		forge_particles.restart()
		forge_particles.emitting = true
		GameManager.forge_seal()
	else:
		GameManager.emit_signal(
			"notification_requested",
			"ARCANE CRUCIBLE",
			GameManager.get_objective_text(),
			Color(0.95, 0.65, 0.32)
		)
