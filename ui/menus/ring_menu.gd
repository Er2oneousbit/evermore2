# =============================================================================
# ring_menu.gd  (autoload: RingMenu)
# -----------------------------------------------------------------------------
# WHAT:  I / gamepad Y pauses the game and opens a ring around whoever you
#        drive. Four rings, all shown as tabs along the top:
#          Equipment  his gear slots; up / down change what's in one
#          Items      what the party carries; confirm uses it on him
#          Alchemy    the kid's formulas; confirm casts it on him (it costs
#                     ingredients and gets stronger with use)
#          Party      both stances and Stay put; up / down change them
#        Controls:
#          left / right     turn the ring (hold to spin)
#          Z / X, LB / RB   the previous / next ring
#          E / A            use or cast (Items, Alchemy)
#          1-4 / D-pad      put the selected item or formula in a quick slot
#          Tab / Back       the other one (you keep driving the same one)
#          I / Esc / B      close
#        Outside the menu, 1-4 / the D-pad use the quick slots on whoever
#        you drive (Usables.fire_slot).
#
# FRIENDLIER THAN THE ORIGINAL (owner, 2026-10-08): every ring is a tab you
#   can see (no cycling through rings to find one); turning is quick and a
#   held direction keeps spinning; changes take effect without a confirm
#   step; the other one is one button away; quick slots mean you don't open
#   the menu for everything.
#
# DIRECTIONS are polled every frame, not read from events: a stick sends a
#   stream of motion events while held, which would spin the ring wildly.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends CanvasLayer

signal opened
signal closed

## The rings, as tabs, in order.
const RINGS := [
	{"id": "equipment", "label": "Equipment"},
	{"id": "items", "label": "Items"},
	{"id": "alchemy", "label": "Alchemy"},
	{"id": "party", "label": "Party"},
]
## Ring size around the character (canvas px at the 640x360 base).
const RADIUS := 56.0
const SLOT_RADIUS := 14.0
## Empty equipment slots show a faded icon of what goes there (item sheet).
const SLOT_ICONS := {"weapon": Vector2i(8, 1), "head": Vector2i(1, 1), "body": Vector2i(6, 3),
		"arms": Vector2i(3, 1), "hands": Vector2i(2, 1), "legs": Vector2i(13, 4),
		"boots": Vector2i(13, 3), "collar": Vector2i(10, 6)}
## The Party ring's entries and their icons.
const PARTY_ENTRIES := ["kid_stance", "dog_stance", "stay"]
const PARTY_ICONS := {"kid_stance": Vector2i(8, 1), "dog_stance": Vector2i(10, 6), "stay": Vector2i(7, 8)}
const STANCE_TEXT := {
	"offensive": ["Offensive", "goes after enemies near you"],
	"defensive": ["Defensive", "stays close and swings at full power at what comes within reach"],
	"search": ["Search", "keeps out of fights and sniffs out hidden items"],
}
## The ring circles his middle: how high that is above his feet (px).
const CENTER_HEIGHT := {"kid": 26.0, "dog": 12.0}
## Turning speed: how quickly the ring eases to the selected slot (1/s).
const TURN_EASE := 28.0
## Hold a direction: first repeat after this long, then one per REPEAT_EVERY.
const REPEAT_DELAY := 0.3
const REPEAT_EVERY := 0.08
## How long a note ("+8", "Apple -> slot 1", "Not enough wild carrot") shows.
const NOTE_SECONDS := 1.6
## Room kept under the ring for the info panel (canvas px).
const INFO_CLEAR := 100.0
const SELECT := Color(0.95, 0.85, 0.6)
const SLOT_BG := Color(0.06, 0.05, 0.1, 0.88)

## Whose ring the menu shows: "kid" or "dog".
var who := "kid"
## Which ring (index into RINGS).
var ring := 0

