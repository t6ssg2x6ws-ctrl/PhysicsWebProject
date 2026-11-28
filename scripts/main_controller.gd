extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	GameManager.reset_game()
	player.interactable_changed.connect(hud.set_interact_prompt)
	player.lumos_toggled.connect(hud.set_lumos_state)
	hud.set_lumos_state(player.lumos_on)
