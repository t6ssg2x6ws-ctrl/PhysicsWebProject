extends CanvasLayer

const INK := Color("38251b")
const WARNING_INK := Color("740001")
const NOTICE_GAP := 36.0
const SCREEN_MARGIN := 24.0
const TRIALS := [
	"Dumbledore's Triple Wand Trial",
	"Snape's Memory Trial",
	"Flitwick's Steady Hand Test",
	"Guess the Number",
]

@onready var prompt_panel: PanelContainer = $Root/PromptPanel
@onready var prompt_label: Label = $Root/PromptPanel/PromptText/PromptLabel
@onready var locked_heading: Label = $Root/PromptPanel/PromptText/LockedHeading
@onready var objective_panel: PanelContainer = $Root/MissionPanel
@onready var objective_label: Label = $Root/MissionPanel/Margin/VBox/ObjectiveLabel
@onready var objective_games: VBoxContainer = $Root/MissionPanel/Margin/VBox/ObjectiveGames
@onready var control_rows: VBoxContainer = $Root/ControlsPanel/Margin/VBox/ControlRows
@onready var controls_panel: PanelContainer = $Root/ControlsPanel
@onready var controls_toggle: Button = $Root/ControlsToggle
@onready var controls_intro_timer: Timer = $ControlsIntroTimer
@onready var toast_panel: PanelContainer = $Root/ToastPanel
@onready var toast_title: Label = $Root/ToastPanel/Margin/VBox/ToastTitle
@onready var toast_body: Label = $Root/ToastPanel/Margin/VBox/ToastBody
@onready var toast_action: Label = $Root/ToastPanel/Margin/VBox/ToastAction
@onready var toast_steps: VBoxContainer = $Root/ToastPanel/Margin/VBox/MissionSteps
@onready var mission_modal: Control = $Root/MissionModal
@onready var pause_overlay: Control = $Root/PauseOverlay

var toast_tween: Tween = null
var _notice_half_width := 280.0
var _current_prompt := ""
var _current_chamber := -1
var _objective_markers: Array[Label] = []
var _objective_titles: Array[Label] = []
var _lumos_state_pill: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt_panel.visible = false
	toast_panel.visible = false
	toast_panel.modulate.a = 0.0
	mission_modal.visible = false
	pause_overlay.visible = false

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.notification_requested.connect(_on_notification_requested)
	GameManager.chamber_sealed_warning_requested.connect(_show_chamber_sealed_warning)
	GameManager.mission_accepted.connect(_show_mission_accepted)
	GameManager.mission_modal_requested.connect(_on_mission_modal_requested)
	GameManager.wand_trial_visibility_changed.connect(_on_wand_trial_visibility_changed)
	get_viewport().size_changed.connect(_position_notice)

	var accept_btn := get_node_or_null("Root/MissionModal/Panel/Margin/VBox/Buttons/AcceptButton")
	if accept_btn is Button:
		accept_btn.pressed.connect(_on_accept_button_pressed)
	var decline_btn := get_node_or_null("Root/MissionModal/Panel/Margin/VBox/Buttons/DeclineButton")
	if decline_btn is Button:
		decline_btn.pressed.connect(_on_decline_button_pressed)
	var resume_btn := get_node_or_null("Root/PauseOverlay/Panel/Margin/VBox/ResumeButton")
	if resume_btn is Button:
		resume_btn.pressed.connect(_on_resume_button_pressed)
	var restart_btn := get_node_or_null("Root/PauseOverlay/Panel/Margin/VBox/RestartButton")
	if restart_btn is Button:
		restart_btn.pressed.connect(_on_restart_button_pressed)

	_build_trial_list($Root/MissionModal/Panel/Margin/VBox/TrialList)
	_build_objective_games()
	_build_controls()
	controls_toggle.pressed.connect(_toggle_controls)
	controls_intro_timer.timeout.connect(_set_controls_expanded.bind(false))
	_set_controls_expanded(true)
	controls_intro_timer.start()
	_refresh_mission_ui()


func _build_controls() -> void:
	var caps := StyleBoxFlat.new()
	caps.bg_color = Color("4d2730")
	caps.set_corner_radius_all(4)
	caps.content_margin_top = 3.0
	caps.content_margin_bottom = 3.0
	var lumos := _add_control_row("F", "Toggle Lumos", caps, WARNING_INK, 20)
	_lumos_state_pill = _text_label(lumos, "OFF", 14, INK)
	for entry in [
		["E", "Use doors & stations"],
		["WASD", "Walk"],
		["Mouse", "Look around"],
		["Shift", "Hold to sprint"],
		["Space", "Jump"],
		["Esc", "Open the pause menu"],
	]:
		_add_control_row(entry[0], entry[1], caps, INK, 17)


