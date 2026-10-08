# =============================================================================
# ring_menu.gd  (autoload: RingMenu)
# -----------------------------------------------------------------------------
# WHAT:  I / gamepad Y pauses the game and opens a ring of slots around
#        whoever you drive. This first version has one ring, Equipment: his
#        gear slots (kid: weapon, head, body, arms, hands, legs, boots; dog:
#        collar), each showing what he wears.
#          left / right   turn the ring (hold to spin)
#          up / down      change what's in the selected slot, right away
#          Tab / Back     the other one's gear (you keep driving the same one)
#          I / Esc / B    close
#        The panel under the ring says what the piece is and what it does,
#        and how your total changed.
#
# FRIENDLIER THAN THE ORIGINAL (owner, 2026-10-08): every ring is a tab you
#   can see at the top (no cycling through rings to find one); turning is
#   quick and a held direction keeps spinning; a change takes effect without
#   a confirm step; the kid's and the dog's gear are one button apart.
#   Quick slots (use an item or formula without opening the menu) come with
#   the Items and Alchemy rings.
#
# DIRECTIONS are polled every frame, not read from events: a stick sends a
#   stream of motion events while held, which would spin the ring wildly.
#   Polling gives one turn per push, then a steady repeat while held.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends CanvasLayer

signal opened
signal closed

## The rings, as tabs. Later: items, alchemy, party.
const RINGS := [{"id": "equipment", "label": "Equipment"}]
## Ring size around the character (canvas px at the 640x360 base).
const RADIUS := 56.0
## Empty slots show a faded icon of what goes there (item sheet cells).
const SLOT_ICONS := {"weapon": Vector2i(8, 1), "head": Vector2i(1, 1), "body": Vector2i(6, 3),
		"arms": Vector2i(3, 1), "hands": Vector2i(2, 1), "legs": Vector2i(13, 4),
		"boots": Vector2i(13, 3), "collar": Vector2i(10, 6)}
## The ring circles his middle: how high that is above his feet (px).
const CENTER_HEIGHT := {"kid": 26.0, "dog": 12.0}
const SLOT_RADIUS := 14.0
## Turning speed: how quickly the ring eases to the selected slot (1/s).
const TURN_EASE := 28.0
## Hold a direction: first repeat after this long, then one per REPEAT_EVERY.
const REPEAT_DELAY := 0.3
const REPEAT_EVERY := 0.08
## How long "+8" (the change to your total) stays up.
const DELTA_SECONDS := 1.5
const SELECT := Color(0.95, 0.85, 0.6)
const SLOT_BG := Color(0.06, 0.05, 0.1, 0.88)

## Whose gear the menu shows: "kid" or "dog".
var who := "kid"

var _root: Control
var _view: _RingView
var _tabs: HBoxContainer
var _header: Label
var _title: Label
var _desc: Label
var _stats: Label
var _hint: Label
## Selected slot per wearer (kept between openings). Unwrapped: it can go
## past the slot count; the ring eases toward it and looks it up modulo.
var _sel := {"kid": 0, "dog": 0}
var _anim := 0.0
var _h_dir := 0
var _h_timer := 0.0
var _v_dir := 0
var _v_timer := 0.0
var _delta_text := ""
var _delta_left := 0.0


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _root != null and _root.visible


## Open on whoever you drive. False if it can't open now (talking, paused).
func open() -> bool:
	if is_open() or Dialogue.is_active() or PauseMenu.is_open() or get_tree().paused:
		return false
	if not is_instance_valid(Party.leader):
		return false
	if _root == null:
		_build()
	who = Equipment.who_of(Party.leader)
	_anim = float(_sel[who])
	_h_dir = _dir_h()  # a direction already held doesn't count as a push
	_v_dir = _dir_v()
	_delta_left = 0.0
	_root.visible = true
	get_tree().paused = true
	Audio.play("ui_open")
	_refresh()
	opened.emit()
	return true


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	get_tree().paused = false
	Audio.play("ui_back")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed("ring_menu") and open():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ring_menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
	elif event.is_action_pressed("switch_control"):
		flip()
	# Everything else stays with the menu while it's open.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	_poll(delta)
	_anim = lerpf(_anim, float(_sel[who]), 1.0 - exp(-delta * TURN_EASE))
	if absf(_anim - _sel[who]) < 0.001:
		_anim = float(_sel[who])
	if _delta_left > 0.0:
		_delta_left -= delta
		if _delta_left <= 0.0:
			_refresh()
	_view.queue_redraw()