var _root: Control
var _view: _RingView
var _tabs: HBoxContainer
var _header: Label
var _title: Label
var _desc: Label
var _stats: Label
var _hint: Label
## Selected entry per "who:ring" (kept between openings). Unwrapped: it can
## go past the entry count; the ring eases toward it and looks it up modulo.
var _sel := {}
var _anim := 0.0
var _h_dir := 0
var _h_timer := 0.0
var _v_dir := 0
var _v_timer := 0.0
var _note := ""
var _note_left := 0.0


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
	_anim = float(_sel_now())
	_h_dir = _dir_h()  # a direction already held doesn't count as a push
	_v_dir = _dir_v()
	_note_left = 0.0
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
		var slot := _quick_slot_of(event)
		if slot >= 0 and not get_tree().paused and not Dialogue.is_active() and is_instance_valid(Party.leader):
			var why := Usables.fire_slot(slot, Party.leader)
			if not why.is_empty():
				EventBus.notice.emit(why)
				Audio.play("ui_back")
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ring_menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
	elif event.is_action_pressed("switch_control"):
		flip()
	# Rebindable actions before the ring keys, which aren't rebindable: a key
	# the player moved to confirm or a quick slot must do that, not flip rings.
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		confirm()
	elif _quick_slot_of(event) >= 0:
		assign(_quick_slot_of(event))
	elif event.is_action_pressed("ring_prev"):
		set_ring(ring - 1)
	elif event.is_action_pressed("ring_next"):
		set_ring(ring + 1)
	# Everything else stays with the menu while it's open.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	_poll(delta)
	_anim = lerpf(_anim, float(_sel_now()), 1.0 - exp(-delta * TURN_EASE))
	if absf(_anim - _sel_now()) < 0.001:
		_anim = float(_sel_now())
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			_refresh()
	_view.queue_redraw()


# -----------------------------------------------------------------------------
# What the controls do
# -----------------------------------------------------------------------------
func ring_id() -> String:
	return RINGS[ring]["id"]


## Switch to a ring (wraps around).
func set_ring(index: int) -> void:
	ring = posmod(index, RINGS.size())
	_anim = float(_sel_now())
	_note_left = 0.0
	Audio.play("ui_move")
	_refresh()


## Turn the ring by `steps` entries (positive = clockwise).
func turn(steps: int) -> void:
	if entries().size() < 2:
		return
	_sel[_key()] = _sel_now() + steps
	_note_left = 0.0
	Audio.play("ui_move")
	_refresh()


## Up / down: change what's in the selected slot (Equipment) or the selected
## setting (Party). Other rings: nothing.
func cycle(steps: int) -> void:
	var e := selected()
	if e.is_empty():
		return
	match ring_id():
		"equipment":
			var slot: String = e["key"]
			var options := Equipment.options(who, slot)
			if options.size() < 2:
				return
			var before := Equipment.defense(who)
			var i := maxi(options.find(Equipment.equipped(who, slot)), 0)
			if Equipment.equip(who, slot, options[posmod(i + steps, options.size())]):
				var change := Equipment.defense(who) - before
				_set_note("" if is_zero_approx(change) else ("%+d" % roundi(change)))
				Audio.play("ui_confirm")
		"party":
			match String(e["key"]):
				"kid_stance", "dog_stance":
					var member: Node2D = Party.kid if e["key"] == "kid_stance" else Party.dog
					var w := "kid" if e["key"] == "kid_stance" else "dog"
					if is_instance_valid(member):
						var list: Array = Party.STANCES[w]
						var i := maxi(list.find(Party.stance_of(member)), 0)
						Party.set_stance(member, list[posmod(i + steps, list.size())])
				"stay":
					if Party.partner():
						Party.set_staying(not Party.staying)
	_refresh()


## Confirm: use the selected item / cast the selected formula on him.
func confirm() -> void:
	var e := selected()
	if e.is_empty():
		return
	var target := _member(who)
	var why := ""
	var at := posmod(_sel_now(), entries().size())
	match ring_id():
		"items":
			why = Usables.use_item(e["key"], target)
		"alchemy":
			why = Usables.cast(e["key"], target)
		_:
			return
	if why.is_empty():
		var name_text := _name_of(who)
		_set_note("Used on %s" % name_text if ring_id() == "items" else "Cast on %s" % name_text)
		Audio.play("ui_confirm")
		_keep_selection_at(at)
	else:
		_set_note(why)
		Audio.play("ui_back")
	_refresh()


## Put the selected item or formula in quick slot `slot` (0-3).
func assign(slot: int) -> void:
	var e := selected()
	if e.is_empty():
		return
	var entry := ""
	match ring_id():
		"items":
			var item := ItemData.find(e["key"])
			if item == null or item.use_effect.is_empty():
				_set_note("Only things you can use go in a quick slot")
				_refresh()
				return
			entry = "item:" + item.id
		"alchemy":
			entry = "formula:" + String(e["key"])
		_:
			return
	Usables.assign_slot(slot, entry)
	_set_note("%s -> quick slot %d" % [e["label"], slot + 1])
	Audio.play("ui_confirm")
	_refresh()


