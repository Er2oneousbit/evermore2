# =============================================================================
# settings.gd  (autoload: Settings)
# -----------------------------------------------------------------------------
# WHAT:  The player's options: graphics, display, audio, gameplay and controls.
#        One table (SCHEMA) lists every option; the settings menu is built from
#        it, so adding an option is one row here plus whoever applies it.
#        Saved to user://settings.cfg and applied live when changed.
#
# WHO APPLIES WHAT:
#        Settings itself    window mode, V-Sync, frame cap, widest view, audio
#                           volumes, control bindings (via InputSetup)
#        HdView             graphics (effects, shadows, brightness, the view)
#        Atmosphere         brightness in the classic 2D view
#        Fx                 screen shake, damage numbers
#        DialogueBox        text speed
#        They read Settings.get_value(key) and listen to Settings.changed.
#
# TESTS never read or write the player's file: a run whose scene is under
#        res://tests/ keeps everything in memory, on the defaults.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## An option changed (already applied by Settings, if it's one of its own).
signal changed(key: String, value: Variant)

## Where settings are saved (tests point it elsewhere).
var path := "user://settings.cfg"

## The menu's tabs, in order: [id, title].
const TABS := [
	["graphics", "Graphics"],
	["display", "Display"],
	["audio", "Audio"],
	["gameplay", "Gameplay"],
	["controls", "Controls"],
]

## Every option. type: "choice" (options = [[value, label], ...]), "bool", or
## "range" (min, max, step; shown as a percent).
const SCHEMA := [
	# --- Graphics --------------------------------------------------------------
	{"key": "view", "tab": "graphics", "label": "View", "type": "choice", "default": "hd2d",
		"options": [["hd2d", "HD-2D"], ["classic", "Classic 2D"]]},
	{"key": "quality", "tab": "graphics", "label": "Quality preset", "type": "choice", "default": "ultra",
		"options": [["low", "Low"], ["medium", "Medium"], ["high", "High"], ["ultra", "Ultra"], ["custom", "Custom"]]},
	{"key": "shadows", "tab": "graphics", "label": "Shadows", "type": "choice", "default": "high",
		"options": [["off", "Off"], ["low", "Low"], ["high", "High"]]},
	{"key": "light_shafts", "tab": "graphics", "label": "Light shafts and haze", "type": "bool", "default": true},
	{"key": "reflections", "tab": "graphics", "label": "Water reflections", "type": "bool", "default": true},
	{"key": "ambient_occlusion", "tab": "graphics", "label": "Ambient occlusion", "type": "bool", "default": true},
	{"key": "tilt_shift", "tab": "graphics", "label": "Tilt-shift blur", "type": "bool", "default": true},
	{"key": "bloom", "tab": "graphics", "label": "Bloom", "type": "bool", "default": true},
	{"key": "particles", "tab": "graphics", "label": "Pollen and fireflies", "type": "bool", "default": true},
	{"key": "clouds", "tab": "graphics", "label": "Cloud shadows", "type": "bool", "default": true},
	{"key": "brightness", "tab": "graphics", "label": "Brightness", "type": "range", "default": 1.0,
		"min": 0.6, "max": 1.4, "step": 0.05},
	# --- Display ---------------------------------------------------------------
	{"key": "window_mode", "tab": "display", "label": "Window", "type": "choice", "default": "windowed",
		"options": [["windowed", "Windowed"], ["borderless", "Borderless fullscreen"], ["fullscreen", "Exclusive fullscreen"]]},
	{"key": "vsync", "tab": "display", "label": "V-Sync", "type": "bool", "default": true},
	{"key": "max_fps", "tab": "display", "label": "Frame rate limit", "type": "choice", "default": 0,
		"options": [[0, "Unlimited"], [30, "30"], [60, "60"], [120, "120"], [144, "144"], [240, "240"]]},
	{"key": "max_aspect", "tab": "display", "label": "Widest view", "type": "choice", "default": 0.0,
		"options": [[0.0, "Fill the screen"], [1.7778, "16:9"], [2.3333, "21:9"], [3.5556, "32:9"]]},
	# --- Audio -----------------------------------------------------------------
	{"key": "volume_master", "tab": "audio", "label": "Master volume", "type": "range", "default": 1.0,
		"min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "volume_music", "tab": "audio", "label": "Music", "type": "range", "default": 0.8,
		"min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "volume_sfx", "tab": "audio", "label": "Sound effects", "type": "range", "default": 0.8,
		"min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "volume_ambience", "tab": "audio", "label": "Ambience", "type": "range", "default": 0.8,
		"min": 0.0, "max": 1.0, "step": 0.05},
	# --- Gameplay --------------------------------------------------------------
	{"key": "text_speed", "tab": "gameplay", "label": "Text speed", "type": "choice", "default": 48.0,
		"options": [[24.0, "Slow"], [48.0, "Normal"], [96.0, "Fast"], [0.0, "Instant"]]},
	{"key": "screen_shake", "tab": "gameplay", "label": "Screen shake", "type": "range", "default": 1.0,
		"min": 0.0, "max": 1.0, "step": 0.25},
	{"key": "damage_numbers", "tab": "gameplay", "label": "Damage numbers", "type": "bool", "default": true},
	{"key": "run_mode", "tab": "gameplay", "label": "Run button", "type": "choice", "default": "hold",
		"options": [["hold", "Hold to run"], ["toggle", "Press to toggle"]]},
]