# -----------------------------------------------------------------------------
# What the controls do
# -----------------------------------------------------------------------------
## Turn the ring by `steps` slots (positive = clockwise).
func turn(steps: int) -> void:
	if slots().size() < 2:
		return
	_sel[who] += steps
	_delta_left = 0.0
	Audio.play("ui_move")
	_refresh()


## Put the next (or previous) owned piece in the selected slot.
func cycle(steps: int) -> void:
	var slot := selected_slot()
	var options := Equipment.options(who, slot)
	if options.size() < 2:
		return
	var current := Equipment.equipped(who, slot)
	var before := Equipment.defense(who)
	var i := maxi(options.find(current), 0)
	if Equipment.equip(who, slot, options[posmod(i + steps, options.size())]):
		var change := Equipment.defense(who) - before
		_delta_text = "" if is_zero_approx(change) else ("%+d" % roundi(change))
		_delta_left = DELTA_SECONDS
		Audio.play("ui_confirm")
	_refresh()


## Show the other one's gear (you keep driving the same one).
func flip() -> void:
	var other := "dog" if who == "kid" else "kid"
	if not is_instance_valid(_member(other)):
		return
	who = other
	_anim = float(_sel[who])
	_delta_left = 0.0
	Audio.play("ui_move")
	_refresh()


## The selected slot's name ("weapon", "head", ...).
func slots() -> Array:
	return Equipment.SLOTS[who]


func selected_slot() -> String:
	var s := slots()
	return s[posmod(_sel[who], s.size())]


## Where the ring is centered on screen (canvas coordinates).
func ring_center() -> Vector2:
	var m := _member(who)
	var size := _root.get_viewport_rect().size if _root else Vector2(640, 360)
	var c := Fx.world_to_screen(m.global_position, CENTER_HEIGHT[who]) if is_instance_valid(m) else size * 0.5
	# Keep the whole ring on screen and clear of the info panel.
	var margin := RADIUS + SLOT_RADIUS + 4.0
	return Vector2(clampf(c.x, margin, size.x - margin), clampf(c.y, margin + 22.0, size.y - margin - 84.0))


## Everything the panel says, one string (tests read it).
func info_text() -> String:
	return "%s\n%s\n%s\n%s" % [_header.text, _title.text, _desc.text, _stats.text]


func _member(w: String) -> Node2D:
	return Party.dog if w == "dog" else Party.kid


func _dir_h() -> int:
	var x := Input.get_axis("move_left", "move_right")
	return 0 if absf(x) < 0.5 else int(signf(x))


func _dir_v() -> int:
	var y := Input.get_axis("move_up", "move_down")
	return 0 if absf(y) < 0.5 else int(signf(y))


## One step per push, then a steady repeat while held.
func _poll(delta: float) -> void:
	var h := _dir_h()
	if h != _h_dir:
		_h_dir = h
		_h_timer = REPEAT_DELAY
		if h != 0:
			turn(h)
	elif h != 0:
		_h_timer -= delta
		if _h_timer <= 0.0:
			_h_timer = REPEAT_EVERY
			turn(h)
	var v := _dir_v()
	if v != _v_dir:
		_v_dir = v
		_v_timer = REPEAT_DELAY
		if v != 0:
			cycle(v)
	elif v != 0:
		_v_timer -= delta
		if _v_timer <= 0.0:
			_v_timer = REPEAT_EVERY
			cycle(v)


