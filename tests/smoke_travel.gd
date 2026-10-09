# =============================================================================
# smoke_travel.gd  -  Headless checks for walking between maps (Travel)
# -----------------------------------------------------------------------------
# WHAT:  The real scene swaps, on the real demo maps:
#          1. a fresh prologue plays its intro (black overlay, kid held)
#          2. street -> yard, driving the DOG into the road's exit: the yard
#             loads, the dog stands on the entry and the kid behind him, both
#             facing into the map; HP, charge, who's driven and Stay put came
#             along; the prologue's clock hold is released; both cameras sit
#             on the leader; no bounce back for 90 frames even with the
#             leader put right on the arrival exit (until he steps off it)
#          3. yard -> arena with the kid walking up the street: Esc mid-fade
#             doesn't open the pause menu; the demo kit isn't handed out twice
#          4. arena -> yard -> street: the street skips its intro (no title
#             card, no dinner, no arrival talk) and holds its clock again
#
# HOW:   Travel.go changes the CURRENT scene, so this node first hands
#        "current scene" to a throwaway holder and lives on beside the maps.
#
# RUN:   godot --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_travel.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const STREET := "res://realms/podunk/ruffleberg_lot_hd.tscn"
const YARD := "res://realms/big_yard/yard_hd.tscn"
const ARENA := "res://realms/test/combat_arena_hd.tscn"
const TILE := 32
const NO_BOUNCE_FRAMES := 90

var _failures: PackedStringArray = []
var _travels := 0
var _bounce_probe := false
## Where the arrival put the leader, before the probe moved him.
var _arrival_spot := Vector2.ZERO


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Stay alive through change_scene_to_file: the holder is what gets freed.
	var holder := Node.new()
	holder.name = "Holder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	Travel.arrived.connect(_on_arrived)
	# Each leg starts where the last one ended: stop at the first broken leg
	# (a bounce back would leave the next one on the wrong map, waiting).
	for leg: Callable in [_test_fresh_intro, _test_street_to_yard, _test_yard_to_arena, _test_back_to_street]:
		await leg.call()
		if not _failures.is_empty():
			break
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[TEST] PASS  smoke_travel  (%d swaps)" % _travels)
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_fresh_intro() -> void:
	get_tree().change_scene_to_file(STREET)
	await get_tree().scene_changed
	await _frames(10)
	var street := _realm()
	_check(street._black.visible, "a fresh street plays its intro (the black overlay is up)")
	_check(not Party.kid.is_physics_processing(), "the kid is held during the intro")
	# The intro marks itself done when the street fades in; a later visit
	# reads the flag. Pretend dinner is over, and load the street again.
	GameState.set_flag(street.INTRO_FLAG)
	get_tree().change_scene_to_file(STREET)
	await get_tree().scene_changed
	await _frames(10)
	_check(not _realm()._black.visible and not Dialogue.is_active(), "with the flag set the street opens straight on the road")


func _test_street_to_yard() -> void:
	var street := _realm()
	_check(Clock.mode == "hold", "the prologue holds the clock (mode %s)" % Clock.mode)
	var kid: Kid = Party.kid
	var dog: Dog = Party.dog
	kid.health.set_hp(kid.health.max_hp - 7)
	var kid_hp_set: int = kid.health.hp
	dog.health.set_hp(dog.health.max_hp - 5)
	kid.charge.value = 0.4
	dog.charge.value = 0.75
	_check(Party.switch_control(), "can drive the dog on the street")
	Party.set_staying(true)
	# Walk the dog east down the road into the exit.
	var exit_cell := Vector2i(37, 11)
	dog.global_position = Vector2((exit_cell.x - 1.5) * TILE, exit_cell.y * TILE + 20)
	kid.global_position = dog.global_position - Vector2(40, 0)
	await _walk_until_travel("move_right", 150)
	_check(Travel.busy, "the dog walking into the road's exit starts the swap")
	_bounce_probe = true
	await Travel.finished
	_bounce_probe = false
	_travels += 1
	var yard := _realm()
	_check(get_tree().current_scene.scene_file_path == YARD, "the yard loaded (%s)" % get_tree().current_scene.scene_file_path)
	_check(Clock.mode == "free", "leaving the prologue released its clock hold (mode %s)" % Clock.mode)
	var spot := yard.entry_spot("from_street", true)
	_check(_arrival_spot.distance_to(spot["dog"]) < 1.0, "the driven dog arrived on the yard entry (%s vs %s)" % [_arrival_spot, spot["dog"]])
	_check(Party.kid.global_position.distance_to(spot["kid"]) < 1.0, "the kid stands behind him (%s vs %s)" % [Party.kid.global_position, spot["kid"]])
	_check(Party.kid.facing == Vector2.RIGHT and Party.dog.facing == Vector2.RIGHT, "both face into the yard")
	# As they left (Travel's snapshot at the exit) vs as they are now.
	var before := Travel.last_carry
	var after := Travel.snapshot()
	_check(before["kid_hp"] == kid_hp_set and before["leader"] == "dog", "the snapshot saw the hurt kid and the driven dog")
	for key in ["kid_hp", "dog_hp", "leader", "staying"]:
		_check(after[key] == before[key], "%s carried over (%s -> %s)" % [key, before[key], after[key]])
	for key in ["kid_charge", "dog_charge"]:
		_check(absf(after[key] - before[key]) < 0.05, "%s carried over (%.2f -> %.2f)" % [key, before[key], after[key]])
	_check(Party.leader == Party.dog, "still driving the dog")
	_check((Party.dog.get_node_or_null("Camera2D")) != null, "the 2D camera rides on the dog")
	var hd: HdView = get_tree().get_first_node_in_group("hd_view")
	var want: Vector3 = hd._clamp_to_map(hd._leader3d().position)
	_check(hd._target.distance_to(want) < 0.3, "the HD camera snapped to the leader (off by %.2f m)" % hd._target.distance_to(want))
	_check(Travel.fade_alpha() == 0.0 and not Travel.busy, "faded back in, input back")
	# No bounce: _on_arrived put the dog right on the arrival exit. He must
	# stay in the yard until he steps off it.
	await _frames(NO_BOUNCE_FRAMES)
	_check(get_tree().current_scene.scene_file_path == YARD and not Travel.busy,
			"standing on the arrival exit doesn't bounce back (%d frames)" % NO_BOUNCE_FRAMES)
	if not is_instance_valid(yard):
		return
	_check(not yard.exits.armed, "exits stay ignored while he hasn't left the exit")
	Party.dog.global_position = spot["dog"]
	await _frames(3)
	_check(yard.exits.armed, "stepping off the exit arms the exits again")
	# The demo kit came with the yard (first demo map of the run).
	_check(GameState.item_count("rusty_sword") == 1, "the yard handed out the demo kit")
	Party.set_staying(false)
	_check(Party.switch_control(), "back to driving the kid")
	await _frames(2)