## Show the other one (you keep driving the same one).
func flip() -> void:
	var other := "dog" if who == "kid" else "kid"
	if not is_instance_valid(_member(other)):
		return
	who = other
	_anim = float(_sel_now())
	_note_left = 0.0
	Audio.play("ui_move")
	_refresh()


## The current ring's entries: [{key, label, icon (Vector2i), faded, count}].
func entries() -> Array:
	var out := []
	match ring_id():
		"equipment":
			for slot: String in Equipment.SLOTS[who]:
				var piece := Equipment.equipped(who, slot)
				out.append({"key": slot, "label": Equipment.SLOT_NAMES[slot],
						"icon": piece.icon_cell if piece else SLOT_ICONS.get(slot, Vector2i.ZERO),
						"faded": piece == null, "count": -1})
		"items":
			var items := []
			for id: String in GameState.inventory:
				var it := ItemData.find(id)
				if it and not (it is EquipmentData) and GameState.item_count(id) > 0:
					items.append(it)
			# Things you can use first, then ingredients, then key items.
			items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				var ra := _item_rank(a)
				var rb := _item_rank(b)
				return ra < rb if ra != rb else a.display_name < b.display_name)
			for it: ItemData in items:
				out.append({"key": it.id, "label": it.display_name, "icon": it.icon_cell,
						"faded": false, "count": GameState.item_count(it.id)})
		"alchemy":
			var known := GameState.formulas.keys()
			known.sort()
			for id: String in known:
				var f := FormulaData.find(id)
				if f:
					out.append({"key": id, "label": f.display_name, "icon": f.icon_cell,
							"faded": not Usables.missing_ingredients(f).is_empty(), "count": -1})
		"party":
			for k: String in PARTY_ENTRIES:
				out.append({"key": k, "label": _party_label(k), "icon": PARTY_ICONS[k],
						"faded": k == "stay" and not Party.staying, "count": -1})
	return out


## The selected entry ({} when the ring is empty).
func selected() -> Dictionary:
	var list := entries()
	if list.is_empty():
		return {}
	return list[posmod(_sel_now(), list.size())]


## The selected equipment slot's name ("" on other rings).
func selected_slot() -> String:
	return String(selected().get("key", "")) if ring_id() == "equipment" else ""


func slots() -> Array:
	return Equipment.SLOTS[who]


## Where the ring is centered on screen (canvas coordinates).
func ring_center() -> Vector2:
	var m := _member(who)
	var size := _root.get_viewport_rect().size if _root else Vector2(640, 360)
	var c := Fx.world_to_screen(m.global_position, CENTER_HEIGHT[who]) if is_instance_valid(m) else size * 0.5
	# Keep the whole ring on screen and clear of the info panel.
	var margin := RADIUS + SLOT_RADIUS + 4.0
	return Vector2(clampf(c.x, margin, size.x - margin), clampf(c.y, margin + 22.0, size.y - margin - INFO_CLEAR))


## Everything the panel says, one string (tests read it).
func info_text() -> String:
	return "%s\n%s\n%s\n%s\n%s" % [_header.text, _title.text, _desc.text, _stats.text, _hint.text]


func _key() -> String:
	return "%s:%s" % [who, ring_id()]


func _sel_now() -> int:
	return int(_sel.get(_key(), 0))


## After using the last of something the list is shorter: stay where it was
## (now the next entry), or the last one. The stored selection is unwrapped,
## so wrapping the old number into the new length could skip an entry.
func _keep_selection_at(at: int) -> void:
	var n := entries().size()
	if n > 0:
		_sel[_key()] = mini(at, n - 1)
		_anim = float(_sel_now())


func _set_note(text: String) -> void:
	_note = text
	_note_left = NOTE_SECONDS if not text.is_empty() else 0.0


func _member(w: String) -> Node2D:
	return Party.dog if w == "dog" else Party.kid


func _name_of(w: String) -> String:
	return GameState.get_dog_name() if w == "dog" else GameState.get_kid_name()


func _item_rank(it: ItemData) -> int:
	if not it.use_effect.is_empty():
		return 0
	return 1 if it.kind == "ingredient" else 2


