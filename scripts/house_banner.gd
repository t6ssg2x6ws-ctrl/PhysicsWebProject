@tool
extends Node3D

enum HouseType {
	GRYFFINDOR,
	SLYTHERIN,
	RAVENCLAW,
	HUFFLEPUFF,
}

@export var house: HouseType = HouseType.GRYFFINDOR:
	set(value):
		house = value
		_apply_house_style()

@onready var cloth_main: MeshInstance3D = get_node_or_null("ClothMain")
@onready var cloth_tip_l: MeshInstance3D = get_node_or_null("ClothTipLeft")
@onready var cloth_tip_r: MeshInstance3D = get_node_or_null("ClothTipRight")
@onready var stripe_center: MeshInstance3D = get_node_or_null("StripeCenter")
@onready var crest_diamond: MeshInstance3D = get_node_or_null("CrestDiamond")
@onready var house_label: Label3D = get_node_or_null("HouseLabel")


func _ready() -> void:
	_apply_house_style()


func _apply_house_style() -> void:
	var primary := Color(0.45, 0.07, 0.08)
	var accent := Color(0.84, 0.65, 0.18)
	var title := "GRYFFINDOR"

	match house:
		HouseType.GRYFFINDOR:
			primary = Color(0.45, 0.07, 0.08)
			accent = Color(0.84, 0.65, 0.18)
			title = "GRYFFINDOR"
		HouseType.SLYTHERIN:
			primary = Color(0.06, 0.26, 0.15)
			accent = Color(0.74, 0.78, 0.82)
			title = "SLYTHERIN"
		HouseType.RAVENCLAW:
			primary = Color(0.08, 0.15, 0.36)
			accent = Color(0.74, 0.50, 0.24)
			title = "RAVENCLAW"
		HouseType.HUFFLEPUFF:
			primary = Color(0.76, 0.55, 0.12)
			accent = Color(0.14, 0.13, 0.14)
			title = "HUFFLEPUFF"

	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = primary
	cloth_mat.roughness = 0.86

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = accent
	accent_mat.metallic = 0.72 if house != HouseType.HUFFLEPUFF else 0.15
	accent_mat.roughness = 0.32 if house != HouseType.HUFFLEPUFF else 0.78

	if cloth_main:
		cloth_main.set_surface_override_material(0, cloth_mat)
	if cloth_tip_l:
		cloth_tip_l.set_surface_override_material(0, cloth_mat)
	if cloth_tip_r:
		cloth_tip_r.set_surface_override_material(0, cloth_mat)
	if stripe_center:
		stripe_center.set_surface_override_material(0, accent_mat)
	if crest_diamond:
		crest_diamond.set_surface_override_material(0, accent_mat)
	if house_label:
		house_label.text = title
		house_label.modulate = accent if house != HouseType.HUFFLEPUFF else Color(0.95, 0.85, 0.45)