# -----------------------------------------------------------------------------
# Building and filling the screen
# -----------------------------------------------------------------------------
func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = MenuTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	# Every ring as a tab across the top: you see them all at once.
	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tabs.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tabs.offset_top = 6
	_tabs.add_theme_constant_override("separation", 10)
	_root.add_child(_tabs)
	for r: Dictionary in RINGS:
		var t := Label.new()
		t.name = String(r["id"]).capitalize()
		t.text = r["label"]
		_tabs.add_child(t)

	_view = _RingView.new()
	_view.name = "Ring"
	_view.menu = self
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_view)

	var panel := PanelContainer.new()
	panel.name = "Info"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -6
	panel.custom_minimum_size = Vector2(300, 0)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	_header = _label(box, "Header", MenuTheme.DIM)
	_title = _label(box, "Title", MenuTheme.BORDER)
	_desc = _label(box, "Description", MenuTheme.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats = _label(box, "Stats", MenuTheme.TEXT)
	_hint = _label(box, "Hint", MenuTheme.DIM)


func _label(parent: Control, label_name: String, color: Color) -> Label:
	var l := Label.new()
	l.name = label_name
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _refresh() -> void:
	if _root == null:
		return
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Label).add_theme_color_override("font_color", MenuTheme.BORDER)
	var m := _member(who)
	var name_text := GameState.get_dog_name() if who == "dog" else GameState.get_kid_name()
	_header.text = "%s's gear" % name_text
	var slot := selected_slot()
	var piece := Equipment.equipped(who, slot)
	var slot_name: String = Equipment.SLOT_NAMES.get(slot, slot)
	var options := Equipment.options(who, slot)
	_title.text = "%s: %s" % [slot_name, piece.display_name if piece else "nothing"]
	if piece:
		_desc.text = piece.description + ("\nPerk: " + piece.perk if not piece.perk.is_empty() else "")
	elif options.size() < 2:
		_desc.text = "Nothing to wear here yet."
	else:
		_desc.text = "Empty."
	var total := Equipment.defense(who)
	var line := ""
	if piece and piece.weapon:
		var w := piece.weapon
		line = "Damage %d   Reach %d   Charges up to x%d" % [roundi(w.damage), roundi(w.reach),
				ChargeMeter.LEVEL_MULTIPLIER[w.max_level]]
	elif piece:
		line = "Defense %d" % roundi(piece.defense)
	line += ("   " if not line.is_empty() else "") + "Total defense %d" % roundi(total)
	if _delta_left > 0.0 and not _delta_text.is_empty():
		line += " (%s)" % _delta_text
	_stats.text = line
	var other := "dog" if who == "kid" else "kid"
	var other_name := GameState.get_dog_name() if other == "dog" else GameState.get_kid_name()
	var hints := PackedStringArray()
	if slots().size() > 1:
		hints.append("Left/Right: slot")
	if options.size() > 1:
		hints.append("Up/Down: change")
	if is_instance_valid(_member(other)):
		hints.append("%s: %s" % [_key("switch_control"), other_name])
	hints.append("%s: close" % _key("ring_menu"))
	_hint.text = "   ".join(hints)
	if not is_instance_valid(m):
		_title.text = ""


func _key(action: String) -> String:
	var keys: Array = InputSetup.bindings_of(action)["keys"]
	return InputSetup.key_label(keys[0]) if not keys.is_empty() else "?"


## Draws the ring: a slot per piece of gear, the selected one at the top.
class _RingView extends Control:
	var menu: Node

	func _draw() -> void:
		var slots: Array = menu.slots()
		var n := slots.size()
		var center: Vector2 = menu.ring_center()
		var sel_i: int = posmod(menu._sel[menu.who], n)
		var font := get_theme_default_font()
		draw_arc(center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 1.0, true)
		for i in n:
			var ang: float = -PI / 2.0 + (i - menu._anim) * TAU / n
			var p := center + Vector2(cos(ang), sin(ang)) * RADIUS
			var selected := i == sel_i
			var r := SLOT_RADIUS * (1.2 if selected else 1.0)
			draw_circle(p, r, SLOT_BG)
			draw_arc(p, r, 0.0, TAU, 24, SELECT if selected else Color(1, 1, 1, 0.35), 1.5 if selected else 1.0, true)
			var piece: EquipmentData = Equipment.equipped(menu.who, slots[i])
			if piece:
				var src := Rect2(Vector2(piece.icon_cell * 32), Vector2(32, 32))
				var size := r * 1.6
				draw_texture_rect_region(ItemData.ICONS, Rect2(p - Vector2(size, size) * 0.5, Vector2(size, size)), src)
			else:
				# Empty: a faded picture of what goes there.
				var cell: Vector2i = SLOT_ICONS.get(slots[i], Vector2i.ZERO)
				var size := r * 1.4
				draw_texture_rect_region(ItemData.ICONS, Rect2(p - Vector2(size, size) * 0.5, Vector2(size, size)),
						Rect2(Vector2(cell * 32), Vector2(32, 32)), Color(0.75, 0.75, 0.8, 0.4))
			if selected:
				var label: String = Equipment.SLOT_NAMES.get(slots[i], "")
				draw_string(font, p + Vector2(-40, -r - 4), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, SELECT)
				# Up/down arrows when there's something to switch to.
				if Equipment.options(menu.who, slots[i]).size() > 1:
					var a := p + Vector2(r + 7, 0)
					draw_colored_polygon(PackedVector2Array([a + Vector2(0, -7), a + Vector2(-3, -3), a + Vector2(3, -3)]), SELECT)
					draw_colored_polygon(PackedVector2Array([a + Vector2(0, 7), a + Vector2(-3, 3), a + Vector2(3, 3)]), SELECT)
