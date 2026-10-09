# =============================================================================
# smoke_settings.gd  -  Headless checks for the settings and the pause menu
# -----------------------------------------------------------------------------
# WHAT:  1. Settings: defaults, out-of-range values clamped, unknown choices
#           rejected; a test run never touches the player's file; saving and
#           loading round-trips (to a scratch file)
#        2. Quality presets set the switches; changing a switch makes it
#           "Custom"; matching a preset by hand names it again
#        3. Settings apply: frame cap, widest view, audio buses and volumes
#        4. The HD-2D view follows the graphics options (bloom, light shafts,
#           shadows, particles, brightness, tilt-shift, the view itself)
#        5. Gameplay options: damage numbers off, screen shake scaled/off,
#           instant text
#        6. Rebinding: a key moves between actions, shared pairs stay shared,
#           reset restores the table, saved overrides come back on load
#        7. Menus: Esc pauses and opens the menu, Settings opens with its tabs,
#           left/right changes a value, a binding slot takes the next key,
#           closing unpauses
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_settings.tscn
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const ARENA_HD := "res://realms/test/combat_arena_hd.tscn"
const SCRATCH := "user://smoke_settings_test.cfg"

var _failures: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps running while the menu pauses
	_run.call_deferred()


func _run() -> void:
	_test_values()
	_test_presets()
	_test_applied()
	await _test_hd()
	await _test_gameplay()
	_test_rebinding()
	await _test_menus()
	_test_window_size()
	_test_persistence()
	for opt: Dictionary in Settings.SCHEMA:
		Settings.set_value(opt["key"], opt["default"])
	Settings.reset_tab("controls")
	if _failures.is_empty():
		print("[TEST] PASS  smoke_settings")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_values() -> void:
	_check(not Settings._persist, "a test run must never read or write the player's settings file")
	for opt: Dictionary in Settings.SCHEMA:
		_check(Settings.get_value(opt["key"]) == opt["default"], "'%s' starts at its default" % opt["key"])
		_check(Settings.TABS.any(func(t: Array) -> bool: return t[0] == opt["tab"]), "'%s' is on a real tab" % opt["key"])
	Settings.set_value("brightness", 5.0)
	_check(is_equal_approx(Settings.get_value("brightness"), 1.4), "a range is clamped to its max")
	Settings.set_value("brightness", 0.97)
	_check(is_equal_approx(Settings.get_value("brightness"), 0.95), "a range snaps to its step")
	Settings.set_value("window_mode", "potato")
	_check(Settings.get_value("window_mode") == "borderless", "an unknown choice falls back to the default")
	Settings.set_value("max_fps", 60)
	_check(Settings.get_value("max_fps") == 60, "a number choice is accepted")
	Settings.set_value("brightness", 1.0)


func _test_presets() -> void:
	Settings.set_value("quality", "low")
	_check(not Settings.get_value("bloom") and not Settings.get_value("light_shafts") and Settings.get_value("shadows") == "low",
			"the Low preset switches the heavy effects off")
	Settings.set_value("bloom", true)
	_check(Settings.get_value("quality") == "custom", "changing a switch after a preset makes it Custom")
	Settings.set_value("quality", "ultra")
	_check(Settings.get_value("reflections") and Settings.get_value("light_shafts"), "Ultra switches everything on")
	Settings.set_value("reflections", false)
	_check(Settings.get_value("quality") == "high", "matching a preset by hand names it (High = Ultra without reflections)")
	Settings.set_value("quality", "ultra")


