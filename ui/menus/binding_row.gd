# =============================================================================
# binding_row.gd  -  One action on the Controls tab: "Attack   J   Space   A"
# -----------------------------------------------------------------------------
# WHAT:  Two keyboard slots and one gamepad slot. Pick a slot, then press the
#        new key (or gamepad button). While it listens:
#          keyboard slot  Esc cancels, Backspace/Delete clears the slot
#          gamepad slot   Start cancels, Back... is a real binding, so only
#                         Start cancels (Start is fixed to the pause menu)
#        A key another action had moves over (that action loses it), except
#        pairs that share on purpose (talk and attack on gamepad A).
# SAVES: through InputSetup.rebind + Settings.store_binding.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name BindingRow
extends HBoxContainer

## The row that's waiting for a key, if any (menus ignore input meanwhile).
static var listening: BindingRow = null

## Emitted after a change, with the actions that lost the key (for a notice).
signal rebound(action: String, taken_from: Array[String])

const SLOT_WIDTH := 70.0

var action := ""
## [kind ("keys" / "buttons"), slot index, Button] for each slot.
var slots: Array = []

var _listen_slot := -1
var _armed := false  # skips the press that started listening


func setup(action_name: String, label_text: String) -> BindingRow:
	action = action_name
	name = action_name
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	for i in InputSetup.MAX_KEYS:
		_add_slot("keys", i)
	for i in InputSetup.MAX_BUTTONS:
		_add_slot("buttons", i)
	refresh()
	return self


func refresh() -> void:
	var b := InputSetup.bindings_of(action)
	for s: Array in slots:
		var list: Array = b[s[0]]
		var btn: Button = s[2]
		if s[1] < list.size():
			btn.text = InputSetup.key_label(list[s[1]]) if s[0] == "keys" else InputSetup.button_label(list[s[1]])
		else:
			btn.text = "-"


func first_slot() -> Button:
	return slots[0][2]


func is_listening() -> bool:
	return listening == self


## Start waiting for a key/button for slot `i` (index into slots).
func listen(i: int) -> void:
	if listening and listening != self:
		listening.cancel()
	listening = self
	_listen_slot = i
	_armed = false
	(slots[i][2] as Button).text = "press a key..." if slots[i][0] == "keys" else "press a button..."
	# Arm on the next frame so the press that picked the slot isn't captured.
	await get_tree().process_frame
	if is_listening():
		_armed = true


func cancel() -> void:
	if listening == self:
		listening = null
	_listen_slot = -1
	refresh()


func _add_slot(kind: String, i: int) -> void:
	var btn := Button.new()
	btn.name = "%s%d" % [kind.capitalize(), i]
	btn.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
	btn.focus_mode = Control.FOCUS_ALL
	btn.clip_text = true
	var index := slots.size()
	btn.pressed.connect(func() -> void:
		if not is_listening():
			listen(index))
	add_child(btn)
	slots.append([kind, i, btn])


func _input(event: InputEvent) -> void:
	if not is_listening() or not _armed:
		return
	var kind: String = slots[_listen_slot][0]
	var slot: int = slots[_listen_slot][1]
	if kind == "keys" and event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		get_viewport().set_input_as_handled()
		if k.physical_keycode == KEY_ESCAPE:
			cancel()
		elif k.physical_keycode == KEY_BACKSPACE or k.physical_keycode == KEY_DELETE:
			InputSetup.unbind(action, "keys", slot)
			_finish([])
		else:
			_finish(InputSetup.rebind(action, k, slot))
	elif kind == "buttons" and event is InputEventJoypadButton and event.pressed:
		var jb := event as InputEventJoypadButton
		get_viewport().set_input_as_handled()
		if jb.button_index == JOY_BUTTON_START:
			cancel()
		else:
			_finish(InputSetup.rebind(action, jb, slot))
	elif event is InputEventMouseButton and event.pressed:
		cancel()  # clicking anywhere else gives up
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		get_viewport().set_input_as_handled()  # wrong kind for this slot: ignore it


func _finish(taken: Array[String]) -> void:
	var btn: Button = slots[_listen_slot][2]
	listening = null
	_listen_slot = -1
	Settings.store_binding(action)
	for other in taken:
		Settings.store_binding(other)
	refresh()
	btn.grab_focus()
	rebound.emit(action, taken)
