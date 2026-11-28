extends Interactable

@export var part_title: String = "Brass Ward Pinion"
@export var glow_color: Color = Color(0.95, 0.76, 0.28)

@onready var visual_mesh: MeshInstance3D = $VisualMesh
@onready var aura_light: OmniLight3D = $AuraLight
@onready var collider: CollisionShape3D = $InteractBody/CollisionShape3D

var collected: bool = false
var time_accum: float = 0.0
var base_y: float = 0.0


func _ready() -> void:
	base_y = visual_mesh.position.y
	aura_light.light_color = glow_color
	GameManager.state_changed.connect(_on_state_changed)
	_refresh_active_visuals()


func _process(delta: float) -> void:
	if collected:
		return
	time_accum += delta
	if GameManager.state >= GameManager.MissionState.MISSION_ACTIVE:
		visual_mesh.position.y = base_y + sin(time_accum * 2.4) * 0.055
		visual_mesh.rotate_y(delta * 0.9)
		aura_light.light_energy = 1.0 + sin(time_accum * 3.8) * 0.25


func _on_state_changed(_new_state: int) -> void:
	_refresh_active_visuals()


func _refresh_active_visuals() -> void:
	if collected:
		return
	var active := GameManager.state >= GameManager.MissionState.MISSION_ACTIVE
	aura_light.visible = active
	var mat := visual_mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.emission_enabled = active
		mat.emission = glow_color
		mat.emission_energy_multiplier = 1.8 if active else 0.0


func can_interact() -> bool:
	return not collected


func get_prompt() -> String:
	if GameManager.state < GameManager.MissionState.MISSION_ACTIVE:
		return "%s — Accept Mission at Lectern first" % part_title
	return "[E] Collect %s" % part_title


func interact(_player: Node3D) -> void:
	if collected:
		return
	if GameManager.state < GameManager.MissionState.MISSION_ACTIVE:
		GameManager.emit_signal(
			"notification_requested",
			"SEALED RELIC",
			"Accept the Mission at the Enchanted Lectern before collecting %s." % part_title,
			Color(0.85, 0.62, 0.32)
		)
		return

	collected = true
	visual_mesh.visible = false
	aura_light.visible = false
	collider.disabled = true
	GameManager.collect_part(part_title)