func _test_applied() -> void:
	Settings.set_value("max_fps", 120)
	_check(Engine.max_fps == 120, "the frame cap applies (%d)" % Engine.max_fps)
	Settings.set_value("max_fps", 0)
	Settings.set_value("max_aspect", 2.3333)
	_check(is_equal_approx(ScreenScaler.max_aspect, 2.3333), "the widest view applies to the scaler")
	Settings.set_value("max_aspect", 0.0)
	for bus in ["Master", "Music", "SFX", "Ambience"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "the %s audio bus exists" % bus)
	Settings.set_value("volume_music", 0.5)
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	_check(absf(db - linear_to_db(0.5)) < 0.01, "music volume sets its bus (%.2f dB)" % db)
	Settings.set_value("volume_sfx", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero volume mutes the bus")
	Settings.set_value("volume_music", 0.8)
	Settings.set_value("volume_sfx", 0.8)


func _test_hd() -> void:
	var scene: Node = load(ARENA_HD).instantiate()
	add_child(scene)
	await _frames(12)
	var hd: HdView = scene.get_node("HdView")
	var caps := HdView.renderer_caps()
	Settings.set_value("bloom", false)
	_check(not hd._env.glow_enabled, "Bloom off turns the glow off")
	Settings.set_value("bloom", true)
	_check(hd._env.glow_enabled, "and back on")
	Settings.set_value("light_shafts", false)
	_check(not hd._env.volumetric_fog_enabled, "Light shafts off turns the volumetric fog off")
	Settings.set_value("light_shafts", true)
	_check(hd._env.volumetric_fog_enabled == caps["volumetric_fog"], "and back on (where the renderer can)")
	Settings.set_value("shadows", "off")
	_check(not hd._sun.shadow_enabled, "Shadows off")
	Settings.set_value("shadows", "high")
	_check(hd._sun.shadow_enabled, "Shadows back on")
	Settings.set_value("particles", false)
	_check(not hd._pollen.visible and not hd._fireflies.visible, "Particles off hides pollen and fireflies")
	Settings.set_value("particles", true)
	Settings.set_value("tilt_shift", false)
	_check(not (hd._cam.attributes as CameraAttributesPractical).dof_blur_far_enabled, "Tilt-shift off")
	Settings.set_value("tilt_shift", true)
	var before := hd._env.tonemap_exposure
	Settings.set_value("brightness", 1.2)
	_check(is_equal_approx(hd._env.tonemap_exposure, before * 1.2), "Brightness scales the exposure (%.2f -> %.2f)" % [before, hd._env.tonemap_exposure])
	Settings.set_value("brightness", 1.0)
	Settings.set_value("view", "classic")
	_check(not hd.enabled, "View: Classic 2D turns the HD-2D view off")
	Settings.set_value("view", "hd2d")
	_check(hd.enabled, "and HD-2D back on")
	scene.queue_free()
	await _frames(2)


func _test_gameplay() -> void:
	var start := Fx.live_effects
	Settings.set_value("damage_numbers", false)
	Fx.damage_number(Vector2.ZERO, 5)
	_check(Fx.live_effects == start, "no damage numbers when they're off")
	Settings.set_value("damage_numbers", true)

	var got := [0.0]
	var grab := func(s: float, _t: float) -> void: got[0] = s
	EventBus.camera_shake.connect(grab)
	Settings.set_value("screen_shake", 0.5)
	Fx.shake(4.0, 0.1)
	_check(is_equal_approx(got[0], 2.0), "screen shake at 50%% halves it (got %.1f)" % got[0])
	got[0] = -1.0
	Settings.set_value("screen_shake", 0.0)
	Fx.shake(4.0, 0.1)
	_check(got[0] == -1.0, "screen shake off sends no shake at all")
	EventBus.camera_shake.disconnect(grab)
	Settings.set_value("screen_shake", 1.0)

	Settings.set_value("text_speed", 0.0)
	var box: DialogueBox = Dialogue.get_box()
	box.show_line("", "Instant text shows the whole line at once, no typing at all.", null)
	await _frames(2)
	_check(not box.is_typing(), "Instant text speed shows the whole line right away")
	box.hide_box()
	Settings.set_value("text_speed", 48.0)


func _test_rebinding() -> void:
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	InputSetup.rebind("attack", k, 0)
	_check(InputSetup.bindings_of("attack")["keys"][0] == KEY_K, "a key can be bound to an action")
	var taken := InputSetup.rebind("toggle_light", k, 0)
	_check(taken.has("attack") and not InputSetup.bindings_of("attack")["keys"].has(KEY_K),
			"binding a key another action had moves it (attack lost K)")
	var x := InputEventJoypadButton.new()
	x.button_index = JOY_BUTTON_X
	InputSetup.rebind("attack", x, 0)
	_check(not InputSetup.bindings_of("partner_stay")["buttons"].has(JOY_BUTTON_X), "a gamepad button moves too")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	InputSetup.rebind("interact", a, 0)
	InputSetup.rebind("attack", a, 0)
	_check(InputSetup.bindings_of("interact")["buttons"].has(JOY_BUTTON_A), "talk and attack may share gamepad A")
	_check(Input.is_action_pressed("attack") == false, "(sanity)")
	Settings.store_binding("attack")
	_check(Settings._controls.has("attack"), "Settings remembers a rebound action")
	Settings.reset_tab("controls")
	_check(InputSetup.bindings_of("attack")["keys"].has(KEY_J) and InputSetup.bindings_of("toggle_light")["keys"] == [KEY_F],
			"Reset puts every key back")
	_check(Settings._controls.is_empty(), "and forgets the overrides")
	_check(InputSetup.key_label(KEY_SPACE) == "Space" and InputSetup.button_label(JOY_BUTTON_RIGHT_SHOULDER) == "RB",
			"bindings read as names (Space, RB)")


func _test_menus() -> void:
	var scene: Node = load("res://realms/test/combat_arena.tscn").instantiate()
	add_child(scene)
	await _frames(8)
	_tap_key(KEY_ESCAPE)
	await _frames(2)
	_check(PauseMenu.is_open() and get_tree().paused, "Esc pauses the game and opens the menu")
	var menu := PauseMenu.open_settings()
	await _frames(3)
	_check(menu.current_tab == "graphics", "Settings opens on Graphics")
	var bloom := menu.row("bloom") as OptionRow
	_check(bloom != null, "the Graphics tab lists Bloom")
	if bloom:
		bloom.value_button.grab_focus()
		await _frames(1)
		_tap_action("ui_right")
		await _frames(2)
		_check(Settings.get_value("bloom") == false, "right on a value changes it (Bloom off)")
		_check(bloom.value_button.text.contains("Off"), "and the row shows it: '%s'" % bloom.value_button.text)
		Settings.set_value("bloom", true)
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
	joy.pressed = true
	Input.parse_input_event(joy)
	await _frames(2)
	_check(menu.current_tab == "display", "RB goes to the next tab")
	menu.show_tab("controls")
	await _frames(2)
	var row := menu.row("attack") as BindingRow
	_check(row != null, "the Controls tab lists Attack")
	if row:
		row.listen(0)
		await _frames(2)
		_check(row.is_listening() and row.first_slot().text.begins_with("press"), "a slot waits for a key")
		_tap_key(KEY_L)
		await _frames(2)
		_check(InputSetup.bindings_of("attack")["keys"][0] == KEY_L, "the next key press is bound")
		_check(not row.is_listening(), "and it stops listening")
		row.listen(0)
		await _frames(2)
		_tap_key(KEY_ESCAPE)
		await _frames(2)
		_check(not row.is_listening() and PauseMenu.is_open(), "Esc cancels a binding without closing the menu")
		_check(InputSetup.bindings_of("attack")["keys"][0] == KEY_L, "and keeps the old key")
	Settings.reset_tab("controls")
	_tap_key(KEY_ESCAPE)  # back out of settings
	await _frames(2)
	_check(PauseMenu.is_open() and PauseMenu._settings == null, "Esc backs out of Settings to the pause menu")
	_tap_key(KEY_ESCAPE)
	await _frames(2)
	_check(not PauseMenu.is_open() and not get_tree().paused, "Esc again resumes the game")
	scene.queue_free()
	await _frames(2)


func _test_window_size() -> void:
	_check(Settings.option("window_size").get("default") == "auto", "window size defaults to auto")
	_check(Settings.get_value("window_size") == "auto", "window size starts on auto")
	_check(Settings.option("window_mode").get("default") == "borderless", "the window defaults to borderless fullscreen")
	_check(Settings.has_resolution_arg(["--path", ".", "--resolution", "1280x720"]), "--resolution is detected (forces windowed)")
	_check(not Settings.has_resolution_arg(["--path", "."]), "no --resolution, no override")
	var S := Settings
	_check(S.auto_window_size(Vector2i(1920, 1040)) == Vector2i(1280, 720), "auto: 1080p screen -> 1280x720")
	_check(S.auto_window_size(Vector2i(2560, 1400)) == Vector2i(1920, 1080), "auto: 1440p screen -> 1920x1080")
	_check(S.auto_window_size(Vector2i(3840, 2100)) == Vector2i(3200, 1800), "auto: 4K screen -> 3200x1800")
	_check(S.auto_window_size(Vector2i(800, 600)) == Vector2i(1280, 720), "auto: tiny screen -> 1280x720 minimum")
	_check(S.resolve_window_size("1920x1080", Vector2i(3840, 2100)) == Vector2i(1920, 1080), "a fixed size that fits is kept")
	_check(S.resolve_window_size("3840x2160", Vector2i(1920, 1040)) == Vector2i(1280, 720), "a fixed size that does not fit is clamped to auto")


func _test_persistence() -> void:
	Settings.path = SCRATCH
	Settings._persist = true
	Settings.set_value("brightness", 1.25)
	Settings.set_value("window_mode", "fullscreen")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_U
	InputSetup.rebind("interact", k, 0)
	Settings.store_binding("interact")
	# Forget it all in memory, then load the file back.
	Settings._values["brightness"] = 1.0
	Settings._values["window_mode"] = "borderless"
	Settings._controls.clear()
	InputSetup.reset_to_defaults()
	Settings._load()
	Settings._apply_all()
	_check(is_equal_approx(Settings.get_value("brightness"), 1.25), "brightness survives a save and load")
	_check(Settings.get_value("window_mode") == "fullscreen", "the window mode survives a save and load")
	_check(InputSetup.bindings_of("interact")["keys"][0] == KEY_U, "a rebound key survives a save and load")
	Settings._persist = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = "user://settings.cfg"
	Settings._values["window_mode"] = "borderless"


# -----------------------------------------------------------------------------
func _tap_key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _tap_action(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
