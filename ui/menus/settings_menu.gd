# =============================================================================
# settings_menu.gd  -  The settings screen: Graphics, Display, Audio, Gameplay,
#                      Controls
# -----------------------------------------------------------------------------
# WHAT:  Tabs along the top, the options of the current tab below (built from
#        Settings.SCHEMA, so a new option appears here by itself), and
#        "Reset this page" / "Back" at the bottom. Changes apply and save as
#        you make them.
# INPUT: mouse, keyboard or gamepad. Up/down moves, left/right changes a value,
#        LB/RB or Page Up/Page Down switches tabs, Esc / gamepad B goes back.
# USED BY: the pause menu (ui/menus/pause_menu.gd); a title screen later.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name SettingsMenu
extends Control

signal closed

const PANEL_SIZE := Vector2(440, 310)

var current_tab := ""
var _tab_buttons: Dictionary = {}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _notice: Label
var _reset: Button
var _back: Button


func _ready() -> void:
	theme = MenuTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	show_tab(Settings.TABS[0][0])


func show_tab(tab: String) -> void:
	if BindingRow.listening:
		BindingRow.listening.cancel()
	current_tab = tab
	for t: String in _tab_buttons:
		var b: Button = _tab_buttons[t]
		b.add_theme_color_override("font_color", MenuTheme.BORDER if t == tab else MenuTheme.DIM)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_notice.text = ""
	if tab == "controls":
		_build_controls()
	else:
		for opt: Dictionary in Settings.options_in(tab):
			_list.add_child(OptionRow.new().setup(opt))
	_wire_focus()
	_scroll.scroll_vertical = 0
	var first := _first_focus()
	if first:
		first.grab_focus.call_deferred()


## The row for an option on the current tab (tests use it).
func row(key: String) -> Node:
	return _list.get_node_or_null(key)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or BindingRow.listening:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
	elif _is_tab_key(event, true):
		_cycle_tab(1)
	elif _is_tab_key(event, false):
		_cycle_tab(-1)
	else:
		return
	get_viewport().set_input_as_handled()


func close() -> void:
	if BindingRow.listening:
		BindingRow.listening.cancel()
	Settings.save()
	closed.emit()


# -----------------------------------------------------------------------------
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = PANEL_SIZE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", MenuTheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", MenuTheme.BORDER)
	col.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 2)
	col.add_child(tabs)
	for pair: Array in Settings.TABS:
		var b := Button.new()
		b.name = pair[0]
		b.text = pair[1]
		b.focus_mode = Control.FOCUS_ALL
		var tab_id: String = pair[0]
		b.pressed.connect(func() -> void: show_tab(tab_id))
		tabs.add_child(b)
		_tab_buttons[tab_id] = b

	col.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 1)
	_scroll.add_child(_list)

	_notice = Label.new()
	_notice.add_theme_color_override("font_color", MenuTheme.DIM)
	_notice.add_theme_font_size_override("font_size", 8)
	col.add_child(_notice)

	var foot := HBoxContainer.new()
	col.add_child(foot)
	var hint := Label.new()
	hint.text = "LB / RB: tabs    B / Esc: back"
	hint.add_theme_color_override("font_color", MenuTheme.DIM)
	hint.add_theme_font_size_override("font_size", 8)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(hint)
	_reset = Button.new()
	_reset.name = "Reset"
	_reset.text = "Reset this page"
	_reset.pressed.connect(func() -> void:
		Settings.reset_tab(current_tab)
		show_tab(current_tab))
	foot.add_child(_reset)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "Back"
	_back.pressed.connect(close)
	foot.add_child(_back)


func _build_controls() -> void:
	var head := HBoxContainer.new()
	var labels := ["", "Keyboard", "", "Gamepad"]
	for i in labels.size():
		var l := Label.new()
		l.text = labels[i]
		l.add_theme_color_override("font_color", MenuTheme.DIM)
		l.add_theme_font_size_override("font_size", 8)
		if i == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size = Vector2(BindingRow.SLOT_WIDTH, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(l)
	_list.add_child(head)
	for pair: Array in InputSetup.REBINDABLE:
		var r := BindingRow.new().setup(pair[0], pair[1])
		r.rebound.connect(_on_rebound)
		_list.add_child(r)
	var fixed := Label.new()
	fixed.text = "Pause menu: Esc / Start (fixed). Sticks always move."
	fixed.add_theme_color_override("font_color", MenuTheme.DIM)
	fixed.add_theme_font_size_override("font_size", 8)
	_list.add_child(fixed)


func _on_rebound(action: String, taken: Array[String]) -> void:
	for c in _list.get_children():
		if c is BindingRow:
			c.refresh()
	if taken.is_empty():
		_notice.text = ""
		return
	var names: PackedStringArray = []
	for t in taken:
		for pair: Array in InputSetup.REBINDABLE:
			if pair[0] == t:
				names.append(pair[1])
	_notice.text = "Moved from %s. Check it still has a key." % ", ".join(names)
	Debug.log_verbose("Rebound %s (taken from %s)" % [action, taken])


## Up/down walks the rows, then the footer; the tabs sit above the first row.
func _wire_focus() -> void:
	var stops: Array[Control] = []
	for c in _list.get_children():
		if c is OptionRow:
			stops.append(c.value_button)
		elif c is BindingRow:
			stops.append(c.first_slot())
	stops.append(_reset)
	var tab_now: Button = _tab_buttons[current_tab]
	for i in stops.size():
		var up: Control = stops[i - 1] if i > 0 else tab_now
		var down: Control = stops[i + 1] if i + 1 < stops.size() else stops[i]
		stops[i].focus_neighbor_top = stops[i].get_path_to(up)
		stops[i].focus_neighbor_bottom = stops[i].get_path_to(down)
	for t: Button in _tab_buttons.values():
		t.focus_neighbor_bottom = t.get_path_to(stops[0]) if not stops.is_empty() else NodePath()
	_back.focus_neighbor_top = _back.get_path_to(stops[stops.size() - 2] if stops.size() > 1 else tab_now)
	# Binding rows: every slot goes up/down to the same column of its neighbor.
	var rows: Array = _list.get_children().filter(func(c: Node) -> bool: return c is BindingRow)
	for i in rows.size():
		for s in rows[i].slots.size():
			var btn: Button = rows[i].slots[s][2]
			var up_btn: Control = rows[i - 1].slots[s][2] if i > 0 else tab_now
			var down_btn: Control = rows[i + 1].slots[s][2] if i + 1 < rows.size() else _reset
			btn.focus_neighbor_top = btn.get_path_to(up_btn)
			btn.focus_neighbor_bottom = btn.get_path_to(down_btn)


func _first_focus() -> Control:
	for c in _list.get_children():
		if c is OptionRow:
			return c.value_button
		if c is BindingRow:
			return c.first_slot()
	return _back


func _cycle_tab(dir: int) -> void:
	var ids: Array = Settings.TABS.map(func(p: Array) -> String: return p[0])
	show_tab(ids[wrapi(ids.find(current_tab) + dir, 0, ids.size())])


static func _is_tab_key(event: InputEvent, next: bool) -> bool:
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == (JOY_BUTTON_RIGHT_SHOULDER if next else JOY_BUTTON_LEFT_SHOULDER)
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode == (KEY_PAGEDOWN if next else KEY_PAGEUP)
	return false
