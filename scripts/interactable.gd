class_name Interactable
extends Node3D


func can_interact() -> bool:
	return true


func get_prompt() -> String:
	return "[E] Interact"


func interact(_player: Node3D) -> void:
	pass
