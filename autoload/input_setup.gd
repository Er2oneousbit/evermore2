# =============================================================================
# input_setup.gd  (autoload: InputSetup)
# -----------------------------------------------------------------------------
# WHAT:  Defines every input action (keyboard + gamepad) in one readable table.
# WHY:   Hand-editing the Input Map inside project.godot is unreadable and
#        merge-conflict bait. This table is the single source of truth, and a
#        future rebinding menu only has to edit these actions at runtime.
#
# REBINDING: the settings menu (Controls tab) changes keys and buttons at
#   runtime through bindings_of / set_bindings / rebind; Settings saves them.
#   Only actions in REBINDABLE show up there (debug keys and pause don't).
#   The analog sticks stay as they are.
#
# HOW TO ADD AN ACTION: add a row to BINDINGS below. That's it.
#   keys   -> Godot Key constants (physical keys, so WASD works on AZERTY too)
#   buttons-> JoyButton constants (Xbox layout names: A/B/X/Y)
#   axes   -> [JoyAxis, direction] pairs for analog sticks
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Analog stick deadzone shared by all movement actions.
const STICK_DEADZONE := 0.25

const BINDINGS := {
	# --- Movement -------------------------------------------------------------
	"move_left":  {"keys": [KEY_A, KEY_LEFT],  "buttons": [JOY_BUTTON_DPAD_LEFT],  "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"move_up":    {"keys": [KEY_W, KEY_UP],    "buttons": [JOY_BUTTON_DPAD_UP],    "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"move_down":  {"keys": [KEY_S, KEY_DOWN],  "buttons": [JOY_BUTTON_DPAD_DOWN],  "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	# --- Actions --------------------------------------------------------------
	# Interact and attack share gamepad A: the kid checks
	# Interaction.try_interact() first (talking wins).
	"interact":        {"keys": [KEY_E, KEY_ENTER, KEY_KP_ENTER], "buttons": [JOY_BUTTON_A]},
	"attack":          {"keys": [KEY_J, KEY_SPACE], "buttons": [JOY_BUTTON_A]},
	"toggle_light":    {"keys": [KEY_F],            "buttons": [JOY_BUTTON_Y]},
	# --- The duo (Party) --------------------------------------------------------
	"switch_control":  {"keys": [KEY_TAB],          "buttons": [JOY_BUTTON_BACK]},
	"partner_stay":    {"keys": [KEY_Q],            "buttons": [JOY_BUTTON_X]},
	"partner_stance":  {"keys": [KEY_R],            "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	# The dog's nose: scent trails while you drive him.
	"sniff":           {"keys": [KEY_C],            "buttons": [JOY_BUTTON_B]},
	# --- Menus (fixed, so a player can always get back to the settings) -------
	"pause":           {"keys": [KEY_ESCAPE],       "buttons": [JOY_BUTTON_START]},
	# --- Debug (prototype only; gate behind a setting before release) ---------
	"debug_cycle_time": {"keys": [KEY_F2]},
	"debug_overlay":    {"keys": [KEY_F3]},
	"debug_warp_dog":   {"keys": [KEY_F4]},
	"debug_toggle_view": {"keys": [KEY_F6]},
}


## Actions the player can rebind, in the order the Controls tab lists them,
## with the names it shows.
const REBINDABLE := [
	["move_up", "Move up"],
	["move_down", "Move down"],
	["move_left", "Move left"],
	["move_right", "Move right"],
	["attack", "Attack"],
	["interact", "Talk / interact"],
	["toggle_light", "Flashlight"],
	["switch_control", "Switch kid / dog"],
	["partner_stay", "Partner: Stay put"],
	["partner_stance", "Partner's stance"],
	["sniff", "Dog: sniff"],
]
## How many keyboard keys and gamepad buttons each action can have.
const MAX_KEYS := 2
const MAX_BUTTONS := 1
## Actions that may share a binding on purpose (gamepad A talks/digs or
## attacks: the kid or dog decides, interacting wins).
const SHARED_OK := [["interact", "attack"]]

const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_MISC1: "Share", JOY_BUTTON_PADDLE1: "P1", JOY_BUTTON_PADDLE2: "P2",
	JOY_BUTTON_PADDLE3: "P3", JOY_BUTTON_PADDLE4: "P4", JOY_BUTTON_TOUCHPAD: "Touchpad",
}


func _ready() -> void:
	for action: String in BINDINGS:
		_register(action, BINDINGS[action])
	Debug.log_verbose("InputSetup registered %d actions" % BINDINGS.size())


func _register(action: String, spec: Dictionary) -> void:
	# If the action already exists (e.g. someone added it in Project Settings),
	# wipe it so this table stays the single source of truth.
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, STICK_DEADZONE)

	for keycode: Key in spec.get("keys", []):
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)

	for button: JoyButton in spec.get("buttons", []):
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)

	for pair: Array in spec.get("axes", []):
		var ev := InputEventJoypadMotion.new()
		ev.axis = pair[0]
		ev.axis_value = pair[1]
		InputMap.action_add_event(action, ev)


