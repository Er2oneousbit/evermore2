# =============================================================================
# input_setup.gd  (autoload: InputSetup)
# -----------------------------------------------------------------------------
# WHAT:  Defines every input action (keyboard + gamepad) in one readable table.
# WHY:   Hand-editing the Input Map inside project.godot is unreadable and
#        merge-conflict bait. This table is the single source of truth, and a
#        future rebinding menu only has to edit these actions at runtime.
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
	"attack":          {"keys": [KEY_J, KEY_SPACE], "buttons": [JOY_BUTTON_A]},
	"toggle_light":    {"keys": [KEY_F],            "buttons": [JOY_BUTTON_Y]},
	"dog_toggle_stay": {"keys": [KEY_E],            "buttons": [JOY_BUTTON_X]},
	# --- Debug (prototype only; gate behind a setting before release) ---------
	"debug_cycle_time": {"keys": [KEY_F2]},
	"debug_overlay":    {"keys": [KEY_F3]},
	"debug_warp_dog":   {"keys": [KEY_F4]},
	"debug_toggle_view": {"keys": [KEY_F6]},
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
