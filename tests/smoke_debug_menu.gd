# =============================================================================
# smoke_debug_menu.gd  -  Headless checks for the Debug Menu (the start screen)
# -----------------------------------------------------------------------------
# WHAT:  1. Debug.start_scene_for (--yard / --arena skip the menu, nothing
#           shows it) and the debug-key lines taken from HELP_TEXT
#        2. the menu builds: a button per map, the options, Settings, Quit,
#           the key panel; every map entry's scene loads; the cursor starts
#           on the first entry
#        3. Start time + Hard + Test yard: the yard opens at that time on a
#           running clock and GameState.difficulty is "hard"
#        4. the pause menu's "Debug menu" comes back to the menu with the
#           cursor and the options on the last choice
#        5. "Prologue (from the start)" clears the intro flag, the skip entry
#           sets it, the arena entry loads the arena
#        6. the end of the prologue slice waits on its card, then fades to
#           the title screen (the wait is shortened here from 10 s)
#
# RUN:   godot --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_debug_menu.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const YARD := "res://realms/big_yard/yard_hd.tscn"
const ARENA := "res://realms/test/combat_arena_hd.tscn"
const STREET := "res://realms/podunk/ruffleberg_lot_hd.tscn"

var _failures: PackedStringArray = []
var _swaps := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# The holder is what Travel / change_scene frees; this node lives on.
	var holder := Node.new()
	holder.name = "Holder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	_test_pure()
	for leg: Callable in [_test_build, _test_yard, _test_back, _test_street_flags, _test_slice_end]:
		await leg.call()
		if not _failures.is_empty():
			break
	if _failures.is_empty():
		print("[TEST] PASS  smoke_debug_menu  (%d swaps)" % _swaps)
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


func _test_pure() -> void:
	_check(Debug.start_scene_for(PackedStringArray(["--yard"])) == YARD, "--yard skips the menu, to the yard")
	_check(Debug.start_scene_for(PackedStringArray(["--debug", "--arena"])) == ARENA, "--arena skips the menu, to the arena")
	_check(Debug.start_scene_for(PackedStringArray()).is_empty(), "no option: no map (the menu shows)")
	_check(Debug.start_scene_for(PackedStringArray(["--hard", "--debug"])).is_empty(), "--hard and --debug alone still show the menu")
	var keys := Debug.key_lines()
	for k in ["F2", "F3", "F4", "F6", "F7", "F9"]:
		_check(keys.size() > 0 and Array(keys).any(func(l: String) -> bool: return l.begins_with(k)), "the key list has %s" % k)
	_check(ProjectSettings.get_setting("application/run/main_scene") == TitleScreen.SCENE, "the title screen is the main scene (the debug menu hangs off it)")


func _test_build() -> void:
	await _go_menu()
	var menu := _menu()
	_check(menu != null and menu.map_buttons.size() == DebugMenu.MAPS.size(), "the menu has a button per map")
	_check(menu.time_button != null and menu.difficulty_button != null and menu.settings_button != null and menu.quit_button != null,
		"the options, Settings and Quit are there")
	for m: Dictionary in DebugMenu.MAPS:
		_check(load(m["scene"]) is PackedScene, "%s: %s loads" % [m["label"], m["scene"]])
	_check(get_viewport().gui_get_focus_owner() == menu.map_buttons["prologue"], "the cursor starts on the first entry")
	var panel := menu.find_child("Keys", true, false)
	var labels := 0
	for c in panel.find_children("*", "Label", true, false):
		labels += 1
	_check(labels == Debug.key_lines().size() + 1, "the key panel lists every debug key (%d labels)" % labels)
	var before := menu.selected_time()
	menu.step_option(menu.time_button, 1)
	_check(menu.selected_time() != before and menu.time_button.text.contains(menu.selected_time().capitalize().split(" ")[0]),
		"stepping Start time changes it and the label (%s)" % menu.time_button.text)
	menu.step_option(menu.time_button, -1)
	_check(menu.selected_time() == before, "and steps back")


