extends OmniLight3D

@export var base_energy: float = 1.6
@export var flicker_amount: float = 0.25
@export var flicker_speed: float = 5.5
@export var float_parent: bool = false
@export var float_amplitude: float = 0.08
@export var float_speed: float = 1.4

var phase: float = 0.0
var start_parent_y: float = 0.0


func _ready() -> void:
	phase = randf() * TAU
	if float_parent and get_parent() is Node3D:
		start_parent_y = (get_parent() as Node3D).position.y


func _process(delta: float) -> void:
	phase += delta
	var n := sin(phase * flicker_speed) * 0.5 + sin(phase * flicker_speed * 2.3 + 1.4) * 0.35 + cos(phase * flicker_speed * 3.7) * 0.15
	light_energy = max(0.1, base_energy + n * flicker_amount)

	if float_parent and get_parent() is Node3D:
		var p := get_parent() as Node3D
		p.position.y = start_parent_y + sin(phase * float_speed) * float_amplitude
