## keypad_guess.gd
## Attached to StationGuessSpell in station_guess_spell.tscn.
##
## ──────────────────────────────────────────────────────────────────────────────
## The parchment popup is built ENTIRELY in GDScript (no .tscn popup scene needed)
## and injected into a CanvasLayer so it renders correctly over the 3-D world.
## ──────────────────────────────────────────────────────────────────────────────
extends Interactable

# ── tunables ──────────────────────────────────────────────────────────────────
const MAX_TRIES   := 3
const NUM_MIN     := 0
const NUM_MAX     := 100
const CLICK_RANGE := 3.5

# ── game state ────────────────────────────────────────────────────────────────
var secret_number : int    = 0
var tries_left    : int    = MAX_TRIES
var current_input : String = ""
var game_active   : bool   = false
var solved        : bool   = false

# ── key-name → action ─────────────────────────────────────────────────────────
const KEY_MAP : Dictionary = {
	"K_0": "0", "K_1": "1", "K_2": "2", "K_3": "3",
	"K_4": "4", "K_5": "5", "K_6": "6", "K_7": "7",
	"K_8": "8", "K_9": "9",
	"K_Hash": "ENTER",
	"K_Star": "CLR",
}

# ── 3-D key meshes ────────────────────────────────────────────────────────────
var key_nodes : Dictionary = {}
var camera    : Camera3D   = null

# press-dip animation
var pressed_key : MeshInstance3D = null
var press_timer : float          = 0.0
const PRESS_DIP  : float = 0.006
const PRESS_HOLD : float = 0.12

# ── OLED node ref (3-D world) ─────────────────────────────────────────────────
@onready var oled_text : Label3D = $ConsoleSlope/OledBezel/OledText

# ── Parchment popup nodes (built in code, live in a CanvasLayer) ───────────────
var _canvas_layer  : CanvasLayer   = null
var _parch_root    : Control       = null   # the whole overlay
var _msg_label     : Label         = null
var _crosses_label : Label         = null
var _tries_label   : Label         = null
var _btn           : Button        = null
var _win_mode      : bool          = false


# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_collect_key_nodes()
	_find_camera()
	_build_popup()
	_start_new_game()


# ── collect clickable key meshes ──────────────────────────────────────────────
func _collect_key_nodes() -> void:
	var pad := get_node_or_null("ConsoleSlope/KeypadPad")
	if pad == null:
		return
	for child in pad.get_children():
		if child is MeshInstance3D and KEY_MAP.has(child.name):
			key_nodes[child.name] = child


# ── find the first-person camera ──────────────────────────────────────────────
func _find_camera() -> void:
	var root := get_tree().get_root()
	for pname in ["Player", "PlayerController", "CharacterBody3D"]:
		var p := root.find_child(pname, true, false)
		if p:
			camera = p.find_child("Camera3D", true, false) as Camera3D
			if camera:
				return
	camera = root.find_child("Camera3D", true, false) as Camera3D


