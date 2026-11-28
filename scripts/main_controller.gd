extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var _trial_entrances: Array[Node3D] = [
	$SerpentArch, $Door2_ToSnape, $Door3_ToFlitwick, $Door4_ToGuess,
]


func _ready() -> void:
	GameManager.reset_game()
	GameManager.wand_trial_result_accepted.connect(_on_wand_trial_result_accepted)
	player.interactable_changed.connect(hud.set_interact_prompt)
	player.lumos_toggled.connect(hud.set_lumos_state)
	hud.set_lumos_state(player.lumos_on)
	_update_current_chamber()


func _physics_process(_delta: float) -> void:
	_update_current_chamber()


func _update_current_chamber() -> void:
	# The castle's trial rooms run from south to north along the Z axis.
	var chamber := -1
	for i in range(_trial_entrances.size()):
		if player.global_position.z >= _trial_entrances[i].global_position.z:
			break
		chamber = i
	hud.set_current_chamber(chamber)


func _on_wand_trial_result_accepted(_result: Dictionary) -> void:
	$Door2_ToSnape.unlock_and_open()
	GameManager.notification_requested.emit(
		"TRIAL RESULT SAVED",
		"Head through the open door to Snape's Memory Trial.",
		Color("d3a625")
	)
