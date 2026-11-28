## keypad_guess.gd
## Attached to StationGuessSpell (station_guess_spell.tscn).
##
## Mechanics
##   • Extends Interactable so the player can walk up and press [E] to activate.
##   • After activation the mouse stays CAPTURED (first-person look).
##   • Left-click on a 3-D key → digit appended / clear / enter.
##   • OLED Label3D beside the keypad shows the digits being typed.
##   • 3 tries to guess the secret number (0-100 inclusive).
##   • Wrong guess → parchment-scroll popup with hint + tries left + "Try Again".
##   • Game over or win → different parchment message.
##   • No backend – pure GDScript.
extends Interactable

# ── tunables ──────────────────────────────────────────────────────────────────
const MAX_TRIES   := 3
const NUM_MIN     := 0
const NUM_MAX     := 100
const CLICK_RANGE := 3.5          # metres — how far a key can be aimed at

# ── game state ────────────────────────────────────────────────────────────────
var secret_number : int    = 0
var tries_left    : int    = MAX_TRIES
var current_input : String = ""
var game_active   : bool   = false
var solved        : bool   = false

# ── key-name → action map ─────────────────────────────────────────────────────
const KEY_MAP : Dictionary = {
	"K_0": "0", "K_1": "1", "K_2": "2", "K_3": "3",
	"K_4": "4", "K_5": "5", "K_6": "6", "K_7": "7",
	"K_8": "8", "K_9": "9",
	"K_Hash": "ENTER",   # gold key  → submit
	"K_Star": "CLR",     # red key   → clear all
}

# ── node refs (paths relative to StationGuessSpell root) ─────────────────────
@onready var oled_text   : Label3D       = $ConsoleSlope/OledBezel/OledText
@onready var parchment   : Control       = $ParchmentPopup
@onready var parch_msg   : RichTextLabel = $ParchmentPopup/ParchmentPanel/VBox/Message
@onready var parch_tries : Label         = $ParchmentPopup/ParchmentPanel/VBox/TriesLabel
@onready var try_btn     : Button        = $ParchmentPopup/ParchmentPanel/VBox/TryAgainBtn

# filled in _ready by searching the scene tree
var camera : Camera3D = null

# 3-D key meshes — built from KeypadPad children at runtime
var key_nodes : Dictionary = {}   # String name → MeshInstance3D

# press-dip animation
var pressed_key  : MeshInstance3D = null
var press_timer  : float          = 0.0
const PRESS_DIP  : float = 0.006   # metres
const PRESS_HOLD : float = 0.12    # seconds


# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_collect_key_nodes()

	# parchment starts hidden
	parchment.visible = false
	try_btn.pressed.connect(_on_try_again_pressed)

	_start_new_game()
	_find_camera()


func _collect_key_nodes() -> void:
	var pad := get_node_or_null("ConsoleSlope/KeypadPad")
	if pad == null:
		return
	for child in pad.get_children():
		if child is MeshInstance3D and KEY_MAP.has(child.name):
			key_nodes[child.name] = child


func _find_camera() -> void:
	# Walk the tree looking for the player's Camera3D
	var root := get_tree().get_root()
	# Try common names first
	for player_name in ["Player", "PlayerController", "CharacterBody3D"]:
		var player := root.find_child(player_name, true, false)
		if player:
			camera = player.find_child("Camera3D", true, false) as Camera3D
			if camera:
				return
	# Fallback: grab any Camera3D
	camera = root.find_child("Camera3D", true, false) as Camera3D


# ══════════════════════════════════════════════════════════════════════════════
# Interactable overrides
# ══════════════════════════════════════════════════════════════════════════════
func get_prompt() -> String:
	if solved:
		return "✦ Cipher Solved"
	if game_active:
		return "[LMB] Click keys • [E] Focus keypad"
	return "[E] Approach the Cipher Keypad"


func can_interact() -> bool:
	return true


func interact(_player: Node3D) -> void:
	if solved:
		return
	if not game_active:
		_start_new_game()
	# Player is now focused on the keypad – nothing else to do;
	# clicks are handled in _unhandled_input below.
	GameManager.emit_signal(
		"notification_requested",
		"TOM RIDDLE'S CIPHER",
		"Click the brass keys to type a number (0-100), then press ↵ to guess.",
		Color(0.95, 0.82, 0.32)
	)


# ══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	# Animate key-press dip
	if pressed_key != null:
		press_timer -= delta
		if press_timer <= 0.0:
			pressed_key.position.y += PRESS_DIP
			pressed_key = null


