extends Node3D

@onready var trial = $Station1_WandTrial
@onready var hearth_flames: Node3D = $CommonRoomFurnishings/Hearth/Flames
@onready var hearth_light: OmniLight3D = $CommonRoomFurnishings/Hearth/FireLight

var revealed := false
var _fixtures: Array[OmniLight3D] = []
var _flames: Array[Node3D] = []


func _ready() -> void:
	_register_fixture($Chandelier, "ChandelierLight", "Flame")
	for sconce in [$SconceW1, $SconceW2, $SconceE1, $SconceE2]:
		_register_fixture(sconce, "SconceLight", "Flame")
	for candle in [$Candle1, $Candle2, $Candle3, $Candle4]:
		_register_fixture(candle, "FlameLight", "FlameMesh")
	trial.base_energy = 0.28
	trial.accent_light.light_energy = 0.28
	trial.accent_light.omni_range = 2.7
	for obelisk in [$Obelisk_2V, $Obelisk_3V, $Obelisk_4V]:
		var orb: OmniLight3D = obelisk.get_node("OrbLight")
		orb.light_energy = 0.19
		orb.omni_range = 2.6
		var core: MeshInstance3D = obelisk.get_node("GlowTarget")
		var material := core.get_surface_override_material(0) as StandardMaterial3D
		material.emission_energy_multiplier = 0.45
	trial.trial_completed.connect(_reveal_room)


func _register_fixture(fixture: Node3D, light_name: String, flame_prefix: String) -> void:
	var light := fixture.get_node(light_name) as OmniLight3D
	light.hide()
	_fixtures.append(light)
	for child in fixture.get_children():
		if child is MeshInstance3D and child.name.begins_with(flame_prefix):
			child.hide()
			_flames.append(child)


func _reveal_room(_result: Dictionary) -> void:
	if revealed:
		return
	revealed = true
	for flame in _flames:
		flame.show()
	hearth_flames.show()
	hearth_light.show()
	var ignition := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	ignition.tween_property(hearth_light, "light_energy", 3.5, 0.9)
	for light in _fixtures:
		# Keep the shared fixture scripts in control of their normal flicker.
		var lit_energy: float = light.base_energy
		var lit_flicker: float = light.flicker_amount
		light.base_energy = 0.0
		light.flicker_amount = 0.0
		light.light_energy = 0.0
		light.show()
		ignition.tween_property(light, "base_energy", lit_energy, 0.9)
		ignition.tween_property(light, "flicker_amount", lit_flicker, 0.9)
