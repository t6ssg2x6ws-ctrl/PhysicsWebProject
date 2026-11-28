@tool
extends Node3D

@export var glow_color: Color = Color(1.0, 0.72, 0.22):
	set(value):
		glow_color = value
		_apply_tint()

@export var display_label: String = "":
	set(value):
		display_label = value
		_apply_label()

@onready var glow_mesh: MeshInstance3D = get_node_or_null("GlowTarget")
@onready var orb_light: OmniLight3D = get_node_or_null("OrbLight")
@onready var plaque_label: Label3D = get_node_or_null("PlaqueLabel")


func _ready() -> void:
	_apply_tint()
	_apply_label()


func _apply_tint() -> void:
	if glow_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = glow_color
		mat.roughness = 0.14
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = 2.8
		glow_mesh.set_surface_override_material(0, mat)
	if orb_light:
		orb_light.light_color = glow_color


func _apply_label() -> void:
	if plaque_label and not display_label.is_empty():
		plaque_label.text = display_label