func _add_control_row(key: String, action: String, caps: StyleBoxFlat, ink: Color, size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	control_rows.add_child(row)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size.x = 73
	badge.add_theme_stylebox_override("panel", caps)
	row.add_child(badge)
	var caption := _text_label(badge, key, 15, Color("fff0d0"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var instruction := _text_label(row, action, size, ink)
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row


func _build_trial_list(list: VBoxContainer) -> void:
	for i in range(TRIALS.size()):
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f6e6c8")
		style.set_corner_radius_all(4)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", style)
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var number := _text_label(row, "%02d" % (i + 1), 18, WARNING_INK)
		number.custom_minimum_size.x = 28
		_text_label(row, TRIALS[i], 23, INK)


func _text_label(row: Control, caption: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if mission_modal.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			GameManager.accept_mission()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			GameManager.close_mission_modal()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_controls") and not get_tree().paused and not GameManager.is_modal_open:
		_toggle_controls()
		get_viewport().set_input_as_handled()


func _toggle_controls() -> void:
	if get_tree().paused or GameManager.is_modal_open:
		return
	controls_intro_timer.stop()
	_set_controls_expanded(not controls_panel.visible)


func _set_controls_expanded(expanded: bool) -> void:
	controls_panel.visible = expanded
	controls_toggle.text = "▾  Hide Controls [H]" if expanded else "▴  Show Controls [H]"


func set_interact_prompt(text: String) -> void:
	if text == _current_prompt:
		return
	_current_prompt = text
	prompt_panel.visible = not text.is_empty()
	var locked := text.begins_with("[LOCKED]")
	locked_heading.visible = locked
	prompt_label.add_theme_font_size_override("font_size", 20 if locked else 24)
	prompt_label.text = text.trim_prefix("[LOCKED]").strip_edges() if locked else text
	# Let the panel shrink to one line again when switching away from a lock.
	prompt_panel.offset_bottom = 84.0


func set_lumos_state(enabled: bool) -> void:
	_lumos_state_pill.text = "ON" if enabled else "OFF"
	_lumos_state_pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lumos_state_pill.add_theme_color_override("font_color", Color("29523a") if enabled else Color("795548"))


func _on_state_changed(_new_state: int) -> void:
	_refresh_mission_ui()


func set_current_chamber(chamber: int) -> void:
	if chamber == _current_chamber:
		return
	_current_chamber = chamber
	_update_objective_marker()


func _refresh_mission_ui() -> void:
	objective_label.text = GameManager.get_objective_text()
	if GameManager.state == GameManager.MissionState.MISSION_ACTIVE:
		objective_label.text = "Complete the chamber trials.\nThen visit the Sorting Hat."
	objective_games.visible = GameManager.state in [GameManager.MissionState.MISSION_ACTIVE, GameManager.MissionState.PARTS_COLLECTED]
	_update_objective_marker()


func _build_objective_games() -> void:
	for caption in TRIALS + ["The Sorting Hat"]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		objective_games.add_child(row)
		var marker := _text_label(row, "▶", 18, WARNING_INK)
		marker.custom_minimum_size.x = 24
		_objective_markers.append(marker)
		_objective_titles.append(_text_label(row, caption, 19, INK))


func _update_objective_marker() -> void:
	var active_row := _current_chamber
	if _current_chamber == TRIALS.size() - 1 and GameManager.state == GameManager.MissionState.PARTS_COLLECTED:
		active_row = TRIALS.size()
	for i in range(_objective_titles.size()):
		var active := i == active_row
		_objective_markers[i].modulate.a = 1.0 if active else 0.0
		_objective_titles[i].add_theme_color_override("font_color", WARNING_INK if active else INK)
		_objective_titles[i].add_theme_font_size_override("font_size", 23 if active else 19)


func _on_notification_requested(title: String, message: String, accent: Color) -> void:
	_show_notice(title, message, accent.darkened(0.58), false)


func _show_chamber_sealed_warning() -> void:
	_show_notice("THE DOOR IS SEALED", "The ward seal has shattered.", WARNING_INK, true)


func _show_mission_accepted() -> void:
	_show_notice("Mission Accepted", "", WARNING_INK, false, true)


func _show_notice(title: String, message: String, color: Color, warning: bool, show_steps := false) -> void:
	_notice_half_width = 365.0 if warning or show_steps else 280.0
	toast_panel.offset_bottom = 70.0
	var title_size := 46 if warning else (38 if show_steps else 26)
	toast_title.add_theme_font_size_override("font_size", title_size)
	toast_title.add_theme_color_override("font_color", color)
	toast_title.text = title
	toast_body.text = message
	toast_body.visible = not show_steps
	toast_action.text = "Read the Enchanted Lectern [E]" if warning else ""
	toast_action.visible = warning
	toast_steps.visible = show_steps
	toast_panel.visible = true
	_position_notice()
	if toast_tween != null and toast_tween.is_running():
		toast_tween.kill()
	toast_panel.modulate.a = 0.0
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.14 if warning else 0.25)
	toast_tween.tween_interval(7.0 if show_steps else (6.0 if warning else 4.2))
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.6)
	toast_tween.tween_callback(_hide_notice)


func _position_notice() -> void:
	if not toast_panel.visible:
		return
	var screen_width := get_viewport().get_visible_rect().size.x
	var earliest_center := objective_panel.get_rect().end.x + NOTICE_GAP + _notice_half_width
	var latest_center := screen_width - SCREEN_MARGIN - _notice_half_width
	objective_panel.visible = earliest_center <= latest_center
	var center := screen_width * 0.5
	if objective_panel.visible:
		center = clampf(center, earliest_center, latest_center)
	var center_offset := center - screen_width * 0.5
	toast_panel.offset_left = center_offset - _notice_half_width
	toast_panel.offset_right = center_offset + _notice_half_width


func _hide_notice() -> void:
	toast_panel.hide()
	objective_panel.show()


func _on_mission_modal_requested(show_modal: bool) -> void:
	if show_modal and toast_tween:
		toast_tween.kill()
		_hide_notice()
	mission_modal.visible = show_modal


func _on_accept_button_pressed() -> void:
	GameManager.accept_mission()


func _on_decline_button_pressed() -> void:
	GameManager.close_mission_modal()


func _on_resume_button_pressed() -> void:
	_set_paused(false)


func _on_wand_trial_visibility_changed(open: bool) -> void:
	visible = not open or get_tree().paused


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_overlay.visible = paused
	layer = 10 if paused else 1
	visible = paused or not GameManager.wand_trial_open
	var show_cursor := paused or GameManager.is_modal_open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if show_cursor else Input.MOUSE_MODE_CAPTURED)


func _on_restart_button_pressed() -> void:
	_set_paused(false)
	GameManager.reset_game()
	get_tree().reload_current_scene()