func _party_label(k: String) -> String:
	match k:
		"kid_stance":
			return "%s's stance" % GameState.get_kid_name()
		"dog_stance":
			return "%s's stance" % GameState.get_dog_name()
	return "Stay put"


func _quick_slot_of(event: InputEvent) -> int:
	for i in Usables.SLOTS:
		if event.is_action_pressed("quick_%d" % (i + 1)):
			return i
	return -1


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
	_tabs.add_theme_constant_override("separation", 14)
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
	panel.custom_minimum_size = Vector2(320, 0)
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
		(_tabs.get_child(i) as Label).add_theme_color_override("font_color", SELECT if i == ring else MenuTheme.DIM)
	var name_text := _name_of(who)
	var e := selected()
	var hints := PackedStringArray()
	if entries().size() > 1:
		hints.append("Left/Right: pick")
	_title.text = ""
	_desc.text = ""
	_stats.text = ""
	match ring_id():
		"equipment":
			_header.text = "%s's gear" % name_text
			_fill_equipment(e, hints)
		"items":
			_header.text = "Items (used on %s)" % name_text
			_fill_item(e, hints)
		"alchemy":
			_header.text = "Alchemy (cast on %s)" % name_text
			_fill_formula(e, hints)
		"party":
			_header.text = "Party"
			_fill_party(e, hints)
	if _note_left > 0.0 and not _note.is_empty():
		_stats.text += ("   " if not _stats.text.is_empty() else "") + "(%s)" % _note
	var other := "dog" if who == "kid" else "kid"
	if is_instance_valid(_member(other)) and ring_id() != "party":
		hints.append("%s: %s" % [_key_name("switch_control"), _name_of(other)])
	hints.append("%s/%s: rings" % [_key_name("ring_prev"), _key_name("ring_next")])
	hints.append("%s: close" % _key_name("ring_menu"))
	_hint.text = "   ".join(hints)


func _fill_equipment(e: Dictionary, hints: PackedStringArray) -> void:
	var slot: String = e.get("key", "")
	var piece := Equipment.equipped(who, slot)
	var options := Equipment.options(who, slot)
	_title.text = "%s: %s" % [Equipment.SLOT_NAMES.get(slot, slot), piece.display_name if piece else "nothing"]
	if piece:
		_desc.text = piece.description + ("\nPerk: " + piece.perk if not piece.perk.is_empty() else "")
	else:
		_desc.text = "Nothing to wear here yet." if options.size() < 2 else "Empty."
	var line := ""
	if piece and piece.weapon:
		var w := piece.weapon
		line = "Damage %d   Reach %d   Charges up to x%d   " % [roundi(w.damage), roundi(w.reach),
				ChargeMeter.LEVEL_MULTIPLIER[w.max_level]]
	elif piece:
		line = "Defense %d   " % roundi(piece.defense)
	_stats.text = line + "Total defense %d" % roundi(Equipment.defense(who))
	if options.size() > 1:
		hints.append("Up/Down: change")


func _fill_item(e: Dictionary, hints: PackedStringArray) -> void:
	if e.is_empty():
		_title.text = "Nothing here yet"
		_desc.text = "Things you find and buy show up here."
		return
	var it := ItemData.find(e["key"])
	_title.text = "%s  x%d" % [it.display_name, GameState.item_count(it.id)]
	_desc.text = it.description
	if it.use_effect == "heal":
		_stats.text = "Heals %d HP" % it.use_power
		hints.append("%s: use" % _key_name("interact"))
		hints.append("%s: quick slot" % _slot_keys())
	elif it.kind == "ingredient":
		_stats.text = "Alchemy ingredient"
	else:
		_stats.text = "Key item"
	var s := _slot_of("item:" + it.id)
	if s >= 0:
		_stats.text += "   In quick slot %d" % (s + 1)


