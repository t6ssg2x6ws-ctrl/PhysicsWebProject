## result_popup.gd
## ─────────────────────────────────────────────────────────────────────────────
## Attached to the root Control node of result_popup.tscn.
## Shows the parchment-scroll overlay with:
##   • MessageLabel   – feedback text
##   • CrossesLabel   – "✗ ✗ ✗" showing remaining tries
##   • TriesLabel     – "X TRIES LEFT"
##   • TryAgainButton – "TRY AGAIN" or "CONTINUE" on win
## ─────────────────────────────────────────────────────────────────────────────
extends Control

signal try_again
signal puzzle_won

# ── node refs ─────────────────────────────────────────────────────────────────
@onready var parchment_rect  : TextureRect = $Dimmer/ParchmentRect
@onready var message_label   : Label       = $Dimmer/ParchmentRect/VBox/MessageLabel
@onready var crosses_label   : Label       = $Dimmer/ParchmentRect/VBox/CrossesLabel
@onready var tries_label     : Label       = $Dimmer/ParchmentRect/VBox/TriesLabel
@onready var try_again_btn   : Button      = $Dimmer/ParchmentRect/VBox/TryAgainButton


# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	try_again_btn.pressed.connect(_on_button_pressed)
	visible = false


# ── Public API ────────────────────────────────────────────────────────────────

## Show a wrong / out-of-tries result.
## game_over=true means no more tries; button becomes a reset.
func show_message(msg: String, remaining_tries: int, game_over: bool) -> void:
	message_label.text  = msg
	crosses_label.text  = _make_crosses(remaining_tries)
	tries_label.text    = "%d TRIES LEFT" % remaining_tries if remaining_tries > 0 else "NO TRIES LEFT"
	try_again_btn.text  = "TRY AGAIN"
	# tag so button handler knows what to do
	try_again_btn.set_meta("mode", "game_over" if game_over else "try_again")
	visible = true


## Show the win result.
func show_correct(secret: int) -> void:
	message_label.text  = "CORRECT!\nYOU UNLOCKED IT!"
	crosses_label.text  = "★ ★ ★"
	tries_label.text    = "CIPHER BROKEN"
	try_again_btn.text  = "CONTINUE"
	try_again_btn.set_meta("mode", "won")
	visible = true


# ── Private ───────────────────────────────────────────────────────────────────

func _make_crosses(n: int) -> String:
	# Shows filled (✗) for used tries and empty (○) for remaining
	var total := 3
	var used  := total - n
	var parts : Array[String] = []
	for i in range(total):
		parts.append("✗" if i < used else "○")
	return "  ".join(parts)


func _on_button_pressed() -> void:
	var mode : String = try_again_btn.get_meta("mode", "try_again")
	match mode:
		"won":
			emit_signal("puzzle_won")
		"game_over", "try_again":
			emit_signal("try_again")