func _test_yard() -> void:
	var menu := _menu()
	menu.step_option(menu.time_button, 2)  # day -> night
	menu.step_option(menu.difficulty_button, 1)
	_check(menu.selected_time() == "night" and menu.selected_difficulty() == "hard", "set night + hard")
	menu.map_buttons["yard"].pressed.emit()
	await _arrive(YARD)
	_check(Clock.phase == "night" and Clock.mode == "free", "the yard opened at night on a running clock (%s, %s)" % [Clock.phase, Clock.mode])
	_check(GameState.difficulty == "hard", "Hard set the difficulty")
	_check(Travel.last_entry == "" and Travel.last_carry.is_empty(), "nothing carried over, no entry: the map's own spawn")


func _test_back() -> void:
	PauseMenu.back_to_debug_menu()
	await _arrive(DebugMenu.SCENE)
	var menu := _menu()
	_check(get_viewport().gui_get_focus_owner() == menu.map_buttons["yard"], "back from the pause menu: the cursor is on the last choice")
	_check(menu.selected_time() == "night" and menu.selected_difficulty() == "hard", "and the options remember night + hard")
	_check(not get_tree().paused, "the tree is unpaused")


func _test_street_flags() -> void:
	var menu := _menu()
	menu.step_option(menu.difficulty_button, 1)  # back to normal
	GameState.set_flag(DebugMenu.INTRO_FLAG)
	GameState.set_flag("prologue.talked_to_maya")
	menu.map_buttons["prologue"].pressed.emit()
	await _arrive(STREET)
	_check(GameState.difficulty == "normal", "Normal again")
	_check(not GameState.get_flag(DebugMenu.INTRO_FLAG) and not GameState.get_flag("prologue.talked_to_maya"),
		"Prologue (from the start) cleared the prologue flags")
	_check(_realm()._black.visible, "and the intro plays (black overlay up)")
	PauseMenu.back_to_debug_menu()
	await _arrive(DebugMenu.SCENE)
	menu = _menu()
	menu.map_buttons["street"].pressed.emit()
	await _arrive(STREET)
	_check(GameState.get_flag(DebugMenu.INTRO_FLAG), "the street entry set the intro-done flag")
	_check(not _realm()._black.visible and Clock.mode == "hold", "and opens on the road with the clock held")
	PauseMenu.back_to_debug_menu()
	await _arrive(DebugMenu.SCENE)
	_menu().map_buttons["arena"].pressed.emit()
	await _arrive(ARENA)
	_check(get_tree().current_scene.scene_file_path == ARENA, "the arena entry loads the arena")
	PauseMenu.back_to_debug_menu()
	await _arrive(DebugMenu.SCENE)
	_menu().map_buttons["street"].pressed.emit()
	await _arrive(STREET)


func _test_slice_end() -> void:
	var lot := _realm()
	lot.end_card_seconds = 0.5
	lot._end_slice()  # not awaited: it ends by sending us to the menu
	var frames := 0
	while frames < 900 and not (get_tree().current_scene != null and get_tree().current_scene.scene_file_path == TitleScreen.SCENE and not Travel.busy):
		await get_tree().physics_frame
		frames += 1
		if frames == 150:  # the 2 s fade is done, the card is up and waiting
			_check(lot._card.visible and lot._card.text.begins_with("To be continued"), "the slice ends on its card")
			_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == STREET, "and waits there")
	_check(frames < 900, "the card gives way to the title screen (%d frames)" % frames)


# -----------------------------------------------------------------------------
func _go_menu() -> void:
	get_tree().change_scene_to_file(DebugMenu.SCENE)
	await get_tree().scene_changed
	for i in 5:
		await get_tree().physics_frame


func _menu() -> DebugMenu:
	return get_tree().current_scene as DebugMenu


func _realm() -> AsciiRealm:
	return get_tree().current_scene.get_node("Yard") as AsciiRealm


## Wait out the swap Travel started and land on `scene`.
func _arrive(scene: String) -> void:
	var frames := 0
	while frames < 900 and not (get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene
			and not Travel.busy and frames > 5):
		await get_tree().physics_frame
		frames += 1
	_swaps += 1
	_check(get_tree().current_scene.scene_file_path == scene, "arrived on %s" % scene.get_file())
	for i in 5:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[TEST] ok    ", what)
	else:
		_failures.append(what)
		printerr("[TEST] FAIL  ", what)