## What each quality preset switches on. Picking one sets these; changing any
## of them afterwards turns the preset into "custom".
const QUALITY_PRESETS := {
	"low": {"shadows": "low", "light_shafts": false, "reflections": false, "ambient_occlusion": false,
		"tilt_shift": false, "bloom": false, "particles": false, "clouds": true},
	"medium": {"shadows": "high", "light_shafts": false, "reflections": false, "ambient_occlusion": false,
		"tilt_shift": true, "bloom": true, "particles": true, "clouds": true},
	"high": {"shadows": "high", "light_shafts": true, "reflections": false, "ambient_occlusion": true,
		"tilt_shift": true, "bloom": true, "particles": true, "clouds": true},
	"ultra": {"shadows": "high", "light_shafts": true, "reflections": true, "ambient_occlusion": true,
		"tilt_shift": true, "bloom": true, "particles": true, "clouds": true},
}

## Audio buses the volumes drive (created if the project doesn't have them).
const BUSES := {"volume_master": "Master", "volume_music": "Music", "volume_sfx": "SFX",
		"volume_ambience": "Ambience"}

var _values: Dictionary = {}
## Saved control overrides: action -> {"keys": [...], "buttons": [...]}.
var _controls: Dictionary = {}
var _persist := true
var _applying_preset := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_persist = not _is_test_run()
	for opt: Dictionary in SCHEMA:
		_values[opt["key"]] = opt["default"]
	_ensure_buses()
	if _persist:
		_load()
	_apply_all()


# -----------------------------------------------------------------------------
# Reading and changing
# -----------------------------------------------------------------------------
func get_value(key: String) -> Variant:
	if not _values.has(key):
		Debug.log_warn("Settings: unknown option '%s'" % key)
		return null
	return _values[key]


func set_value(key: String, value: Variant) -> void:
	var opt := option(key)
	if opt.is_empty():
		Debug.log_warn("Settings: unknown option '%s'" % key)
		return
	value = _sanitize(opt, value)
	if _values[key] == value:
		return
	_values[key] = value
	_apply(key)
	changed.emit(key, value)
	# Presets and their switches keep each other honest.
	if key == "quality" and QUALITY_PRESETS.has(value):
		_applying_preset = true
		for k: String in QUALITY_PRESETS[value]:
			set_value(k, QUALITY_PRESETS[value][k])
		_applying_preset = false
	elif not _applying_preset and _is_quality_switch(key):
		_values["quality"] = _matching_preset()
		changed.emit("quality", _values["quality"])
	save()


## The SCHEMA row for `key` (empty if there's none).
func option(key: String) -> Dictionary:
	for opt: Dictionary in SCHEMA:
		if opt["key"] == key:
			return opt
	return {}


func options_in(tab: String) -> Array:
	return SCHEMA.filter(func(o: Dictionary) -> bool: return o["tab"] == tab)


