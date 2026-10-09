# =============================================================================
# shop_shutter.gd  -  The "closed" shutter over a shop's counter
# -----------------------------------------------------------------------------
# WHAT:  A slatted panel with a blank sign that covers a stall while its Shop
#        is closed. Walk up and talk to it: the shop's "closed" dialogue node
#        says when it opens. Hidden (and so not talkable) while the shop is open.
# WHY A NODE, NOT A PROP: props are baked into the HD-2D view once; this one
#        comes and goes with the clock, so it's an "hd_actor" whose own
#        `visible` HdView mirrors every frame.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name ShopShutter
extends Node2D

## How close the kid must be to read it (px).
## (A bit long: in HD-2D the 3D counter keeps him about 55 px from the stall.)
@export var interact_range := 72.0

var shop: Shop


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("hd_actor")
	# HD-2D draws the closed shutter as a 3D panel (ShopBuilding3D), not a quad.
	set_meta("hd_skip", true)
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = Shop.SHUTTER_TEXTURE
	# Origin at the feet: the panel's bottom edge sits on the stall's base.
	s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	add_child(s)


func interact() -> void:
	if shop and not shop.closed_node.is_empty():
		Dialogue.start(shop.dialogue_file, shop.closed_node, self)


func interact_label() -> String:
	return "Read the sign"
