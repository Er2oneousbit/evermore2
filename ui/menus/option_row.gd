# =============================================================================
# option_row.gd  -  One setting in the settings menu: "Bloom      <  On  >"
# -----------------------------------------------------------------------------
# WHAT:  A label and a value you change with left/right (keyboard, D-pad,
#        stick), by pressing it (next value), or with the mouse (click the
#        left half for the previous value, the right half for the next). Works
#        the same for every kind of option, so gamepad players never fight a
#        dropdown or a tiny slider.
# DATA:  One row of Settings.SCHEMA. It writes Settings.set_value and follows
#        Settings.changed (picking a quality preset updates the switches).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name OptionRow
extends HBoxContainer

const VALUE_WIDTH := 150.0

var option: Dictionary
## The focusable part (the menu hands focus to it).
var value_button: Button


func setup(opt: Dictionary) -> OptionRow:
	option = opt
	name = String(opt["key"])
	var label := Label.new()
	label.text = opt["label"]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	value_button = Button.new()
	value_button.name = "Value"
	value_button.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	value_button.focus_mode = Control.FOCUS_ALL
	value_button.gui_input.connect(_on_value_input)
	value_button.pressed.connect(func() -> void: step(1))
	add_child(value_button)
	refresh()
	Settings.changed.connect(func(key: String, _v: Variant) -> void:
		if key == option["key"]:
			refresh())
	return self


## Move to the next (+1) or previous (-1) value.
func step(dir: int) -> void:
	var key: String = option["key"]
	var v: Variant = Settings.get_value(key)
	match option["type"]:
		"bool":
			Settings.set_value(key, not v)
		"range":
			Settings.set_value(key, float(v) + dir * float(option["step"]))
		"choice":
			var opts: Array = option["options"]
			var i := _index_of(opts, v)
			Settings.set_value(key, opts[wrapi(i + dir, 0, opts.size())][0])


func refresh() -> void:
	value_button.text = "<  %s  >" % value_text()


## The current value as the player reads it.
func value_text() -> String:
	var v: Variant = Settings.get_value(option["key"])
	match option["type"]:
		"bool":
			return "On" if v else "Off"
		"range":
			return "%d%%" % roundi(float(v) * 100.0)
		"choice":
			var opts: Array = option["options"]
			var i := _index_of(opts, v)
			return opts[i][1] if i >= 0 else str(v)
	return str(v)


func _on_value_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		step(1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Left half goes back, right half goes forward.
		step(-1 if event.position.x < value_button.size.x * 0.5 else 1)
		value_button.grab_focus()
		accept_event()


static func _index_of(opts: Array, v: Variant) -> int:
	for i in opts.size():
		var o: Variant = opts[i][0]
		if (o is float or o is int) and (v is float or v is int):
			if absf(float(o) - float(v)) < 0.001:
				return i
		elif o == v:
			return i
	return -1