func _test_yard_to_arena() -> void:
	var kid: Kid = Party.kid
	kid.global_position = Vector2(48.5 * TILE, 1.6 * TILE)
	Party.dog.global_position = kid.global_position + Vector2(0, 30)
	var hp_before: int = kid.health.hp
	await _walk_until_travel("move_up", 120)
	_check(Travel.busy, "the kid walking up the street starts the swap to the arena")
	# Esc mid-fade: swallowed, no pause menu over a half-built scene.
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(2)
	_check(not PauseMenu.is_open() and not get_tree().paused, "Esc during the swap doesn't pause")
	await Travel.finished
	_travels += 1
	_check(get_tree().current_scene.scene_file_path == ARENA, "the arena loaded")
	var spot := _realm().entry_spot("from_yard")
	_check(Party.kid.global_position.distance_to(spot["kid"]) < 1.0, "the kid stands on the arena entry")
	_check(Party.kid.facing == Vector2.UP, "facing up, into the arena")
	_check(Party.kid.health.hp == hp_before, "kid HP carried again (%d -> %d)" % [hp_before, Party.kid.health.hp])
	_check(GameState.item_count("rusty_sword") == 1, "the arena doesn't hand out the kit a second time (%d swords)" % GameState.item_count("rusty_sword"))
	# Arena -> yard, walking south down the little path.
	Party.kid.global_position = Vector2(14.5 * TILE, 12.6 * TILE)
	await _walk_until_travel("move_down", 120)
	await Travel.finished
	_travels += 1
	_check(get_tree().current_scene.scene_file_path == YARD, "back in the yard from the arena")
	spot = _realm().entry_spot("from_arena")
	_check(Party.kid.global_position.distance_to(spot["kid"]) < 1.0, "on the yard's north entry")


func _test_back_to_street() -> void:
	Party.kid.global_position = Vector2(1.5 * TILE, 7 * TILE + 20)
	Party.dog.global_position = Party.kid.global_position + Vector2(30, 0)
	await _walk_until_travel("move_left", 120)
	await Travel.finished
	_travels += 1
	var street := _realm()
	_check(get_tree().current_scene.scene_file_path == STREET, "back on the street")
	await _frames(30)
	_check(not street._black.visible, "no title card or dinner on the way back")
	_check(not Dialogue.is_active(), "no arrival conversation on the way back")
	_check(Party.kid.is_physics_processing(), "the kid can walk straight away")
	_check(Clock.mode == "hold", "the street holds its clock again (mode %s)" % Clock.mode)
	var spot := street.entry_spot("from_yard")
	_check(Party.kid.global_position.distance_to(spot["kid"]) < 2.0, "the kid came in on the road's entry")


# -----------------------------------------------------------------------------
## During the street -> yard arrival: put the leader right on the exit he
## came through, as a spawn on the exit (or momentum) would.
func _on_arrived(_entry: String) -> void:
	if not _bounce_probe:
		return
	var realm := get_tree().get_first_node_in_group("ascii_realm") as AsciiRealm
	var c: Vector2i = realm.exits.exits[0]["cell"]
	for e: Dictionary in realm.exits.exits:
		if e["to"] == STREET:
			c = e["cell"]
	_arrival_spot = Party.leader.global_position
	Party.leader.global_position = Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.6)


func _walk_until_travel(action: String, max_frames: int) -> void:
	Input.action_press(action)
	for i in max_frames:
		await get_tree().physics_frame
		if Travel.busy:
			break
	Input.action_release(action)


func _realm() -> AsciiRealm:
	return get_tree().current_scene.get_node("Yard") as AsciiRealm


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[TEST] ok    ", what)
	else:
		_failures.append(what)
		printerr("[TEST] FAIL  ", what)
