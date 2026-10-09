# =============================================================================
# debug_menu.gd  (main scene: ui/debug_menu/debug_menu.tscn)
# -----------------------------------------------------------------------------
# WHAT:  The screen the game opens on while it's a prototype: pick the map to
#        start in, the time of day and the difficulty, read the debug keys,
#        open Settings or quit. Same look as the pause and settings menus.
#          Prologue (from the start)      title card, dinner, street; the
#                                         prologue's flags are cleared
#          Prologue street (skip intro)   the street with the intro done
#          Test yard, Combat arena        the demo maps
#        Start time applies to maps with a free clock (the prologue keeps its
#        held story timing). Hard is what --hard sets.
# HOW:   begin() sets the options and hands the map to Travel.go (fade out,
#        load, fade in) with carry = false: nothing rides along, the party
#        stands on the map's own spawn. The pause menu's "Debug menu" and the
#        end of the prologue slice come back here the same way. The last
#        choice is remembered in user://debug_menu.cfg (test runs keep it in
#        memory) and the cursor starts on it.
#        --yard / --arena skip the menu: Debug sends the game there and this
#        scene stays empty (Debug.start_scene_for decides).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DebugMenu
extends Control

const SCENE := "res://ui/debug_menu/debug_menu.tscn"
const STREET := "res://realms/podunk/ruffleberg_lot_hd.tscn"
const INTRO_FLAG := "prologue.intro_done"

## The map entries, in menu order.
const MAPS := [
	{"id": "prologue", "label": "Prologue (from the start)", "scene": STREET},
	{"id": "street", "label": "Prologue street (skip the intro)", "scene": STREET},
	{"id": "yard", "label": "Test yard", "scene": "res://realms/big_yard/yard_hd.tscn"},
	{"id": "arena", "label": "Combat arena", "scene": "res://realms/test/combat_arena_hd.tscn"},
]
const TIMES := [["morning", "Morning"], ["day", "Day"], ["golden", "Golden hour"], ["night", "Night"]]
const DIFFICULTIES := [["normal", "Normal"], ["hard", "Hard"]]

## Where the last choice is saved.
static var path := "user://debug_menu.cfg"
## The last choice: {"map", "time", "difficulty"} (loaded on first use).
static var last := {}

var map_buttons := {}
var time_button: Button
var difficulty_button: Button
var settings_button: Button
var quit_button: Button

var _time := "day"
var _difficulty := "normal"
var _layout: Control
var _settings: SettingsMenu
var _building := true  # no focus tick for the focus the build sets


func _ready() -> void:
	# --yard / --arena: Debug is already on its way there.
	if not Debug.start_scene_for(OS.get_cmdline_user_args()).is_empty():
		return
	Audio.stop_music(0.5)
	Audio.set_ambience("")
	_load_last()
	_time = last["time"]
	_difficulty = last["difficulty"]
	_build()
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void:
		if not _building:
			Audio.play("ui_move"))
	var start: Button = map_buttons.get(last["map"], map_buttons[MAPS[0]["id"]])
	start.grab_focus()
	_building = false


# -----------------------------------------------------------------------------
# Starting a map (tests call these too)
# -----------------------------------------------------------------------------
static func map_entry(id: String) -> Dictionary:
	for m: Dictionary in MAPS:
		if m["id"] == id:
			return m
	return {}


## Set the options and travel to the map. False if Travel refused.
static func begin(id: String, time: String, difficulty: String) -> bool:
	var entry := map_entry(id)
	if entry.is_empty():
		return false
	GameState.difficulty = difficulty
	if id == "prologue":
		GameState.clear_flags("prologue.")
	elif id == "street":
		GameState.set_flag(INTRO_FLAG)
	# Free-clock maps keep the phase they find; the held prologue sets its own.
	Clock.paused = false
	Clock.jump(time, 0.0)
	last = {"map": id, "time": time, "difficulty": difficulty}
	_save_last()
	return await Travel.go(entry["scene"], "", false)


static func _persist() -> bool:
	for a in OS.get_cmdline_args():
		if a.begins_with("res://tests/"):
			return false
	return true