func _fill_formula(e: Dictionary, hints: PackedStringArray) -> void:
	if e.is_empty():
		_title.text = "No formulas yet"
		_desc.text = "Alchemists teach formulas."
		return
	var f := FormulaData.find(e["key"])
	var lvl := Usables.level_of(f.id)
	_title.text = "%s  Lv %d" % [f.display_name, lvl]
	_desc.text = f.description
	var costs := PackedStringArray()
	for id: String in f.costs:
		var ing := ItemData.find(id)
		costs.append("%d %s (have %d)" % [int(f.costs[id]), ing.display_name.to_lower() if ing else id, GameState.item_count(id)])
	var next := Usables.xp_needed(f.id)
	_stats.text = "Heals %d HP   Costs %s   %s" % [f.power_at(lvl), ", ".join(costs),
			("Next level in %d %s" % [next, "cast" if next == 1 else "casts"]) if next > 0 else "Top level"]
	var s := _slot_of("formula:" + f.id)
	if s >= 0:
		_stats.text += "   In quick slot %d" % (s + 1)
	hints.append("%s: cast" % _key_name("interact"))
	hints.append("%s: quick slot" % _slot_keys())


func _fill_party(e: Dictionary, hints: PackedStringArray) -> void:
	var k: String = e.get("key", "")
	match k:
		"kid_stance", "dog_stance":
			var member: Node2D = Party.kid if k == "kid_stance" else Party.dog
			var st := Party.stance_of(member) if is_instance_valid(member) else "offensive"
			var t: Array = STANCE_TEXT.get(st, [st, ""])
			_title.text = "%s: %s" % [_party_label(k), t[0]]
			_desc.text = "When you aren't driving him, he %s." % t[1]
		"stay":
			var p := Party.partner()
			_title.text = "Stay put: %s" % ("On" if Party.staying else "Off")
			_desc.text = ("%s holds his spot until you call him back." % _name_of(Equipment.who_of(p))) if p \
					else "Nobody to leave behind."
	hints.append("Up/Down: change")


func _slot_of(entry: String) -> int:
	return GameState.quick_slots.find(entry)


## The quick slot keys as the player has them ("1-4" by default).
func _slot_keys() -> String:
	var names := PackedStringArray()
	for i in Usables.SLOTS:
		names.append(_key_name("quick_%d" % (i + 1)))
	return "1-4" if names == PackedStringArray(["1", "2", "3", "4"]) else "/".join(names)


func _key_name(action: String) -> String:
	var keys: Array = InputSetup.bindings_of(action)["keys"]
	return InputSetup.key_label(keys[0]) if not keys.is_empty() else "?"


## Draws the ring: a slot per entry, the selected one at the top.
class _RingView extends Control:
	var menu: Node

	func _draw() -> void:
		var list: Array = menu.entries()
		var center: Vector2 = menu.ring_center()
		var font := get_theme_default_font()
		draw_arc(center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 1.0, true)
		var n := list.size()
		if n == 0:
			draw_string(font, center + Vector2(-60, 4), "(empty)", HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(1, 1, 1, 0.5))
			return
		var sel_i: int = posmod(menu._sel_now(), n)
		for i in n:
			var e: Dictionary = list[i]
			var ang: float = -PI / 2.0 + (i - menu._anim) * TAU / n
			var p := center + Vector2(cos(ang), sin(ang)) * RADIUS
			var selected := i == sel_i
			var r := SLOT_RADIUS * (1.2 if selected else 1.0)
			draw_circle(p, r, SLOT_BG)
			draw_arc(p, r, 0.0, TAU, 24, SELECT if selected else Color(1, 1, 1, 0.35), 1.5 if selected else 1.0, true)
			var cell: Vector2i = e["icon"]
			var size := r * (1.4 if e["faded"] else 1.6)
			var tint := Color(0.75, 0.75, 0.8, 0.4) if e["faded"] else Color.WHITE
			draw_texture_rect_region(ItemData.ICONS, Rect2(p - Vector2(size, size) * 0.5, Vector2(size, size)),
					Rect2(Vector2(cell * 32), Vector2(32, 32)), tint)
			if int(e["count"]) >= 0:
				draw_string(font, p + Vector2(r - 9, r + 2), str(e["count"]), HORIZONTAL_ALIGNMENT_RIGHT, 14, 9, Color.WHITE)
			if selected:
				draw_string(font, p + Vector2(-60, -r - 4), String(e["label"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 10, SELECT)
				if menu.ring_id() == "equipment" or menu.ring_id() == "party":
					var a := p + Vector2(r + 7, 0)
					draw_colored_polygon(PackedVector2Array([a + Vector2(0, -7), a + Vector2(-3, -3), a + Vector2(3, -3)]), SELECT)
					draw_colored_polygon(PackedVector2Array([a + Vector2(0, 7), a + Vector2(-3, 3), a + Vector2(3, 3)]), SELECT)