# ══════════════════════════════════════════════════════════════════════════════
# Build the full parchment popup purely in GDScript.
# A CanvasLayer is added to the scene root so the Control renders over 3-D.
# ══════════════════════════════════════════════════════════════════════════════
func _build_popup() -> void:
	# ── CanvasLayer (renders over everything) ─────────────────────────────────
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	get_tree().get_root().call_deferred("add_child", _canvas_layer)
	await get_tree().process_frame   # wait for add_child to complete

	# ── Dark dimmer (full screen) ──────────────────────────────────────────────
	_parch_root = Control.new()
	_parch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_parch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parch_root.visible = false
	_canvas_layer.add_child(_parch_root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.04, 0.02, 0.01, 0.80)
	_parch_root.add_child(dimmer)

	# ── Parchment panel (centred in screen) ────────────────────────────────────
	var panel := PanelContainer.new()
	# Anchor to screen centre, then offset by half the panel size to truly centre it
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.custom_minimum_size = Vector2(500, 340)
	panel.offset_left   = -250.0
	panel.offset_top    = -170.0
	panel.offset_right  =  250.0
	panel.offset_bottom =  170.0
	# parchment look via StyleBoxFlat
	var sbox := StyleBoxFlat.new()
	sbox.bg_color             = Color(0.878, 0.812, 0.671, 1.0)
	sbox.border_width_left    = 7
	sbox.border_width_top     = 7
	sbox.border_width_right   = 7
	sbox.border_width_bottom  = 7
	sbox.border_color         = Color(0.388, 0.242, 0.09, 1)
	sbox.corner_radius_top_left     = 6
	sbox.corner_radius_top_right    = 6
	sbox.corner_radius_bottom_right = 6
	sbox.corner_radius_bottom_left  = 6
	sbox.shadow_color = Color(0.05, 0.03, 0.01, 0.75)
	sbox.shadow_size  = 28
	panel.add_theme_stylebox_override("panel", sbox)
	_parch_root.add_child(panel)

	# ── VBox inside panel ──────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# margin padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   40)
	margin.add_theme_constant_override("margin_right",  40)
	margin.add_theme_constant_override("margin_top",    30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 20)
	margin.add_child(inner)

	# ── Message ────────────────────────────────────────────────────────────────
	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_label.add_theme_font_size_override("font_size", 24)
	_msg_label.add_theme_color_override("font_color", Color(0.14, 0.08, 0.03, 1))
	inner.add_child(_msg_label)

	# ── Crosses (try indicators) ───────────────────────────────────────────────
	_crosses_label = Label.new()
	_crosses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosses_label.add_theme_font_size_override("font_size", 34)
	_crosses_label.add_theme_color_override("font_color", Color(0.55, 0.14, 0.08, 1))
	inner.add_child(_crosses_label)

	# ── Tries remaining ───────────────────────────────────────────────────────
	_tries_label = Label.new()
	_tries_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tries_label.add_theme_font_size_override("font_size", 18)
	_tries_label.add_theme_color_override("font_color", Color(0.3, 0.18, 0.06, 1))
	inner.add_child(_tries_label)

	# ── Button (wood style) ────────────────────────────────────────────────────
	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(260, 54)
	_btn.add_theme_font_size_override("font_size", 22)
	_btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72, 1))
	_btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.9, 1))
	# normal style
	var btn_n := StyleBoxFlat.new()
	btn_n.bg_color           = Color(0.192, 0.133, 0.075, 1)
	btn_n.border_width_left  = 3
	btn_n.border_width_top   = 3
	btn_n.border_width_right = 3
	btn_n.border_width_bottom = 3
	btn_n.border_color       = Color(0.588, 0.431, 0.196, 1)
	btn_n.corner_radius_top_left     = 8
	btn_n.corner_radius_top_right    = 8
	btn_n.corner_radius_bottom_right = 8
	btn_n.corner_radius_bottom_left  = 8
	btn_n.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	btn_n.shadow_size  = 6
	_btn.add_theme_stylebox_override("normal",  btn_n)
	# hover style
	var btn_h := StyleBoxFlat.new()
	btn_h.bg_color           = Color(0.282, 0.192, 0.098, 1)
	btn_h.border_width_left  = 3
	btn_h.border_width_top   = 3
	btn_h.border_width_right = 3
	btn_h.border_width_bottom = 3
	btn_h.border_color       = Color(0.72, 0.56, 0.24, 1)
	btn_h.corner_radius_top_left     = 8
	btn_h.corner_radius_top_right    = 8
	btn_h.corner_radius_bottom_right = 8
	btn_h.corner_radius_bottom_left  = 8
	_btn.add_theme_stylebox_override("hover",   btn_h)
	# pressed style
	var btn_p := StyleBoxFlat.new()
	btn_p.bg_color           = Color(0.12, 0.08, 0.04, 1)
	btn_p.border_width_left  = 3
	btn_p.border_width_top   = 3
	btn_p.border_width_right = 3
	btn_p.border_width_bottom = 3
	btn_p.border_color       = Color(0.45, 0.32, 0.12, 1)
	btn_p.corner_radius_top_left     = 8
	btn_p.corner_radius_top_right    = 8
	btn_p.corner_radius_bottom_right = 8
	btn_p.corner_radius_bottom_left  = 8
	_btn.add_theme_stylebox_override("pressed", btn_p)
	inner.add_child(_btn)
	_btn.pressed.connect(_on_popup_btn_pressed)


# ══════════════════════════════════════════════════════════════════════════════
# Interactable overrides
# ══════════════════════════════════════════════════════════════════════════════
func get_prompt() -> String:
	if solved:
		return "✦ Cipher Solved"
	if game_active:
		return "[LMB] Click keys  •  [E] Focus"
	return "[E] Approach the Cipher Keypad"


func can_interact() -> bool:
	return true


