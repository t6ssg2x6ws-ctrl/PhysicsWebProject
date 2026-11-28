## keypad_puzzle.gd
## ─────────────────────────────────────────────────────────────────────────────
## Attached to the root Control node of keypad_puzzle.tscn.
## Manages:
##   • Number-button presses  (0-9)
##   • Clear  → wipes the display
##   • Enter  → evaluates the guess, opens the ResultPopup
##   • Receives "try_again" / "continue" signals back from the popup
## ─────────────────────────────────────────────────────────────────────────────
extends Control

# ── tunables ──────────────────────────────────────────────────────────────────
const NUM_MIN    := 0
const NUM_MAX    := 100
const MAX_TRIES  := 3

# ── node refs ─────────────────────────────────────────────────────────────────
@onready var display_label : Label   = $KeypadPanel/VBox/Display
@onready var popup         : Control = $ResultPopup

# button paths inside the keypad panel rows
const ROW_BASE := "KeypadPanel/VBox/Rows/"
const DIGIT_BUTTONS := {
	0: "Row4/Btn0",
	1: "Row3/Btn1", 2: "Row3/Btn2", 3: "Row3/Btn3",
	4: "Row2/Btn4", 5: "Row2/Btn5", 6: "Row2/Btn6",
	7: "Row1/Btn7", 8: "Row1/Btn8", 9: "Row1/Btn9",
}

# ── state ─────────────────────────────────────────────────────────────────────
var secret_number : int    = 0
var tries_left    : int    = MAX_TRIES
var current_input : String = ""
var solved        : bool   = false


# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_start_new_game()
	popup.visible = false
	popup.connect("try_again",  _on_try_again)
	popup.connect("puzzle_won", _on_puzzle_won)

	# ── connect digit buttons (bind captures the digit value per iteration) ───
	var digit_map := {
		0: "Row4/Btn0",
		1: "Row3/Btn1", 2: "Row3/Btn2", 3: "Row3/Btn3",
		4: "Row2/Btn4", 5: "Row2/Btn5", 6: "Row2/Btn6",
		7: "Row1/Btn7", 8: "Row1/Btn8", 9: "Row1/Btn9",
	}
	for digit in digit_map.keys():
		var btn := get_node_or_null("KeypadPanel/VBox/Rows/" + digit_map[digit]) as Button
		if btn:
			btn.pressed.connect(_on_digit_pressed.bind(digit))

	# ── connect CLR and ENTER ─────────────────────────────────────────────────
	var clr_btn   := get_node_or_null("KeypadPanel/VBox/Rows/Row4/BtnClear") as Button
	var enter_btn := get_node_or_null("KeypadPanel/VBox/Rows/Row4/BtnEnter") as Button
	if clr_btn:
		clr_btn.pressed.connect(_on_clear_pressed)
	if enter_btn:
		enter_btn.pressed.connect(_on_enter_pressed)


# ══════════════════════════════════════════════════════════════════════════════
# Called by every digit Button (set via "pressed" signal in the scene)
# Button must have its name set to "Btn0" … "Btn9".
# ══════════════════════════════════════════════════════════════════════════════
func _on_digit_pressed(digit: int) -> void:
	if solved or popup.visible:
		return
	if current_input.length() < 3:          # max 3 chars → "100"
		current_input += str(digit)
		_refresh_display()


func _on_clear_pressed() -> void:
	if solved or popup.visible:
		return
	current_input = ""
	_refresh_display()


func _on_enter_pressed() -> void:
	if solved or popup.visible or current_input == "":
		return

	var guess := current_input.to_int()
	current_input = ""
	_refresh_display()

	if guess < NUM_MIN or guess > NUM_MAX:
		popup.show_message(
			"ENTER A NUMBER\nBETWEEN %d AND %d" % [NUM_MIN, NUM_MAX],
			tries_left, false
		)
		return

	if guess == secret_number:
		solved = true
		popup.show_correct(secret_number)
	elif guess < secret_number:
		tries_left -= 1
		if tries_left <= 0:
			popup.show_message("OUT OF TRIES!\nThe number was %d." % secret_number, 0, true)
		else:
			popup.show_message(
				"THE NUMBER IS TOO LOW.\nTRY HIGHER.",
				tries_left, false
			)
	else:   # guess > secret_number
		tries_left -= 1
		if tries_left <= 0:
			popup.show_message("OUT OF TRIES!\nThe number was %d." % secret_number, 0, true)
		else:
			popup.show_message(
				"THE NUMBER IS TOO HIGH.\nTRY LOWER.",
				tries_left, false
			)


# ══════════════════════════════════════════════════════════════════════════════
func _on_try_again() -> void:
	popup.visible = false
	if tries_left <= 0:
		_start_new_game()
	_refresh_display()


func _on_puzzle_won() -> void:
	popup.visible = false
	# Notify the parent scene / GameManager
	if get_parent().has_method("on_keypad_solved"):
		get_parent().on_keypad_solved()


# ══════════════════════════════════════════════════════════════════════════════
func _start_new_game() -> void:
	secret_number = randi_range(NUM_MIN, NUM_MAX)
	tries_left    = MAX_TRIES
	current_input = ""
	solved        = false
	_refresh_display()


func _refresh_display() -> void:
	display_label.text = current_input if current_input != "" else "_ _ _"
