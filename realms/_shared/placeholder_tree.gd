# =============================================================================
# placeholder_tree.gd  -  Drawn tree with a solid trunk (no art needed)
# -----------------------------------------------------------------------------
# WHAT:  A tree whose origin is the TRUNK BASE. Only the trunk is solid; the
#        canopy is just drawn, so the kid can walk "behind" it.
# Y-SORT: put trees under a parent with y_sort_enabled = true (the level's
#        World node). Anything whose origin is above the trunk base (smaller y)
#        draws first, so the canopy covers it. That's the whole trick.
# REPLACE WITH: a Sprite2D tree scene (same origin convention) once art exists.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name PlaceholderTree
extends Node2D

const COLOR_SHADOW := Color(0, 0, 0, 0.3)
const COLOR_TRUNK := Color("6b4423")
const COLOR_LEAF_DARK := Color("2f6b2a")
const COLOR_LEAF := Color("3f8a35")
const COLOR_LEAF_LIGHT := Color("5aa845")


func _ready() -> void:
	# Small solid trunk footprint on the "world" physics layer (layer 1).
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 5)
	col.shape = shape
	col.position = Vector2(0, -2)
	body.add_child(col)
	add_child(body)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 12.0, COLOR_SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_rect(Rect2(-3, -12, 6, 12), COLOR_TRUNK)
	draw_circle(Vector2(-7, -18), 8.0, COLOR_LEAF_DARK)
	draw_circle(Vector2(7, -18), 8.0, COLOR_LEAF_DARK)
	draw_circle(Vector2(0, -24), 10.0, COLOR_LEAF)
	draw_circle(Vector2(-3, -27), 4.0, COLOR_LEAF_LIGHT)
