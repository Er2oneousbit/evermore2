# =============================================================================
# name_entry.gd  -  The name screen: an on-screen letter grid or the keyboard
# -----------------------------------------------------------------------------
# WHAT:  Asks for one name (the kid's, then the dog's). A grid of letters you
#        move over with the D-pad / stick / arrows and press (gamepad, mouse),
#        or you just type: letters, digits, ' and space; Backspace deletes;
#        Enter (or the Done button, or gamepad Start) accepts. Esc / gamepad B
#        goes back. X on a pad deletes.
# RULES: at most MAX_LENGTH characters; never empty (an empty name is rejected
#        with a message and a sound); no leading or doubled spaces; the first
#        letter of a name and of each word starts as a capital on the grid.
# HOW:   NewGameFlow creates one, sets `heading` and `text` (the default),
#        adds it and listens for `accepted(name)` / `cancelled`. Tests drive
#        type_char / backspace / submit directly.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name NameEntry
extends Control

signal accepted(entry: String)
signal cancelled

const MAX_LENGTH := 10
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const COLUMNS := 10
## Allowed non-letters (besides digits).
const EXTRA := "' "

var heading := "Name"
var text := ""
var error := ""

var _shift := true
var _letter_buttons: Array[Button] = []
var _name_label: Label
var _count_label: Label
var _error_label: Label
var _done: Button
var _age := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = text.substr(0, MAX_LENGTH)
	_shift = text.is_empty() or text.ends_with(" ")
	_build()
	_refresh()
	_letter_buttons[0].grab_focus.call_deferred()


func _process(delta: float) -> void:
	_age += delta
	# The cursor blinks (game time).
	_name_label.text = _display()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var title := Label.new()
	title.name = "Heading"
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", MenuTheme.BORDER)
	box.add_child(title)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.custom_minimum_size = Vector2(200, 28)
	_name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_name_label)
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_color_override("font_color", MenuTheme.DIM)
	box.add_child(_count_label)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for ch in LETTERS:
		var b := _key(ch, func() -> void: type_char(_shown_letter(ch)))
		b.name = "Key" + ch
		grid.add_child(b)
		_letter_buttons.append(b)
	grid.add_child(_key("Aa", func() -> void:
		_shift = not _shift
		_refresh()))
	grid.add_child(_key("Spc", func() -> void: type_char(" ")))
	grid.add_child(_key("'", func() -> void: type_char("'")))
	var del := _key("Del", func() -> void: backspace())
	del.name = "KeyDel"
	grid.add_child(del)

	_error_label = Label.new()
	_error_label.name = "Error"
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	box.add_child(_error_label)

	_done = Button.new()
	_done.name = "Done"
	_done.text = "Done"
	_done.focus_mode = Control.FOCUS_ALL
	_done.pressed.connect(func() -> void: submit())
	box.add_child(_done)

	var hint := Label.new()
	hint.text = "Type, or pick letters.  Enter / Start: done.  Backspace / X: delete.  Esc / B: back."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", MenuTheme.DIM)
	box.add_child(hint)


func _key(label: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(26, 18)
	b.pressed.connect(func() -> void:
		Audio.play("ui_confirm")
		action.call())
	return b


func _shown_letter(ch: String) -> String:
	return ch if _shift else ch.to_lower()


func _refresh() -> void:
	for b in _letter_buttons:
		b.text = _shown_letter(b.name.substr(3))
	_count_label.text = "%d / %d" % [text.length(), MAX_LENGTH]
	if not _name_label:
		return
	_name_label.text = _display()


func _display() -> String:
	var blink := int(_age * 2.0) % 2 == 0
	if text.length() >= MAX_LENGTH:
		return text
	return text + ("_" if blink else " ")


## Add one character. False if it isn't allowed or the name is full.
func type_char(c: String) -> bool:
	if c.length() != 1:
		return false
	var ok := c.to_upper() != c.to_lower() or c.is_valid_int() or EXTRA.contains(c)
	if c == " " and (text.is_empty() or text.ends_with(" ")):
		ok = false
	if not ok or text.length() >= MAX_LENGTH:
		Audio.play("ui_back")
		return false
	text += c
	error = ""
	_error_label.text = ""
	_shift = text.ends_with(" ")
	_refresh()
	return true


func backspace() -> void:
	if text.is_empty():
		return
	text = text.substr(0, text.length() - 1)
	_shift = text.is_empty() or text.ends_with(" ")
	error = ""
	_error_label.text = ""
	_refresh()


## Accept the name. False (with a message) if it's empty.
func submit() -> bool:
	var entry := text.strip_edges()
	if entry.is_empty():
		error = "A name is needed."
		_error_label.text = error
		Audio.play("ui_back")
		return false
	accepted.emit(entry)
	return true


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or _age < 0.15:
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_BACKSPACE:
			backspace()
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			if k.echo:
				return
			submit()
		elif k.keycode == KEY_ESCAPE:
			cancelled.emit()
		elif k.unicode >= 32 and not k.echo:
			type_char(String.chr(k.unicode))
		else:
			return  # arrows, Tab: the focus system
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var j := event as InputEventJoypadButton
		if j.button_index == JOY_BUTTON_X:
			backspace()
		elif j.button_index == JOY_BUTTON_START:
			submit()
		elif j.button_index == JOY_BUTTON_B:
			cancelled.emit()
		else:
			return
		get_viewport().set_input_as_handled()
