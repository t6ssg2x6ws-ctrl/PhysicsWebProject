extends CanvasLayer

signal start_requested
signal back_requested
signal retry_requested
signal continue_requested

const GOLD := Color("d3a625")
const PARCHMENT := Color("e8d6b0")
const INK := Color("38251b")
const WINE := Color("740001")
const MUTED_INK := Color("614736")
const LIGHT_PARCHMENT := Color("f4e5c8")
const PARCHMENT_EDGE := Color("cbb286")
const BURGUNDY := Color(0.23, 0.025, 0.043, 0.92)
const ROMAN := ["I", "II", "III"]
const SCROLL_FRAME := preload("res://assets/materials/scroll_frame.tres")

var _display: Control
var _start: CenterContainer
var _finish: CenterContainer
var _start_button: Button
var _continue_button: Button
var _elapsed: Label
var _progress: Label
var _instructions: Label
var _final_time: Label
var _final_wands: Label
var _final_score: Label
var _readouts: Array[Label] = []
var _marks: Array[Label] = []
var _transition: Tween


func _ready() -> void:
	layer = 3
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display = _build_display(root)
	_start = _build_start(root)
	_finish = _build_finish(root)


func set_elapsed(seconds: float) -> void:
	var formatted := _format_time(seconds)
	if _elapsed.text != formatted:
		_elapsed.text = formatted


func set_wands(volts: Array[float], calibrated: Array[bool], active: int) -> void:
	_progress.text = "%d/3 WANDS" % calibrated.count(true)
	for i in range(ROMAN.size()):
		_marks[i].text = "◆" if calibrated[i] else "◇"
		_marks[i].modulate = GOLD if calibrated[i] else PARCHMENT
		var state := "Awakened" if calibrated[i] else ("Selected" if i == active else "Dormant")
		_readouts[i].text = "%s · %.2f V\n%s" % [ROMAN[i], volts[i], state]
		_readouts[i].modulate = GOLD if calibrated[i] or i == active else PARCHMENT


func show_instructions() -> void:
	_stop_transition()
	_start.modulate.a = 1.0
	_start.show()
	_finish.hide()
	_display.hide()
	if visible:
		focus_start()


func focus_start() -> void:
	_start_button.grab_focus()


func show_playing() -> void:
	_stop_transition()
	_start_button.release_focus()
	_start_button.disabled = true
	_display.show()
	_instructions.text = "Drag a knob or scroll over it  ·  1–3 to select, ← / → to adjust"
	_transition = create_tween()
	_transition.tween_property(_start, "modulate:a", 0.0, 0.24)
	_transition.tween_callback(func():
		_start.hide()
		_start_button.disabled = false
	)


func show_completion(result: Dictionary) -> void:
	_stop_transition()
	_start.hide()
	_start_button.disabled = false
	_instructions.text = "All three wands are calibrated"
	var elapsed: float = result.completion_time_seconds
	var seconds := int(elapsed)
	var centiseconds := clampi(int((elapsed - seconds) * 100.0), 0, 99)
	_final_time.text = "%s.%02d" % [_format_time(elapsed), centiseconds]
	_final_wands.text = "3 / 3"
	_final_score.text = "%.1f / 100" % result.performance_score
	_finish.modulate.a = 0.0
	_transition = create_tween()
	_transition.tween_interval(0.48)
	_transition.tween_callback(_finish.show)
	_transition.tween_property(_finish, "modulate:a", 1.0, 0.3)
	_transition.tween_callback(_continue_button.grab_focus)


func _stop_transition() -> void:
	if _transition:
		_transition.kill()