func interact(_player: Node3D) -> void:
	if solved:
		return
	if not game_active:
		_start_new_game()
	GameManager.emit_signal(
		"notification_requested",
		"TOM RIDDLE'S CIPHER",
		"Click the brass keys to type a number (0–100), then press ↵ to guess.",
		Color(0.95, 0.82, 0.32)
	)


# ══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if pressed_key != null:
		press_timer -= delta
		if press_timer <= 0.0:
			pressed_key.position.y += PRESS_DIP
			pressed_key = null


func _unhandled_input(event: InputEvent) -> void:
	if not game_active or solved:
		return
	if _parch_root != null and _parch_root.visible:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_try_click_key()


# ══════════════════════════════════════════════════════════════════════════════
func _try_click_key() -> void:
	if camera == null:
		_find_camera()
		if camera == null:
			return

	var center  := get_viewport().get_visible_rect().size * 0.5
	var ray_org := camera.project_ray_origin(center)
	var ray_dir := camera.project_ray_normal(center)

	var closest_key  : String = ""
	var closest_dist : float  = 0.055

	for kname in key_nodes:
		var km : MeshInstance3D = key_nodes[kname]
		var to_key := km.global_position - ray_org
		var proj   := to_key.dot(ray_dir)
		if proj < 0.0 or proj > CLICK_RANGE:
			continue
		var perp := (to_key - ray_dir * proj).length()
		if perp < closest_dist:
			closest_dist = perp
			closest_key  = kname

	if closest_key != "":
		_animate_press(closest_key)
		_handle_key(KEY_MAP[closest_key])


func _animate_press(kname: String) -> void:
	if pressed_key != null:
		return
	var km := key_nodes.get(kname) as MeshInstance3D
	if km == null:
		return
	pressed_key = km
	press_timer = PRESS_HOLD
	km.position.y -= PRESS_DIP


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
func _submit_guess() -> void:
	if current_input == "":
		return
	var guess := current_input.to_int()
	current_input = ""
	_refresh_oled()

	if guess == secret_number:
		_show_popup_win()
	else:
		tries_left -= 1
		_show_popup_wrong(guess, tries_left <= 0)


func _show_popup(msg: String, crosses: String, tries_txt: String, btn_txt: String, win: bool) -> void:
	if _parch_root == null:
		return
	_msg_label.text     = msg
	_crosses_label.text = crosses
	_tries_label.text   = tries_txt
	_btn.text           = btn_txt
	_win_mode           = win
	_parch_root.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _show_popup_win() -> void:
	_show_popup(
		"CORRECT!\nYOU UNLOCKED IT!",
		"★  ★  ★",
		"CIPHER BROKEN",
		"CONTINUE",
		true
	)


func _show_popup_wrong(guess: int, game_over: bool) -> void:
	var hint   := "THE NUMBER IS TOO LOW.\nTRY HIGHER." if guess < secret_number \
				else "THE NUMBER IS TOO HIGH.\nTRY LOWER."
	var crosses := _make_crosses(tries_left)
	var tries_txt := "OUT OF TRIES!" if game_over else "%d TRIES LEFT" % tries_left
	var msg := hint if not game_over else "OUT OF TRIES!\nThe number was %d." % secret_number
	_show_popup(msg, crosses, tries_txt, "TRY AGAIN", false)


func _make_crosses(remaining: int) -> String:
	# X marks used tries (left), O marks remaining tries (right)
	# 3 left (0 used) → ○ ○ ○
	# 2 left (1 used) → ✗ ○ ○
	# 1 left (2 used) → ✗ ✗ ○
	# 0 left (3 used) → ✗ ✗ ✗
	var used  := MAX_TRIES - remaining
	var parts : Array[String] = []
	for i in range(MAX_TRIES):
		parts.append("✗" if i < used else "○")
	return "  ".join(parts)


func _on_popup_btn_pressed() -> void:
	_parch_root.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _win_mode:
		solved      = true
		game_active = false
		oled_text.text = "SOLVED  ✦\nWell done!"
		GameManager.collect_part("Cipher Riddle")
	else:
		if tries_left <= 0:
			_start_new_game()
		_refresh_oled()


# ══════════════════════════════════════════════════════════════════════════════
func _start_new_game() -> void:
	secret_number = randi_range(NUM_MIN, NUM_MAX)
	tries_left    = MAX_TRIES
	current_input = ""
	game_active   = true
	solved        = false
	_refresh_oled()


func _exit_tree() -> void:
	# Clean up the CanvasLayer when the station is unloaded
	if _canvas_layer and is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
