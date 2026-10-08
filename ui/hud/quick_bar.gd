# =============================================================================
# quick_bar.gd  -  The four quick slots on the HUD
# -----------------------------------------------------------------------------
# WHAT:  Four small boxes in the top-left corner: what's in each quick slot
#        (an item with how many are left, or a formula, faded when you're out
#        of its ingredients) and the key that fires it (1-4 / the D-pad).
#        Empty slots stay as outlines, so you can see there's room. Fill them
#        from the ring menu (select an item or formula, press 1-4).
#        Reads GameState every frame; no signals.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name QuickBar
extends Control

const CELL := 20.0
const GAP := 3.0
const BG := Color(0.06, 0.05, 0.1, 0.7)
const BORDER := Color(1, 1, 1, 0.35)


func _ready() -> void:
	custom_minimum_size = Vector2(CELL * 4 + GAP * 3, CELL + 9)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keeps drawing while the ring menu pauses the game: you see a slot fill
	# the moment you assign it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


## What a slot shows: [icon cell, count (-1 = none), faded]; empty slot = [].
static func slot_view(slot: int) -> Array:
	var entry: String = GameState.quick_slots[slot]
	if entry.begins_with("item:"):
		var it := ItemData.find(entry.substr(5))
		if it:
			var n := GameState.item_count(it.id)
			return [it.icon_cell, n, n <= 0]
	elif entry.begins_with("formula:"):
		var f := FormulaData.find(entry.substr(8))
		if f:
			return [f.icon_cell, -1, not Usables.missing_ingredients(f).is_empty()]
	return []


func _draw() -> void:
	var font := get_theme_default_font()
	for i in Usables.SLOTS:
		var r := Rect2(Vector2(i * (CELL + GAP), 0), Vector2(CELL, CELL))
		draw_rect(r, BG)
		draw_rect(r, BORDER, false, 1.0)
		var v := slot_view(i)
		if not v.is_empty():
			var cell: Vector2i = v[0]
			draw_texture_rect_region(ItemData.ICONS, r.grow(-1), Rect2(Vector2(cell * 32), Vector2(32, 32)),
					Color(1, 1, 1, 0.35) if v[2] else Color.WHITE)
			if int(v[1]) >= 0:
				draw_string(font, r.end + Vector2(-14, -1), str(v[1]), HORIZONTAL_ALIGNMENT_RIGHT, 13, 8, Color.WHITE)
		var keys: Array = InputSetup.bindings_of("quick_%d" % (i + 1))["keys"]
		var label := InputSetup.key_label(keys[0]) if not keys.is_empty() else ""
		draw_string(font, Vector2(r.position.x, CELL + 8), label, HORIZONTAL_ALIGNMENT_CENTER, CELL, 7,
				Color(1, 1, 1, 0.6))