static func _load_last() -> void:
	if not last.is_empty():
		return
	last = {"map": MAPS[0]["id"], "time": "day",
		"difficulty": "hard" if GameState.difficulty == "hard" else "normal"}
	var cfg := ConfigFile.new()
	if _persist() and cfg.load(path) == OK:
		var map: String = cfg.get_value("last", "map", last["map"])
		var time: String = cfg.get_value("last", "time", last["time"])
		var diff: String = cfg.get_value("last", "difficulty", last["difficulty"])
		last = {"map": map if not map_entry(map).is_empty() else last["map"],
			"time": time if TIMES.any(func(t: Array) -> bool: return t[0] == time) else last["time"],
			"difficulty": diff if diff in ["normal", "hard"] else last["difficulty"]}


static func _save_last() -> void:
	if not _persist():
		return
	var cfg := ConfigFile.new()
	for k: String in last:
		cfg.set_value("last", k, last[k])
	cfg.save(path)


# -----------------------------------------------------------------------------
# Building the screen
# -----------------------------------------------------------------------------
func _build() -> void:
	theme = MenuTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var frame := SafeFrame.new()
	frame.name = "Frame"
	add_child(frame)
	_layout = CenterContainer.new()
	_layout.name = "Layout"
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_layout)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_layout.add_child(row)

	var left := PanelContainer.new()
	left.name = "Menu"
	row.add_child(left)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(190, 0)
	list.add_theme_constant_override("separation", 3)
	left.add_child(list)
	var title := Label.new()
	title.text = "Debug Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", MenuTheme.TITLE_SIZE)
	title.add_theme_color_override("font_color", MenuTheme.BORDER)
	list.add_child(title)
	list.add_child(_caption("Start in"))
	for m: Dictionary in MAPS:
		var id: String = m["id"]
		map_buttons[id] = _button(list, m["label"], func() -> void: _start(id))
	list.add_child(_caption("Options (left / right changes)"))
	time_button = _cycler(list, "Start time", TIMES, func() -> String: return _time,
		func(v: String) -> void: _time = v)
	difficulty_button = _cycler(list, "Difficulty", DIFFICULTIES, func() -> String: return _difficulty,
		func(v: String) -> void: _difficulty = v)
	settings_button = _button(list, "Settings", _open_settings)
	quit_button = _button(list, "Quit", func() -> void: get_tree().quit())

	var right := PanelContainer.new()
	right.name = "Keys"
	row.add_child(right)
	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 2)
	right.add_child(keys)
	var kt := Label.new()
	kt.text = "Debug keys"
	kt.add_theme_color_override("font_color", MenuTheme.BORDER)
	keys.add_child(kt)
	for line in Debug.key_lines():
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(210, 0)
		l.add_theme_color_override("font_color", MenuTheme.DIM)
		keys.add_child(l)


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", MenuTheme.DIM)
	return l


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = text.replace(" ", "")
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		Audio.play("ui_confirm")
		action.call())
	parent.add_child(b)
	return b


## A button that steps through `options` ([[value, label], ...]): Enter or
## right = next, left = previous.
func _cycler(parent: Control, label: String, options: Array, getter: Callable, setter: Callable) -> Button:
	var b := Button.new()
	b.name = label.replace(" ", "")
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var step := func(by: int) -> void:
		var i := 0
		for k in options.size():
			if options[k][0] == getter.call():
				i = k
		var nxt: Array = options[posmod(i + by, options.size())]
		setter.call(nxt[0])
		b.text = "%s: < %s >" % [label, nxt[1]]
		Audio.play("ui_move")
	b.set_meta("step", step)
	var refresh := func() -> void:
		for o: Array in options:
			if o[0] == getter.call():
				b.text = "%s: < %s >" % [label, o[1]]
	refresh.call()
	b.pressed.connect(func() -> void: step.call(1))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_left"):
			step.call(-1)
			b.accept_event()
		elif e.is_action_pressed("ui_right"):
			step.call(1)
			b.accept_event())
	parent.add_child(b)
	return b


## Step an option (tests use this instead of key events).
func step_option(button: Button, by: int) -> void:
	(button.get_meta("step") as Callable).call(by)


func selected_time() -> String:
	return _time


func selected_difficulty() -> String:
	return _difficulty


func _start(id: String) -> void:
	begin(id, _time, _difficulty)


func _open_settings() -> void:
	if _settings:
		return
	_layout.visible = false
	_settings = SettingsMenu.new()
	_settings.name = "Settings"
	_settings.closed.connect(func() -> void:
		_settings.queue_free()
		_settings = null
		Audio.play("ui_back")
		_layout.visible = true
		settings_button.grab_focus.call_deferred())
	add_child(_settings)