func _build_display(root: Control) -> Control:
	var margin := MarginContainer.new()
	_attach_full(root, margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var layout := VBoxContainer.new()
	_add(margin, layout)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_add(layout, top)
	var left := _card(top, false, Vector2(155, 0))
	_add(left, _label("⌛  ELAPSED", 15, PARCHMENT))
	_elapsed = _label("00:00", 34, PARCHMENT)
	_add(left, _elapsed)
	var title := _card(top)
	title.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(title, _label("Dumbledore's Triple Wand Trial", 30, PARCHMENT))
	_add(title, _label("TRIAL OF COURAGE", 15, GOLD))
	var right := _card(top, false, Vector2(155, 0))
	_progress = _label("0/3 WANDS", 16, PARCHMENT)
	_add(right, _progress)
	var marks := HBoxContainer.new()
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	_add(right, marks)
	for i in range(ROMAN.size()):
		var mark := _label("◇", 24, PARCHMENT)
		_marks.append(mark)
		_add(marks, mark)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add(layout, spacer)
	var bottom := CenterContainer.new()
	_add(layout, bottom)
	var card := _card(bottom)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	_add(card, row)
	for i in range(ROMAN.size()):
		var readout := _label("", 19, PARCHMENT)
		readout.custom_minimum_size.x = 112
		_readouts.append(readout)
		_add(row, readout)
	_instructions = _label("", 17, PARCHMENT)
	_add(card, _instructions)
	return margin


func _build_start(root: Control) -> CenterContainer:
	var center := CenterContainer.new()
	_attach_full(root, center)
	var panel := _card(center, true, Vector2(610, 0))
	_add(panel, _label("The Trial of Courage", 40, WINE))
	_instruction_step(panel, "1", "Read the clues", "The chamber obelisks hint at each wand's voltage.")
	_instruction_step(panel, "2", "Turn the knobs", "Drag or scroll over a knob.\nKeyboard: select with 1–3, adjust with ← / →.")
	_instruction_step(panel, "3", "Awaken all three wands", "Get all three wands glowing gold to stop the timer.")
	var buttons := _buttons(panel)
	_button(buttons, "Back", func(): back_requested.emit())
	_start_button = _button(buttons, "Begin Trial", func(): start_requested.emit(), true)
	return center


func _build_finish(root: Control) -> CenterContainer:
	var center := CenterContainer.new()
	_attach_full(root, center)
	var panel := _card(center, true, Vector2(610, 0))
	_add(panel, _label("Trial Complete", 40, WINE))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	_add(panel, stats)
	_final_time = _result_metric(stats, "FINAL TIME", "00:00.00")
	_final_wands = _result_metric(stats, "WANDS AWAKENED", "3 / 3")
	_final_score = _result_metric(stats, "PERFORMANCE", "100.0 / 100", true)
	var buttons := _buttons(panel)
	_button(buttons, "Retry", func(): retry_requested.emit())
	_continue_button = _button(buttons, "Save Result & Continue", func(): continue_requested.emit(), true)
	return center


func _instruction_step(parent: VBoxContainer, number: String, title: String, detail: String) -> void:
	var card := _inset(parent)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	_add(card, line)
	var marker := _label(number, 23, WINE)
	marker.custom_minimum_size.x = 28
	_add(line, marker)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 2)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(line, copy)
	var heading := _label(title, 25, WINE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_add(copy, heading)
	var description := _label(detail, 19, INK)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(copy, description)


func _result_metric(parent: HBoxContainer, heading: String, initial: String, accent := false) -> Label:
	var card := _inset(parent, accent)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 158
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	_add(card, stack)
	_add(stack, _label(heading, 15, PARCHMENT if accent else MUTED_INK))
	var value := _label(initial, 32 if accent else 28, LIGHT_PARCHMENT if accent else INK)
	_add(stack, value)
	return value


func _inset(parent: Control, accent := false) -> PanelContainer:
	var card := PanelContainer.new()
	var style := _style(WINE if accent else LIGHT_PARCHMENT, GOLD if accent else PARCHMENT_EDGE, 8.0)
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	_add(parent, card)
	return card


func _card(parent: Control, parchment := false, minimum := Vector2.ZERO) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	if parchment:
		panel.add_theme_stylebox_override("panel", SCROLL_FRAME)
	else:
		var style := _style(BURGUNDY, GOLD, 13.0)
		style.content_margin_left = 20.0
		style.content_margin_right = 20.0
		panel.add_theme_stylebox_override("panel", style)
	_add(parent, panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8 if parchment else 3)
	_add(panel, column)
	return column


func _buttons(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_add(parent, row)
	return row


func _button(parent: Control, title: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(125, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 22 if primary else 18)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", PARCHMENT)
	button.add_theme_color_override("font_pressed_color", PARCHMENT)
	button.add_theme_stylebox_override("normal", _style(Color("740001") if primary else INK, GOLD, 9.0))
	button.add_theme_stylebox_override("hover", _style(Color("9e101a"), GOLD, 9.0))
	button.add_theme_stylebox_override("pressed", _style(Color("580207"), GOLD, 9.0))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, PARCHMENT, 9.0))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _style(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = padding + 5.0
	style.content_margin_right = padding + 5.0
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _label(caption: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label


func _attach_full(parent: Control, child: Control) -> void:
	_add(parent, child)
	child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _add(parent: Control, child: Control) -> void:
	child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(child)


func _format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]