## Back to the defaults for one tab (controls included).
func reset_tab(tab: String) -> void:
	if tab == "controls":
		_controls.clear()
		InputSetup.reset_to_defaults()
		changed.emit("controls", null)
		save()
		return
	for opt: Dictionary in options_in(tab):
		set_value(opt["key"], opt["default"])


# -----------------------------------------------------------------------------
# Controls (InputSetup does the binding; Settings remembers it)
# -----------------------------------------------------------------------------
## Remember an action's current bindings (call after InputSetup changed them).
func store_binding(action: String) -> void:
	_controls[action] = InputSetup.bindings_of(action)
	changed.emit("controls", action)
	save()


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save() -> void:
	if not _persist:
		return
	var cfg := ConfigFile.new()
	for opt: Dictionary in SCHEMA:
		cfg.set_value(opt["tab"], opt["key"], _values[opt["key"]])
	for action: String in _controls:
		cfg.set_value("controls", action, _controls[action])
	var err := cfg.save(path)
	if err != OK:
		Debug.log_warn("Settings: couldn't save %s (error %d)" % [path, err])


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return  # first run: defaults
	for opt: Dictionary in SCHEMA:
		if cfg.has_section_key(opt["tab"], opt["key"]):
			_values[opt["key"]] = _sanitize(opt, cfg.get_value(opt["tab"], opt["key"]))
	if cfg.has_section("controls"):
		for action: String in cfg.get_section_keys("controls"):
			var b: Variant = cfg.get_value("controls", action)
			if b is Dictionary and InputSetup.is_rebindable(action):
				_controls[action] = b
	Debug.log_verbose("Settings loaded from %s" % path)


# -----------------------------------------------------------------------------
# Applying the ones Settings owns
# -----------------------------------------------------------------------------
func _apply_all() -> void:
	for key: String in _values:
		_apply(key)
	for action: String in _controls:
		InputSetup.set_bindings(action, _controls[action])
	# An old save mustn't steal a binding from an action added since.
	for action in InputSetup.resolve_clashes(_controls.keys()):
		_controls[action] = InputSetup.bindings_of(action)
		Debug.log_info("Controls: %s gave up a binding a newer action uses" % action)


func _apply(key: String) -> void:
	var v: Variant = _values[key]
	match key:
		"window_mode":
			if DisplayServer.get_name() == "headless":
				return
			var mode := DisplayServer.WINDOW_MODE_WINDOWED
			if v == "borderless":
				mode = DisplayServer.WINDOW_MODE_FULLSCREEN
			elif v == "fullscreen":
				mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if DisplayServer.window_get_mode() != mode:
				DisplayServer.window_set_mode(mode)
		"vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(
						DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)
		"max_fps":
			Engine.max_fps = int(v)
		"max_aspect":
			ScreenScaler.max_aspect = float(v)
		"volume_master", "volume_music", "volume_sfx", "volume_ambience":
			var bus := AudioServer.get_bus_index(BUSES[key])
			if bus >= 0:
				AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(v), 0.0001)))
				AudioServer.set_bus_mute(bus, float(v) <= 0.0)


func _ensure_buses() -> void:
	for key: String in BUSES:
		var bus_name: String = BUSES[key]
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


# -----------------------------------------------------------------------------
func _sanitize(opt: Dictionary, value: Variant) -> Variant:
	match opt["type"]:
		"bool":
			return bool(value)
		"range":
			var step: float = opt["step"]
			var f := clampf(float(value), opt["min"], opt["max"])
			return snappedf(f, step)
		"choice":
			for pair: Array in opt["options"]:
				if _same(pair[0], value):
					return pair[0]
			return opt["default"]
	return value


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.001
	return a == b


func _is_quality_switch(key: String) -> bool:
	return QUALITY_PRESETS["ultra"].has(key)


func _matching_preset() -> String:
	for preset: String in QUALITY_PRESETS:
		var all_match := true
		for k: String in QUALITY_PRESETS[preset]:
			if _values[k] != QUALITY_PRESETS[preset][k]:
				all_match = false
				break
		if all_match:
			return preset
	return "custom"


## Tests run scenes from res://tests/: never touch the player's settings.
static func _is_test_run() -> bool:
	for a in OS.get_cmdline_args():
		if a.begins_with("res://tests/"):
			return true
	return false