# -----------------------------------------------------------------------------
# Rebinding (the Controls tab)
# -----------------------------------------------------------------------------
func is_rebindable(action: String) -> bool:
	for pair: Array in REBINDABLE:
		if pair[0] == action:
			return true
	return false


## An action's current keys and buttons: {"keys": [Key...], "buttons": [JoyButton...]}.
func bindings_of(action: String) -> Dictionary:
	var keys: Array = []
	var buttons: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			keys.append(int((ev as InputEventKey).physical_keycode))
		elif ev is InputEventJoypadButton:
			buttons.append(int((ev as InputEventJoypadButton).button_index))
	return {"keys": keys, "buttons": buttons}


## Replace an action's keys and buttons (sticks are kept).
func set_bindings(action: String, b: Dictionary) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventJoypadButton:
			InputMap.action_erase_event(action, ev)
	for k in b.get("keys", []).slice(0, MAX_KEYS):
		var ev := InputEventKey.new()
		ev.physical_keycode = int(k) as Key
		InputMap.action_add_event(action, ev)
	for btn in b.get("buttons", []).slice(0, MAX_BUTTONS):
		var ev := InputEventJoypadButton.new()
		ev.button_index = int(btn) as JoyButton
		InputMap.action_add_event(action, ev)


## Put `event` (a key or a gamepad button) in slot `slot` of `action`, taking
## it away from any other rebindable action that had it (except pairs that
## share on purpose). Returns the actions it was taken from.
func rebind(action: String, event: InputEvent, slot := 0) -> Array[String]:
	var taken: Array[String] = []
	var kind := "keys" if event is InputEventKey else "buttons"
	var code := int((event as InputEventKey).physical_keycode) if event is InputEventKey \
			else int((event as InputEventJoypadButton).button_index)
	if kind == "keys" and code == 0:
		code = int((event as InputEventKey).keycode)
	for pair: Array in REBINDABLE:
		var other: String = pair[0]
		if other == action or _shared_ok(action, other):
			continue
		var ob := bindings_of(other)
		if ob[kind].has(code):
			ob[kind].erase(code)
			set_bindings(other, ob)
			taken.append(other)
	var b := bindings_of(action)
	var list: Array = b[kind]
	list.erase(code)
	var limit := MAX_KEYS if kind == "keys" else MAX_BUTTONS
	if slot < list.size():
		list[slot] = code
	else:
		list.append(code)
	b[kind] = list.slice(0, limit)
	set_bindings(action, b)
	return taken


## Take a key or button off an action.
func unbind(action: String, kind: String, slot: int) -> void:
	var b := bindings_of(action)
	if slot < b[kind].size():
		b[kind].remove_at(slot)
		set_bindings(action, b)


## Every rebindable action back to the BINDINGS table.
func reset_to_defaults() -> void:
	for pair: Array in REBINDABLE:
		_register(pair[0], BINDINGS[pair[0]])


## Readable name for a binding, e.g. "W", "Space", "RB".
static func key_label(code: int) -> String:
	var shown := DisplayServer.keyboard_get_keycode_from_physical(code as Key) if DisplayServer.get_name() != "headless" else code as Key
	var s := OS.get_keycode_string(shown)
	return s if s != "" else "Key %d" % code


static func button_label(button: int) -> String:
	return BUTTON_NAMES.get(button, "Button %d" % button)


func _shared_ok(a: String, b: String) -> bool:
	for pair: Array in SHARED_OK:
		if pair.has(a) and pair.has(b):
			return true
	return false