func _unhandled_input(event: InputEvent) -> void:
	if not game_active or solved:
		return
	if parchment.visible:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_try_click_key()


# ══════════════════════════════════════════════════════════════════════════════
# Raycast → closest key
# ══════════════════════════════════════════════════════════════════════════════
func _try_click_key() -> void:
	if camera == null:
		_find_camera()
		if camera == null:
			return

	var vp     := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	var ray_org := camera.project_ray_origin(center)
	var ray_dir := camera.project_ray_normal(center)

	var closest_key  : String = ""
	var closest_dist : float  = 0.055   # half key-width tolerance

	for key_name in key_nodes:
		var km      : MeshInstance3D = key_nodes[key_name]
		var kpos    : Vector3        = km.global_position
		var to_key  : Vector3        = kpos - ray_org
		var proj    : float          = to_key.dot(ray_dir)
		if proj < 0.0 or proj > CLICK_RANGE:
			continue
		var perp := (to_key - ray_dir * proj).length()
		if perp < closest_dist:
			closest_dist = perp
			closest_key  = key_name

	if closest_key != "":
		_animate_press(closest_key)
		_handle_key(KEY_MAP[closest_key])


func _animate_press(key_name: String) -> void:
	if pressed_key != null:
		return   # already animating another key
	var km := key_nodes.get(key_name) as MeshInstance3D
	if km == null:
		return
	pressed_key = km
	press_timer = PRESS_HOLD
	km.position.y -= PRESS_DIP


# ══════════════════════════════════════════════════════════════════════════════
# Key logic
# ══════════════════════════════════════════════════════════════════════════════
func _handle_key(value: String) -> void:
	match value:
		"CLR":
			current_input = ""
		"ENTER":
			_submit_guess()
			return
		_:
			if current_input.length() < 3:
				current_input += value
	_refresh_oled()


func _refresh_oled() -> void:
	var display := current_input if current_input != "" else "_"
	oled_text.text = "GUESS  %d–%d\nINPUT: %s" % [NUM_MIN, NUM_MAX, display]


# ══════════════════════════════════════════════════════════════════════════════
# Guess evaluation
# ══════════════════════════════════════════════════════════════════════════════
func _submit_guess() -> void:
	if current_input == "":
		return
	var guess := current_input.to_int()
	current_input = ""
	_refresh_oled()

	if guess == secret_number:
		_show_parchment_win()
	else:
		tries_left -= 1
		if tries_left <= 0:
			_show_parchment_wrong(guess, true)
		else:
			_show_parchment_wrong(guess, false)


func _show_parchment_win() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	parchment.visible = true
	parch_msg.text  = (
		"[center][b]✦ Correct! ✦[/b]\n\nThe number was [b]%d[/b].\n"
		+ "The cipher runes unlock![/center]"
	) % secret_number
	parch_tries.text = ""
	try_btn.text     = "✦  Seal the Cipher"
	# swap signal for the win button
	if try_btn.pressed.is_connected(_on_try_again_pressed):
		try_btn.pressed.disconnect(_on_try_again_pressed)
	if not try_btn.pressed.is_connected(_on_win_pressed):
		try_btn.pressed.connect(_on_win_pressed)


func _show_parchment_wrong(guess: int, game_over: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	parchment.visible = true

	var hint := "too low…" if guess < secret_number else "too high…"
	if game_over:
		parch_msg.text = (
			"[center][b]The runes fade…[/b]\n\n"
			+ "Your guess of [b]%d[/b] was %s\n"
			+ "The number was [b]%d[/b].[/center]"
		) % [guess, hint, secret_number]
		parch_tries.text = "No tries remaining."
		try_btn.text     = "⟳  Try Again (New Game)"
	else:
		parch_msg.text = (
			"[center][b]Wrong![/b]\n\n"
			+ "%d is %s[/center]"
		) % [guess, hint]
		parch_tries.text = "Tries left: %d" % tries_left
		try_btn.text     = "Try Again"


func _on_try_again_pressed() -> void:
	parchment.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if tries_left <= 0:
		_start_new_game()
	_refresh_oled()


func _on_win_pressed() -> void:
	parchment.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	solved     = true
	game_active = false
	oled_text.text = "SOLVED  ✦\nWell done!"
	# Award the quest part via GameManager
	GameManager.collect_part("Cipher Riddle")


# ══════════════════════════════════════════════════════════════════════════════
func _start_new_game() -> void:
	secret_number = randi_range(NUM_MIN, NUM_MAX)
	tries_left    = MAX_TRIES
	current_input = ""
	game_active   = true
	solved        = false
	_refresh_oled()
