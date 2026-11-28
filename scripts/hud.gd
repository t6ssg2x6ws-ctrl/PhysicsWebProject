extends CanvasLayer

@onready var prompt_panel: PanelContainer = $Root/PromptPanel
@onready var prompt_label: Label = $Root/PromptPanel/PromptLabel
@onready var objective_label: Label = $Root/MissionPanel/Margin/VBox/ObjectiveLabel
@onready var parts_list_label: Label = $Root/MissionPanel/Margin/VBox/PartsListLabel
@onready var lumos_label: Label = $Root/ControlsPanel/Margin/VBox/LumosLabel
@onready var toast_panel: PanelContainer = $Root/ToastPanel
@onready var toast_title: Label = $Root/ToastPanel/Margin/VBox/ToastTitle
@onready var toast_body: Label = $Root/ToastPanel/Margin/VBox/ToastBody
@onready var mission_modal: Control = $Root/MissionModal
@onready var pause_overlay: Control = $Root/PauseOverlay
@onready var guess_overlay: Control = $Root/GuessOverlay
@onready var guess_input: LineEdit = $Root/GuessOverlay/Panel/Margin/VBox/GuessInput
@onready var guess_submit: Button = $Root/GuessOverlay/Panel/Margin/VBox/Buttons/SubmitButton
@onready var guess_restart: Button = $Root/GuessOverlay/Panel/Margin/VBox/Buttons/RestartButton
@onready var guess_feedback: Label = $Root/GuessOverlay/Panel/Margin/VBox/FeedbackLabel
@onready var guess_tries: Label = $Root/GuessOverlay/Panel/Margin/VBox/TriesLabel

var toast_tween: Tween = null
var secret_number := 0
var tries_left := 3
var guess_round_active := false
var guess_rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt_panel.visible = false
	toast_panel.visible = false
	toast_panel.modulate.a = 0.0
	mission_modal.visible = false
	pause_overlay.visible = false
	guess_overlay.visible = false

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.quest_progress_changed.connect(_on_quest_progress_changed)
	GameManager.notification_requested.connect(_on_notification_requested)
	GameManager.mission_modal_requested.connect(_on_mission_modal_requested)
	GameManager.mission_station_interacted.connect(_on_mission_station_interacted)
	guess_rng.randomize()

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
	guess_submit.pressed.connect(_on_guess_submit_pressed)
	guess_restart.pressed.connect(_start_guess_round)
	guess_input.text_submitted.connect(_on_guess_text_submitted)
	var close_guess_btn := get_node_or_null("Root/GuessOverlay/Panel/Margin/VBox/Buttons/CloseButton")
	if close_guess_btn is Button:
		close_guess_btn.pressed.connect(_close_guess_game)

	_refresh_mission_ui()


func _unhandled_input(event: InputEvent) -> void:
	if guess_overlay.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			_close_guess_game()
			get_viewport().set_input_as_handled()
		return

	if mission_modal.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			GameManager.accept_mission()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			GameManager.close_mission_modal()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause"):
		var now_paused := not get_tree().paused
		get_tree().paused = now_paused
		pause_overlay.visible = now_paused
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if now_paused else Input.MOUSE_MODE_CAPTURED)


func set_interact_prompt(text: String) -> void:
	if text.is_empty():
		prompt_panel.visible = false
	else:
		prompt_label.text = text
		prompt_panel.visible = true


func set_lumos_state(enabled: bool) -> void:
	lumos_label.text = "[F] Wand Lumos: ON" if enabled else "[F] Wand Lumos: OFF"
	lumos_label.modulate = Color(1.0, 0.95, 0.72) if enabled else Color(0.75, 0.76, 0.8)


func _on_state_changed(_new_state: int) -> void:
	_refresh_mission_ui()


func _on_quest_progress_changed(_collected: int, _total: int) -> void:
	_refresh_mission_ui()


func _refresh_mission_ui() -> void:
	objective_label.text = GameManager.get_objective_text()
	if GameManager.state < GameManager.MissionState.MISSION_ACTIVE:
		parts_list_label.text = ""
		parts_list_label.visible = false
	else:
		parts_list_label.visible = true
		var expected := [
			"1. Dumbledore's Triple Wand Trial",
			"2. Snape's Memory Trial",
			"3. Flitwick's Steady Hand Test",
			"4. Guess the Number",
			"5. The Sorting Hat"
		]
		var lines: Array[String] = []
		for item in expected:
			var mark := "[X]" if item in GameManager.collected_parts else "[ ]"
			lines.append("%s %s" % [mark, item])
		parts_list_label.text = "\n".join(lines)


func _on_notification_requested(title: String, message: String, accent: Color) -> void:
	toast_title.text = title
	toast_title.modulate = accent
	toast_body.text = message
	toast_panel.visible = true
	if toast_tween != null and toast_tween.is_running():
		toast_tween.kill()
	toast_panel.modulate.a = 0.0
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	toast_tween.tween_interval(4.2)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.6)
	toast_tween.tween_callback(func(): toast_panel.visible = false)


func _on_mission_modal_requested(show_modal: bool) -> void:
	mission_modal.visible = show_modal


func _on_mission_station_interacted(station_id: String, _step_number: int, _station_title: String) -> void:
	# "guess_spell" is now handled by the 3-D keypad (keypad_guess.gd).
	# The old text-based GuessOverlay is intentionally suppressed here.
	if station_id == "guess_spell":
		return
	# (future stations could be dispatched here)


func _start_guess_round() -> void:
	secret_number = guess_rng.randi_range(1, 100)
	tries_left = 3
	guess_round_active = true
	guess_feedback.text = "A number has been chosen. Make your first guess!"
	guess_tries.text = "Tries left: %d" % tries_left
	guess_input.text = ""
	guess_input.editable = true
	guess_submit.disabled = false
	guess_restart.disabled = false
	guess_input.grab_focus()


func _on_guess_submit_pressed() -> void:
	_submit_guess()


func _on_guess_text_submitted(_text: String) -> void:
	_submit_guess()


func _submit_guess() -> void:
	if not guess_round_active:
		guess_feedback.text = "This round is over. Select New Round to play again."
		return
	var entered := guess_input.text.strip_edges()
	if not entered.is_valid_int() or int(entered) < 1 or int(entered) > 100:
		guess_feedback.text = "Enter a whole number from 1 to 100."
		return
	var guess := int(entered)
	tries_left -= 1
	guess_tries.text = "Tries left: %d" % tries_left
	if guess == secret_number:
		guess_round_active = false
		guess_feedback.text = "Correct! The number was %d. Start a new round whenever you like." % secret_number
		guess_input.editable = false
		guess_submit.disabled = true
	elif tries_left == 0:
		guess_round_active = false
		guess_feedback.text = "Out of tries. The number was %d. Try another round!" % secret_number
		guess_input.editable = false
		guess_submit.disabled = true
	elif guess > secret_number:
		guess_feedback.text = "Too high. Try a smaller number."
		_enable_next_guess()
	else:
		guess_feedback.text = "Too low. Try a larger number."
		_enable_next_guess()


func _enable_next_guess() -> void:
	guess_input.text = ""
	guess_input.editable = true
	guess_submit.disabled = false
	guess_input.grab_focus()


func _close_guess_game() -> void:
	guess_overlay.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_accept_button_pressed() -> void:
	GameManager.accept_mission()


func _on_decline_button_pressed() -> void:
	GameManager.close_mission_modal()


func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
	GameManager.reset_game()
	get_tree().reload_current_scene()
