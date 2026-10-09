# =============================================================================
# pause_menu.gd  (autoload: PauseMenu)
# -----------------------------------------------------------------------------
# WHAT:  Esc / gamepad Start pauses the game and opens: Resume, Settings, Debug
#        menu (back to the start menu), Quit to desktop. The game world stops (get_tree().paused); this menu and
#        the settings screen keep running.
# HOW:   It's always loaded but builds its nodes the first time it opens.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends CanvasLayer

signal opened
signal closed

var _root: Control
var _list: VBoxContainer
var _settings: SettingsMenu
var _resume: Button
var _settings_button: Button
var _found: Label
var _opening := false  # no focus tick for the focus that opening sets


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A tick whenever the highlighted item changes (pause or settings menu).
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void:
		if is_open() and not _opening:
			Audio.play("ui_move"))


func is_open() -> bool:
	return _root != null and _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		if is_open() and _settings == null and event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return
	if BindingRow.listening:
		return
	if not is_open():
		open()
	elif _settings == null:
		close()
	else:
		return  # the settings screen handles its own back
	get_viewport().set_input_as_handled()


func open() -> void:
	if _root == null:
		_build()
	_root.visible = true
	_list.visible = true
	_refresh_found()
	get_tree().paused = true
	Audio.play("ui_open")
	_opening = true
	_resume.grab_focus()
	_opening = false
	opened.emit()


func close() -> void:
	if _settings:
		_close_settings()
	if _root and _root.visible:
		Audio.play("ui_back")
	if _root:
		_root.visible = false
	get_tree().paused = false
	closed.emit()


func open_settings() -> SettingsMenu:
	if _root == null or not _root.visible:
		open()
	_list.visible = false
	_settings = SettingsMenu.new()
	_settings.name = "Settings"
	_settings.closed.connect(_close_settings)
	_root.add_child(_settings)
	return _settings


## Unpause and fade back to the debug start menu (nothing carries over).
func back_to_debug_menu() -> void:
	close()
	Travel.go(DebugMenu.SCENE, "", false)


func _close_settings() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
		Audio.play("ui_back")
	_list.visible = true
	_settings_button.grab_focus.call_deferred()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = MenuTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.custom_minimum_size = Vector2(150, 0)
	_list.add_theme_constant_override("separation", 3)
	panel.add_child(_list)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", MenuTheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", MenuTheme.BORDER)
	_list.add_child(title)
	_found = Label.new()
	_found.name = "HiddenFound"
	_found.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(_found)
	_resume = _button("Resume", close)
	_settings_button = _button("Settings", func() -> void: open_settings())
	_button("Debug menu", back_to_debug_menu)
	_button("Quit to desktop", func() -> void: get_tree().quit())
	# The panel and list share visibility with the settings screen's swap.
	_list.visibility_changed.connect(func() -> void: panel.visible = _list.visible)


## "Hidden items: 2 / 5" for the realm you're in (no silent missables).
func _refresh_found() -> void:
	var realm := get_tree().get_first_node_in_group("ascii_realm") as AsciiRealm
	var c := realm.hidden_counts() if realm else Vector2i.ZERO
	_found.visible = c.y > 0
	_found.text = "Hidden items: %d / %d" % [c.x, c.y]


## The hidden-items line as shown ("" when hidden). Tests read it.
func found_text() -> String:
	return _found.text if _found and _found.visible else ""


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = text.replace(" ", "")
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		Audio.play("ui_confirm")
		action.call())
	_list.add_child(b)
	return b
